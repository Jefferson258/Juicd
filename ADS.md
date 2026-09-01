# Juicd — Ads

Play-tab ads: **Google AdMob banners** (SDK wired) plus optional fake placeholder creatives for layout testing.

---

## What was implemented

1. **`JuicdAdsConfig`** — reads `GADApplicationIdentifier` and `JUICD_ADMOB_BANNER_UNIT_ID` from Info.plist. Empty / missing → Google **test** IDs.
2. **`JuicdMobileAds.start()`** — initializes the Google Mobile Ads SDK at launch (`JuicdApp`). Requests are tagged **non-personalized** (`npa=1`) so we do not need ATT yet.
3. **`JuicdBannerAdView`** — adaptive banner in the Play feed.
4. **`JuicdAdsDev`** — frequency helpers + fake creatives (spawn from Profile).
5. **`JuicdNativeAdPlaceholder`** — still used when you spawn a fake sponsor from Profile.
6. **Profile → Prototype tools** — toggle **Show ads on Play tab** (default **off**). With test IDs, the toggle shows one real test banner so the SDK can be verified.

---

## Credentials to paste later (no Google password)

From [AdMob](https://admob.google.com/) → Apps → Juicd iOS (`com.jefferson258.juicd`):

1. **App ID** — `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
2. **Banner ad unit ID** — `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`

Put them in `Juicd/Info.plist`:

| Key | Value |
|-----|--------|
| `GADApplicationIdentifier` | App ID |
| `JUICD_ADMOB_BANNER_UNIT_ID` | Banner unit ID |

**Pasted Sep 1, 2026** (publisher `pub-1484242722888691`):

| Key | Value |
|-----|--------|
| `GADApplicationIdentifier` | `ca-app-pub-1484242722888691~4589222474` |
| `JUICD_ADMOB_BANNER_UNIT_ID` | `ca-app-pub-1484242722888691/1963059137` |

Payouts (W-9, LLC bank) are still required before Google will fully approve the account and pay out. Fill may be empty until payment setup is done. Never click your own ads. Never use Google’s sample test IDs (`ca-app-pub-3940256099942544…`) in a shipped store build.

---

## Frequency

- **Test IDs:** one banner per Play feed rebuild while the Profile toggle is on (so you can see it).
- **Production IDs:** same 4% + 120s cooldown as the old placeholder (`JuicdAdsDev.shouldShowAd`).

---

## App Store / privacy (when shipping with ads)

- App Privacy: advertising data; tracking **no** while we stay non-personalized / no ATT.
- Privacy Policy already mentions AdMob/ATT for when that is enabled.

---

## Files

| File | Role |
|------|------|
| `Services/JuicdAdsConfig.swift` | Test vs production IDs |
| `Services/JuicdMobileAds.swift` | SDK start + npa request |
| `Views/JuicdBannerAdView.swift` | SwiftUI banner wrapper |
| `Services/JuicdAdsDev.swift` | Policy + fake creatives |
| `Views/JuicdNativeAdPlaceholder.swift` | Spawn-preview card |
| `Views/PlayView.swift` | Feed insertion |
| `Views/ProfileView.swift` | Toggle |
| `Juicd/Info.plist` | App ID + banner unit |
