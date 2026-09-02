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
- Currently **build 9** on TestFlight (Option B ads: dismissible 300×250).
- Ads: **Option B with X** — dismissible 300×250 AdMob box in the sponsored
  card on Play and Tourney. Sticky banners off. Simulator/DEBUG uses Google
  test creatives; store builds use the plist unit. Toggle default **on**.
  Payouts still need the LLC bank + AdMob payments.
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
  Staging-only atomic settlement lives in
  `supabase/staging/AUTHORITATIVE_SETTLEMENT.sql` and is off unless
  `JUICD_AUTHORITATIVE_SETTLEMENT=1` **and**
  `staging_authoritative_settlement=on` on a disposable project. Never apply
  that SQL or env var to `hwyxtklbffqwcbtuetit`.
- **Odds board cache (Jul 26):** `play-board` reads `juicd_play_board_snapshots`
  first. Fresh within `odds_board_ttl_seconds` (default **1800**) → no Odds API.
  Stampede lock via `refresh_started_at`. Client soft-cache **180s** + in-flight
  dedupe; Sync bypasses client cache only (Edge TTL still applies).
- **Runtime:** `odds_mode=live` (Odds API + Edge snapshot cache); `outcome_mode`
  still **simulated**. Cache TTL default **1800s** mitigates quota burn. Do not
  flip `outcome_mode` to live without owner + counsel OK. Re-pause risk: free
  Supabase projects go inactive — restore via Management API `/restore` if needed.
- All migrations are **idempotent** (verified rerunnable). Keep them additive.
  See `supabase/README.md`. **Do not** run destructive SQL on
  `hwyxtklbffqwcbtuetit` without explicit approval.

## Analytics & error logging

Client events POST to `juicd_analytics_events`; failures to `juicd_app_errors`
when Supabase is configured (`SupabaseAnalyticsProvider`, `AppErrorLogger`).
Apply migration `20260721200000_juicd_analytics_logging.sql`, then query via
Supabase SQL Editor — see LaunchPilot `docs/HOW_TO_VIEW_ANALYTICS.md`.

Profile **Help → Report an issue** writes the user’s text through
`IssueReportService.sink` (swap this to change destination). Default sink:
dedicated `juicd_issue_reports` (migration `20260902120000_juicd_issue_reports.sql`,
applied 2026-09-02) plus an info breadcrumb on `juicd_app_errors` with
`extra.kind=user_report`. Query via `supabase db query --linked` / SQL Editor.

## Going to real data (high priority, but gated)

1. Owner provides an **Odds API key** (free/dev tier; never pay without asking).
2. Agent sets `ODDS_API_KEY` as a **Supabase Edge Function secret** (not in git).
3. Smoke-test `play-board` with live data.
4. Only then flip `juicd_runtime_config.odds_mode` `simulated -> live`
   (`outcome_mode` separately, with care). This is a behavior change — confirm
   with the owner before flipping.

**Status 2026-08-30:** steps 1–4 for `odds_mode` are already done in production.
Leave `outcome_mode=simulated`. Do not re-flip or force-refresh the board
without an explicit ask (Odds API quota).

## What's been done

- Created the Supabase project, applied all migrations, deployed edge functions,
  wired URL+anon key, uploaded build 4.
- Created an external "Beta Testers" TestFlight group (public link).
- Set export-compliance flag; fixed bundle ID to `com.jefferson258.juicd`.

## Marketing

- Product playbook: `docs/MARKETING.md` (includes social + claim rules)
- ASO paste copy: `docs/APP_STORE_LISTING.md`
- Shared pipeline design: MarketingPilot (`~/Desktop/MarketingPilot`)

## Current blockers (owner)

- Device smoke: confirm TestFlight still shows the Live API ribbon (real
  matchup), not only `NBA Player N` placeholders. Production `odds_mode` is
  already `live`; `outcome_mode` stays `simulated`.
- Social handles (Instagram / TikTok / X) — see `docs/MARKETING.md`
- `juicd.app` domain + Vercel token for the marketing site
