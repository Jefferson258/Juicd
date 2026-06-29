-- Juicd — core production schema: profiles/stats, groups, tournaments, bet slips,
-- points ledger, and bet-consensus aggregates ("% of points on each side").
--
-- Mirrors the Swift models in Models/JuicdModels.swift. The client currently
-- uses an in-memory repository; this is the production backing store.
--
-- Idempotent: safe to rerun. Uses create-if-not-exists, add-column-if-not-exists,
-- create-or-replace for functions/triggers, drop-policy-if-exists before create,
-- and insert ... on conflict do nothing for seeds.

-- =============================================================================
-- 1. Profiles + per-user stats
-- =============================================================================
create table if not exists public.juicd_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Player',
  mmr double precision,
  current_tier text not null default 'bronze'
    check (current_tier in ('bronze','silver','gold','platinum','emerald','diamond','challenger','champion')),
  season_points_won integer not null default 0,
  all_time_points_won integer not null default 0,
  available_daily_points integer not null default 0,
  last_daily_points_award_date text,            -- local slate key yyyy-MM-dd (6am boundary)
  last_daily_match jsonb,                        -- DailyMatchSnapshot
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint juicd_profiles_display_name_len check (char_length(display_name) between 1 and 40)
);
create index if not exists juicd_profiles_mmr_idx on public.juicd_profiles (mmr desc nulls last);
create index if not exists juicd_profiles_season_pts_idx on public.juicd_profiles (season_points_won desc);
create index if not exists juicd_profiles_alltime_pts_idx on public.juicd_profiles (all_time_points_won desc);

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.juicd_handle_new_user()
  returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.juicd_profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Player'))
  on conflict (id) do nothing;
  return new;
end;
$$;
create or replace trigger juicd_on_auth_user_created
  after insert on auth.users for each row execute function public.juicd_handle_new_user();

-- =============================================================================
-- 2. Groups + memberships (private leagues, invite codes)
-- =============================================================================
create table if not exists public.juicd_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint juicd_groups_name_len check (char_length(name) between 1 and 60)
);

create table if not exists public.juicd_group_members (
  group_id uuid not null references public.juicd_groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists juicd_group_members_user_idx on public.juicd_group_members (user_id);

-- security-definer helper avoids RLS recursion on group_members policies
create or replace function public.juicd_my_group_ids()
  returns setof uuid language sql security definer set search_path = public stable as $$
  select group_id from public.juicd_group_members where user_id = auth.uid();
$$;

-- Join a group by invite code atomically (bypasses RLS via security definer).
create or replace function public.juicd_join_group_by_code(p_code text)
  returns uuid language plpgsql security definer set search_path = public as $$
declare g_id uuid;
begin
  select id into g_id from public.juicd_groups where invite_code = p_code;
  if g_id is null then raise exception 'invalid invite code'; end if;
  insert into public.juicd_group_members (group_id, user_id, role)
  values (g_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
  return g_id;
end;
$$;

-- =============================================================================
-- 3. Tournaments (daily / weekly group / season) + per-user entries
-- =============================================================================
create table if not exists public.juicd_tournaments (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('daily','weeklyGroup','season')),
  status text not null default 'upcoming' check (status in ('upcoming','active','finished')),
  start_at timestamptz not null,
  end_at timestamptz not null,
  stage_count integer not null default 4,
  season_year integer,
  group_id uuid references public.juicd_groups (id) on delete cascade,  -- set for weeklyGroup
  created_at timestamptz not null default now()
);
create index if not exists juicd_tournaments_status_idx on public.juicd_tournaments (status, start_at desc);
create index if not exists juicd_tournaments_group_idx on public.juicd_tournaments (group_id);

-- A user's bracket state in a tournament (DailyClosestTournamentState).
create table if not exists public.juicd_tournament_entries (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.juicd_tournaments (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  day_iso text not null,
  game_id text,
  game_label text,
  tournament_name text,
  bracket_size integer not null default 16,
  user_slot integer not null default 0,
  next_quarter integer not null default 1,
  eliminated boolean not null default false,
  completed boolean not null default false,
  rounds_completed jsonb not null default '[]',   -- [DailyClosestQuarterResult]
  round_specs jsonb not null default '[]',         -- [DailyRoundPropSpec]
  placement integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tournament_id, user_id)
);
create index if not exists juicd_tournament_entries_user_idx on public.juicd_tournament_entries (user_id);
create index if not exists juicd_tournament_entries_tourney_idx on public.juicd_tournament_entries (tournament_id);

-- =============================================================================
-- 4. Bet slips (Play parlays + ranked daily) and the points ledger
-- =============================================================================
create table if not exists public.juicd_bet_slips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tournament_id uuid references public.juicd_tournaments (id) on delete set null,
  slate_day_key text not null,
  stage_index integer not null default 1,
  stake_points integer not null default 0,
  legs jsonb not null default '[]',                -- [BetLeg]
  leg_summaries jsonb not null default '[]',       -- [String] (display)
  combined_odds double precision not null default 1,
  implied_parlay_odds double precision not null default 1,
  estimated_net_points integer not null default 0,
  status text not null default 'submitted'
    check (status in ('composing','submitted','resolved','eliminated')),
  did_win boolean not null default false,
  season_points_earned integer not null default 0,
  play_leg_wins integer not null default 0,
  play_leg_losses integer not null default 0,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists juicd_bet_slips_user_idx on public.juicd_bet_slips (user_id, created_at desc);
create index if not exists juicd_bet_slips_slate_idx on public.juicd_bet_slips (slate_day_key);
create index if not exists juicd_bet_slips_status_idx on public.juicd_bet_slips (status);

create table if not exists public.juicd_points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tournament_id uuid references public.juicd_tournaments (id) on delete set null,
  bet_slip_id uuid references public.juicd_bet_slips (id) on delete set null,
  delta_points integer not null,
  reason text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists juicd_points_ledger_user_idx on public.juicd_points_ledger (user_id, created_at desc);

-- =============================================================================
-- 5. Bet consensus / "action" — % of points + tickets on each side of a prop
-- =============================================================================
-- One row per (slate, prop, side). Incremented when a slip is submitted, so the
-- app can show "67% of points are on the Over" style consensus.
create table if not exists public.juicd_prop_action (
  slate_day_key text not null,
  prop_id text not null,           -- stable id for the market/prop
  prop_label text not null default '',
  choice_label text not null,      -- the side: "Over", "Under", "Home Win", ...
  total_stake_points bigint not null default 0,
  bet_count bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (slate_day_key, prop_id, choice_label)
);
create index if not exists juicd_prop_action_slate_idx on public.juicd_prop_action (slate_day_key, prop_id);

-- Record action on one side of a prop (call once per leg when a slip is placed).
create or replace function public.juicd_record_prop_action(
  p_slate text, p_prop_id text, p_prop_label text, p_choice text, p_stake bigint
) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.juicd_prop_action (slate_day_key, prop_id, prop_label, choice_label, total_stake_points, bet_count, updated_at)
  values (p_slate, p_prop_id, coalesce(p_prop_label,''), p_choice, greatest(p_stake,0), 1, now())
  on conflict (slate_day_key, prop_id, choice_label) do update
    set total_stake_points = public.juicd_prop_action.total_stake_points + greatest(p_stake,0),
        bet_count = public.juicd_prop_action.bet_count + 1,
        prop_label = coalesce(nullif(excluded.prop_label,''), public.juicd_prop_action.prop_label),
        updated_at = now();
end;
$$;

-- View: each side's share of points and tickets within its prop.
create or replace view public.juicd_prop_action_split as
select
  a.slate_day_key,
  a.prop_id,
  a.prop_label,
  a.choice_label,
  a.total_stake_points,
  a.bet_count,
  sum(a.total_stake_points) over (partition by a.slate_day_key, a.prop_id) as prop_total_stake,
  sum(a.bet_count) over (partition by a.slate_day_key, a.prop_id) as prop_total_bets,
  case when sum(a.total_stake_points) over (partition by a.slate_day_key, a.prop_id) > 0
    then round(100.0 * a.total_stake_points
      / sum(a.total_stake_points) over (partition by a.slate_day_key, a.prop_id), 1)
    else 0 end as pct_of_points,
  case when sum(a.bet_count) over (partition by a.slate_day_key, a.prop_id) > 0
    then round(100.0 * a.bet_count
      / sum(a.bet_count) over (partition by a.slate_day_key, a.prop_id), 1)
    else 0 end as pct_of_tickets
from public.juicd_prop_action a;

-- =============================================================================
-- 6. Leaderboard views
-- =============================================================================
create or replace view public.juicd_season_leaderboard as
select id as user_id, display_name, current_tier, mmr, season_points_won,
       rank() over (order by season_points_won desc) as season_rank
from public.juicd_profiles;

create or replace view public.juicd_alltime_leaderboard as
select id as user_id, display_name, current_tier, mmr, all_time_points_won,
       rank() over (order by all_time_points_won desc) as alltime_rank
from public.juicd_profiles;

-- Per-user career betting summary (mirrors CareerBettingStats roll-ups).
create or replace view public.juicd_career_betting_stats as
select
  s.user_id,
  count(*) filter (where s.status = 'resolved' and s.did_win) as slip_wins,
  count(*) filter (where s.status in ('resolved','eliminated') and not s.did_win) as slip_losses,
  coalesce(sum(s.play_leg_wins),0) as leg_wins,
  coalesce(sum(s.play_leg_losses),0) as leg_losses,
  coalesce(sum(s.stake_points),0) as total_points_staked,
  coalesce(sum(s.season_points_earned),0) as total_season_points_earned
from public.juicd_bet_slips s
group by s.user_id;

-- =============================================================================
-- 7. Row Level Security
-- =============================================================================
alter table public.juicd_profiles          enable row level security;
alter table public.juicd_groups             enable row level security;
alter table public.juicd_group_members      enable row level security;
alter table public.juicd_tournaments        enable row level security;
alter table public.juicd_tournament_entries enable row level security;
alter table public.juicd_bet_slips          enable row level security;
alter table public.juicd_points_ledger      enable row level security;
alter table public.juicd_prop_action        enable row level security;

-- Profiles: anyone signed in can read (leaderboard/search); you edit only yours.
drop policy if exists "juicd profiles readable" on public.juicd_profiles;
create policy "juicd profiles readable" on public.juicd_profiles for select to authenticated using (true);
drop policy if exists "juicd profiles update own" on public.juicd_profiles;
create policy "juicd profiles update own" on public.juicd_profiles for update to authenticated using (auth.uid() = id);
drop policy if exists "juicd profiles insert own" on public.juicd_profiles;
create policy "juicd profiles insert own" on public.juicd_profiles for insert to authenticated with check (auth.uid() = id);

-- Groups: members can read their groups; any signed-in user can create one.
drop policy if exists "juicd groups read member" on public.juicd_groups;
create policy "juicd groups read member" on public.juicd_groups for select to authenticated
  using (id in (select public.juicd_my_group_ids()));
drop policy if exists "juicd groups insert" on public.juicd_groups;
create policy "juicd groups insert" on public.juicd_groups for insert to authenticated
  with check (auth.uid() = created_by);

-- Group members: read members of groups you're in; insert/remove yourself.
drop policy if exists "juicd group_members read same group" on public.juicd_group_members;
create policy "juicd group_members read same group" on public.juicd_group_members for select to authenticated
  using (user_id = auth.uid() or group_id in (select public.juicd_my_group_ids()));
drop policy if exists "juicd group_members insert self" on public.juicd_group_members;
create policy "juicd group_members insert self" on public.juicd_group_members for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "juicd group_members delete self" on public.juicd_group_members;
create policy "juicd group_members delete self" on public.juicd_group_members for delete to authenticated
  using (user_id = auth.uid());

-- Tournaments: readable by all signed-in users (group ones only to members).
drop policy if exists "juicd tournaments read" on public.juicd_tournaments;
create policy "juicd tournaments read" on public.juicd_tournaments for select to authenticated
  using (group_id is null or group_id in (select public.juicd_my_group_ids()));

-- Tournament entries: read entries in tournaments you can see; write your own.
drop policy if exists "juicd entries read" on public.juicd_tournament_entries;
create policy "juicd entries read" on public.juicd_tournament_entries for select to authenticated using (true);
drop policy if exists "juicd entries upsert own" on public.juicd_tournament_entries;
create policy "juicd entries upsert own" on public.juicd_tournament_entries for insert to authenticated
  with check (auth.uid() = user_id);
drop policy if exists "juicd entries update own" on public.juicd_tournament_entries;
create policy "juicd entries update own" on public.juicd_tournament_entries for update to authenticated
  using (auth.uid() = user_id);

-- Bet slips: you read/write only your own slips.
drop policy if exists "juicd slips read own" on public.juicd_bet_slips;
create policy "juicd slips read own" on public.juicd_bet_slips for select to authenticated using (auth.uid() = user_id);
drop policy if exists "juicd slips insert own" on public.juicd_bet_slips;
create policy "juicd slips insert own" on public.juicd_bet_slips for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "juicd slips update own" on public.juicd_bet_slips;
create policy "juicd slips update own" on public.juicd_bet_slips for update to authenticated using (auth.uid() = user_id);

-- Points ledger: you read only your own entries (writes via service role / RPC).
drop policy if exists "juicd ledger read own" on public.juicd_points_ledger;
create policy "juicd ledger read own" on public.juicd_points_ledger for select to authenticated using (auth.uid() = user_id);

-- Prop action: aggregate consensus is public to read (no PII); writes via RPC.
drop policy if exists "juicd prop_action read" on public.juicd_prop_action;
create policy "juicd prop_action read" on public.juicd_prop_action for select to authenticated using (true);

-- =============================================================================
-- 8. Comments
-- =============================================================================
comment on table public.juicd_profiles is 'Per-user stats: MMR, tier, season/all-time points, daily allowance.';
comment on table public.juicd_groups is 'Private leagues; join via invite_code (use juicd_join_group_by_code).';
comment on table public.juicd_group_members is 'Group membership edges.';
comment on table public.juicd_tournaments is 'Daily / weekly-group / season tournaments.';
comment on table public.juicd_tournament_entries is 'A user''s bracket state per tournament.';
comment on table public.juicd_bet_slips is 'Play parlays + ranked daily slips with resolution.';
comment on table public.juicd_points_ledger is 'Append-only points movements (stakes, payouts, rewards).';
comment on table public.juicd_prop_action is 'Aggregate stake/tickets per side of a prop; powers consensus %.';
comment on view public.juicd_prop_action_split is 'Per-side share of points and tickets within each prop (the "x% on this side" view).';
