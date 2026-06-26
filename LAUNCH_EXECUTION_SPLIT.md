# Launch Execution Split — Juicd (You vs Agent)

Who does what to get Juicd (app + website) launched. Generated from the planning canvas.

**Legend**

- **You** — identity / money / legal (Apple account, AdMob payouts, domains, LLC, final legal sign-off).
- **Agent** — repeatable technical work (builds, Supabase, edge functions, deploys, screenshots, metadata, TestFlight upload loop).
- **Shared** — I prepare it, you finish the identity-bound or judgment step.

> With full access, roughly **~80%** of Juicd's out-of-code launch is agent-led.

> ⚠️ **Highest legal priority.** Sports-pick UX draws App Review scrutiny. I can build, deploy, and prep everything, but the contest/gambling positioning and the Texas launch decision must be cleared by counsel before any public release.

---

## App (`LAUNCH_OUT_OF_CODE.md` + `SETUP.md` + `ADVERTISERS_SETUP.md`)

| Phase | Task | Owner | Notes |
|---|---|---|---|
| 0 | Accounts (Supabase, Odds API, AdMob, domain) | Shared | You own identity/payment; I drive setup once invited. |
| 1 | Run app locally (Skip = local dev account) | Agent | I build and run on simulator. |
| 2 | Register App ID + Sign in with Apple | You | Apple portal identity. |
| 3 | Xcode signing (bundle juicd.Juicd, team 8H2437SV33) | Shared | Team already baked in; you confirm device run. |
| 4 | Supabase migrations + edge fns (play-board, resolve-play-slip) | Agent | I run SQL + deploy functions. |
| 4 | Set edge secrets + flip odds_mode (simulated/live) | Agent | Keys stay server-side; I switch via SQL. |
| 5 | Apple auth provider (portal side) | You | Tied to your Apple account. |
| 6 | Deploy site + privacy/terms/contest pages | Agent | Counsel must clear gambling-adjacent copy first. |
| 7 | Create App Store Connect app | You | One-time. |
| 8 | Listing copy + screenshots + review notes (virtual points) | Agent | I prep the no-real-money review narrative. |
| 8 | App Privacy + age rating (18+) | Shared | I draft; you confirm. |
| 9 | AdMob account + payments/tax | You | Identity + payout verification. |
| 9 | AdMob SDK + UMP/ATT wiring | Shared | In-code work under your ad account. |
| 9 | Direct-sponsor data model (ad_campaigns, ad_creatives, ad_deliveries) | Agent | I build Supabase tables + get-play-sponsored-slot. |
| 10 | TestFlight archive + upload | Agent | Via TestFlight scripts + API key. |
| 11 | Submit for review | Shared | I prepare; you submit. |
| 12 | Replace App Store URL + refresh screenshots | Agent | I update juicd-website constants. |
| 13 | LLC + AdMob payouts under LLC | You | You + counsel. |

## Website (`juicd-website/LAUNCH_OUT_OF_CODE.md`)

| Phase | Task | Owner | Notes |
|---|---|---|---|
| 1-3 | Build, push to GitHub, deploy on Vercel | Agent | Needs gh token + Vercel access. |
| 4 | Buy domain (juicd.app) | You | Payment + registrar identity. |
| 4 | DNS records to Vercel | Shared | I set with registrar access; else you paste. |
| 6 | Privacy/Terms/Contest pages live | Agent | Publish only after counsel sign-off on positioning. |
| 7-8 | App Store link + screenshot assets | Agent | I map screenshots and update constants.ts. |

---

## Only you can do (one-time)

- Enroll / maintain Apple Developer Program and accept agreements.
- Generate an App Store Connect API key (.p8) with App Manager role.
- Create the App Store Connect app record.
- Register the App ID and enable Sign in with Apple in the portal.
- Buy the domain; complete AdMob payout identity + tax.
- Final legal sign-off (especially gambling-adjacent positioning) and any LLC formation with counsel.

## How much I can do, by access level

| If you grant | I can reach | What that unlocks |
|---|---|---|
| Repo only | ~35% | Drafts, copy, config prep, screenshot plans, review notes |
| + Mac / Xcode | ~50% | Local builds, UITest screenshots, signing config |
| + Supabase + Vercel/GitHub | ~70% | Backends live, sites deployed, legal URLs hosted |
| + ASC API key + app records | ~80% | TestFlight upload loop, repeatable build/deploy |
| + registrar / ad / portal logins | ~85-90% | Domains end-to-end; still not legal/entity finalization |

## Recommended kickoff (you spend ~30-60 min, then I run)

**You do once:** create the App Store Connect app record, generate one ASC API key (.p8), invite me to Supabase + Vercel + GitHub, buy the domain, and fill `TestFlight/config.sh`.

**I do after that:** run Supabase migrations + edge functions, deploy the website with legal URLs (after counsel sign-off), generate screenshots and metadata, run the TestFlight build/upload loop, and prep review submission for your final click.
