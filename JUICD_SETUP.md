# Juicd setup (reference)

**Use this file for background notes.** The **step-by-step out-of-code checklist** (Xcode, Sign in with Apple, notifications, Supabase, Odds API, App Store) is maintained in **[README.md](README.md)** — start there.

---

## What this doc adds

- Deeper **Supabase table / RLS** outline
- **Production odds** pattern (proxy, no client keys)
- **Ads / league revenue** considerations (non-code)

The Swift prototype in this repo uses an **in-memory/local repository** (`UserDefaults`) so the UI works without any backend.

---

## 0) What you have right now

1. The SwiftUI prototype lives next to `Juicd.xcodeproj` in the repo root.
2. Tabs: **Play** (Odds API hook), **Dashboard**, **Tourney** (daily closest-pick), **Groups**, **Profile**.
3. **Profile** includes notification preference toggles (stored locally; wire to APNs + backend for real pushes).

---

## Supabase schema outline (optional detail)

See the original sections in git history or expand your backend with:

- `profiles` — user display, season stats, tier, optional cached balances
- `points_ledger` — append-only point movements
- `tournaments`, `tournament_participants` — if you persist bracket state server-side
- `bet_slips` / `bet_legs` — parlay model
- `groups`, `group_memberships`, `user_badges`

Enable **RLS** on all user-specific tables; use Edge Functions for trusted writes.

---

## Live odds: production pattern

Do not ship provider API keys in the app. Use a Supabase Edge Function (or other backend) as an **odds proxy** with caching and rate limits.

---

## Ads revenue

Integrating an ad SDK (e.g. AdMob) and any league revenue-sharing is **contract + reporting** work beyond client-only code.
