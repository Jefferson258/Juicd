# Juicd Supabase backend

- **`migrations/`** — schema (friends/requests, odds runtime, board snapshots).
- **`functions/`** — Edge Functions: `play-board`, `resolve-play-slip`.

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
```

Re-running is safe (idempotent migrations; function deploys overwrite).

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

`juicd_runtime_config` seeds `odds_mode = simulated` and
`outcome_mode = simulated`. Leave these as `simulated` for the beta (no
real-money / live-odds behavior). Flip to `live` only after legal sign-off.
