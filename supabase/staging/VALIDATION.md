# Juicd staging integrity validation

`INTEGRITY_HARDENING.sql` is a review harness, not a migration. Apply it only
to a disposable Supabase project containing the current Juicd schema. It
removes authenticated client write privileges from balances, slips, ledger
entries, tournament entries, and prop-action recording without choosing the
eventual settlement model.

## Safe setup

1. Create two ordinary staging users and keep their access tokens local.
2. Confirm the staging URL does **not** contain
   `hwyxtklbffqwcbtuetit.supabase.co`.
3. Apply the SQL harness in the staging SQL editor or with `psql`.
4. Run the Deno validation tests:

   ```bash
   deno test supabase/functions/resolve-play-slip/validation_test.ts
   ```

5. Verify the `play-board?force=1` request is rejected without the internal
   service-role bearer token. Never put that token in an app, test file, or
   shell history.

## Expected negative cases

- An authenticated client cannot insert or update a `juicd_profiles` balance.
- An authenticated client cannot insert, update, or delete a bet slip.
- An authenticated client cannot write the points ledger or tournament entry
  directly.
- An authenticated client cannot call `juicd_record_prop_action` directly.
- `resolve-play-slip` rejects a missing token, a mismatched `userId`, malformed
  legs, duplicate leg IDs, non-finite odds, and odds outside `(1, 1000]`.
- A valid settlement response must cover every submitted leg exactly once;
  incomplete or unknown-leg responses are refused by the iOS client.

Production `resolve-play-slip` still returns deterministic virtual-point
outcomes only. Atomic wallet/ledger writes exist as a **staging-gated** RPC
and stay off unless the disposable-project flag and env var below are set.
Do not flip `outcome_mode` to live without owner + counsel sign-off.

## Staging-only authoritative settlement

`AUTHORITATIVE_SETTLEMENT.sql` adds `juicd_staging_settle_slip`. Apply it only
on a disposable project after `INTEGRITY_HARDENING.sql`.

1. Confirm the project ref is **not** `hwyxtklbffqwcbtuetit`.
2. Set `juicd_runtime_config.staging_authoritative_settlement` to `on`.
3. Set Edge secret/env `JUICD_AUTHORITATIVE_SETTLEMENT=1` on that project only.
4. `resolve-play-slip` then requires `slipId` and calls the RPC (service role).
5. Without the env var, production behavior is unchanged: outcomes only.

Do not deploy this env var or SQL to production. Live-event (`outcome_mode`)
settlement still needs owner + counsel sign-off.

```bash
deno test supabase/functions/resolve-play-slip/validation_test.ts
deno test supabase/functions/resolve-play-slip/settlement_test.ts
```
