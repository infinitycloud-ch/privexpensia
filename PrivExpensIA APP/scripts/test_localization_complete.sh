#!/bin/bash

# Test de localisation complet - Toutes vues x Toutes langues
# Capture chaque vue (Home, Expenses, Scan, Stats, Settings) dans chaque langue

PROJECT_DIR="~/moulinsart/PrivExpensIA"
SCREENSHOTS_DIR="$PROJECT_DIR/validation/localization_complete"
REPORT_FILE="$PROJECT_DIR/validation/localization_complete_report.html"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Créer le dossier pour les screenshots
mkdir -p "$SCREENSHOTS_DIR"
rm -rf "$SCREENSHOTS_DIR"/*

# Langues à tester
LANGUAGES=("en" "fr" "de" "it" "es" "ja" "ko" "sk")
LANGUAGE_NAMES=("English" "Français" "Deutsch" "Italiano" "Español" "日本語" "한국어" "Slovenčina")

# Vues à tester (avec leurs identifiants)
VIEWS=("Home" "Expenses" "Scan" "Stats" "Settings")

# Fonction pour capturer un screenshot
capture_screenshot() {
    local lang=$1
    local view=$2
    local filename="$SCREENSHOTS_DIR/${lang}_${view}.png"

    echo "📸 Capturing $view in $lang..."

    # Simuler la navigation vers la vue
    xcrun simctl io booted screenshot "$filename"

    # Attendre un peu pour la transition
    sleep 1
}

# Fonction pour naviguer vers une vue spécifique
navigate_to_view() {
    local view=$1

    case $view in
        "Home")
            echo "🏠 Navigating to Home..."
            # Tap sur l'icône Home (en bas à gauche)
            xcrun simctl io booted tap 75 1350
            ;;
        "Expenses")
            echo "📋 Navigating to Expenses..."
            # Tap sur l'icône Expenses
            xcrun simctl io booted tap 225 1350
            ;;
        "Scan")
            echo "📷 Navigating to Scan..."
            # Tap sur l'icône Scan (centre)
            xcrun simctl io booted tap 375 1350
            ;;
        "Stats")
            echo "📊 Navigating to Stats..."
            # Tap sur l'icône Stats
            xcrun simctl io booted tap 525 1350
            ;;
        "Settings")
            echo "⚙️ Navigating to Settings..."
            # Tap sur l'icône Settings
            xcrun simctl io booted tap 675 1350
            ;;
    esac

    sleep 2  # Attendre que la vue se charge
}

# Fonction pour changer la langue dans l'app
change_language_in_app() {
    local lang_name=$1

    echo "🌐 Changing language to $lang_name..."

    # Aller dans Settings
    navigate_to_view "Settings"

    # Tap sur Language selector (approximativement au milieu)
    xcrun simctl io booted tap 375 280
    sleep 2

    # Sélectionner la langue selon sa position dans la liste
    case $lang_name in
        "English")     xcrun simctl io booted tap 375 250 ;;
        "Français")    xcrun simctl io booted tap 375 340 ;;
        "Deutsch")     xcrun simctl io booted tap 375 430 ;;
        "Italiano")    xcrun simctl io booted tap 375 520 ;;
        "Español")     xcrun simctl io booted tap 375 610 ;;
        "日本語")       xcrun simctl io booted tap 375 700 ;;
        "한국어")       xcrun simctl io booted tap 375 790 ;;
        "Slovenčina")  xcrun simctl io booted tap 375 880 ;;
    esac

    sleep 1

    # Tap Done
    xcrun simctl io booted tap 620 165
    sleep 2
}

echo "🚀 Starting complete localization test..."
echo "Testing ${#LANGUAGES[@]} languages x ${#VIEWS[@]} views = $((${#LANGUAGES[@]} * ${#VIEWS[@]})) screenshots"

# Compiler et lancer l'app
echo "🔨 Building and launching app..."
cd "$PROJECT_DIR"
xcodegen generate
xcodebuild -scheme PrivExpensIA -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -quiet &
BUILD_PID=$!

# Attendre que le build se termine
wait $BUILD_PID

# Lancer l'app
xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
xcrun simctl launch booted com.mtd.PrivExpensIA

sleep 5

# Capturer pour chaque langue
for i in "${!LANGUAGES[@]}"; do
    lang="${LANGUAGES[$i]}"
    lang_name="${LANGUAGE_NAMES[$i]}"

    echo ""
    echo "=================="
    echo "🌍 Testing $lang_name ($lang)"
    echo "=================="

    # Changer la langue dans l'app
    change_language_in_app "$lang_name"

    # Capturer chaque vue
    for view in "${VIEWS[@]}"; do
        navigate_to_view "$view"
        capture_screenshot "$lang" "$view"
    done
done

# Générer le rapport HTML
echo ""
echo "📝 Generating HTML report..."

cat > "$REPORT_FILE" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Complete Localization Test Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            color: white;
            margin-bottom: 10px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .timestamp {
            text-align: center;
            color: rgba(255,255,255,0.9);
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-bottom: 40px;
        }
        .stat {
            background: rgba(255,255,255,0.2);
            padding: 15px 30px;
            border-radius: 15px;
            color: white;
            text-align: center;
            backdrop-filter: blur(10px);
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
        }
        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
            margin-top: 5px;
        }
        .language-section {
            background: white;
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .language-header {
            display: flex;
            align-items: center;
            margin-bottom: 25px;
            padding-bottom: 15px;
            border-bottom: 3px solid #667eea;
        }
        .language-flag {
            font-size: 2em;
            margin-right: 15px;
        }
        .language-name {
            font-size: 1.8em;
            color: #333;
            font-weight: 600;
        }
        .language-code {
            font-size: 1em;
            color: #666;
            margin-left: 10px;
            font-weight: normal;
        }
        .views-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }
        .view-card {
            background: #f8f9fa;
            border-radius: 15px;
            overflow: hidden;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .view-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
        }
        .view-name {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 10px;
            text-align: center;
            font-weight: 600;
            font-size: 1.1em;
        }
        .screenshot {
            width: 100%;
            height: auto;
            display: block;
        }
        .issues {
            margin-top: 20px;
            padding: 15px;
            background: #fff3cd;
            border-radius: 10px;
            border-left: 4px solid #ffc107;
        }
        .issues-title {
            font-weight: bold;
            color: #856404;
            margin-bottom: 10px;
        }
        .issue-item {
            color: #856404;
            margin-left: 20px;
            margin-top: 5px;
        }
        .success-badge {
            background: #28a745;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-left: 15px;
        }
        .warning-badge {
            background: #ffc107;
            color: #856404;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-left: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌍 Complete Localization Test Report</h1>
        <div class="timestamp">Generated on: <span id="timestamp"></span></div>

        <div class="stats">
            <div class="stat">
                <div class="stat-value">8</div>
                <div class="stat-label">Languages</div>
            </div>
            <div class="stat">
                <div class="stat-value">5</div>
                <div class="stat-label">Views</div>
            </div>
            <div class="stat">
                <div class="stat-value">40</div>
                <div class="stat-label">Total Screenshots</div>
            </div>
        </div>
HTML

# Ajouter les sections pour chaque langue
for i in "${!LANGUAGES[@]}"; do
    lang="${LANGUAGES[$i]}"
    lang_name="${LANGUAGE_NAMES[$i]}"

    # Déterminer l'emoji du drapeau
    case $lang in
        "en") flag="🇬🇧" ;;
        "fr") flag="🇫🇷" ;;
        "de") flag="🇩🇪" ;;
        "it") flag="🇮🇹" ;;
        "es") flag="🇪🇸" ;;
        "ja") flag="🇯🇵" ;;
        "ko") flag="🇰🇷" ;;
        "sk") flag="🇸🇰" ;;
        *) flag="🌐" ;;
    esac

    cat >> "$REPORT_FILE" << HTML
        <div class="language-section">
            <div class="language-header">
                <span class="language-flag">$flag</span>
                <span class="language-name">$lang_name</span>
                <span class="language-code">($lang)</span>
            </div>

            <div class="views-grid">
HTML

    # Ajouter chaque vue
    for view in "${VIEWS[@]}"; do
        screenshot_file="${lang}_${view}.png"
        cat >> "$REPORT_FILE" << HTML
                <div class="view-card">
                    <div class="view-name">$view</div>
                    <img src="$screenshot_file" alt="$lang_name - $view" class="screenshot">
                </div>
HTML
    done

    cat >> "$REPORT_FILE" << HTML
            </div>
        </div>
HTML
done

# Fermer le HTML
cat >> "$REPORT_FILE" << 'HTML'
    </div>

    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();

        // Analyser les images pour détecter les problèmes
        window.addEventListener('load', function() {
            const images = document.querySelectorAll('.screenshot');
            images.forEach(img => {
                img.addEventListener('error', function() {
                    this.alt = '❌ Screenshot missing';
                    this.style.padding = '40px';
                    this.style.textAlign = 'center';
                    this.style.background = '#f8d7da';
                    this.style.color = '#721c24';
                });
            });
        });
    </script>
</body>
</html>
HTML

echo ""
echo "✅ Test complete!"
echo "📊 Generated $((${#LANGUAGES[@]} * ${#VIEWS[@]})) screenshots"
echo "📁 Screenshots saved in: $SCREENSHOTS_DIR"
echo "📄 Report available at: $REPORT_FILE"
echo ""
echo "Opening report..."
open "$REPORT_FILE"