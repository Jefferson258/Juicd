# Juicd Supabase backend

- **`migrations/`** — schema (friends/requests, odds runtime, board snapshots).
- **`functions/`** — Edge Functions: `play-board`, `resolve-play-slip`, and
  authenticated `delete-account`.

## Idempotency (safe to rerun)

Both migrations are **idempotent** — safe to run again on the same database:

- `create table if not exists`, `create index if not exists`
- `enable row level security` (no-op if already on)
- `drop policy if exists` before every `create policy`
- seed rows via `insert ... on conflict do nothing` (won't overwrite manual edits)

> Keep these patterns if you edit the SQL. Avoid bare `create policy` /
> `create trigger` / `add constraint` without a guard so reruns stay clean.

## Deploy

Once a Supabase project exists, from this repo:

```bash
export SUPABASE_ACCESS_TOKEN=sbp_xxx          # account token — never commit
supabase link --project-ref <project-ref>
supabase db push
supabase functions deploy play-board
supabase functions deploy resolve-play-slip
supabase functions deploy delete-account
```

  Re-running is safe (idempotent migrations; function deploys overwrite).

`delete-account` validates the caller's bearer token inside the function, then
uses the runtime-injected service-role key to delete that exact Auth user.
Deploy and smoke-test it with a disposable account before enabling the in-app
action. Never put the service-role key in the iOS target.

## Analytics & errors (Supabase)

Migration `20260721200000_juicd_analytics_logging.sql` adds insert-only
`juicd_analytics_events` + `juicd_app_errors` (client POST via REST). Profile
“Report an issue” also writes `juicd_issue_reports` (migration
`20260902120000_juicd_issue_reports.sql`) and a breadcrumb on `juicd_app_errors`.
Query in Supabase SQL Editor — see LaunchPilot `docs/HOW_TO_VIEW_ANALYTICS.md`.

## After deploy: wire the app

The app reads these from its Xcode build settings / Info.plist
(`Services/SupabaseConfig.swift`):

- `SUPABASE_URL` = `https://<project-ref>.supabase.co`
- `SUPABASE_ANON_KEY` = from `supabase projects api-keys --project-ref <ref>`

Get the anon key:

```bash
supabase projects api-keys --project-ref <project-ref>
```

## Runtime config

Migrations **seed** `odds_mode = simulated` and `outcome_mode = simulated`
(`insert … on conflict do nothing` will not overwrite a later manual flip).

**Production check (2026-08-30, read-only REST on `hwyxtklbffqwcbtuetit`):**

| key | value | notes |
|---|---|---|
| `odds_mode` | `live` | since 2026-06-29; Edge secret `ODDS_API_KEY` is set |
| `outcome_mode` | `simulated` | do not flip without owner + counsel |
| `odds_board_ttl_seconds` | `1800` | |

Same-day snapshot `slate_key=2026-08-30` had `source=odds_api` and a Live API
moneyline ribbon (real NBA matchup) plus the usual simulated filler ribbons.
Public copy may say a shared sports-data line exists; do **not** claim
sportsbook / real-money odds. Do **not** call `play-board?force=1` casually —
that burns Odds API quota.

## Staging integrity harness

`staging/INTEGRITY_HARDENING.sql` and `staging/VALIDATION.md` are intentionally
outside `migrations/` and must be applied only to a disposable staging
project. They exercise fail-closed client-write and settlement-input guards
without changing the live schema. The app refuses to settle a configured
backend slip when the response is missing or does not cover every submitted
leg exactly once; local deterministic settlement remains available only when
the backend is not configured.
