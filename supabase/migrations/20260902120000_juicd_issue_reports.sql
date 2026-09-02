-- User-submitted issue reports from Profile. Insert-only via RLS.
-- Idempotent. Does not rewrite juicd_app_errors.

create table if not exists public.juicd_issue_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  body text not null,
  screen text,
  app_version text,
  build text,
  user_id uuid references auth.users (id) on delete set null,
  platform text not null default 'ios',
  extra jsonb not null default '{}'::jsonb,
  constraint juicd_issue_reports_body_len check (char_length(body) between 1 and 4000)
);

create index if not exists juicd_issue_reports_created_idx
  on public.juicd_issue_reports (created_at desc);

alter table public.juicd_issue_reports enable row level security;

grant insert on public.juicd_issue_reports to anon, authenticated;

drop policy if exists "juicd issue reports insert" on public.juicd_issue_reports;
create policy "juicd issue reports insert"
  on public.juicd_issue_reports for insert
  to anon, authenticated
  with check (user_id is null or auth.uid() = user_id);

comment on table public.juicd_issue_reports is
  'In-app “Report an issue” submissions. Insert-only; read in SQL Editor / LaunchPilot.';
