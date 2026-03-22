# Juicd iOS App Setup (Out-of-Code)

This document explains the steps to turn the SwiftUI prototype in this repo (same folder as `Juicd.xcodeproj`) into a real functioning iOS app with:
- real authentication + profiles
- weekly bracket tournaments + group play
- points ledger (10 daily points, bet stake + payouts)
- rank tiers from season points won
- live odds (The Odds API in the prototype; use a backend proxy in production so you never ship keys in shipped builds)
- groups with friend invites
- rewards/badges at tournament end + season end
- ads + (optional) league revenue-sharing pipeline

The code in this workspace currently uses an **in-memory/local prototype repository** (so the UI works without any backend). In production you will replace that repository with a Supabase-backed one and implement scheduled resolution + odds fetching.

---

## 0) What you have right now

1. The SwiftUI prototype UI + local logic lives in the **repo root** next to `Juicd.xcodeproj` (same folder as this file).
2. It includes tabs for:
   - **Play** — pick board; **one** live moneyline from The Odds API (cached; minimal API usage)
   - **Dashboard** — bankroll + full **Rankings** ladder (with “how it works” sheet)
   - **Tourney** — weekly sport bracket: top **50%** each round advance; bonuses on elimination or win
   - **Groups** — create/join + weekly prototype standings
   - **Profile** — stats + badge gallery
3. It stores data locally via `UserDefaults` to keep the demo state across launches.

---

## 1) Create the actual Xcode project

1. Open **Xcode**
2. Create a new project:
   - iOS -> **App**
3. Name: `Juicd`
4. Interface: `SwiftUI`
5. Language: `Swift`
6. Choose an iOS deployment target:
   - Recommended: **iOS 17+** (SwiftUI + modern APIs)
7. Create the project
8. In Xcode, create a folder reference or copy the Swift files from this repo into your project:
   - Copy all `*.swift` from the repo root (same level as `Juicd.xcodeproj`) into your project’s Swift source area.
9. In the Xcode project settings:
   - Ensure **Swift language version** is compatible (default should work).

Notes:
- If you prefer not to copy files, you can add them to the Xcode project via “Add Files to …”.
- The prototype code is written to compile as standard SwiftUI sources.

---

## 1.1) Initialize Git and push to GitHub

1. **Use the repo’s `.gitignore`** at the **repository root** (same folder as `Juicd.xcodeproj`) — e.g. `~/Desktop/juicd/.gitignore`. It ignores Xcode `DerivedData/`, `xcuserdata/`, SwiftPM build artifacts, macOS junk, and **local secrets** files like `Local.xcconfig` / `Secrets.xcconfig`. Do **not** commit `ODDS_API_KEY` — keep it in Xcode Info only on your machine, or in a **gitignored** `Local.xcconfig` (see `Local.xcconfig.example` in the same folder).

2. **In Terminal**, go to that **repository root** (same folder as `Juicd.xcodeproj`):

   ```bash
   cd ~/Desktop/juicd
   git init
   git add .
   git commit -m "Initial Juicd prototype"
   ```

3. **Create an empty repo on GitHub** (no README/license if you want a clean first push — or add them and use `pull --rebase` first).

4. **Add the remote and push** (replace `YOUR_USER` / `YOUR_REPO`):

   ```bash
   git branch -M main
   git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
   git push -u origin main
   ```

5. **If GitHub shows an error about unrelated histories**, you may have created a repo with a README on GitHub first. Then:

   ```bash
   git pull origin main --rebase
   git push -u origin main
   ```

6. **Optional — SSH instead of HTTPS**: add an SSH key in GitHub account settings, then use `git@github.com:YOUR_USER/YOUR_REPO.git` as `origin`.

---

## 2) The Odds API key (prototype)

The **Play** tab calls **The Odds API** once per session (plus optional disk cache for 1 hour) and only displays **one** moneyline line to limit free-tier usage.

1. Sign up at [the-odds-api.com](https://the-odds-api.com/) and copy your API key.
2. In Xcode: select the **Juicd** target → **Info** → **Custom iOS Target Properties** → add a new key:
   - **Key:** `ODDS_API_KEY` (String)
   - **Value:** your key  
   Or add to **Info.plist** as source XML if you use a plist file.

3. For **App Store / production**, move this call to a **backend or Supabase Edge Function** and remove the key from the client (see section 5 in this doc).

---

## 3) Add app identity + configuration

1. Set your Bundle Identifier in Xcode (example: `com.yourcompany.juicd`)
2. Add App Icon(s) and Launch Screen assets (Xcode will guide you)
3. Enable required capabilities only when needed:
   - If using Supabase Auth with Sign in with Apple, enable “Sign in with Apple” capability.

---

## 4) Supabase: create the backend foundation

### 4.1 Create a Supabase project

1. Go to Supabase and create a new project.
2. Note these values for later:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. In Supabase, enable:
   - Authentication providers you intend to support (Apple, Google, email, etc.)

### 4.2 Decide how you want to store points

Recommended production approach:
1. Use a **points ledger** table that records every point movement (daily award + bet stake + bet payout).
2. Derive “available points” as a query (or maintain a cached column via backend jobs).
3. Never “just set a balance” in the client—only backend writes should update ledger.

### 4.3 Suggested Supabase tables (schema outline)

Create these tables in Supabase (names are examples; pick your own):

1. `profiles`
   - `id uuid primary key references auth.users(id)`
   - `display_name text`
   - `season_year int`
   - `season_points_won int default 0`
   - `all_time_points_won int default 0`
   - `current_tier text`
   - `available_daily_points int default 0` (optional cached value)
   - `last_daily_award_date date`

2. `points_ledger`
   - `id uuid primary key default gen_random_uuid()`
   - `created_at timestamptz default now()`
   - `user_id uuid references profiles(id)`
   - `tournament_id uuid null`
   - `bet_slip_id uuid null`
   - `delta_points int`
   - `reason text`

3. `tournaments`
   - `id uuid primary key default gen_random_uuid()`
   - `kind text` (`weekly_bracket`, `weekly_group`, `season`)
   - `status text` (`upcoming`, `active`, `finished`)
   - `start_at timestamptz`
   - `end_at timestamptz`
   - `sport_key text`
   - `season_year int null`

4. `tournament_participants`
   - `id uuid primary key default gen_random_uuid()`
   - `tournament_id uuid references tournaments(id)`
   - `user_id uuid references profiles(id)`
   - `current_round int`
   - `eliminated bool`
   - `day_scores int[]` (or normalized table)

5. `bet_slips` / `bet_legs` — as needed for your pick slip model.

6. `groups`, `group_memberships`, `badges_catalog`, `user_badges` — same ideas as before.

### 4.4 Enable Row Level Security (RLS)

1. Turn on RLS for each user-specific table (`profiles`, `points_ledger`, `bet_slips`, etc.)
2. Add policies like:
   - `select` on `points_ledger` where `user_id = auth.uid()`
   - `insert` on `points_ledger` only allowed via trusted backend functions/edge functions
3. For `groups`:
   - allow viewing group only if the user is a member
   - allow joining by invite code via an edge function (recommended, avoids leaking private group IDs)

---

## 5) Live odds: production pattern

For production, **do not** ship provider API keys in the app. Use a Supabase Edge Function (or your backend) as an **odds proxy** with caching.

The prototype uses **The Odds API** directly with `ODDS_API_KEY` in Info for convenience — replace with server-side fetching before release.

---

## 6) Authentication (Supabase)

1. Add Supabase auth to the iOS project
2. Decide login:
   - Apple sign-in recommended for gambling apps
   - email/password is also possible
3. Update client logic:
   - use `auth.uid()` equivalent as `profiles.id`
   - after login, fetch `profiles` row
4. Ensure the backend is the only place that updates balances and tournament state in production.

---

## 7) Ads revenue from sports leagues

### 7.1 Technical ad integration (recommended baseline)

1. Use an ad network SDK (example: Google AdMob)
2. Integrate banner/rewarded ads into the iOS app
3. Record impressions and payout metrics server-side

### 7.2 League revenue sharing

Requires contracts + reporting pipelines — not something you can “code only” in the client.

---

## 8) App Store Connect requirements checklist

1. Create an app record in App Store Connect
2. Fill out pricing, App Privacy, age rating (gambling content)
3. Privacy policy URL
4. Sign in with Apple setup if used
5. Ads: declare data collection per network policies

---

## 9) Environment variables / secrets (client)

Never commit secrets. Use `.xcconfig` or Xcode **User-Defined** settings excluded from git, or Secrets in CI.

---

## 10) Testing plan before App Store

1. Staging Supabase
2. Test ledger, tournaments, RLS
3. Test odds proxy latency (production)

---

## 11) Next steps

Confirm launch region, auth method, and whether bracket rounds are calendar days vs. simulated rounds for your backend.
