# Max-Access Setup Split — Juicd

Assumption: you give the agent as much control as reasonably possible while keeping identity, money, and legal decisions with you.

The agent can use the power for good: automate setup, keep secrets out of git, document every live change, and treat Juicd's sports/contest risk as a hard launch gate.

## Short answer on The Odds API

Juicd does **not** need The Odds API key for a simulated beta. The app can run local-first and the Supabase `play-board` flow can stay in `simulated` mode.

Juicd **does** need an Odds API key if you want live sports odds. In production, that key should be set only as a Supabase Edge Function secret, never in the iOS app.

Recommended launch sequence:

1. Start beta in `simulated` mode.
2. Verify Supabase shared board + deterministic slip outcomes.
3. Add `ODDS_API_KEY` as an Edge Function secret.
4. Flip `juicd_runtime_config.odds_mode` from `simulated` to `live`.
5. Monitor Supabase logs and Odds API quota.

## What you still have to do

These steps are tied to your identity, payment methods, or legal responsibility:

1. Maintain Apple Developer Program enrollment and accept all Apple agreements.
2. Register the Juicd App ID in Apple Developer and enable Sign in with Apple.
3. Create the Juicd App Store Connect app record for bundle `juicd.Juicd`.
4. Generate an App Store Connect API key with App Manager access and store the `.p8` locally.
5. Create / own the Supabase account or invite the agent to the project.
6. Create / own The Odds API account if live odds are used.
7. Create / own AdMob account if ads are used.
8. Complete Google payments profile, tax forms, and payout verification.
9. Buy or approve `juicd.app` and any DNS/account ownership changes.
10. Get counsel sign-off on Juicd's contest/gambling-adjacent model before public launch.
11. Handle LLC formation, D-U-N-S, Apple Organization migration, and tax/accounting decisions with counsel/CPA.

## Access / credentials to give the agent

Do not paste secrets into normal chat if avoidable. Prefer dashboard invites, local config files, or secret stores.

1. GitHub access to `Juicd` / `juicd` and `Juicd-website`.
2. Vercel access for the Juicd website.
3. Domain registrar access, or permission for the agent to tell you exact DNS records to paste.
4. Supabase project access with permission to:
   - run SQL migrations
   - deploy Edge Functions
   - set Edge Function secrets
   - edit runtime config rows
   - view logs
5. App Store Connect API key values in `TestFlight/config.sh`:
   - `TEAM_ID`
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_PATH`
6. Supabase app config values:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
7. Supabase Edge Function secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `ODDS_API_KEY` (only for live mode)
8. Optional AdMob values:
   - app ID
   - ad unit IDs
   - test device IDs
   - consent/UMP configuration details

## What the agent can do after access is granted

### Supabase

1. Create or verify the Supabase project.
2. Run migrations:
   - `supabase/migrations/20260322120000_juicd_friends.sql`
   - `supabase/migrations/20260424113000_juicd_odds_runtime.sql`
3. Deploy Edge Functions:
   - `play-board`
   - `resolve-play-slip`
4. Set Edge Function secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - optional `ODDS_API_KEY`
5. Keep `odds_mode='simulated'` for beta unless you explicitly approve live mode.
6. Flip `odds_mode='live'` only after the Odds API key is set and logs are clean.
7. Verify two devices/simulators show the same board.
8. Monitor function logs, response times, and quota usage.

### Xcode / TestFlight

1. Run local builds using the dev account path.
2. Configure Supabase URL and anon key through the approved config pattern.
3. Confirm Sign in with Apple after you create the Apple-side App ID.
4. Capture QA screenshots.
5. Draft App Store copy, App Review notes, and App Privacy answers.
6. Archive and upload builds through the TestFlight automation kit after you create the App Store Connect app record and API key.

### Website

1. Build and QA `juicd-website`.
2. Deploy on Vercel.
3. Configure canonical, Open Graph, and Twitter URLs.
4. Publish Privacy Policy, Terms, and Contest Rules only after you approve/counsel clears the language.
5. Add App Store URL after the app record/build is live.
6. Refresh screenshots and OG assets.

### Ads

1. Keep dev placeholders until AdMob is approved and legal/privacy language is final.
2. Add AdMob IDs to a non-committed config path.
3. Prep UMP/ATT implementation plan.
4. Draft App Privacy answers for ads/tracking.
5. Build direct sponsor tables and delivery function if you choose direct sponsors:
   - `ad_campaigns`
   - `ad_creatives`
   - `ad_deliveries`
   - `get-play-sponsored-slot`

## Launch guardrails

1. Juicd must be described as free sports entertainment, not betting.
2. Virtual points, tiers, badges, and ranks must have no cash value.
3. No cash-out, redemption, gift cards, crypto, merchandise, or paid entry unless counsel redoes the legal analysis.
4. Avoid sportsbook language in App Store metadata.
5. Sponsored content must be clearly labeled.
6. App Review notes should explicitly state:
   - no real-money wagering
   - no paid entry
   - no cash value
   - no redemption
   - Apple is not a contest sponsor
7. Counsel should clear Texas contest/gambling risk before public launch.

## Practical handoff order

1. You create Apple App ID + App Store Connect app record.
2. You generate ASC API key and fill `TestFlight/config.sh`.
3. You create or invite the agent to Supabase.
4. You decide whether beta starts with simulated odds (recommended).
5. The agent runs migrations, deploys functions, configures `simulated` mode, deploys the website, captures screenshots, and uploads TestFlight.
6. You get counsel sign-off on Juicd legal language.
7. The agent prepares final review package.
8. You click submit.
