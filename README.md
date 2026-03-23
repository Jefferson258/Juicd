# Juicd

iOS prototype: **Play** tab (odds / parlays), **Dashboard** (daily balance + tier), **Tourney** (daily closest-pick bracket), **Friends**, **Profile**. Data is **local** (`UserDefaults` via `InMemoryJuicdRepository`) so the UI runs without a backend.

## What to do

1. **Run & build:** Open `Juicd.xcodeproj` in Xcode, pick a simulator or device, ⌘R.
2. **Everything you configure outside code** (signing, Odds API key, Supabase later, App Store): follow **[SETUP.md](SETUP.md)** — that file is the step-by-step checklist.
3. **Long-form notes** (product detail, migrations, ops): **[README_REFERENCE.md](README_REFERENCE.md)** and **[JUICD_SETUP.md](JUICD_SETUP.md)**.

## Sign-in

Launch shows **Sign in with Apple** (uses your Apple ID name when Apple provides it) and **Skip — local dev account** (prototype: signs in as **Player**, same profile each time). No display-name field on every launch.

## Repo hygiene

Do not commit API keys. Use **Info** `ODDS_API_KEY` or a gitignored `Local.xcconfig` (see SETUP).
