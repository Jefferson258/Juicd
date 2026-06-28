# App Privacy questionnaire — Juicd (App Store Connect)

**Draft answers.** Update when AdMob and full Supabase auth ship.  
Privacy Policy URL: `https://juicd.app/privacy`

---

## Data collection summary (target production)

| Data type | Collected? | Linked? | Tracking? | Purpose |
|-----------|------------|---------|----------|---------|
| Contact info (email via Apple) | Yes | Yes | No | App functionality |
| User ID | Yes | Yes | No | App functionality |
| User content (display name, picks) | Yes | Yes | No | App functionality |
| Gameplay content (slips, leaderboard) | Yes | Yes | No | App functionality |
| Device ID / advertising ID | If ads | Varies | **Maybe** | Advertising |
| Crash / diagnostics | If SDK added | Often no | No | Analytics |

---

## Sign in with Apple

- **Email / name:** As provided by Apple — linked — App functionality
- **User ID:** Supabase + Apple subject — linked — App functionality

---

## Virtual gameplay data

- Pick history, virtual balance, rank, badges — **linked** — App functionality
- **Not** financial data — virtual points have no cash value (state in privacy policy)

---

## Advertising (when AdMob ships)

| Type | Typical answer |
|------|----------------|
| Device ID | Collected by ad SDK |
| Linked to user | Often **Yes** for personalized ads |
| Used for tracking | **Yes** if personalized ads + ATT |
| Purpose | Third-party advertising |

**Required when ads go live:**
- [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) prompt
- Google UMP for consent (EEA)
- Privacy policy section on ad partners

**Beta without real ads:** Answer questionnaire for **current** build. Dev placeholders only → may answer **No** for advertising until production ad SDK ships — but **update before** enabling real ad units.

---

## Data NOT collected (confirm)

- Payment info (no IAP)
- Precise location (unless added)
- Health data
- Real-money gambling / wallet data

---

## Practices

| Question | Beta (no ads) | Production (ads) |
|----------|---------------|------------------|
| Data used to track you | No | Likely **Yes** if personalized ads |
| Data linked to you | Yes (account) | Yes |
| Third-party advertising | No | **Yes** |

---

## Account deletion

Required if accounts exist. Document path in review notes and implement Supabase user deletion.

---

## Before submit

1. Counsel-approved privacy policy live at juicd.app/privacy
2. Questionnaire matches **actual** SDKs in the submitted binary
3. If ads: ATT + UMP tested on device
