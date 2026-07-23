-- Juicd — first-party analytics events + app error logging (insert-only via RLS).
-- Idempotent: safe to rerun. Query dashboards via SQL Editor / service role only.
-- Free-tier Supabase only; additive schema.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.juicd_analytics_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  event_name text not null,
  params jsonb not null default '{}'::jsonb,
  session_id text,
  app_version text,
  build text,
  user_id uuid references auth.users (id) on delete set null,
  platform text not null default 'ios'
);

create index if not exists juicd_analytics_events_created_idx
  on public.juicd_analytics_events (created_at desc);
create index if not exists juicd_analytics_events_name_idx
  on public.juicd_analytics_events (event_name, created_at desc);

create table if not exists public.juicd_app_errors (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  severity text not null,
  message text not null,
  screen text,
  extra jsonb not null default '{}'::jsonb,
  app_version text,
  build text,
  user_id uuid references auth.users (id) on delete set null,
  platform text not null default 'ios',
  constraint juicd_app_errors_severity_check
    check (severity in ('info', 'warning', 'error', 'fatal'))
);

create index if not exists juicd_app_errors_created_idx
  on public.juicd_app_errors (created_at desc);
create index if not exists juicd_app_errors_severity_idx
  on public.juicd_app_errors (severity, created_at desc);

-- ---------------------------------------------------------------------------
-- 2. RLS — insert for anon + authenticated (Juicd uses anonymous auth);
--    no SELECT for clients (service role / dashboard only).
-- ---------------------------------------------------------------------------

alter table public.juicd_analytics_events enable row level security;
alter table public.juicd_app_errors enable row level security;

grant insert on public.juicd_analytics_events to anon, authenticated;
grant insert on public.juicd_app_errors to anon, authenticated;

drop policy if exists "juicd analytics events insert" on public.juicd_analytics_events;
create policy "juicd analytics events insert"
  on public.juicd_analytics_events for insert
  to anon, authenticated
  with check (user_id is null or auth.uid() = user_id);

drop policy if exists "juicd app errors insert" on public.juicd_app_errors;
create policy "juicd app errors insert"
  on public.juicd_app_errors for insert
  to anon, authenticated
  with check (user_id is null or auth.uid() = user_id);

comment on table public.juicd_analytics_events is
  'Product analytics events from the iOS client. Insert-only via RLS; read in SQL Editor.';
comment on table public.juicd_app_errors is
  'Client-reported errors (auth/social/API). Insert-only via RLS; read in SQL Editor.';

-- ---------------------------------------------------------------------------
-- 3. Dashboard views (SQL Editor / service role)
-- ---------------------------------------------------------------------------

create or replace view public.v_juicd_analytics_daily
  with (security_invoker = true)
as
select
  date_trunc('day', created_at)::date as day,
  event_name,
  count(*)::bigint as event_count
from public.juicd_analytics_events
group by 1, 2
order by 1 desc, 3 desc;

create or replace view public.v_juicd_app_errors_daily
  with (security_invoker = true)
as
select
  date_trunc('day', created_at)::date as day,
  severity,
  count(*)::bigint as error_count
from public.juicd_app_errors
group by 1, 2
order by 1 desc, 3 desc;

create or replace view public.v_juicd_sign_ins_daily
  with (security_invoker = true)
as
select
  date_trunc('day', created_at)::date as day,
  count(*)::bigint as sign_in_count
from public.juicd_analytics_events
where event_name = 'sign_in'
group by 1
order by 1 desc;

-- Product metrics from existing tables (bets / slips / friends / groups).
create or replace view public.v_juicd_product_counts
  with (security_invoker = true)
as
select
  (select count(*)::bigint from public.juicd_bet_slips) as total_slips,
  (select count(*)::bigint from public.juicd_bet_slips
    where created_at >= now() - interval '7 days') as slips_last_7d,
  (select count(*)::bigint from public.juicd_play_slip_outcomes) as total_play_outcomes,
  (select count(*)::bigint from public.juicd_friendships) as total_friendships,
  (select count(*)::bigint from public.juicd_friend_requests) as pending_friend_requests,
  (select count(*)::bigint from public.juicd_groups) as total_groups,
  (select count(*)::bigint from public.juicd_group_members) as total_group_memberships;

create or replace view public.v_juicd_slip_events_daily
  with (security_invoker = true)
as
select
  date_trunc('day', created_at)::date as day,
  count(*) filter (where event_name = 'slip_submitted')::bigint as slips_submitted,
  count(*) filter (
    where event_name = 'slip_resolved'
      and coalesce(params->>'won', params->>'did_win', 'false') = 'true'
  )::bigint as slip_wins,
  count(*) filter (
    where event_name = 'slip_resolved'
      and coalesce(params->>'won', params->>'did_win', 'false') = 'false'
  )::bigint as slip_losses
from public.juicd_analytics_events
where event_name in ('slip_submitted', 'slip_resolved')
group by 1
order by 1 desc;
