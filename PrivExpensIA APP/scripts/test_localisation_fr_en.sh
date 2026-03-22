#!/bin/bash

# Test de localisation simplifié - Français vs Anglais seulement
# Pour identifier rapidement tous les problèmes de traduction

PROJECT_DIR="~/moulinsart/PrivExpensIA"
SCREENSHOTS_DIR="$PROJECT_DIR/validation/localization_fr_en"
REPORT_FILE="$PROJECT_DIR/validation/localization_fr_en_report.html"

# Créer le dossier
mkdir -p "$SCREENSHOTS_DIR"
rm -rf "$SCREENSHOTS_DIR"/*

echo "🌍 Test de Localisation FR vs EN"
echo "================================"
echo ""
echo "📱 INSTRUCTIONS MANUELLES:"
echo ""
echo "Ce script va vous guider pour capturer les screenshots."
echo "Assurez-vous que l'app PrivExpensIA est lancée dans le simulateur."
echo ""

# Fonction pour capturer avec guidage
capture_view() {
    local lang=$1
    local view=$2
    local lang_name=$3

    echo ""
    echo "📸 Capture: $lang_name - $view"
    echo "   Appuyez sur ENTRÉE quand vous êtes prêt..."
    read -r

    xcrun simctl io booted screenshot "$SCREENSHOTS_DIR/${lang}_${view}.png"
    echo "   ✅ Capturé: ${lang}_${view}.png"
}

# FRANÇAIS
echo "========================================="
echo "🇫🇷 PARTIE 1: FRANÇAIS"
echo "========================================="
echo ""
echo "1. Allez dans Settings"
echo "2. Changez la langue vers 'Français'"
echo "3. Appuyez sur ENTRÉE quand c'est fait..."
read -r

echo ""
echo "Maintenant, naviguez vers chaque vue et appuyez sur ENTRÉE:"

capture_view "fr" "Home" "Français"
capture_view "fr" "Expenses" "Français"
capture_view "fr" "Scan" "Français"
capture_view "fr" "Stats" "Français"
capture_view "fr" "Settings" "Français"

# ANGLAIS
echo ""
echo "========================================="
echo "🇬🇧 PARTIE 2: ENGLISH"
echo "========================================="
echo ""
echo "1. Allez dans Settings"
echo "2. Changez la langue vers 'English'"
echo "3. Appuyez sur ENTRÉE quand c'est fait..."
read -r

echo ""
echo "Maintenant, naviguez vers chaque vue et appuyez sur ENTRÉE:"

capture_view "en" "Home" "English"
capture_view "en" "Expenses" "English"
capture_view "en" "Scan" "English"
capture_view "en" "Stats" "English"
capture_view "en" "Settings" "English"

# Générer le rapport HTML comparatif
echo ""
echo "📝 Génération du rapport comparatif..."

cat > "$REPORT_FILE" << 'HTML'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Localisation FR vs EN - PrivExpensIA</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            color: white;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .view-section {
            background: white;
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .view-title {
            font-size: 1.8em;
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        .comparison {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
        }
        .lang-column {
            text-align: center;
        }
        .lang-header {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin-bottom: 15px;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .flag {
            font-size: 1.5em;
        }
        .lang-name {
            font-size: 1.2em;
            font-weight: 600;
            color: #333;
        }
        .screenshot {
            width: 100%;
            max-width: 400px;
            height: auto;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            border: 2px solid #e0e0e0;
        }
        .issues-box {
            margin-top: 20px;
            padding: 20px;
            background: #fff3cd;
            border-radius: 10px;
            border-left: 4px solid #ffc107;
        }
        .issues-title {
            font-weight: bold;
            color: #856404;
            margin-bottom: 10px;
            font-size: 1.1em;
        }
        .issue-item {
            color: #856404;
            margin: 8px 0;
            padding-left: 20px;
            position: relative;
        }
        .issue-item:before {
            content: "⚠️";
            position: absolute;
            left: 0;
        }
        .success-box {
            margin-top: 20px;
            padding: 20px;
            background: #d4edda;
            border-radius: 10px;
            border-left: 4px solid #28a745;
        }
        .success-title {
            font-weight: bold;
            color: #155724;
            margin-bottom: 10px;
            font-size: 1.1em;
        }
        .timestamp {
            text-align: center;
            color: rgba(255,255,255,0.9);
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .summary {
            background: white;
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .summary-title {
            font-size: 1.5em;
            color: #333;
            margin-bottom: 20px;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌍 Test de Localisation FR vs EN</h1>
        <div class="timestamp">Généré le: <span id="timestamp"></span></div>

        <div class="summary">
            <h2 class="summary-title">📊 Résumé</h2>
            <div class="summary-grid">
                <div class="stat-card">
                    <div class="stat-value">2</div>
                    <div class="stat-label">Langues testées</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">5</div>
                    <div class="stat-label">Vues testées</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">10</div>
                    <div class="stat-label">Screenshots</div>
                </div>
            </div>
        </div>
HTML

# Ajouter les sections pour chaque vue
VIEWS=("Home" "Expenses" "Scan" "Stats" "Settings")

for view in "${VIEWS[@]}"; do
    cat >> "$REPORT_FILE" << HTML
        <div class="view-section">
            <h2 class="view-title">📱 $view</h2>
            <div class="comparison">
                <div class="lang-column">
                    <div class="lang-header">
                        <span class="flag">🇫🇷</span>
                        <span class="lang-name">Français</span>
                    </div>
                    <img src="localization_fr_en/fr_${view}.png" alt="FR - $view" class="screenshot">
                </div>
                <div class="lang-column">
                    <div class="lang-header">
                        <span class="flag">🇬🇧</span>
                        <span class="lang-name">English</span>
                    </div>
                    <img src="localization_fr_en/en_${view}.png" alt="EN - $view" class="screenshot">
                </div>
            </div>

            <div class="issues-box">
                <div class="issues-title">Problèmes identifiés:</div>
                <div class="issue-item">À analyser après capture des screenshots</div>
            </div>
        </div>
HTML
done

# Fermer le HTML
cat >> "$REPORT_FILE" << 'HTML'
    </div>

    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString('fr-FR');

        // Auto-analyse des images
        window.addEventListener('load', function() {
            const images = document.querySelectorAll('.screenshot');
            images.forEach(img => {
                img.addEventListener('error', function() {
                    this.style.background = '#f8d7da';
                    this.style.padding = '40px';
                    this.style.border = '2px dashed #721c24';
                    this.alt = '❌ ' + this.alt + ' - Image manquante';
                });
            });
        });
    </script>
</body>
</html>
HTML

echo "✅ Test terminé!"
echo ""
echo "📊 Résultats:"
echo "  - 10 screenshots capturés (2 langues × 5 vues)"
echo "  - Rapport disponible: $REPORT_FILE"
echo ""
echo "📂 Ouverture du rapport..."
open "$REPORT_FILE"