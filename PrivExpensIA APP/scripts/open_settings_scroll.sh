#!/bin/bash

set -euo pipefail

# Usage:
# ./open_settings_scroll.sh [--udid <UDID> | --simulator-name "iPhone 16 Pro Max"]

UDID=""
SIM_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid)
      UDID="$2"; shift 2;;
    --simulator-name)
      SIM_NAME="$2"; shift 2;;
    *)
      shift;;
  esac
done

PROJECT_DIR="~/moulinsart/PrivExpensIA"
XCODEPROJ="$PROJECT_DIR/PrivExpensIA.xcodeproj"
SCHEME="PrivExpensIA"

resolve_udid() {
  local chosen=""
  if [[ -n "$UDID" ]]; then
    chosen="$UDID"
  elif [[ -n "$SIM_NAME" ]]; then
    chosen=$("$PROJECT_DIR/scripts/simulator_utils.py" --ensure --name "$SIM_NAME" || true)
  else
    # Prendre le premier simulateur iOS Booted
    chosen=$("$PROJECT_DIR/scripts/simulator_utils.py" --list-booted | python3 -c 'import sys,json;d=json.loads(sys.stdin.read());print(d[0]["udid"] if d else "")')
  fi
  if [[ -z "$chosen" ]]; then
    echo "❌ Aucun simulateur booté détecté et aucun UDID/nom fourni" >&2
    exit 1
  fi
  echo "$chosen"
}

DEVICE_UDID=$(resolve_udid)
echo "🎯 Cible: $DEVICE_UDID"

# S'assurer qu'il est booté et prêt
xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b

echo "🧪 Lancement du test UI: Settings + scroll"
xcodebuild -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_UDID" \
  -only-testing:PrivExpensIAUITests/LocalizationScreenshotTests/testOpenSettingsAndScrollToBottom \
  -derivedDataPath "$PROJECT_DIR/build" test | xcbeautify | sed -e 's/\x1b\[[0-9;]*m//g'

echo "✅ Test exécuté sur $DEVICE_UDID"


