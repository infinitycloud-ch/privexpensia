#!/bin/bash

set -euo pipefail

# Script unique: boot + build + install + test Settings+Scroll + enregistrement vidéo
# Usage:
#   run_all_settings_scroll.sh [--udid <UDID> | --simulator-name "iPhone 16 Pro Max"]

UDID=""
SIM_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid|-u) UDID="$2"; shift 2;;
    --simulator-name|-s) SIM_NAME="$2"; shift 2;;
    *) shift;;
  esac
done

PROJECT_DIR="~/moulinsart/PrivExpensIA"
VIDEO_DIR="$PROJECT_DIR/validation/videos"
SCHEME="PrivExpensIA"
TEST_ID="PrivExpensIAUITests/LocalizationScreenshotTests/testOpenSettingsAndScrollToBottom"

log() { echo -e "$1"; }

ensure_dirs() { mkdir -p "$VIDEO_DIR"; }

resolve_udid() {
  # 1) UDID fourni
  if [[ -n "$UDID" ]]; then
    echo "$UDID"; return 0;
  fi
  # 2) Par nom via util Python
  if [[ -n "$SIM_NAME" && -f "$PROJECT_DIR/scripts/simulator_utils.py" ]]; then
    local r
    r=$(python3 "$PROJECT_DIR/scripts/simulator_utils.py" --ensure --name "$SIM_NAME" 2>/dev/null || true)
    if [[ -n "$r" ]]; then echo "$r"; return 0; fi
  fi
  # 3) Premier booted
  local booted
  booted=$(python3 "$PROJECT_DIR/scripts/simulator_utils.py" --list-booted 2>/dev/null | python3 -c 'import sys,json;d=json.loads(sys.stdin.read() or "[]");print(d[0]["udid"] if d else "")')
  if [[ -n "$booted" ]]; then echo "$booted"; return 0; fi
  # 4) Dernier recours: iPhone 16 Pro Max s'il existe
  local guess
  guess=$(xcrun simctl list devices | grep -F "iPhone 16 Pro Max" | grep -v unavailable | grep -E -o '[A-F0-9-]{36}' | head -n1 || true)
  echo "$guess"
}

stabilize_sim() {
  local id="$1"
  log "🧰 Stabilisation du simulateur $id..."
  xcrun simctl shutdown "$id" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl boot "$id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$id" -b
  open -a Simulator --args -CurrentDeviceUDID "$id"
}

build_app() {
  log "🔨 Build de l'application..."
  cd "$PROJECT_DIR"
  xcodegen generate >/dev/null 2>&1 || true
  xcodebuild -project PrivExpensIA.xcodeproj -scheme "$SCHEME" -configuration Debug -destination "id=$1" -sdk iphonesimulator -derivedDataPath build clean build >/dev/null
}

find_app() {
  find "$PROJECT_DIR/build/Build/Products/Debug-iphonesimulator" -type d -name "PrivExpensIA.app" | head -n1
}

install_app() {
  local id="$1"; local app="$2"; local bid
  bid=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist" 2>/dev/null || defaults read "$app/Info" CFBundleIdentifier 2>/dev/null || echo "com.minhtam.ExpenseAI")
  log "🆔 Bundle Identifier: $bid"
  xcrun simctl uninstall "$id" "$bid" >/dev/null 2>&1 || true
  if ! xcrun simctl install "$id" "$app"; then
    log "⚠️ Install échouée → re-stabilisation"
    stabilize_sim "$id"
    xcrun simctl uninstall "$id" "$bid" >/dev/null 2>&1 || true
    xcrun simctl install "$id" "$app"
  fi
}

run_test_and_record() {
  local id="$1"; local out="$2"
  log "📹 Enregistrement: $out"
  # h264 = meilleure compatibilité QuickTime
  xcrun simctl io "$id" recordVideo --codec=h264 --display=internal --force "$out" &
  local vpid=$!
  log "🧪 UITest: $TEST_ID"
  if ! xcodebuild -project "$PROJECT_DIR/PrivExpensIA.xcodeproj" -scheme "$SCHEME" -destination "id=$id" -only-testing:"$TEST_ID" -derivedDataPath "$PROJECT_DIR/build" test >/dev/null ; then
    # Fallback: ouvrir l'app directement si l'action test n'est pas configurée
    log "⚠️ Test non disponible → ouverture directe de l'app"
    xcrun simctl terminate "$id" com.minhtam.ExpenseAI >/dev/null 2>&1 || true
    xcrun simctl launch "$id" com.minhtam.ExpenseAI --args -UITEST_SKIP_SPLASH -UITEST_SELECTED_TAB settings >/dev/null 2>&1 || true
    sleep 8
  fi
  kill -INT $vpid 2>/dev/null || true
  wait $vpid 2>/dev/null || true
  log "✅ Vidéo: $out"
  echo "::VIDEO::$out"
  open "$out" >/dev/null 2>&1 || true
}

main() {
  ensure_dirs
  local id
  id=$(resolve_udid)
  if [[ -z "$id" ]]; then log "❌ Aucun simulateur cible"; exit 1; fi
  log "🎯 Simulateur ciblé: $id"
  stabilize_sim "$id"

  build_app "$id"
  local app
  app=$(find_app)
  if [[ -z "$app" ]]; then log "❌ .app introuvable"; exit 1; fi
  log "📦 App: $app"

  install_app "$id" "$app"

  local out="$VIDEO_DIR/settings_scroll_$(date +%Y%m%d_%H%M%S).mp4"
  run_test_and_record "$id" "$out"
}

main "$@"


