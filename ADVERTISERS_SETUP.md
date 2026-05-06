# Juicd - Advertiser Setup Playbook

This is a practical step-by-step for moving Juicd from placeholder ads to real advertiser demand.

---

## 1) Pick a monetization path

Choose one path first:

1. **Ad network first** (fastest): AdMob / mediation for immediate fill.
2. **Direct sponsor sales first** (higher control): fixed campaigns sold directly.
3. **Hybrid** (recommended): direct deals for premium slots + network fallback for fill.

---

## 2) Define inventory and policy

Before talking to advertisers:

1. Define placements:
   - Play feed sponsored card
   - Optional secondary placements (non-intrusive)
2. Define frequency caps:
   - max ads per session
   - max ads above fold
3. Define disclosure:
   - clear "Sponsored" label
4. Define prohibited categories:
   - illegal gambling claims
   - misleading financial claims
   - restricted verticals based on App Store policy

---

## 3) Data model and delivery contract (server-side)

Implement in Supabase:

1. `ad_campaigns`
   - advertiser name
   - start/end dates
   - status
   - targeting fields
2. `ad_creatives`
   - headline/body/cta/icon/image
   - destination URL
   - compliance status
3. `ad_deliveries`
   - impression and click events for reporting/billing

Serve ads from Edge Function:

- `get-play-sponsored-slot` returns one eligible creative.

---

## 4) Measurement and billing basics

Track:

1. Impression timestamp + placement.
2. Click timestamp + destination.
3. Device/session dedupe key.

Billing options:

1. CPM (per 1,000 impressions)
2. CPC (per click)
3. Flat weekly sponsorship

Start with flat weekly + impression reporting for simplicity.

---

## 5) Legal and compliance checklist

1. Update Privacy Policy to mention ad measurement.
2. If required in region, implement consent flow before personalized ads.
3. Add advertiser terms:
   - acceptable content
   - delivery guarantees and make-goods
   - payment terms
4. Keep audit history of approved creatives.

---

## 6) Operational rollout plan

Phase 1 (beta):

1. Keep current placeholder format.
2. Serve direct mock creatives from Supabase.
3. Validate impression/click logging.

Phase 2 (pilot advertisers):

1. Onboard 2-5 sponsors.
2. Run fixed date campaigns.
3. Weekly reporting email.

Phase 3 (scale):

1. Add mediation fallback for unsold inventory.
2. Add targeting and pacing controls.
3. Add automated campaign dashboard.

---

## 7) Sales motion (practical)

1. Build one-page media kit:
   - audience
   - placements
   - rates
   - sample creative specs
2. Outreach:
   - sports podcasts, betting tools, apparel, local bars, fantasy communities
3. Offer pilot package:
   - 2-week fixed fee with post-campaign report
4. Use insertion order template and invoice process.

---

## 8) Creative spec template for advertisers

Provide this exact spec:

1. Sponsor name (max 32 chars)
2. Headline (max 42 chars)
3. Body (max 90 chars)
4. CTA (max 18 chars)
5. Icon (1:1 PNG)
6. Optional hero image (1200x628)
7. Landing URL with UTM tags

Review SLA:

- 2 business days for creative approval

---

## 9) App Store-safe ad UX rules

1. Never fake system alerts.
2. Never obstruct core gameplay.
3. Keep dismissibility where required.
4. Keep sponsored labeling visible at all times.

---

## 10) Minimum implementation milestone

You are "ready for paid advertisers" when all are true:

1. Campaigns editable in Supabase.
2. Delivery endpoint serves active campaigns only.
3. Impression/click logs exportable by date range.
4. Billing report reproducible from logs.
5. Privacy disclosures updated.

