-- STAGING ONLY — never apply to hwyxtklbffqwcbtuetit or another live project.
--
-- This review harness removes client write privileges from balance, slip,
-- tournament-entry, and aggregate-action tables. It intentionally does not
-- introduce settlement rules or change production migrations. Apply it only
-- to a disposable copy of the current schema, then exercise the negative
-- cases documented in VALIDATION.md.

begin;

revoke insert, update, delete on public.juicd_profiles from anon, authenticated;
revoke insert, update, delete on public.juicd_bet_slips from anon, authenticated;
revoke insert, update, delete on public.juicd_points_ledger from anon, authenticated;
revoke insert, update, delete on public.juicd_tournament_entries from anon, authenticated;
revoke execute on function public.juicd_record_prop_action(text, text, text, text, bigint)
  from public, anon, authenticated;

-- The future server-authoritative settlement path may grant these privileges
-- to a narrowly scoped RPC or service role after owner/counsel approval.
commit;
