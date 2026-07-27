-- Juicd — play-board snapshot TTL / stampede helpers (additive)
-- Safe to rerun: IF NOT EXISTS / ON CONFLICT DO NOTHING

alter table public.juicd_play_board_snapshots
  add column if not exists refresh_started_at timestamptz;

comment on column public.juicd_play_board_snapshots.refresh_started_at is
  'Set while Odds API refresh is in flight; used to coalesce stampedes.';

-- Default TTL for live Odds board cache (seconds). Edge reads this; 1800 = 30 min.
insert into public.juicd_runtime_config (key, value)
values ('odds_board_ttl_seconds', '1800')
on conflict (key) do nothing;
