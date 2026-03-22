#!/bin/bash

set -euo pipefail

# Usage: 03_run_settings_scroll_video.sh --udid <UDID>

UDID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) UDID="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$UDID" ]]; then
  echo "❌ Fournir --udid" >&2
  exit 1
fi

PROJECT_DIR="~/moulinsart/PrivExpensIA"
VIDEO_DIR="$PROJECT_DIR/validation/videos"
mkdir -p "$VIDEO_DIR"
OUT="$VIDEO_DIR/settings_scroll_$(date +%Y%m%d_%H%M%S).mp4"

echo "📹 Enregistrement: $OUT"
xcrun simctl io "$UDID" recordVideo "$OUT" &
PID=$!

echo "🧪 Test UITest Settings+Scroll"
xcodebuild -project "$PROJECT_DIR/PrivExpensIA.xcodeproj" -scheme PrivExpensIA -destination "id=$UDID" -only-testing:PrivExpensIAUITests/LocalizationScreenshotTests/testOpenSettingsAndScrollToBottom -derivedDataPath "$PROJECT_DIR/build" test >/dev/null || true

kill -INT $PID
wait $PID 2>/dev/null || true

echo "✅ Vidéo: $OUT"
open "$OUT"


