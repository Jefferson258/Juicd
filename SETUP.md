# Juicd — Setup (outside the codebase)

Configure **Xcode**, **Apple Developer**, **keys**, and **Supabase** here. **Feature overview** → [README.md](README.md). **Deep dives** → [README_REFERENCE.md](README_REFERENCE.md).

---

## Quick checklist

| Step | What |
|------|------|
| ☐ | Open `Juicd.xcodeproj` → **Juicd** scheme → **Run** (⌘R) on Simulator or device |
| ☐ | **Signing & Capabilities** → Team + unique **Bundle ID** |
| ☐ | **Sign in with Apple** capability (entitlements file `Juicd.entitlements` is in the repo; enable capability in Xcode if needed) |
| ☐ | **Supabase shared odds mode:** run SQL migrations + deploy Edge Functions (`play-board`, `resolve-play-slip`; sources in `supabase/functions/`) |
| ☐ | Add `SUPABASE_URL` + `SUPABASE_ANON_KEY` to iOS target **Info** (or `Local.xcconfig`, gitignored) |
| ☐ | Add `ODDS_API_KEY` as a **Supabase Edge Function secret** (for live mode); optional **`ODDS_API_KEY` in iOS Info** only for client fallback when Supabase isn’t configured |
| ☐ | (Later) **Push:** capability + APNs key + backend to send |
| ☐ | (Ship) **App Store Connect** record, privacy URL, encryption export answer |
| ☐ | (Ads) See **§8** when wiring Google Mobile Ads or mediation |

---

## 1. Open project and build

1. Install **Xcode** (Mac App Store).
2. Open **`Juicd.xcodeproj`** at the repo root (same folder as this file).
3. Select the **Juicd** scheme and an **iOS Simulator** or **device**.
4. **Product → Build** (⌘B).

---

## 2. Signing, bundle ID, Sign in with Apple

1. Select the **Juicd** target → **Signing & Capabilities**.
2. **Team:** your Apple Developer team.
3. **Bundle Identifier:** unique (e.g. `com.yourname.juicd`).
4. **+ Capability → Sign in with Apple** (should match `Juicd.entitlements`).

For **Supabase Auth** later: **Authentication → Providers → Apple** → **Client ID** = iOS **Bundle ID** (native only).

---

## 3. Supabase shared odds + outcomes (beta default)

The app now uses Supabase Edge Functions for:

- shared Play board odds across all beta devices (`play-board`)
- shared deterministic slip outcomes (`resolve-play-slip`)
- runtime source switch (`simulated` vs `live`) via DB config

---

### 3.1 Run SQL migration

Run these migrations in Supabase SQL editor (or CLI):

- `supabase/migrations/20260322120000_juicd_friends.sql`
- `supabase/migrations/20260424113000_juicd_odds_runtime.sql`

These migrations are idempotent and safe to rerun:

- tables: `create table if not exists`
- indexes: `create index if not exists`
- policies: `drop policy if exists` then recreate

The second migration creates:

- `juicd_runtime_config` (contains `odds_mode`, `outcome_mode`)
- `juicd_play_board_snapshots`
- `juicd_play_slip_outcomes`

### 3.2 Deploy Edge Functions

From your local machine (with Supabase CLI + linked project):

- `supabase functions deploy play-board`
- `supabase functions deploy resolve-play-slip`

### 3.3 Set Supabase function secrets

Set these in Supabase (Edge Functions secrets):

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ODDS_API_KEY` (only used when `odds_mode=live`)

### 3.4 Configure iOS app keys (client)

In **Juicd** target → **Info** → **Custom iOS Target Properties**:

- `SUPABASE_URL` (your project URL)
- `SUPABASE_ANON_KEY` (anon/public key)

Do not add `ODDS_API_KEY` to iOS target Info for this flow.

**Optional (local dev only):** if `SUPABASE_URL` / `SUPABASE_ANON_KEY` are **not** set but **`ODDS_API_KEY`** is in target **Info**, the app can still load a single cached **The Odds API** line on-device. Prefer the Edge Function path above for betas and production so provider keys stay off the client.

### 3.5 Flip switch: simulated -> live

For beta (default, no external dependency), keep:

```sql
update public.juicd_runtime_config
set value = 'simulated', updated_at = now()
where key = 'odds_mode';
```

When you are ready for real Odds API:

```sql
update public.juicd_runtime_config
set value = 'live', updated_at = now()
where key = 'odds_mode';
```

Rollback is the same switch back to `simulated`.

### 3.6 (Optional) Prewarm board snapshots on a schedule

To keep responses fast and avoid first-user cold generation, schedule `play-board` in Supabase:

- Use Supabase cron/pg_cron or an external scheduler.
- Hit `GET https://<project-ref>.supabase.co/functions/v1/play-board` every 5-15 minutes.
- Include headers:
  - `apikey: <SUPABASE_ANON_KEY>`
  - `Authorization: Bearer <SUPABASE_ANON_KEY>`

---

## 4. Supabase (general)

1. Create a project → **Settings → API**: **Project URL** + **anon public key**.
2. This app currently calls Supabase Edge Functions via `URLSession`; no extra SDK required for odds mode.
3. Run SQL migrations under `supabase/migrations/`.
4. Enable **RLS** on user tables; never ship **service_role** in the app.

---

## 5. Push notifications (optional / later)

1. **Signing & Capabilities → Push Notifications**.
2. Apple Developer → **Keys** → APNs **.p8** (Key ID + Team ID).
3. Implement token upload + your sender (Edge Function or other).

Profile toggles are local until you wire a backend.

---

## 6. Secrets and git

- Do **not** commit `ODDS_API_KEY`, `SUPABASE_ANON_KEY` (if you treat it as secret), or APNs keys.
- Use `Local.xcconfig` (gitignored) or Xcode **User-Defined** settings for local keys.

---

## 7. App Store / TestFlight (ship)

1. **App Store Connect** → new app → **Bundle ID** must exist in Developer portal.
2. **Privacy Policy URL**, **App Privacy** questionnaire, **encryption** (`ITSAppUsesNonExemptEncryption` = NO if only HTTPS).
3. **Archive** → **Distribute** → TestFlight / App Store.

---

## 8. In-app ads (Google Mobile Ads or other)

The app ships with **dev-only** placeholder ads on the **Play** tab (toggle under **Profile → Prototype tools**). Behavior and frequency math are documented in **[ADS.md](ADS.md)**.

To connect **real** ads:

1. **Create ad units** in [Google AdMob](https://admob.google.com/) (or your network): use **native** or **banner** formats to match the current placeholder layout.
2. **Add the SDK** — e.g. [Google Mobile Ads SDK for iOS](https://developers.google.com/admob/ios/quick-start): Swift Package Manager **or** CocoaPods as Google documents.
3. **Use test ad unit IDs** while developing ([Google test units](https://developers.google.com/admob/ios/test-ads)); put production IDs in **Info.plist** / **xcconfig** that is **gitignored** if the repo is public.
4. **Initialize** the SDK once at launch (e.g. in `JuicdApp` / app delegate pattern per Google’s current SwiftUI guidance).
5. **Privacy / EEA:** integrate the **User Messaging Platform (UMP)** SDK for consent where required before loading personalized ads.
6. **App Store Connect:** answer the advertising / tracking questions; provide a **Privacy Policy URL** if you show third-party ads.
7. **Replace** the SwiftUI placeholder in [`Views/PlayView.swift`](Views/PlayView.swift) with your network’s native ad view; keep your own **frequency caps** if you want to stay close to the rare dev behavior in [ADS.md](ADS.md).

**Note:** Many ad networks restrict **real-money gambling** creatives; sports media / generic brand ads are easier to fill. Get legal/compliance review for your jurisdictions.

For a full advertiser onboarding/sales/ops playbook, see [`ADVERTISERS_SETUP.md`](ADVERTISERS_SETUP.md).

---

## 9. App Store listing copy (draft)

### App Name

Juicd

### Subtitle

Daily sports picks, ladders, and friends

### Promotional Text

Build quick picks, track season progress, and compete with friends in a fast, skill-first sports experience.

### Description

Juicd is a fast sports picks app built for short daily sessions.

- Build singles and parlays from a shared board
- Compete in daily Tourney brackets
- Track points, rank movement, and season progress
- Compare with friends on leaderboard views
- Earn badges as you win and improve

Built for smooth, focused play:

- Shared board odds across beta devices
- Deterministic outcomes for reproducible testing
- Quick navigation with clear, high-contrast UI

### Keywords

sports picks,parlay,predictions,leaderboard,fantasy,sports betting tracker,tournament

---

## 10. Screenshot plan for App Store page

Capture at least 6 iPhone screenshots (prepare 6.7-inch and 6.5-inch sets):

1. **Play board**: sport filters + visible odds tiles
2. **Parlay builder**: legs, stake, estimated payout
3. **Tourney**: bracket entry + round pick flow
4. **Dashboard**: Play slips (today / past slates), rank tier + progress cards
5. **Friends leaderboard**: social comparison view
6. **Profile + badges**: long-term progression

Suggested caption snippets:

- "Build picks in seconds"
- "Mix picks your way"
- "Compete in daily rounds"
- "Track rank and momentum"
- "Climb with your crew"
- "See your progress and rewards"

Quality rules:

- Use polished sample data (no debug/dev labels)
- Keep copy readable and uncluttered
- Keep color/style consistent across all screenshots

---

## Troubleshooting

| Symptom | Likely fix |
|---------|------------|
| Sign in with Apple fails | Capability on target + **Bundle ID** matches App ID with Sign in with Apple |
| No shared odds | Check iOS `SUPABASE_URL` + `SUPABASE_ANON_KEY`, function deploy, and function logs in Supabase dashboard |
| No odds at all | If Supabase isn’t set up, set **`ODDS_API_KEY`** in target Info for client fallback, or complete §3 |
| Live mode not working | Verify `juicd_runtime_config.odds_mode='live'` and Edge secret `ODDS_API_KEY` is set |
| Build errors after clone | Open `.xcodeproj`, clean build folder (⇧⌘K), rebuild |
| Ads don’t appear | Toggle **Show dev ad placeholders** on Profile; change sport/filter to rebuild feed; wait **cooldown** (see [ADS.md](ADS.md)) |

---

*For nightly boosts, slate jobs, friends SQL, and long checklists → [README_REFERENCE.md](README_REFERENCE.md).*
