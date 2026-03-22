#!/bin/bash

# TEST SUR IPHONE PHYSIQUE - GUIDE ORACLE
# =========================================

echo "📱 DÉPLOIEMENT SUR IPHONE PHYSIQUE"
echo "===================================="
echo ""
echo "🔧 PRÉREQUIS:"
echo "-------------"
echo "1. iPhone connecté par câble USB"
echo "2. iPhone déverrouillé et 'Faire confiance' accepté"
echo "3. Mode développeur activé sur l'iPhone"
echo "   (Réglages → Confidentialité → Mode développeur)"
echo ""
echo "Appuyez sur Enter quand prêt..."
read

echo ""
echo "📋 ÉTAPE 1: Vérification de la connexion"
echo "-----------------------------------------"
xcrun devicectl list devices | grep -i iphone || xcrun simctl list devices | grep -i phone

echo ""
echo "🔨 ÉTAPE 2: Build pour appareil physique"
echo "-----------------------------------------"
cd ~/moulinsart/PrivExpensIA

echo "Building for iOS Device..."
xcodebuild clean build \
    -project PrivExpensIA.xcodeproj \
    -scheme PrivExpensIA \
    -configuration Debug \
    -sdk iphoneos \
    -allowProvisioningUpdates \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
    2>&1 | grep -E "(BUILD|SUCCEEDED|FAILED|error:)" | tail -20

echo ""
echo "📲 ÉTAPE 3: Installation via Xcode (RECOMMANDÉ)"
echo "------------------------------------------------"
echo ""
echo "MÉTHODE XCODE (Plus simple):"
echo "1. Ouvrez Xcode"
echo "2. Ouvrez le projet: open PrivExpensIA.xcodeproj"
echo "3. Sélectionnez votre iPhone dans la barre d'outils"
echo "4. Cliquez sur ▶️ (Run)"
echo "5. L'app s'installe et se lance automatiquement"
echo ""
echo "OU"
echo ""
echo "MÉTHODE LIGNE DE COMMANDE:"
echo "xcrun devicectl device install app --device [DEVICE_ID] ~/Library/Developer/Xcode/DerivedData/PrivExpensIA-*/Build/Products/Debug-iphoneos/PrivExpensIA.app"
echo ""
echo "================================================"
echo ""
echo "📱 TEST DU MOTEUR QWEN SUR IPHONE:"
echo "===================================="
echo ""
echo "1️⃣ Lancez l'app PrivExpensIA sur votre iPhone"
echo ""
echo "2️⃣ Allez dans l'onglet Settings (engrenage)"
echo ""
echo "3️⃣ Scrollez jusqu'à 'Developer Tools'"
echo ""
echo "4️⃣ Tapez sur 'Test Moteur Qwen' ⚡"
echo ""
echo "5️⃣ OBSERVEZ:"
echo "   • Un spinner pendant le chargement (~2.3s)"
echo "   • Un message de succès avec les résultats"
echo "   • Les données extraites du reçu test"
echo ""
echo "📊 MÉTRIQUES À VÉRIFIER:"
echo "========================"
echo "• Temps de chargement: ~2.34 secondes ✅"
echo "• Temps d'inférence: ~222 ms ✅"
echo "• Pas de crash ✅"
echo "• Extraction correcte (CARREFOUR, 25.04€) ✅"
echo ""
echo "🔍 POUR VOIR LES LOGS DÉTAILLÉS:"
echo "================================="
echo "1. Connectez votre iPhone à Xcode"
echo "2. Window → Devices and Simulators"
echo "3. Sélectionnez votre iPhone"
echo "4. Cliquez sur 'Open Console'"
echo "5. Filtrez par 'PrivExpensIA' ou 'Qwen'"
echo ""
echo "💡 ASTUCE RAPIDE:"
echo "================="
echo "Si vous avez déjà Xcode ouvert:"
echo "1. Cmd+Shift+2 (Devices)"
echo "2. Sélectionnez votre iPhone"
echo "3. Cliquez Run ▶️"
echo ""
echo "C'est la méthode la plus simple!"
echo ""