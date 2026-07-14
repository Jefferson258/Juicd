#!/usr/bin/env bash
# Capture visual-QA screenshots for Juicd via UITests → qa-screenshots/
# Invoked by: ./bin/pilot qa juicd-app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/qa-screenshots"
PROJECT="$ROOT/Juicd.xcodeproj"
SCHEME="Juicd"
TEST="JuicdUITests/JuicdUITests/testVisualQAScreenshots"
DERIVED="${JUICD_DERIVED_DATA:-/tmp/JuicdQADerivedData}"

# Prefer a recent iPhone sim
SIM_NAME="${JUICD_SIM_NAME:-}"
if [[ -z "$SIM_NAME" ]]; then
  for candidate in "iPhone 17 Pro" "iPhone 17" "iPhone 16e" "iPhone 16 Pro"; do
    if xcrun simctl list devices available | grep -q "$candidate"; then
      SIM_NAME="$candidate"
      break
    fi
  done
fi
if [[ -z "$SIM_NAME" ]]; then
  echo "No suitable iPhone simulator found" >&2
  exit 1
fi

UDID="$(xcrun simctl list devices available | grep "$SIM_NAME" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')"
echo "==> Juicd visual QA on $SIM_NAME ($UDID)"
mkdir -p "$OUT" "$DERIVED"
xcrun simctl boot "$UDID" 2>/dev/null || true

export QA_SCREENSHOT_DIR="$OUT"
rm -f "$OUT"/01-play.png "$OUT"/03-tourney.png "$OUT"/04-dashboard.png \
  "$OUT"/05-friends.png "$OUT"/06-profile.png 2>/dev/null || true

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -only-testing:"$TEST" \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1

count="$(find "$OUT" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
echo "Done. $count PNG(s) in $OUT"
test "$count" -gt 0
