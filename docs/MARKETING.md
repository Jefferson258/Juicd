# Marketing playbook — Juicd

How we market Juicd: App Store (ASO), website, and social. Pair with
[APP_STORE_LISTING.md](APP_STORE_LISTING.md), [APP_PRIVACY_QUESTIONNAIRE.md](APP_PRIVACY_QUESTIONNAIRE.md),
and the website `LAUNCH_OUT_OF_CODE.md`.

Counsel approved **entertainment / virtual-points** positioning (Jul 2026) —
keep every channel aligned. Orchestration design:
MarketingPilot (`~/Desktop/MarketingPilot`) (README + PIPELINE).

---

## Current marketing surfaces

| Surface | Status | Notes |
|---------|--------|-------|
| App Store listing copy | Counsel-aligned draft | Also `kits/appstore/products/juicd/metadata.md` |
| Screenshots | QA + ASC framed | Confirm parlay shot exists before final ASC push |
| Marketing site | Builds; hero + legal note in first viewport | Contest rules page required |
| App Store URL in site | **Placeholder** `idXXXXXXXXX` | Update `juicd-website/src/constants.ts` when live |
| Instagram / TikTok / X | **Not created** | Owner — see Social |
| In-app ads | Dev placeholders only | Not brand social |
| Paid acquisition | Not started | Owner only |

---

## Positioning (keep consistent everywhere)

- **Subtitle:** Virtual sports picks & tourneys / tours (≤30 chars)  
- **Promise:** Pick your spots. Climb the ladder.  
- **Audience:** Sports fans who want rivalry without real-money risk  
- **Monetization:** Free + advertising · **no IAP** · no cash prizes  

### Claim rules

**Do say:** entertainment only; virtual points; no cash value; not a sportsbook; 18+.  
**Do not say:** betting, wager, sportsbook, real money, cash out, "get paid."  
**Odds:** runtime is **simulated** until intentionally flipped — do not claim live
sportsbook odds in ads or social.

---

## Social media (owner creates accounts)

Suggested handles:

| Channel | Handle target | Why |
|---------|---------------|-----|
| Instagram | `@juicd` / `@juicdapp` | Slip builds + tourney energy |
| TikTok | same | Fast "build a parlay" screen recordings |
| X | same | Sports-day chatter + launch |

### Bio template

```
Daily picks. Ranked rivalries. Tournament nights.
Entertainment only — virtual points, no cash value. 18+
🔗 [juicd.app or current Vercel URL]
```

Pin or highlight: **Contest rules** + Privacy.

### Week-0 content

1. UI posts: Play board, slip, tourney, dashboard, friends.  
2. One explainer Reel: "Virtual points only — here's what that means."  
3. One gameplay Reel: build → submit → leaderboard (no cash language).  
4. Soft CTA: TestFlight / App Store. No ads until you decide.

### Content pillars

1. Play board  
2. Tourney nights  
3. Leaderboard / tiers  
4. Friends rivalries  
5. Rules clarity (trust + App Review)

---

## Process (who does what)

| Step | You | Agent |
|------|-----|-------|
| Create social accounts + bios | ✓ | — |
| Draft captions with claim-check | — | ✓ |
| ASO / site copy PRs | — | ✓ |
| Publish contest/legal pages | approve / counsel | draft only |
| Post / schedule social | ✓ | draft only |
| Paid ads / boosts | ✓ | never |
| Flip odds to live (product) | ✓ | only after key + your OK |

---

## Automation (with LaunchPilot)

Draft → claim-check against forbidden words → PR / `jobs/…/marketing/` folder.
**Never auto-post.** Never buy ads. See MarketingPilot `docs/PIPELINE.md`.

After handles exist, send `@` names so the agent can update brand docs and
optional site links.
