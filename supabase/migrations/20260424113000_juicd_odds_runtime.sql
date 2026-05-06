-- Juicd — odds runtime + shared board snapshots
-- Idempotent: safe to rerun in Supabase SQL editor or via CLI (same patterns as `20260322120000_juicd_friends.sql`).
--   • tables: create if not exists
--   • seed rows: insert … on conflict do nothing (does not overwrite manual changes)
--   • indexes: create index if not exists
--   • RLS: enable (no-op if already on) + drop policy if exists, then create policy

create table if not exists public.juicd_runtime_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

insert into public.juicd_runtime_config (key, value)
values ('odds_mode', 'simulated')
on conflict (key) do nothing;

insert into public.juicd_runtime_config (key, value)
values ('outcome_mode', 'simulated')
on conflict (key) do nothing;

create table if not exists public.juicd_play_board_snapshots (
  slate_key text primary key,
  mode text not null,
  source text not null,
  board jsonb not null,
  updated_at timestamptz not null default now()
);

create index if not exists juicd_play_board_updated_idx
  on public.juicd_play_board_snapshots (updated_at desc);

-- server-side deterministic outcomes cache for reproducibility
create table if not exists public.juicd_play_slip_outcomes (
  slip_key text primary key,
  slate_key text not null,
  outcomes jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.juicd_runtime_config enable row level security;
alter table public.juicd_play_board_snapshots enable row level security;
alter table public.juicd_play_slip_outcomes enable row level security;

-- app reads snapshots; writes are done via service role in edge functions.
drop policy if exists "public read runtime config" on public.juicd_runtime_config;
create policy "public read runtime config"
  on public.juicd_runtime_config for select
  using (true);

drop policy if exists "public read board snapshots" on public.juicd_play_board_snapshots;
create policy "public read board snapshots"
  on public.juicd_play_board_snapshots for select
  using (true);

-- no public reads on outcome cache (edge function uses service role anyway)

comment on table public.juicd_runtime_config is 'Runtime switches: odds_mode (simulated|live), outcome_mode, etc.';
comment on table public.juicd_play_board_snapshots is 'Cached shared Play board JSON per slate; populated by play-board Edge Function.';
comment on table public.juicd_play_slip_outcomes is 'Deterministic leg outcomes per normalized slip key; written by resolve-play-slip.';
