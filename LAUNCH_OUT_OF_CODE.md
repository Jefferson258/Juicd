# Juicd — Everything to do outside the codebase

Step-by-step runbook to run Juicd locally, connect Supabase, optionally monetize with ads, ship TestFlight, and publish on the **App Store**.

**You have a personal Apple Developer account today.** LLC, banking, and ad payout setup: **[`../LegalDocuments/BUSINESS_LLC_AND_MONETIZATION.md`](../LegalDocuments/BUSINESS_LLC_AND_MONETIZATION.md)**.

**Start here (your numbered steps + time estimates):** [YOUR_LAUNCH_CHECKLIST.md](YOUR_LAUNCH_CHECKLIST.md)  
**You vs Agent by phase:** [LAUNCH_EXECUTION_SPLIT.md](LAUNCH_EXECUTION_SPLIT.md) · **Max access + credentials (incl. Odds API):** [MAX_ACCESS_SETUP_SPLIT.md](MAX_ACCESS_SETUP_SPLIT.md)  
**Service & key setup:** [SETUP.md](SETUP.md)  
**Ad sales / direct sponsors:** [ADVERTISERS_SETUP.md](ADVERTISERS_SETUP.md)  
**Ad behavior reference:** [ADS.md](ADS.md)  
**Marketing site:** [../juicd-website/LAUNCH_OUT_OF_CODE.md](../juicd-website/LAUNCH_OUT_OF_CODE.md)

---

## Phase 0 — Accounts you need

| Account | Why |
|---------|-----|
| **Apple Developer** (you have this) | Signing, TestFlight, App Store |
| **Supabase** | Shared play board, slip outcomes, optional auth/friends |
| **The Odds API** (optional, live mode) | Real odds via Edge Function secret only |
| **Google AdMob** (optional) | In-app ads — see Phase 9 |
| **Domain + Vercel** | `juicd.app` marketing site + privacy URL |

---

## Phase 1 — Run the app locally (no backend)

1. Install **Xcode**.
2. Open `Juicd.xcodeproj`.
3. Scheme **Juicd** → iOS Simulator → **Product → Run** (⌘R).
4. On sign-in screen, use **Skip — local dev account** for offline UI testing.

The app runs **local-first** with `UserDefaults` when Supabase is not configured.

---

## Phase 2 — Apple Developer portal (App ID)

1. [developer.apple.com/account](https://developer.apple.com/account) → **Identifiers → +** → **App IDs**.
2. **Bundle ID:** explicit (e.g. `com.yourname.juicd` or `juicd.Juicd` — must match Xcode).
3. Enable:
   - **Sign in with Apple** (if shipping auth)
   - **Push Notifications** (optional, later)
   - **In-App Purchase** (only if you add IAP later)
4. Register the identifier.

---

## Phase 3 — Xcode signing

1. **Juicd** target → **Signing & Capabilities**.
2. **Team:** your developer team.
3. **Bundle Identifier:** matches Phase 2.
4. **+ Capability → Sign in with Apple** (matches `Juicd.entitlements` in repo).
5. Run on a **physical device** once to confirm signing.

**Codesign on Desktop/iCloud:** if builds fail, use `-derivedDataPath /tmp/juicd-derived` or build from a non-iCloud folder.

---

## Phase 4 — Supabase (shared board + outcomes)

Follow [SETUP.md §3–§4](SETUP.md):

1. Create Supabase project → copy **URL** + **anon key**.
2. Run SQL migrations in `supabase/migrations/` (see SETUP.md for file list).
3. Deploy Edge Functions:
   - `play-board`
   - `resolve-play-slip`
4. Set Edge Function **secrets**: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, optional `ODDS_API_KEY` for live mode.
5. In Xcode **Juicd** target **Info**:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
6. Keep `ODDS_API_KEY` **off the client** in production; use `juicd_runtime_config.odds_mode` (`simulated` vs `live`).

**Verify:** Two simulators show the same board odds after refresh.

---

## Phase 5 — Sign in with Apple + Supabase Auth (if shipping accounts)

1. App Store Connect / Developer portal: Sign in with Apple enabled on App ID.
2. Supabase → **Authentication → Providers → Apple** → **Client ID** = iOS Bundle ID.
3. Configure Apple Services ID / keys per Supabase docs if using web callback (native-only can use bundle ID).
4. Test real Sign in with Apple on device.

---

## Phase 6 — Legal URLs & App Store compliance

Juicd touches sports picks — expect scrutiny on gambling positioning. You need clear copy that you are **not** a real-money sportsbook unless licensed.

1. Deploy [juicd-website](../juicd-website).
2. Publish **Privacy Policy** URL (required).
3. Publish **Terms of Use** (recommended; required for subscriptions/ads in many cases).
4. **Support contact** (email or form).
5. If showing **third-party ads**, disclose in privacy policy and App Privacy questionnaire.

---

## Phase 7 — App Store Connect: create the app

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → +** → **New App**.
2. **Name:** Juicd  
3. **Bundle ID:** from Phase 2.  
4. **SKU:** e.g. `juicd-ios-001`.

---

## Phase 8 — Listing assets & metadata

Draft copy in [SETUP.md §9–§10](SETUP.md).

1. **1024×1024** app icon.
2. **Screenshots** — use `qa-screenshots/` or capture via `JuicdUITests` (`testVisualQAScreenshots`).
3. Required iPhone display sizes per App Store Connect.
4. **App Privacy** — declare data collected (identifiers, usage data if analytics, ad data if AdMob).
5. **Age rating** — answer honestly; sports/gambling-adjacent content may affect rating.
6. **Export compliance** — typically standard HTTPS only.

**Review risk:** Prepare review notes explaining virtual points only, no real-money wagering, regional restrictions if any.

---

## Phase 9 — Ads & advertiser revenue (optional)

### Path A — AdMob (network fill)

1. Create [Google AdMob](https://admob.google.com/) account.
2. Register **Juicd** iOS app → create **ad units** (native/banner).
3. Complete **UMP** (consent) for EEA users before personalized ads.
4. Link AdMob to **Google payments profile** for payouts (see LLC doc for entity).
5. Use **test ad unit IDs** until App Store approval.
6. App Store Connect: declare ads / tracking as applicable.

Details: [SETUP.md §8](SETUP.md), [ADS.md](ADS.md).

### Path B — Direct sponsors

1. Follow [ADVERTISERS_SETUP.md](ADVERTISERS_SETUP.md) for contracts, Supabase `ad_campaigns`, billing.
2. Invoice advertisers to your **LLC bank account** (not personal once you incorporate).

---

## Phase 10 — TestFlight

1. Xcode **Archive** → upload to App Store Connect.
2. Internal TestFlight → external after beta review.
3. Test with Supabase `simulated` mode first; flip to `live` only when secrets are ready.

---

## Phase 11 — Submit for review

1. Create version **1.0.0** → attach build.
2. **Review notes:** demo account or skip path; explain virtual currency.
3. Attach privacy URL, support URL, marketing URL (juicd.app).
4. Submit.

---

## Phase 12 — After launch

1. Replace placeholder App Store URL in `juicd-website` (`src/constants.ts`).
2. Refresh website screenshots from `juicd/qa-screenshots/`.
3. Monitor Supabase function logs and odds API quota if live.

---

## Phase 13 — LLC + org Apple account (later)

See [BUSINESS_LLC_AND_MONETIZATION.md](../LegalDocuments/BUSINESS_LLC_AND_MONETIZATION.md) for entity formation, D-U-N-S, Organization developer enrollment, and routing AdMob / App Store payouts to the LLC.

---

## Related files

| File | Purpose |
|------|---------|
| [SETUP.md](SETUP.md) | Keys, Supabase, App Store draft copy |
| [ADVERTISERS_SETUP.md](ADVERTISERS_SETUP.md) | Direct ad sales |
| [README_REFERENCE.md](README_REFERENCE.md) | Long checklists |

---

*Not legal or tax advice. Sports picks apps may face regional gambling regulations — consult a lawyer.*
