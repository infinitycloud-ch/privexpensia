#!/bin/bash

# Test automatique de localisation avec changement de langue programmatique

PROJECT_DIR="~/moulinsart/PrivExpensIA"
SCREENSHOTS_DIR="$PROJECT_DIR/validation/localization_auto"
REPORT_FILE="$PROJECT_DIR/validation/localization_auto_report.html"
DEVICE="iPhone 16"

# Créer le dossier
mkdir -p "$SCREENSHOTS_DIR"
rm -rf "$SCREENSHOTS_DIR"/*

echo "🚀 Test Automatique de Localisation FR vs EN"
echo "============================================="
echo ""

# Fonction pour capturer une vue
capture_view() {
    local lang=$1
    local view=$2
    local x=$3
    local y=$4

    echo "  📍 Capturing $view..."
    xcrun simctl io "$DEVICE" tap $x $y 2>/dev/null
    sleep 2
    xcrun simctl io "$DEVICE" screenshot "$SCREENSHOTS_DIR/${lang}_${view}.png" 2>/dev/null
}

# Fonction pour changer la langue via l'interface
change_language_ui() {
    local target_lang=$1

    echo "🔄 Changing language to $target_lang..."

    # Aller dans Settings
    xcrun simctl io "$DEVICE" tap 675 1350 2>/dev/null
    sleep 2

    # Ouvrir le sélecteur de langue (position approximative)
    xcrun simctl io "$DEVICE" tap 375 280 2>/dev/null
    sleep 2

    # Sélectionner la langue
    case $target_lang in
        "en")
            xcrun simctl io "$DEVICE" tap 375 250 2>/dev/null  # English
            ;;
        "fr")
            xcrun simctl io "$DEVICE" tap 375 340 2>/dev/null  # Français
            ;;
    esac
    sleep 1

    # Fermer le sélecteur (Done button)
    xcrun simctl io "$DEVICE" tap 620 165 2>/dev/null
    sleep 2
}

# Fonction pour relancer l'app avec une langue spécifique
launch_app_with_language() {
    local lang=$1

    echo "🔄 Relaunching app with language: $lang..."

    # Terminer l'app
    xcrun simctl terminate "$DEVICE" com.mtd.PrivExpensIA 2>/dev/null
    sleep 1

    # Relancer avec la langue spécifiée
    xcrun simctl launch "$DEVICE" com.mtd.PrivExpensIA --args -AppleLanguages "($lang)" 2>/dev/null
    sleep 3
}

# TEST 1: FRANÇAIS
echo "🇫🇷 TEST FRANÇAIS"
echo "=================="
launch_app_with_language "fr"

# Capturer toutes les vues
capture_view "fr" "Home" 75 1350
capture_view "fr" "Expenses" 225 1350
capture_view "fr" "Scan" 375 1350
capture_view "fr" "Stats" 525 1350
capture_view "fr" "Settings" 675 1350

echo ""

# TEST 2: ENGLISH
echo "🇬🇧 TEST ENGLISH"
echo "=================="
launch_app_with_language "en"

# Capturer toutes les vues
capture_view "en" "Home" 75 1350
capture_view "en" "Expenses" 225 1350
capture_view "en" "Scan" 375 1350
capture_view "en" "Stats" 525 1350
capture_view "en" "Settings" 675 1350

# Générer le rapport HTML
echo ""
echo "📝 Generating comparison report..."

cat > "$REPORT_FILE" << 'HTML'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Automatique Localisation FR vs EN</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 20px;
            text-align: center;
            margin-bottom: 30px;
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .view-comparison {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .view-title {
            font-size: 1.8em;
            color: #333;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .screenshots-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 20px;
        }
        .screenshot-box {
            text-align: center;
        }
        .lang-label {
            background: #f0f0f0;
            padding: 10px;
            border-radius: 10px 10px 0 0;
            font-weight: 600;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
        }
        .screenshot {
            width: 100%;
            max-width: 400px;
            border: 2px solid #e0e0e0;
            border-radius: 0 0 10px 10px;
        }
        .issues {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 5px;
            margin-top: 20px;
        }
        .issue-title {
            font-weight: bold;
            color: #856404;
            margin-bottom: 10px;
        }
        .differences {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-top: 10px;
        }
        .diff-item {
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
            font-family: monospace;
            font-size: 0.9em;
        }
        .diff-fr { border-left: 3px solid #007bff; }
        .diff-en { border-left: 3px solid #28a745; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌍 Test Automatique de Localisation</h1>
        <p>Comparaison Français vs English - PrivExpensIA</p>
        <p style="margin-top: 10px; opacity: 0.9;">Généré le: <span id="timestamp"></span></p>
    </div>
HTML

# Ajouter les comparaisons pour chaque vue
for view in "Home" "Expenses" "Scan" "Stats" "Settings"; do
    cat >> "$REPORT_FILE" << HTML
    <div class="view-comparison">
        <h2 class="view-title">
            <span>📱</span>
            <span>$view</span>
        </h2>
        <div class="screenshots-grid">
            <div class="screenshot-box">
                <div class="lang-label">
                    <span>🇫🇷</span>
                    <span>Français</span>
                </div>
                <img src="localization_auto/fr_${view}.png" alt="FR - $view" class="screenshot">
            </div>
            <div class="screenshot-box">
                <div class="lang-label">
                    <span>🇬🇧</span>
                    <span>English</span>
                </div>
                <img src="localization_auto/en_${view}.png" alt="EN - $view" class="screenshot">
            </div>
        </div>
        <div class="issues">
            <div class="issue-title">⚠️ Points à vérifier:</div>
            <div class="differences">
                <div class="diff-item diff-fr">
                    <strong>FR:</strong> À analyser
                </div>
                <div class="diff-item diff-en">
                    <strong>EN:</strong> À analyser
                </div>
            </div>
        </div>
    </div>
HTML
done

# Fermer le HTML
cat >> "$REPORT_FILE" << 'HTML'
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString('fr-FR');
    </script>
</body>
</html>
HTML

echo ""
echo "✅ Test completed!"
echo "📊 10 screenshots captured"
echo "📄 Report: $REPORT_FILE"
echo ""
echo "Opening report..."
open "$REPORT_FILE"