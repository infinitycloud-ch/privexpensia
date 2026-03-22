#!/bin/bash

echo "🎬 TEST SIMPLE SETTINGS"
echo "======================="

# Build l'app
echo "🔨 Build de l'application..."
cd ~/moulinsart/PrivExpensIA
xcodegen generate
xcodebuild -project PrivExpensIA.xcodeproj -scheme PrivExpensIA -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' build

if [ $? -ne 0 ]; then
    echo "❌ Échec du build"
    exit 1
fi

echo "✅ Build réussi"

# Lancer l'app
echo "📱 Lancement de l'app..."
xcrun simctl terminate booted com.mtd.PrivExpensIA 2>/dev/null
xcrun simctl launch booted com.mtd.PrivExpensIA

# Attendre que l'app se lance
sleep 3

# Nom du fichier vidéo
VIDEO_FILE="validation/videos/test_simple_$(date +%Y%m%d_%H%M%S).mp4"
mkdir -p validation/videos

echo "📹 Démarrage enregistrement vidéo..."
echo "    Fichier: $VIDEO_FILE"

# Démarrer l'enregistrement
xcrun simctl io booted recordVideo "$VIDEO_FILE" &
RECORD_PID=$!

# Attendre que l'enregistrement démarre
sleep 2

echo "🎯 Navigation test:"
echo "   1. Aller aux Settings (tab 5)"
echo "   2. Scroll down"
echo "   3. Attendre 3 secondes"

# Navigation simple
echo "   → Tap Settings tab"
xcrun simctl io booted tap 675 1350  # Settings tab (iPhone 16)
sleep 2

echo "   → Scroll down"
xcrun simctl io booted swipe 400 800 400 300  # Scroll down
sleep 1

echo "   → Scroll down encore"
xcrun simctl io booted swipe 400 700 400 200  # Scroll down plus
sleep 2

echo "📹 Arrêt de l'enregistrement..."
kill $RECORD_PID
wait $RECORD_PID 2>/dev/null

# Attendre que le fichier soit écrit
sleep 3

echo "✅ Vidéo générée: $VIDEO_FILE"
ls -la "$VIDEO_FILE"

echo "🎬 TEST TERMINÉ"
echo "Pour voir la vidéo: open $VIDEO_FILE"