#!/bin/bash

set -euo pipefail

# Usage: 02_build_install.sh --udid <UDID>

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
APP_PATH=""

echo "🔨 Build de l'application..."
cd "$PROJECT_DIR"
xcodebuild -project PrivExpensIA.xcodeproj -scheme PrivExpensIA -configuration Debug -destination "id=$UDID" -sdk iphonesimulator -derivedDataPath build clean build >/dev/null

APP_PATH=$(find "$PROJECT_DIR/build/Build/Products/Debug-iphonesimulator" -type d -name "PrivExpensIA.app" | head -n1)
if [[ -z "$APP_PATH" ]]; then
  echo "❌ .app introuvable dans $PROJECT_DIR/build/Build/Products/Debug-iphonesimulator" >&2
  echo "   Astuce: ouvre Xcode et fais Product > Clean Build Folder, puis relance." >&2
  exit 1
fi

echo "📲 Installation sur $UDID..."
xcrun simctl uninstall "$UDID" com.minhtam.ExpenseAI >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP_PATH"
echo "✅ Install OK"


