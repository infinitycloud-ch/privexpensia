#!/bin/bash

set -euo pipefail

SIMULATOR_NAME="${1:-iPhone 16 Pro Max}"
PROJECT_PATH="~/moulinsart/PrivExpensIA/PrivExpensIA.xcodeproj"
SCHEME="PrivExpensIA"
BUILD_DIR="/tmp/privexpensia_sim_build"

echo "🎯 Build forcé sur simulateur: $SIMULATOR_NAME"

# Résoudre UDID via simctl
SIMULATOR_UDID=$(xcrun simctl list devices | grep -F "$SIMULATOR_NAME" | grep -v unavailable | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)
if [ -z "$SIMULATOR_UDID" ]; then
  echo "❌ Simulateur '$SIMULATOR_NAME' introuvable."
  exit 1
fi

echo "🆔 UDID: $SIMULATOR_UDID"
echo "📱 Démarrage du simulateur..."
xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

echo "🔨 Build de l'app..."
xcodebuild -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "id=$SIMULATOR_UDID" \
  -derivedDataPath "$BUILD_DIR" \
  clean build | xcbeautify || true

APP_PATH=$(find "$BUILD_DIR/Build/Products" -type d -name "PrivExpensIA.app" | head -n1)
if [ -z "$APP_PATH" ]; then
  echo "❌ .app introuvable dans $BUILD_DIR"
  exit 1
fi

echo "📲 Installation sur le simulateur..."
xcrun simctl uninstall "$SIMULATOR_UDID" com.minhtam.ExpenseAI >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

echo "$SIMULATOR_UDID"
echo "✅ Build+Install terminé"


