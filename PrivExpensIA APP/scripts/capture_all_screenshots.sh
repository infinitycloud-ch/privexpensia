#!/bin/bash

# Script pour capturer manuellement tous les screenshots pour chaque langue et vue

SCREENSHOTS_DIR="~/moulinsart/PrivExpensIA/validation/localization_complete"
SIMULATOR="iPhone 16"

# Langues et leurs codes
LANGUAGES=("en" "fr" "de" "it" "es" "ja" "ko" "sk")
LANGUAGE_NAMES=("English" "Français" "Deutsch" "Italiano" "Español" "日本語" "한국어" "Slovenčina")

echo "📸 Capture manuelle des screenshots pour rapport de localisation"
echo "IMPORTANT: Assurez-vous que l'app est lancée dans le simulateur iPhone 16"
echo ""

# Pour chaque langue
for i in "${!LANGUAGES[@]}"; do
    lang="${LANGUAGES[$i]}"
    lang_name="${LANGUAGE_NAMES[$i]}"

    echo "===================="
    echo "🌍 Langue: $lang_name ($lang)"
    echo "===================="
    echo ""
    echo "👉 INSTRUCTIONS:"
    echo "1. Allez dans Settings"
    echo "2. Changez la langue vers '$lang_name'"
    echo "3. Naviguez vers chaque vue et appuyez sur Entrée après chaque capture"
    echo ""

    # Pour chaque vue
    for view in "Home" "Expenses" "Scan" "Stats" "Settings"; do
        echo "📱 Naviguez vers: $view"
        echo "   Appuyez sur Entrée quand vous êtes prêt..."
        read -r

        # Capturer le screenshot
        xcrun simctl io "$SIMULATOR" screenshot "$SCREENSHOTS_DIR/${lang}_${view}.png"
        echo "✅ Capturé: ${lang}_${view}.png"
    done

    echo ""
done

echo "✅ Capture terminée!"
echo "📊 40 screenshots capturés dans: $SCREENSHOTS_DIR"

# Vérifier que tous les fichiers sont là
echo ""
echo "Vérification des fichiers:"
ls -la "$SCREENSHOTS_DIR"/*.png | wc -l
echo "fichiers PNG trouvés"