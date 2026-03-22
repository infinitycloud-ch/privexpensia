#!/bin/bash

# TEST DIRECT DU MOTEUR QWEN
# Opération Test du Chronomètre - Vérification
# ================================================

echo "🚀 TEST DIRECT MOTEUR QWEN - VÉRIFICATION ORACLE"
echo "================================================"
echo ""

# 1. BUILD L'APPLICATION
echo "🔨 PHASE 1: Build de l'application..."
cd ~/moulinsart/PrivExpensIA

xcodebuild clean build \
    -project PrivExpensIA.xcodeproj \
    -scheme PrivExpensIA \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    2>&1 | grep -E "(BUILD|SUCCEEDED|FAILED|error:|warning:)" | tail -20

if [ $? -eq 0 ]; then
    echo "✅ Build réussi!"
else
    echo "❌ Build échoué! Vérifiez les erreurs ci-dessus."
    exit 1
fi

echo ""
echo "📱 PHASE 2: Lancement de l'app dans le simulateur..."

# Ouvrir le simulateur
open -a Simulator
sleep 3

# Installer et lancer l'app
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install "iPhone 16" ~/Library/Developer/Xcode/DerivedData/PrivExpensIA-*/Build/Products/Debug-iphonesimulator/PrivExpensIA.app
xcrun simctl launch "iPhone 16" com.minhtam.ExpenseAI

echo ""
echo "🧪 PHASE 3: Instructions pour tester Qwen:"
echo "============================================"
echo ""
echo "1️⃣ Dans l'app, allez dans l'onglet SETTINGS (icône engrenage)"
echo ""
echo "2️⃣ Scrollez jusqu'à la section 'Developer Tools'"
echo ""
echo "3️⃣ Cliquez sur 'Test Moteur Qwen' (icône éclair)"
echo ""
echo "4️⃣ Observez dans la console Xcode:"
echo "   - Temps de chargement initial (2.34s attendu)"
echo "   - Temps d'inférence (222ms attendu)"
echo "   - Utilisation mémoire (128.6MB attendu)"
echo ""
echo "5️⃣ Le test affiche:"
echo "   - Extraction du marchand: CARREFOUR MARKET"
echo "   - Total: 25.04€"
echo "   - TVA: 1.31€"
echo "   - 5 articles détectés"
echo ""
echo "📊 MÉTRIQUES ATTENDUES:"
echo "========================"
echo "• Chargement modèle: ~2.34 secondes"
echo "• Inférence moyenne: ~222 millisecondes"
echo "• Mémoire: ~128.6 MB"
echo "• Cache: < 10ms sur 2ème appel"
echo ""
echo "✅ Si ces valeurs correspondent = QWEN VALIDÉ!"
echo "❌ Si échec ou crash = Problème à investiguer"
echo ""
echo "Appuyez sur Enter après avoir testé..."
read

echo ""
echo "📝 GÉNÉRATION DU RAPPORT..."
date > /tmp/qwen_test_report.txt
echo "TEST MOTEUR QWEN - RAPPORT" >> /tmp/qwen_test_report.txt
echo "===========================" >> /tmp/qwen_test_report.txt
echo "" >> /tmp/qwen_test_report.txt
echo "Notez vos observations:" >> /tmp/qwen_test_report.txt
echo "- Temps chargement: _____ secondes" >> /tmp/qwen_test_report.txt
echo "- Temps inférence: _____ ms" >> /tmp/qwen_test_report.txt
echo "- Mémoire: _____ MB" >> /tmp/qwen_test_report.txt
echo "- Crash: OUI / NON" >> /tmp/qwen_test_report.txt
echo "- Extraction correcte: OUI / NON" >> /tmp/qwen_test_report.txt
echo "" >> /tmp/qwen_test_report.txt

open /tmp/qwen_test_report.txt

echo ""
echo "🎯 TEST TERMINÉ!"
echo "Le rapport est ouvert dans votre éditeur."
echo "Complétez-le avec vos observations."