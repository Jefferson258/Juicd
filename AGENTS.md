# Agent instructions — Juicd (iOS app)

Juicd is a free-to-play sports prediction game using **virtual points only**
(no real-money wagering). Daily tournaments, parlays, groups, MMR/tiers,
leaderboards.

## Operating principles (non-negotiable)

1. **Be open and honest.** Report exactly what you did, what failed, and what's
   uncertain. Verify before claiming success. If you assumed, say so.
2. **Never spend money.** No domains, plan upgrades, paid tiers, billing, or
   charge-incurring actions. Free tiers only. If it costs money, stop and ask.
3. **No destructive/sweeping changes without explicit per-action approval:**
   no `DROP`/`DELETE`/`TRUNCATE`/destructive `ALTER`, no deleting Supabase data,
   no `git push --force`, history rewrites, mass deletions, or secret rotation.
4. **Protect the database.** Additive, idempotent SQL only. Never remove/rewrite
   existing data without explicit approval.
5. **Secrets never go in git** (`.p8`, DB passwords, service-role keys, access
   tokens, Odds API key). Anon key is intentionally embeddable in the client.

## Legal posture (important)

Juicd is **virtual points only — not gambling / no real-money payouts.** Keep
all copy, schema, and runtime behavior consistent with that. Real-odds/live
settlement changes need owner + counsel sign-off before shipping.

## App facts

- **Bundle ID:** `com.jefferson258.juicd` · **ASC app id:** `6785327494`
  (`juicd.Juicd` was taken; this is the registered one).
- **Apple Team:** `8H2437SV33` · manual signing.
- `ITSAppUsesNonExemptEncryption=NO` set in target build settings.
- Currently **build 4** on TestFlight with the Supabase backend wired in.
- Build/upload: see TestFlight section in `LAUNCH_OUT_OF_CODE.md`.

## Supabase (`supabase/`)

- **Project ref:** `hwyxtklbffqwcbtuetit` (live, free tier). URL + anon key are
  wired into the target's `INFOPLIST_KEY_SUPABASE_URL/_ANON_KEY`.
- **Tables (13):** `juicd_profiles` (stats: MMR, tier, season/all-time points,
  daily allowance), `juicd_groups` + `juicd_group_members`, `juicd_tournaments`
  + `juicd_tournament_entries`, `juicd_bet_slips`, `juicd_points_ledger`,
  `juicd_prop_action` (consensus: stake/tickets per side), plus
  `juicd_friendships`, `juicd_friend_requests`, `juicd_runtime_config`,
  `juicd_play_board_snapshots`, `juicd_play_slip_outcomes`.
- **Views (4):** `juicd_prop_action_split` (% of points/tickets per side),
  `juicd_season_leaderboard`, `juicd_alltime_leaderboard`,
  `juicd_career_betting_stats`.
- **RPCs (4):** `juicd_record_prop_action`, `juicd_join_group_by_code`,
  `juicd_my_group_ids`, `juicd_handle_new_user` (auto-creates a profile row).
- **Edge functions:** `play-board`, `resolve-play-slip` (deployed).
- **Runtime:** `juicd_runtime_config.odds_mode` and `outcome_mode` = `simulated`.
  The app currently uses an in-memory repo; the DB is the production backing
  store ahead of client wiring.
- All migrations are **idempotent** (verified rerunnable). Keep them additive.
  See `supabase/README.md`. **Do not** run destructive SQL on
  `hwyxtklbffqwcbtuetit` without explicit approval.

## Going to real data (high priority, but gated)

1. Owner provides an **Odds API key** (free/dev tier; never pay without asking).
2. Agent sets `ODDS_API_KEY` as a **Supabase Edge Function secret** (not in git).
3. Smoke-test `play-board` with live data.
4. Only then flip `juicd_runtime_config.odds_mode` `simulated -> live`
   (`outcome_mode` separately, with care). This is a behavior change — confirm
   with the owner before flipping.

## What's been done

- Created the Supabase project, applied all migrations, deployed edge functions,
  wired URL+anon key, uploaded build 4.
- Created an external "Beta Testers" TestFlight group (public link).
- Set export-compliance flag; fixed bundle ID to `com.jefferson258.juicd`.
