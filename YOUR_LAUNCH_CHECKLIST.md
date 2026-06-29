# Your Launch Checklist — Juicd (step by step)

Use this when you want to sit down and **get Juicd launch-ready**. It assumes you give the agent as much access as possible.

**Related docs**

| Doc | Purpose |
|-----|---------|
| [LAUNCH_OUT_OF_CODE.md](LAUNCH_OUT_OF_CODE.md) | Full phase runbook |
| [LAUNCH_EXECUTION_SPLIT.md](LAUNCH_EXECUTION_SPLIT.md) | You vs Agent by phase |
| [MAX_ACCESS_SETUP_SPLIT.md](MAX_ACCESS_SETUP_SPLIT.md) | Credentials, Odds API, AdMob, guardrails |
| [SETUP.md](SETUP.md) | Supabase, keys, App Store copy |
| [ADVERTISERS_SETUP.md](ADVERTISERS_SETUP.md) | Direct sponsor ads |
| [../juicd-website/LAUNCH_OUT_OF_CODE.md](../juicd-website/LAUNCH_OUT_OF_CODE.md) | Website deploy |

**Your active time (focused): ~5–10 hours** (counsel review extra)

---

## The Odds API (honest answer)

| Mode | Need Odds API key? | Where key lives |
|------|-------------------|-----------------|
| **Simulated beta** (recommended first) | **No** | — |
| **Live odds** | **Yes** | Supabase Edge Function secret `ODDS_API_KEY` only — **never** in the iOS app |

Flip mode in Supabase SQL:

```sql
update public.juicd_runtime_config
set value = 'simulated', updated_at = now()
where key = 'odds_mode';
```

Use `live` only after key is set and logs are clean.

---

## Do once (Apple + tooling setup) — ~2–3 hours

| Step | You | Time |
|------|-----|------|
| 1 | Apple Developer agreements current | 10–20 min |
| 2 | App Store Connect API key (`.p8`) + `../TestFlight/config.sh` | 20–40 min |
| 3 | Invite agent: GitHub (juicd + juicd-website), Vercel, Supabase | 15–30 min |
| 4 | LLC/EIN/bank when ready — [../LegalDocuments/BUSINESS_LLC_AND_MONETIZATION.md](../LegalDocuments/BUSINESS_LLC_AND_MONETIZATION.md) | 1–3 hrs spread |

---

## Juicd app — your steps in order

| # | You do | Time | Then agent can |
|---|--------|------|----------------|
| 1 | **Apple Developer → App ID** for `juicd.Juicd` + **Sign in with Apple** | 30–60 min | Match signing in Xcode |
| 2 | **App Store Connect → Apps → +** — Juicd, bundle `juicd.Juicd`, SKU e.g. `juicd-ios-001` | 20–30 min | Upload TestFlight |
| 3 | Buy **juicd.app** | 20–40 min | Deploy site + DNS |
| 4 | **Supabase** project create or invite agent | 15–20 min | Run migrations + deploy `play-board`, `resolve-play-slip` |
| 5 | **Stay on simulated odds** for first TestFlight unless you approve live | 0 min | Agent sets `odds_mode=simulated` |
| 6 | (Later) **the-odds-api.com** account → give agent key for Edge secret only | 15–30 min | Agent sets `ODDS_API_KEY`, flips to `live` |
| 7 | (If ads) **AdMob** app + ad units + Google payments/tax profile | 1–2 hrs | Agent wires SDK/UMP (in-code) |
| 8 | **Counsel** — review Terms, Privacy, Contest Rules; Juicd gambling-adjacent posture | 1–3 hrs active | Agent publishes only after you approve |
| 9 | **App Store Connect** — privacy, support, contest URL; App Privacy; **18+** age rating | 30–60 min | — |
| 10 | TestFlight internal test | 20–30 min | — |
| 11 | Submit — use review notes: virtual points, no betting, no cash value, Apple not sponsor | 30–60 min | You click Submit |

---

## Hand off to agent (say: “Juicd max access — simulated beta”)

1. Run migrations `20260322120000_juicd_friends.sql`, `20260424113000_juicd_odds_runtime.sql`.
2. Deploy Edge Functions `play-board`, `resolve-play-slip`.
3. Set secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (optional `ODDS_API_KEY` later).
4. Wire iOS `SUPABASE_URL` + `SUPABASE_ANON_KEY`.
5. Deploy juicd-website; legal pages after your/counsel approval.
6. Screenshots + metadata + review-note draft.
7. `./../TestFlight/build-check.sh juicd` → `bump-build.sh juicd` → `archive-and-upload.sh juicd`.

---

## Guardrails (do not skip)

- Entertainment only — **not** a sportsbook or real-money wagering.
- Virtual points have **no cash value**, ever.
- No paid entry, cash-out, gift cards, or IAP for play currency without new legal analysis.
- Do **not** public-launch until counsel clears contest/gambling risk (especially Texas).

---

## Calendar reality

| Milestone | Typical calendar time |
|-----------|------------------------|
| Simulated TestFlight | ~1 week after access |
| Public App Store + marketing | **3–8 weeks** (legal + App Review scrutiny) |
