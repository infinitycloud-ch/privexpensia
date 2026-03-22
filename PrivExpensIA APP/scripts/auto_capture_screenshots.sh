#!/bin/bash

# Script automatisé pour capturer tous les screenshots

SCREENSHOTS_DIR="~/moulinsart/PrivExpensIA/validation/localization_complete"
DEVICE="iPhone 16"

echo "🚀 Capture automatique des screenshots..."

# S'assurer que le dossier existe
mkdir -p "$SCREENSHOTS_DIR"

# Langues à tester
LANGUAGES=("en" "fr" "de" "it" "es" "ja" "ko" "sk")
VIEWS=("Home" "Expenses" "Scan" "Stats" "Settings")

# Positions approximatives des boutons de la tab bar (pour iPhone 16)
TAB_POSITIONS=(
    "75 1350"    # Home
    "225 1350"   # Expenses
    "375 1350"   # Scan
    "525 1350"   # Stats
    "675 1350"   # Settings
)

echo "📱 Capture en cours sur: $DEVICE"

# Pour chaque langue
for lang in "${LANGUAGES[@]}"; do
    echo ""
    echo "🌍 Langue: $lang"

    # Pour chaque vue
    for i in "${!VIEWS[@]}"; do
        view="${VIEWS[$i]}"
        position="${TAB_POSITIONS[$i]}"

        # Naviguer vers la vue
        echo "  📍 Navigation vers $view..."
        xcrun simctl io "$DEVICE" tap $position
        sleep 2  # Attendre que la vue se charge

        # Capturer le screenshot
        xcrun simctl io "$DEVICE" screenshot "$SCREENSHOTS_DIR/${lang}_${view}.png"
        echo "  ✅ Capturé: ${lang}_${view}.png"
    done
done

echo ""
echo "✅ Capture terminée!"
echo "📊 Total screenshots générés:"
ls "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l