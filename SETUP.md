# Juicd — Setup (outside the codebase)

Configure **Xcode**, **Apple Developer**, **keys**, and **Supabase** here. **Feature overview** → [README.md](README.md). **Deep dives** → [README_REFERENCE.md](README_REFERENCE.md).

---

## Quick checklist

| Step | What |
|------|------|
| ☐ | Open `Juicd.xcodeproj` → **Juicd** scheme → **Run** (⌘R) on Simulator or device |
| ☐ | **Signing & Capabilities** → Team + unique **Bundle ID** |
| ☐ | **Sign in with Apple** capability (entitlements file `Juicd.entitlements` is in the repo; enable capability in Xcode if needed) |
| ☐ | **Odds API (Play tab):** add `ODDS_API_KEY` in target **Info** (or `Local.xcconfig`, gitignored) — [the-odds-api.com](https://the-odds-api.com/) |
| ☐ | (Later) **Supabase** project + Swift package + `SUPABASE_URL` / `SUPABASE_ANON_KEY` — do not commit secrets |
| ☐ | (Later) **Push:** capability + APNs key + backend to send |
| ☐ | (Ship) **App Store Connect** record, privacy URL, encryption export answer |

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

## 3. Odds API key (Play tab)

1. Sign up at [the-odds-api.com](https://the-odds-api.com/) and copy your API key.
2. **Juicd** target → **Info** → **Custom iOS Target Properties**:
   - Key: **`ODDS_API_KEY`** (String)
   - Value: your key  

**Production:** do not ship the key in the client; use a **backend or Supabase Edge Function** proxy.

---

## 4. Supabase (when you wire a backend)

1. Create a project → **Settings → API**: **Project URL** + **anon public key**.
2. Add **supabase-swift** to the target; pass URL/key via **Info.plist** / **xcconfig** (gitignored if public repo).
3. Run SQL migrations under `supabase/migrations/` as needed (see README_REFERENCE for friends, etc.).
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

## Troubleshooting

| Symptom | Likely fix |
|---------|------------|
| Sign in with Apple fails | Capability on target + **Bundle ID** matches App ID with Sign in with Apple |
| No live odds | `ODDS_API_KEY` set on the **Juicd** target Info; check quota / network |
| Build errors after clone | Open `.xcodeproj`, clean build folder (⇧⌘K), rebuild |

---

*For nightly boosts, slate jobs, friends SQL, and long checklists → [README_REFERENCE.md](README_REFERENCE.md).*
