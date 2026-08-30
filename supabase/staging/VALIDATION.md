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

The current `resolve-play-slip` function still produces deterministic
virtual-point outcomes and does not atomically settle balances, slips, and the
ledger. Do not describe it as authoritative settlement or flip
`outcome_mode` to live. Designing and shipping that path remains an
owner/counsel product and integrity decision.
