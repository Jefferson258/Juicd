# Juicd — Ads

**Option B with X (locked Sep 1, 2026; height cut Sep 11):** a dismissible
**320×100 AdMob large banner** inside the dark “Sponsored” card on Play and
Tourney. No sticky banner above the tab bar. No rewarded video.

Simulator/DEBUG loads Google **Test Ad** creatives. TestFlight shows no
ads. The App Store build uses the banner unit in `Juicd/Info.plist`.

---

## What the player sees

- **Play:** one 320×100 box under the Play title, including when the board
  is empty. Tap **X** and it stays gone until relaunch (DEBUG can spawn
  another from Profile). The slot is not created while another tab is showing.
- **Tourney:** the same card under the title. It loads with the screen so it
  is already there when that tab is opened. **X** hides it for that visit.
- A failed load retries up to 4 times, then the slot stays collapsed.
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
