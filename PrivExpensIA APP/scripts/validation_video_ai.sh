#!/bin/bash

# Validation Vidéo avec Analyse AI
# Génère une vidéo de validation et prépare pour analyse LLM

PROJECT_DIR="~/moulinsart/PrivExpensIA"
VIDEO_DIR="$PROJECT_DIR/validation/videos"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUNDLE_ID="${BUNDLE_ID:-}"
CONFIGURATION="${CONFIGURATION:-Debug}"

# Parsing simple des arguments (ex: --udid <UDID>, --scenario settings_scroll)
REQUESTED_UDID=""
REQUESTED_SIM_NAME=""
SCENARIO="${SCENARIO:-localization}"
while [ $# -gt 0 ]; do
    case "$1" in
        --udid|-u)
            REQUESTED_UDID="$2"; shift 2;;
        --scenario|-s)
            SCENARIO="$2"; shift 2;;
        --simulator-name)
            REQUESTED_SIM_NAME="$2"; shift 2;;
        *)
            shift;;
    esac
done

# Variables d'environnement possibles (fallback)
if [ -z "$REQUESTED_UDID" ]; then
    REQUESTED_UDID="${TARGET_UDID:-${SIM_UDID:-}}"
fi

# Créer les dossiers nécessaires
mkdir -p "$VIDEO_DIR"

echo "🎬 VALIDATION VIDÉO AVEC AI"
echo "=========================="
echo ""

# Sélection automatique d'un simulateur iOS et ouverture dédiée
select_target_simulator() {
    local preferred_device="iPhone 16 Pro Max"
    local udid

    # Si un nom de simulateur est fourni, tenter de le résoudre en UDID via python util
    if [ -z "$REQUESTED_UDID" ] && [ -n "$REQUESTED_SIM_NAME" ]; then
        local py_util="$PROJECT_DIR/scripts/simulator_utils.py"
        if [ -f "$py_util" ]; then
            udid=$(python3 "$py_util" --ensure --name "$REQUESTED_SIM_NAME" 2>/dev/null || true)
        fi
    fi

    # Si un UDID explicite est demandé, l'utiliser s'il est disponible
    if [ -n "$REQUESTED_UDID" ]; then
        if xcrun simctl list devices available | grep -q "$REQUESTED_UDID"; then
            udid="$REQUESTED_UDID"
            echo "🔒 UDID demandé détecté: $udid"
        else
            echo "⚠️ UDID demandé introuvable parmi les simulateurs. Fallback automatique."
        fi
    fi

    # Sinon, cherche d'abord l'iPhone 16 Pro Max disponible
    if [ -z "$udid" ]; then
        udid=$(xcrun simctl list devices available | grep -m 1 "${preferred_device} (" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
    fi

    # Sinon, prend le premier iPhone disponible
    if [ -z "$udid" ]; then
        udid=$(xcrun simctl list devices available | grep -m 1 -E "iPhone .*\(" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
    fi

    if [ -z "$udid" ]; then
        echo "❌ Aucun simulateur iPhone disponible. Installez un runtime iOS dans Xcode."
        exit 1
    fi

    TARGET_UDID="$udid"
    echo "🎯 Simulateur ciblé: $TARGET_UDID"

    # Boot (autorise plusieurs simulateurs bootés) et attendre la disponibilité
    xcrun simctl boot "$TARGET_UDID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$TARGET_UDID" -b

    # Ouvrir l'app Simulator pointant sur le device choisi
    open -a Simulator --args -CurrentDeviceUDID "$TARGET_UDID"
}

# Assainir l'état du simulateur (fixe l'état "Shutting Down")
stabilize_simulator() {
    echo "🧰 Stabilisation du simulateur $TARGET_UDID..."
    xcrun simctl shutdown "$TARGET_UDID" >/dev/null 2>&1 || true
    sleep 1
    xcrun simctl boot "$TARGET_UDID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$TARGET_UDID" -b
}

# BUILD OBLIGATOIRE EN PREMIER
echo "🔨 Build de l'application..."
cd "$PROJECT_DIR"
xcodebuild -project PrivExpensIA.xcodeproj -scheme PrivExpensIA -sdk iphonesimulator -configuration "$CONFIGURATION" -derivedDataPath build clean build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Build réussi"
else
    echo "❌ Échec du build - arrêt"
    exit 1
fi

# Localiser le .app produit
APP_PATH=$(find "$PROJECT_DIR/build/Build/Products/$CONFIGURATION-iphonesimulator" -type d -name "PrivExpensIA.app" | head -n 1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Impossible de trouver l'app construite (.app)."
    exit 1
fi

echo "📦 App trouvée: $APP_PATH"
echo ""

# Installation explicite sur le simulateur choisi
install_app_on_simulator() {
    echo "📲 Installation de l'app sur le simulateur $TARGET_UDID..."
    if [ -z "$BUNDLE_ID" ]; then
        if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
            BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null)
        fi
        if [ -z "$BUNDLE_ID" ]; then
            BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier 2>/dev/null)
        fi
    fi

    if [ -z "$BUNDLE_ID" ]; then
        echo "❌ Impossible de déterminer CFBundleIdentifier depuis Info.plist"
        exit 1
    fi

    echo "🆔 Bundle Identifier détecté: $BUNDLE_ID"

    xcrun simctl uninstall "$TARGET_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if ! xcrun simctl install "$TARGET_UDID" "$APP_PATH"; then
        echo "⚠️ Install a échoué, tentative de stabilisation du simulateur..."
        stabilize_simulator
        xcrun simctl uninstall "$TARGET_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
        xcrun simctl install "$TARGET_UDID" "$APP_PATH"
    fi
}

# Fonction pour générer vidéo de localisation
generate_localization_video() {
    local output_file="$VIDEO_DIR/localization_test_${TIMESTAMP}.mp4"

    echo "📹 Génération vidéo de test localisation..."
    echo "   Fichier: $output_file"
    echo ""

    # Démarrer l'enregistrement (sur le simulateur ciblé)
    xcrun simctl io "$TARGET_UDID" recordVideo "$output_file" &
    local video_pid=$!

    # Test pour chaque langue principale
    for lang in "fr" "en" "de" "es"; do
        echo "🌍 Test langue: $lang"

        # Relancer l'app avec la langue
        xcrun simctl terminate "$TARGET_UDID" $BUNDLE_ID 2>/dev/null
        sleep 1
        xcrun simctl launch "$TARGET_UDID" $BUNDLE_ID --args -AppleLanguages "($lang)" 2>/dev/null || true
        sleep 4

        # Parcourir toutes les vues avec pauses pour analyse
        echo "  📱 Navigation dans l'app..."

        # Navigation automatique désactivée par défaut (gestes non supportés par simctl)
        if [ "${ENABLE_GESTURES:-false}" = "true" ]; then
            # Home
            xcrun simctl io "$TARGET_UDID" tap 75 1350 || true
            sleep 3

            # Expenses
            xcrun simctl io "$TARGET_UDID" tap 225 1350 || true
            sleep 3

            # Scan
            xcrun simctl io "$TARGET_UDID" tap 375 1350 || true
            sleep 2

            # Stats (avec scroll)
            xcrun simctl io "$TARGET_UDID" tap 525 1350 || true
            sleep 2
            xcrun simctl io "$TARGET_UDID" swipe 375 600 375 200 || true
            sleep 2

            # Settings (avec scroll complet)
            xcrun simctl io "$TARGET_UDID" tap 675 1350 || true
            sleep 2
            xcrun simctl io "$TARGET_UDID" swipe 375 600 375 200 || true
            sleep 2
            xcrun simctl io "$TARGET_UDID" swipe 375 600 375 200 || true
            sleep 2
        else
            echo "ℹ️ Gestes tap/swipe désactivés (ENABLE_GESTURES=false)."
        fi
    done

    # Arrêter l'enregistrement
    kill -INT $video_pid
    wait $video_pid 2>/dev/null

    echo "✅ Vidéo générée: $output_file"
    echo ""
    echo "::VIDEO::$output_file"

    return 0
}

# Scénario: enregistrement vidéo pendant un test UI qui ouvre Settings et scrolle
generate_settings_scroll_video() {
    local output_file="$VIDEO_DIR/settings_scroll_${TIMESTAMP}.mp4"

    echo "📹 Génération vidéo settings_scroll..."
    echo "   Fichier: $output_file"
    echo ""

    # Démarrer l'enregistrement
    xcrun simctl io "$TARGET_UDID" recordVideo "$output_file" &
    local video_pid=$!

    # Lancer uniquement le test UI ciblé sur le simulateur
    xcodebuild -project "$PROJECT_DIR/PrivExpensIA.xcodeproj" -scheme PrivExpensIA -destination "id=$TARGET_UDID" -only-testing:PrivExpensIAUITests/LocalizationScreenshotTests/testOpenSettingsAndScrollToBottom -derivedDataPath "$PROJECT_DIR/build" test > /tmp/ui_test_settings_scroll_${TIMESTAMP}.log 2>&1 || true

    # Arrêter l'enregistrement
    kill -INT $video_pid
    wait $video_pid 2>/dev/null

    echo "✅ Vidéo générée: $output_file"
    echo ""
    echo "::VIDEO::$output_file"
}

# Fonction pour préparer le prompt LLM
create_llm_prompt() {
    cat > "$VIDEO_DIR/llm_prompt_localization.txt" << 'EOF'
ANALYSE VIDÉO - VALIDATION LOCALISATION

Tu vas analyser une vidéo montrant une app iOS testée en 4 langues (FR, EN, DE, ES).
Chaque segment de ~15 secondes montre l'app dans une langue différente.

MISSION CRITIQUE - DÉTECTER:

1. UNDERSCORES (_):
   - ALERTE ROUGE pour tout texte contenant "_"
   - Noter: timestamp exact, langue, vue, texte complet
   - Exemple: "home_title" au lieu de "Accueil"

2. TEXTES NON TRADUITS:
   - Identifier TOUT texte en anglais quand la langue est FR/DE/ES
   - Vérifier: titres, boutons, labels, graphiques, jours semaine
   - Exemple: "Monday" au lieu de "Lundi" en français

3. INCOHÉRENCES:
   - Mélange de langues dans une même vue
   - Format dates/nombres incorrect pour la locale
   - Devise qui ne correspond pas

4. ÉLÉMENTS SPÉCIFIQUES À VÉRIFIER:
   Vue HOME:
   - Salutation (Good Morning / Bonjour / Guten Morgen / Buenos días)
   - "Today's Spending" doit être traduit
   - "Budget Left" doit être traduit
   - Jours: Mon/Tue/Wed → Lun/Mar/Mer (FR) → Mo/Di/Mi (DE)

   Vue STATS:
   - "Total Spent" / "Spending Trend" / "By Category"
   - "vs last period" doit être traduit

   Vue SETTINGS:
   - "Preferences" / "Privacy" / "Language" / "Currency"
   - Tous les toggles et leurs labels

RAPPORT ATTENDU:
Pour chaque problème, indiquer:
- ⏱️ Timestamp vidéo (ex: 0:23)
- 🌍 Langue active
- 📱 Vue concernée
- ❌ Problème exact
- ✅ Correction suggérée
- 🚨 Priorité: CRITIQUE (underscores) / HAUTE (non traduit) / MOYENNE

Sois IMPITOYABLE. Aucune erreur ne doit passer.
EOF

    echo "📝 Prompt LLM créé: $VIDEO_DIR/llm_prompt_localization.txt"
}

# Fonction pour préparer l'analyse
prepare_for_analysis() {
    local video_path=$1

    echo "🤖 Préparation pour analyse AI..."
    echo ""
    echo "📹 Vidéo à analyser: $video_path"
    echo "📝 Prompt: $VIDEO_DIR/llm_prompt_localization.txt"
    echo ""
    echo "Pour analyser avec Claude:"
    echo "1. Ouvrir la vidéo: open $video_path"
    echo "2. Utiliser le prompt pour l'analyse"
    echo "3. Générer le rapport de validation"
    echo ""

    # Créer un template de rapport
    cat > "$VIDEO_DIR/rapport_template_${TIMESTAMP}.md" << EOF
# 🤖 Rapport Validation AI - Localisation

Date: $(date)
Vidéo analysée: $video_path

## 🔴 Problèmes CRITIQUES (Underscores)
<!-- Liste ici tous les underscores trouvés -->

## 🟠 Problèmes HAUTS (Textes non traduits)
<!-- Liste ici tous les textes en anglais dans les autres langues -->

## 🟡 Problèmes MOYENS (Incohérences)
<!-- Liste ici les problèmes mineurs -->

## 📊 Résumé par langue
- FR: X problèmes
- EN: X problèmes
- DE: X problèmes
- ES: X problèmes

## ✅ Actions requises

### DUPONT2 (Localisation):
- [ ] Corriger tous les underscores
- [ ] Compléter les traductions manquantes

### DUPONT1 (Swift):
- [ ] Vérifier l'utilisation des clés de localisation
- [ ] Corriger les textes hardcodés

### TINTIN (QA):
- [ ] Revalider après corrections
- [ ] Nouvelle vidéo de validation

---
Généré par AI Validator
EOF

    echo "📄 Template rapport: $VIDEO_DIR/rapport_template_${TIMESTAMP}.md"
}

# Exécution principale
echo "Démarrage du workflow de validation vidéo..."
echo ""

# 1. Sélectionner et booter un simulateur dédié
select_target_simulator

# 2. Stabiliser puis installer l'app sur ce simulateur
stabilize_simulator
install_app_on_simulator

# 3. Générer la vidéo selon le scénario
case "$SCENARIO" in
  settings_scroll)
    generate_settings_scroll_video ;;
  *)
    generate_localization_video ;;
esac

# 4. Créer le prompt LLM
create_llm_prompt

# 5. Préparer pour analyse
prepare_for_analysis "$VIDEO_DIR/localization_test_${TIMESTAMP}.mp4"

echo ""
echo "✅ WORKFLOW TERMINÉ"
echo ""
echo "Prochaine étape:"
echo "- Analyser la vidéo avec le prompt LLM"
echo "- Compléter le rapport de validation"
echo "- Envoyer aux équipes pour correction"