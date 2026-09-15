# Juicd — Ads

**Option B with X (locked Sep 1, 2026; height cut Sep 11):** a dismissible
**320×100 AdMob large banner** inside the dark “Sponsored” card on Play and
Tourney. No sticky banner above the tab bar. No rewarded video.

Simulator/DEBUG loads Google **Test Ad** creatives. Release on device uses
the banner unit in `Juicd/Info.plist` requested as a 320×100 large banner.

---

## What the player sees

- **Play:** one 320×100 box at the top of the pick list. Tap **X** and it
  stays gone until relaunch (DEBUG can spawn another from Profile).
- **Tourney:** the same card under the header. **X** hides it for that visit.
- **Dashboard / Friends / Profile:** no ads.
- No interstitials, no full-screen ads, no 4% roll, no bottom strip.

---

## Files

| File | Role |
|------|------|
| `Views/JuicdBannerAdView.swift` | `JuicdSponsoredBannerCard` (320×100 + X) |
| `Views/JuicdNativeAdPlaceholder.swift` | Option A mock (launch-arg only) |
| `Services/JuicdAdsConfig.swift` | IDs + default `.cardBanner` |
| `Services/JuicdAdsDev.swift` | Session placement helper |
| `Views/PlayView.swift` | In-feed insertion |
| `Views/TourneyView.swift` | Card under header |
| `Views/ProfileView.swift` | DEBUG spawn previews only |
| `Juicd/Info.plist` | AdMob App ID + banner unit |
