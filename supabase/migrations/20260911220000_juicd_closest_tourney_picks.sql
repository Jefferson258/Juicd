-- Closest-number daily/weekly tourney: persist human picks on existing tables.
-- Additive only. Bots stay generated (no auth.users rows).

alter table public.juicd_tournaments
  drop constraint if exists juicd_tournaments_kind_check;
alter table public.juicd_tournaments
  add constraint juicd_tournaments_kind_check
  check (kind in ('daily','weeklyGroup','season','weekly'));

alter table public.juicd_tournaments
  add column if not exists period_key text;
alter table public.juicd_tournaments
  add column if not exists payload jsonb;

create unique index if not exists juicd_tournaments_kind_period_uidx
  on public.juicd_tournaments (kind, period_key)
  where period_key is not null;

alter table public.juicd_tournament_entries
  add column if not exists picks jsonb not null default '[]'::jsonb;
alter table public.juicd_tournament_entries
  add column if not exists display_name text;
