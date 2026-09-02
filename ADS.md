# Juicd — Ads

**Option B with X (locked Sep 1, 2026):** a dismissible **300×250 AdMob**
box inside the dark “Sponsored” card on Play and Tourney. No sticky banner
above the tab bar. No rewarded video.

Simulator/DEBUG loads Google **Test Ad** creatives. Release on device uses
the banner unit in `Juicd/Info.plist` requested as a medium rectangle.

---

## What the player sees

- **Play:** one 300×250 box at the top of the pick list. Tap **X** and it
  stays gone until they spawn another from Profile (or relaunch).
- **Tourney:** the same card under the header. **X** hides it for that visit.
- **Dashboard / Friends / Profile:** no ads.
- No interstitials, no full-screen ads, no 4% roll, no bottom strip.

---

## Files

| File | Role |
|------|------|
| `Views/JuicdBannerAdView.swift` | `JuicdSponsoredBannerCard` (300×250 + X) |
| `Views/JuicdNativeAdPlaceholder.swift` | Option A mock (launch-arg only) |
| `Services/JuicdAdsConfig.swift` | IDs + default `.cardBanner` |
| `Services/JuicdAdsDev.swift` | Toggle helper |
| `Views/PlayView.swift` | In-feed insertion |
| `Views/TourneyView.swift` | Card under header |
| `Views/ProfileView.swift` | Show ads + spawn previews |
| `Juicd/Info.plist` | AdMob App ID + banner unit |
