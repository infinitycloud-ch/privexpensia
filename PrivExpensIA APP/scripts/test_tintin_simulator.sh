#!/bin/bash

# UUID du simulateur Tintin spécifique
TINTIN_UUID="9D1B772E-7D9B-4934-A7F4-D2829CEB0065"

echo "🎬 TEST AVEC SIMULATEUR TINTIN SPÉCIFIQUE"
echo "========================================="
echo "📱 Simulateur: tintin (iPhone 16 Pro Max)"
echo "🆔 UUID: $TINTIN_UUID"

# S'assurer que le bon simulateur est démarré
echo "📱 Démarrage du simulateur Tintin..."
xcrun simctl boot $TINTIN_UUID 2>/dev/null || echo "  (déjà démarré)"

# Attendre le démarrage
sleep 3

# Installer l'app sur ce simulateur spécifique
echo "📦 Installation de l'app sur Tintin..."
xcrun simctl install $TINTIN_UUID ~/Library/Developer/Xcode/DerivedData/PrivExpensIA-gyardwqilzcihxbytsrowpxzhbdf/Build/Products/Debug-iphonesimulator/PrivExpensIA.app

# Lancer l'app
echo "🚀 Lancement de PrivExpensIA..."
xcrun simctl terminate $TINTIN_UUID com.mtd.PrivExpensIA 2>/dev/null || true
xcrun simctl launch $TINTIN_UUID com.mtd.PrivExpensIA

# Attendre que l'app se lance
sleep 3

# Nom du fichier vidéo
VIDEO_FILE="validation/videos/test_tintin_$(date +%Y%m%d_%H%M%S).mp4"
mkdir -p validation/videos

echo "📹 Démarrage enregistrement vidéo..."
echo "    Fichier: $VIDEO_FILE"

# Démarrer l'enregistrement sur le simulateur spécifique
xcrun simctl io $TINTIN_UUID recordVideo "$VIDEO_FILE" &
RECORD_PID=$!

# Attendre que l'enregistrement démarre
sleep 2

echo "🎯 Navigation test sur Tintin:"

# 1. Home tab (déjà affiché)
echo "   1. Home tab (déjà visible)"
sleep 2

# 2. Aller aux Settings
echo "   2. → Tap Settings tab"
xcrun simctl io $TINTIN_UUID tap 675 1350  # Settings tab (iPhone 16)
sleep 3

# 3. Scroll down dans Settings
echo "   3. → Scroll down dans Settings"
xcrun simctl io $TINTIN_UUID swipe 400 800 400 300  # Scroll down
sleep 2

# 4. Scroll down encore
echo "   4. → Scroll down encore"
xcrun simctl io $TINTIN_UUID swipe 400 700 400 200  # Scroll down plus
sleep 2

# 5. Retour Home
echo "   5. → Retour Home tab"
xcrun simctl io $TINTIN_UUID tap 75 1350   # Home tab
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