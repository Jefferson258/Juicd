#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

function_file="supabase/functions/delete-account/index.ts"
[[ -f "$function_file" ]] || { echo "Missing $function_file" >&2; exit 1; }

if rg -n "SUPABASE_SERVICE_ROLE_KEY" . --glob '*.swift' >/dev/null; then
  echo "Service-role key referenced by the iOS target" >&2
  exit 1
fi

rg -n 'auth\.getUser\(token\)' "$function_file" >/dev/null
rg -n 'auth\.admin\.deleteUser\(authData\.user\.id\)' "$function_file" >/dev/null
rg -n 'delete-account' Services/SupabaseAuthService.swift >/dev/null
rg -n 'supabase functions deploy delete-account$' supabase/README.md >/dev/null

echo "Account-deletion static checks passed."
