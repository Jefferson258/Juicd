#!/usr/bin/env bash
# Juicd visual QA — thin wrapper around LaunchPilot kits/qa/ios-uitest-capture.sh
# Invoked by: ./bin/pilot qa juicd-app
#
# QA_DEPTH=deep (default): seeded tab tour + anonymous cloud friend-code capture
# QA_DEPTH=smoke: tab tour only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LP_QA="${PILOT_QA_KIT:-$ROOT/../LaunchPilot/kits/qa}"
HELPER="$LP_QA/ios-uitest-capture.sh"
if [[ ! -f "$HELPER" ]]; then
  echo "Missing shared QA helper: $HELPER (set PILOT_QA_KIT)" >&2
  exit 1
fi

DEPTH="${QA_DEPTH:-deep}"
TESTS=(
  --test "JuicdUITests/JuicdUITests/testVisualQAScreenshots"
)
if [[ "$DEPTH" == "deep" ]]; then
  TESTS+=(
    --test "JuicdUITests/JuicdUITests/testAnonymousCloudFriendCodeScreenshot"
  )
fi

bash "$HELPER" \
  --project "$ROOT/Juicd.xcodeproj" \
  --scheme Juicd \
  --out "$ROOT/qa-screenshots" \
  --derived "${JUICD_DERIVED_DATA:-/tmp/JuicdQADerivedData}" \
  --sim-prefer "iPhone 17 Pro,iPhone 17,iPhone 16e,iPhone 16 Pro" \
  --clean-glob "01-play.png" \
  --clean-glob "03-tourney.png" \
  --clean-glob "04-dashboard.png" \
  --clean-glob "05-friends.png" \
  --clean-glob "05-friends-cloud.png" \
  --clean-glob "06-profile.png" \
  "${TESTS[@]}"
