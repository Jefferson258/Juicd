# App Store listing — Juicd (copy-paste ready)

**Do not submit until counsel signs off on contest/gambling posture.**  
Pair with [APP_PRIVACY_QUESTIONNAIRE.md](APP_PRIVACY_QUESTIONNAIRE.md) and [../SETUP.md](../SETUP.md).

---

## App name

Juicd

## Subtitle (≤30 characters)

Virtual sports picks & tourneys

## Promotional text (optional)

Free entertainment with virtual points only. Build picks, climb leaderboards, and compete with friends — no real-money wagering.

## Description

Juicd is a free sports entertainment app. Build virtual picks, track season progress, and compete on leaderboards — using points that have no cash value.

**Virtual points only**  
All balances, payouts, and prizes are virtual. Points cannot be withdrawn, redeemed, or converted to money, gift cards, or cryptocurrency. Juicd is not a sportsbook or real-money gambling app.

**Play**  
Browse a shared board, build singles and parlays, and submit slips using virtual stake.

**Tourney**  
Enter daily bracket-style rounds with virtual scoring.

**Dashboard**  
Track rank tiers, season progress, and past slates.

**Friends**  
Compare leaderboard position with people you follow.

**Ads-supported**  
Juicd is free and supported by advertising. No in-app purchases.

For entertainment purposes only. Must be 18+.

Official rules: https://juicd.app/contest-rules  
Privacy: https://juicd.app/privacy  
Terms: https://juicd.app/terms

## Keywords (tune for ASC length limit)

sports,entertainment,leaderboard,virtual,parlay,tournament,friends,picks,bracket

**Avoid:** “betting,” “wager,” “sportsbook,” “real money,” “cash out”

## Category suggestions

- **Primary:** Sports
- **Secondary:** Entertainment

## Age rating

Target **17+** or **18+** given sports-themed UX and ads. Gate sign-in accordingly.

## Copyright

© 2026 [Your LLC Legal Name], LLC

## Support URL

`https://juicd.app`

## Privacy Policy URL

`https://juicd.app/privacy`

---

## Screenshot plan (iPhone 6.7" + 6.5")

Use polished sample data — no “dev” or “prototype” labels.

| # | Screen | Caption |
|---|--------|---------|
| 1 | Play board | Build picks in seconds |
| 2 | Parlay builder | Mix picks your way |
| 3 | Tourney bracket | Compete in daily rounds |
| 4 | Dashboard | Track rank and momentum |
| 5 | Friends leaderboard | Climb with your crew |
| 6 | Profile + badges | See your progress |

---

## App Review notes (paste into “Notes for Review”)

```
IMPORTANT — NOT REAL-MONEY GAMBLING

Juicd is a free entertainment app. All points, balances, and prizes are VIRTUAL and have NO CASH VALUE. Users cannot deposit money, withdraw funds, or redeem points for anything of monetary value. There are no in-app purchases.

REVENUE: Advertising only (AdMob or similar when wired). No IAP.

BETA ODDS: Shared board odds use SIMULATED data by default (Supabase runtime config odds_mode=simulated). No live sportsbook integration in this build.

SIGN-IN: Sign in with Apple is available. A "Skip — local dev account" option exists for TestFlight; remove or hide before App Store if required.

TEST ACCOUNT (if needed):
- Use Sign in with Apple with reviewer Apple ID, OR
- Skip to local dev account (Player profile)

CONTEST RULES: https://juicd.app/contest-rules
PRIVACY: https://juicd.app/privacy
TERMS: https://juicd.app/terms

Apple is not a sponsor of any tournament or promotion in the app.

Counsel review pending for Texas entertainment positioning — submit only after legal sign-off.
```

---

## Encryption export

`ITSAppUsesNonExemptEncryption` = **NO** if the app only uses standard HTTPS/TLS.

---

## Pre-submission checklist

- [ ] Counsel approved Terms, Privacy, and Contest Rules
- [ ] In-app copy says “virtual points / no cash value” on pay-adjacent screens
- [ ] No IAP products configured in App Store Connect
- [ ] `odds_mode` = `simulated` in production Supabase
- [ ] App Privacy labels include ads (when AdMob ships) + Sign in with Apple
- [ ] Account deletion flow works if accounts are created
- [ ] Remove or gate “Skip — local dev account” for production if Apple objects
