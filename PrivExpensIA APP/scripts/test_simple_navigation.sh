#!/bin/bash

echo "🎬 TEST SIMPLE NAVIGATION"
echo "========================"

# Lancer l'app
echo "📱 Lancement de l'app..."
xcrun simctl terminate booted com.mtd.PrivExpensIA 2>/dev/null || true
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

# 1. Home tab (déjà affiché)
echo "   1. Home tab (déjà visible)"
sleep 2

# 2. Aller aux Settings
echo "   2. → Tap Settings tab"
xcrun simctl io booted tap 675 1350  # Settings tab (iPhone 16)
sleep 3

# 3. Scroll down dans Settings
echo "   3. → Scroll down dans Settings"
xcrun simctl io booted swipe 400 800 400 300  # Scroll down
sleep 2

# 4. Scroll down encore
echo "   4. → Scroll down encore"
xcrun simctl io booted swipe 400 700 400 200  # Scroll down plus
sleep 2

# 5. Retour Home
echo "   5. → Retour Home tab"
xcrun simctl io booted tap 75 1350   # Home tab
sleep 2

echo "📹 Arrêt de l'enregistrement..."
kill $RECORD_PID
wait $RECORD_PID 2>/dev/null

# Attendre que le fichier soit écrit
sleep 3

echo "✅ Vidéo générée: $VIDEO_FILE"
ls -la "$VIDEO_FILE"

echo ""
echo "🎬 TEST TERMINÉ"
echo "Pour voir la vidéo: open $VIDEO_FILE"