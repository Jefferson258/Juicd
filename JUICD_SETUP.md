# Juicd setup (short reference)

**Do this first:** **[SETUP.md](SETUP.md)** — Xcode, signing, Odds API key, Supabase, App Store (step-by-step, minimal clutter).

**Long narrative + full checklists:** **[README_REFERENCE.md](README_REFERENCE.md)**

---

## What this file is for

- Brief **Supabase schema** ideas and **production odds** pattern (no client API keys).
- Pointers only; the detailed sections moved to **README_REFERENCE.md**.

The Swift prototype uses **`InMemoryJuicdRepository`** (`UserDefaults`) so the UI runs with no backend.

---

## Supabase schema outline (optional)

- `profiles` — display name, season stats, tier, balances
- `points_ledger` — append-only movements
- `tournaments`, bracket state — if persisted server-side
- `bet_slips` / `bet_legs` — parlay model
- `groups`, `group_memberships`, `user_badges`

Enable **RLS**; use Edge Functions for trusted writes.

---

## Live odds (production)

Do not ship provider keys in the app. Use a **Supabase Edge Function** (or other backend) as an odds proxy with caching and rate limits.

---

## Ads / revenue

Ad SDKs and league revenue share are **contract + reporting** work beyond the client prototype.
