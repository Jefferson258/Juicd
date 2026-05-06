# Juicd setup (short reference)

**Do this first:** **[SETUP.md](SETUP.md)** — Xcode, signing, **Supabase** (shared board + Edge Functions), optional client odds fallback, App Store (step-by-step, minimal clutter).

**Long narrative + full checklists:** **[README_REFERENCE.md](README_REFERENCE.md)**

---

## What this file is for

- Brief **Supabase schema** ideas and **production odds** pattern (no client API keys).
- Pointers only; the detailed sections moved to **README_REFERENCE.md**.

The Swift prototype uses **`InMemoryJuicdRepository`** (`UserDefaults`) so the UI runs with no backend.

**Recent client behavior (still local-first):** high-contrast black canvas; **Dashboard → Play slips** with a slate-day picker (today + past days with bets); **Play** sport pills only for leagues that have priced props on the current board; Supabase board fetch is guarded against overlapping refreshes; parlay submit is single-flight to avoid double stakes.

---

## Supabase schema outline (optional)

- `profiles` — display name, season stats, tier, balances
- `points_ledger` — append-only movements
- `tournaments`, bracket state — if persisted server-side
- `bet_slips` / `bet_legs` — parlay model
- `groups`, `group_memberships`, `user_badges`
- `juicd_runtime_config` — runtime switches (`odds_mode`)
- `juicd_play_board_snapshots` — shared board payload per slate
- `juicd_play_slip_outcomes` — deterministic cached outcomes per normalized slip

Enable **RLS**; use Edge Functions for trusted writes.

---

## Shared odds + switchable live mode

Use Supabase Edge Functions (sources under `supabase/functions/` — deploy with CLI; see **SETUP.md §3**):

- `play-board`: returns shared board for all devices; source controlled by `juicd_runtime_config.odds_mode` (and optional `outcome_mode` for slip resolution behavior).
- `resolve-play-slip`: returns deterministic shared outcomes for a normalized slip shape.

Switch modes with SQL:

```sql
update public.juicd_runtime_config
set value = 'simulated', updated_at = now()
where key = 'odds_mode';
```

```sql
update public.juicd_runtime_config
set value = 'live', updated_at = now()
where key = 'odds_mode';
```

Keep `ODDS_API_KEY` only in Supabase function secrets (not in iOS client).

---

## Ads / revenue

Ad SDKs and league revenue share are **contract + reporting** work beyond the client prototype.
