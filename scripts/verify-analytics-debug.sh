#!/bin/bash
# Proves Juicd's analytics debug sink writes events with no network access.
# Installs the already-built Debug-iphonesimulator app, launches it with the
# same dev-skip launch args used by JuicdUITests, waits for app_open, then
# prints Documents/analytics-debug-events.jsonl from the sim's app container.
#
# Usage: scripts/verify-analytics-debug.sh [device-udid-or-name]
# (defaults to the currently booted simulator)
#
# Build the app first if you haven't:
#   xcodebuild build -project Juicd.xcodeproj -scheme Juicd \
#     -destination 'platform=iOS Simulator,name=<some booted device>'

set -euo pipefail

BUNDLE_ID="com.jefferson258.juicd"
DEVICE="${1:-booted}"

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 6 -type d \
  -path "*Juicd-*/Build/Products/Debug-iphonesimulator/Juicd.app" 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "FAIL: couldn't find a built Juicd.app under DerivedData. Build it first:" >&2
  echo "  xcodebuild build -project Juicd.xcodeproj -scheme Juicd -destination 'platform=iOS Simulator,name=iPhone 17'" >&2
  exit 1
fi

echo "==> Installing $APP_PATH on device '$DEVICE'"
xcrun simctl install "$DEVICE" "$APP_PATH"

echo "==> Launching $BUNDLE_ID"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -skipTutorial -acceptLegalTerms -seedDemoData

echo "==> Waiting for app_open to be written..."
sleep 4

CONTAINER=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)
JSONL="$CONTAINER/Documents/analytics-debug-events.jsonl"

if [[ ! -f "$JSONL" ]]; then
  echo "FAIL: no debug JSONL file found at $JSONL" >&2
  exit 1
fi

echo "==> Events recorded so far (all launches, oldest first):"
cat "$JSONL"

if ! grep -q '"name":"app_open"' "$JSONL"; then
  echo "FAIL: no app_open event found in $JSONL" >&2
  exit 1
fi

echo
echo "PASS: AnalyticsService debug sink wrote events to $JSONL with no network access."
