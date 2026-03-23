# Juicd — Ads (dev placeholders)

This document describes the **in-app dev ad prototype**: where it appears, how often, fake campaign data, and how to replace it with a real network (e.g. Google Mobile Ads).

---

## What was implemented

1. **`JuicdAdsDev`** ([`Services/JuicdAdsDev.swift`](Services/JuicdAdsDev.swift))  
   - Constants: eligibility probability and cooldown between **recorded** impressions.  
   - `shouldShowAd(adsEnabled:)` — decides whether the current Play feed build may include **one** sponsored row.  
   - `recordImpression()` — called when the ad cell is first shown (viewable row).

2. **`JuicdDevAdCreative`** — five **fictional** sponsors (sports drink, streaming mock, odds concept, fantasy, podcast). Used only for layout/copy testing.

3. **`JuicdNativeAdPlaceholder`** ([`Views/JuicdNativeAdPlaceholder.swift`](Views/JuicdNativeAdPlaceholder.swift))  
   - Native-style card: “Sponsored”, headline, body, fake CTA. Clearly **not** a betting tile. **Top-trailing** `xmark.circle.fill` dismisses the ad for the current ribbon feed (clears any forced creative; random ads stay off until you change sport/filter or similar so the ribbon list identity changes).

4. **Play tab** ([`Views/PlayView.swift`](Views/PlayView.swift))  
   - When ads are enabled, the feed may insert **at most one** ad at a **random index** among ribbon blocks (index `0...n`, so it can sit before the first ribbon or after the last).

5. **Profile → Prototype tools**  
   - Toggle **`juicd_ads_enabled`** (default **off**): “Show dev ad placeholders (Play tab)”.
   - **Spawn** buttons (one per fake sponsor): set a **forced creative id** and bump a **revision** counter so the **Play** tab rebuilds placement immediately—shows that ad **before the first ribbon** without the 4% roll. Does **not** require the main ad toggle to be on. **Clear forced preview** clears the id; turning the main ad toggle **off** also clears the forced id.

No third-party SDK is linked yet; nothing loads from an ad network.

---

## Frequency math (why ads feel rare)

Let:

- \(A\) = ads toggle **on** (user must enable in Profile).  
- \(C\) = **cooldown** passed: last recorded impression was at least **`minSecondsBetweenImpressions`** ago (default **120 s**).  
- \(R\) = **random pass**: a single draw succeeds with probability **`sessionEligibilityProbability`** (default **0.04** = **4%**).

On each **Play feed rebuild** (ribbon list identity changes, or toggle turns on), an ad **slot** is considered **only if**:

\[
\text{show attempt} = A \land C \land R
\]

So **conditional on** the toggle being on and cooldown clear:

- **P(eligible this rebuild)** = **4%** per rebuild.  
- After an impression is recorded, **no new ad** is eligible until **120 seconds** pass (then the next rebuild can roll again).

**Rough expectations** (toggle on, user changes filters / sport often so rebuilds happen):

- If you get **10** independent rebuilds per session and cooldown is always satisfied: **expected** ad opportunities ≈ \(10 \times 0.04 = 0.4\) slots per session (many sessions show **zero** ads).  
- Cooldown **reduces** repeated impressions when the user stays on Play and scrolls without changing ribbons.

Constants live in code as `JuicdAdsDev.sessionEligibilityProbability` and `JuicdAdsDev.minSecondsBetweenImpressions` — tune there, then update this doc to match.

---

## Dev campaign list (fake data)

| id | Sponsor (fictional) | Theme |
|----|---------------------|--------|
| `voltade` | VoltaDe Sports Drink | Hydration |
| `gridiron_plus` | Gridiron+ | Streaming mock |
| `lineup_labs` | Lineup Labs | Odds comparison concept |
| `bench_warmer` | Bench Warmer Fantasy | Casual fantasy |
| `prime_time_audio` | Prime Time Audio | Podcast network mock |

---

## Replacing with real ads

See **[SETUP.md](SETUP.md)** §8 (Google Mobile Ads / consent / App Store). At a high level:

1. Add the **Google Mobile Ads SDK** (or another mediation stack) via SPM or CocoaPods.  
2. Use **test ad unit IDs** in Debug; never ship real units in source for public repos — use **Info.plist** / **xcconfig** (gitignored).  
3. For EEA/UK, integrate **UMP** (user consent) before loading personalized ads.  
4. Swap `JuicdNativeAdPlaceholder` for a **GADNativeAd** (or banner) view wrapper; keep **one slot** per feed and your own caps if you want parity with the dev math.  
5. App Store Connect: declare **Advertising** and, if applicable, **tracking**.

---

## Files touched

| File | Role |
|------|------|
| [`Services/JuicdAdsDev.swift`](Services/JuicdAdsDev.swift) | Policy + dev creatives |
| [`Views/JuicdNativeAdPlaceholder.swift`](Views/JuicdNativeAdPlaceholder.swift) | SwiftUI placeholder |
| [`Views/PlayView.swift`](Views/PlayView.swift) | Feed insertion + `.task` / toggle reaction |
| [`Views/ProfileView.swift`](Views/ProfileView.swift) | `@AppStorage` toggle |
