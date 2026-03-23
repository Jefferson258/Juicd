# Juicd

iOS app prototype — ranked sports picks, daily closest-pick tournament, friends (requests + MMR leaderboard), and profile badges.

This README is the **single step-by-step checklist** for everything you must configure **outside the code** (Xcode, Apple, notifications, Supabase, keys, App Store). The app currently uses a **local in-memory repository** with `UserDefaults` so the UI runs without a backend; wire a real backend when you’re ready.

---

## Before you commit

1. **Do not commit API keys.** Use the Xcode target **Info** for `ODDS_API_KEY` locally, or copy `Local.xcconfig.example` → `Local.xcconfig`, put your key there, and keep that file gitignored (already in `.gitignore`).
2. From the **repo root** (folder containing `Juicd.xcodeproj` and this `README.md`):

   ```bash
   git add .
   git commit -m "Initial commit"
   ```

3. Create an empty repo on GitHub, then:

   ```bash
   git branch -M main
   git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
   git push -u origin main
   ```

---

## Full setup checklist (out of code)

### 1) Open the project and build

1. Install **Xcode** from the Mac App Store (current stable release).
2. Open `Juicd.xcodeproj` in the repo root.
3. Select the **Juicd** scheme and an iOS Simulator or device.
4. Product → **Build** (⌘B) to confirm the project compiles.

### 2) Bundle ID, signing, and team

1. Select the **Juicd** target → **Signing & Capabilities**.
2. Set **Team** to your Apple Developer team.
3. Set a unique **Bundle Identifier** (e.g. `com.yourcompany.juicd`).
4. Enable **Automatically manage signing** for development, or configure manual profiles for distribution.

### 3) Sign in with Apple (when you add real auth)

1. In [Apple Developer](https://developer.apple.com), register an **App ID** with **Sign in with Apple** enabled.
2. In Xcode → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**.
3. In **Supabase** (or your auth provider), enable the Apple provider and paste **Services ID**, **Key ID**, **Team ID**, and **private key** per Supabase docs.
4. In your app’s login flow, call the Sign in with Apple API and exchange the credential with Supabase (implementation is not in this prototype repo).

### 4) Push notifications (APNs + in-app toggles)

The **Profile** tab has toggles (daily, tournament/bracket, seasonal) that store preferences in `@AppStorage`. To deliver real pushes later:

1. In Xcode → **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
2. If you use notification **extensions** or **background modes**, add only what you need.
3. In Apple Developer, create an **APNs** key (or certificates for legacy flows).
4. Upload the APNs key to **Supabase** (or your push provider) if you use it for outbound notifications.
5. Implement device token registration in the app (`UIApplication` / `UNUserNotificationCenter`) and send the token to your backend.

Until then, toggles only record user intent; no remote pushes are sent by this prototype.

### 5) Local notifications (optional)

If you schedule local reminders on-device, request permission when the user enables a toggle (the prototype requests permission when a notification toggle is turned on). For production, align copy and timing with App Store guidelines.

### 6) The Odds API key (Play tab)

1. Sign up at [the-odds-api.com](https://the-odds-api.com/) and copy your API key.
2. In Xcode: **Juicd** target → **Info** → **Custom iOS Target Properties**:
   - **Key:** `ODDS_API_KEY` (String)
   - **Value:** your key  
   Or add the same entry to **Info.plist**.
3. **Production:** do **not** ship the key in the client. Move calls to a **Supabase Edge Function** or backend proxy and strip the key from the app binary (see below).

### 6b) Juicd nightly boosted odds (product + ops)

The app can highlight a couple of props each **local slate** (see §6c) with a **1.5×** multiplier on displayed decimal odds (the prototype picks them deterministically from the slate key).

**Out of code (production):**

1. **Schedule:** Run a nightly job (e.g. Supabase **pg_cron**, **Edge Function** on a schedule, or external worker) shortly after odds settle or before the US slate — whenever your trading/compliance window allows.
2. **Selection rules:** Decide how many boosts per night (e.g. 2), eligible sports/markets, and max liability. Store selections in a table such as `juicd_nightly_boosts` with `date_utc`, `market_id` / `prop_id`, `multiplier`, `enabled`.
3. **API:** Expose boosts to the client via your odds proxy or a small **RPC** so the app never trusts client-side random picks for real money.
4. **Compliance:** Get these rules reviewed for your jurisdictions; display clear copy that boosted prices are promotional.
5. **A/B or killswitch:** Optional feature flag in **Remote Config** or a Supabase row to disable boosts without an app update.

### 6c) Daily slate (6am local), one board for everyone, college + pro, live odds

**What the prototype does in code**

- **Slate day** = your **local calendar date** whose window starts at **6:00** (not midnight). Before 6am, you’re still on the **previous** slate. The daily **100 pt** refill, ranked participation keys, Play board IDs, and Juicd boost picks all use this **same** `yyyy-MM-dd` key in the device’s timezone.
- **Same bets / same prices without a database:** the Play tab builds props from `DailySlateBoard` + `StableUUID` so **every user** with the same slate key gets the **identical** stub lines and decimal prices. That’s enough for UI demos; it is **not** a substitute for a real trading pipeline.
- **Live Odds API:** when `ODDS_API_KEY` is set, the prototype loads **one** cached moneyline per cold start: **1-hour** disk TTL plus **at most one network fetch per app process** (`TheOddsAPIService`) so you don’t hammer the API while iterating. Production should move calls behind a **Supabase Edge Function** (or other proxy), optionally **store odds snapshots** in Postgres for feeds, history, and fair settlement — the client then reads your API instead of polling The Odds API directly.

**What you should do in production (outside this repo)**

1. **Morning “global” slate job (recommended):** Schedule a **Supabase Edge Function** or worker shortly after **6am in each target timezone** (or run once in **UTC** and slice by region). That job should:
   - Call The Odds API (server-side key) for **each** sport you offer — include **NCAA** and **pro** by using the right `sport_key` values from [the-odds-api docs](https://the-odds-api.com/sports-odds-data/sport-schemas.html) (e.g. `basketball_ncaab`, `basketball_nba`, `americanfootball_ncaaf`, `americanfootball_nfl`, etc.).
   - Filter to **events whose start time falls on “today”** in that timezone (or your chosen cutoff).
   - Write rows to something like `daily_slate_events` + `daily_slate_markets` with **frozen opening lines** for the social/competition layer (so leaderboard math is fair), while the app still shows **live** prices from polling for display.
2. **Optional single source of truth:** If you need **one** identical number for every player for settlement (not just display), store **event id + market id + price snapshot** in Postgres and have the client **read** that for eligible picks; use the API only for refresh/confirmation.
3. **College vs pro:** Enable only the sport keys you’re licensed to offer in each state; compliance is **out of code** (counsel, geo-fencing, age gates).
4. **Polling vs push:** The Odds API allows periodic fetches; respect their rate limits. You do **not** need a DB **only** for “live” prices if clients poll an Edge proxy — you **do** need durable storage if you must prove what line was offered at bet time.

### 7) Supabase: project and client config

1. Create a project at [Supabase](https://supabase.com).
2. Note **Project URL** (`SUPABASE_URL`) and **anon public key** (`SUPABASE_ANON_KEY`).
3. Add the Supabase Swift package to the app when you integrate; store URL/key in **Info.plist** / **xcconfig** (gitignored) or **build settings**, not in source control.
4. Enable **Authentication** providers you need (Apple, email, etc.).
5. Design tables for **profiles**, **points ledger**, **bet slips**, **groups**, **badges** — see `JUICD_SETUP.md` for a longer schema outline (optional reference).
6. Turn on **Row Level Security** and write policies so users only read/write their own rows; privileged writes should go through **Edge Functions** or **RPC** with `service_role` on the server only.
7. **Daily tournament entry window:** Persist slate games with `tip_off_at` (UTC). Set **`entry_closes_at = tip_off_at − 1 hour`** so the backend can finalize bracket seeds after entries close and before tip. Reject new entries after `entry_closes_at`.

### 7b) Daily closest tournament (content & ops)

The app supports **daily closest-pick** brackets: users pick a **tournament variant** (headline game + schedule), see a **preview of four rounds** before entering, then submit one numeric pick per round. Production behavior should mirror that flow with data you maintain **outside** the client:

1. **Tournament variants (catalog rows)**  
   For each row: `id`, `tournament_name` (e.g. “NFL prime-time sprint”), `headline_label` (e.g. “KC @ BUF”), `tip_off_at`, `entry_closes_at` (= tip − 1 hour), and **four round definitions** (see below). The client only renders what the API returns—no hard-coded copy in the shipped app.

2. **Four rounds — semantics**  
   Each round must describe a **real time window** so copy matches the stat:
   - **Quarter rounds:** e.g. “Q3 combined points” = both teams’ points scored **in the third quarter only** (not first half or full game).
   - **Final round options** (pick one style per variant): **full game** total, **second half** only, **fourth quarter** only, or another scoped line—keep the label and settlement rule identical.

3. **Round payload (example fields)**  
   Per round: `round_index` (1…4), `title`, `subtitle` / settlement description, optional `sim_min` / `sim_max` if the server drives dev or sandbox simulations. Persist the **locked** round list when the user enters so mid-tournament copy cannot change.

4. **Bracket rules**  
   One entry per user per **slate day** (aligned with your existing 6am local slate key if you share the Play board). Sixteen slots, single elimination vs a seeded opponent per round; tiebreakers are app-defined (closest to result). **Demo “simulate full bracket”** in the prototype only: it plays all four rounds for visibility even after a loss—competitive mode still eliminates on first loss.

5. **Where the prototype lives**  
   Until a backend exists, dev tournament options and round text are defined in **`Services/JuicdRepository.swift`** (`dailyGameOptions`). Replace that with API-driven models when you wire Supabase or an Edge Function.

### 7c) Friends — requests, leaderboard, recent form (Supabase)

**In the app (prototype):** The **Friends** tab stores invites and friendships in the same local `UserDefaults` blob as the rest of Juicd (`InMemoryJuicdRepository`). Search finds **other profiles created on this device** (different sign-in names). The MMR leaderboard includes **you + accepted friends**. Tapping a friend shows **recent Play parlays** only (ranked daily / daily bracket history can be added when those flows are backed by SQL).

**Out of code (production):**

1. Apply the SQL migration **[`supabase/migrations/20260322120000_juicd_friends.sql`](supabase/migrations/20260322120000_juicd_friends.sql)** (or paste into the Supabase SQL editor). It creates:
   - `juicd_friend_requests` — pending rows (`from_id`, `to_id`); delete on accept/reject/cancel.
   - `juicd_friendships` — one row per undirected edge with **`user_low < user_high`** (UUID lexicographic) so pairs are unique.
2. **RLS:** Policies in the file are a starting point. Prefer **RPC** or Edge Functions for “accept” (transaction: delete request + insert friendship) so clients never forge edges. Tighten `INSERT` on `juicd_friendships` if you only allow server-side writes.
3. **Leaderboard:** Read friends via `juicd_friendships` + join `profiles` for `display_name`, `mmr`, `current_tier`. Sort by `mmr desc`.
4. **Friend activity:** Expose a view or RPC returning recent **`play_slips` / ledger** rows for a given `friend_user_id`, scoped by RLS (only if friendship exists).
5. **First-launch tutorial** is controlled by **`UserDefaults` key `juicd_tutorial_completed`** (no server).

### 8) Secrets and CI

1. Never commit `ODDS_API_KEY`, `SUPABASE_ANON_KEY` (if treated as secret in your threat model), or APNs private keys.
2. Use `Local.xcconfig` / **User-Defined Build Settings** excluded from git, or Secrets in CI.
3. Confirm `.gitignore` includes `Local.xcconfig`, `xcuserdata/`, and `DerivedData/`.

### 9) App Store Connect

1. Create an app record in **App Store Connect**.
2. Set **pricing**, **App Privacy**, **age rating** (gambling/sports betting may require extra disclosures by region).
3. Provide a **Privacy Policy URL**.
4. Complete **Sign in with Apple** configuration if you use it.
5. Declare **ads** and analytics per network policies if you add AdMob or similar.

### 10) Testing before release

1. Use a **staging** Supabase project for end-to-end tests.
2. Exercise auth, ledger, RLS, and odds proxy latency.
3. Verify no API keys appear in the shipping binary (strings dump / archive inspection).

---

## Extra reference

- Longer narrative notes (schema ideas, ads, revenue share) live in [`JUICD_SETUP.md`](JUICD_SETUP.md). Prefer this **README** for the ordered checklist.
