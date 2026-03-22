#!/usr/bin/env bash
# 🌍 i18n Automation Script for PrivExpensIA
# Automatise les tests de localisation pour 8 langues
# UDID fixe pour éviter les problèmes de nom de simulateur

set -euo pipefail

# ====== CONFIGURATION ======
DEVICE="9D1B772E-7D9B-4934-A7F4-D2829CEB0065"  # iPhone 16 Pro Max "tintin"
APP_ID="com.minhtam.ExpenseAI"
PROJECT_DIR="~/moulinsart/PrivExpensIA"
OUT="$PROJECT_DIR/proof/i18n"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Langues à tester (code:locale)
declare -a langs=(
  'fr-CH:fr_CH'  # Français Suisse
  'de-CH:de_CH'  # Allemand Suisse
  'it-CH:it_CH'  # Italien Suisse
  'en:en_US'     # Anglais US
  'ja:ja_JP'     # Japonais
  'ko:ko_KR'     # Coréen
  'sk:sk_SK'     # Slovaque
  'es:es_ES'     # Espagnol
)

# ====== FUNCTIONS ======
log() {
  echo "[$(date +'%H:%M:%S')] $1"
}

error() {
  echo "❌ ERROR: $1" >&2
  exit 1
}

# ====== SETUP ======
log "🚀 Starting i18n automation..."
mkdir -p "$OUT"

# ====== BUILD ======
log "🔨 Building app..."
cd "$PROJECT_DIR"

# Generate project if needed
if [ ! -d "PrivExpensIA.xcodeproj" ]; then
  log "Generating Xcode project..."
  xcodegen generate || error "Failed to generate project"
fi

# Clean and build
log "Cleaning and building..."
xcodebuild -project PrivExpensIA.xcodeproj \
           -scheme PrivExpensIA \
           -destination "platform=iOS Simulator,id=$DEVICE" \
           -configuration Debug \
           -sdk iphonesimulator \
           clean build > "$OUT/build_log_$TIMESTAMP.txt" 2>&1 || error "Build failed - check $OUT/build_log_$TIMESTAMP.txt"

log "✅ Build successful"

# ====== SIMULATOR ======
log "📱 Preparing simulator..."

# Boot if needed
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b

# Install app
log "Installing app on simulator..."
APP_PATH=$(xcodebuild -project PrivExpensIA.xcodeproj \
                      -scheme PrivExpensIA \
                      -sdk iphonesimulator \
                      -showBuildSettings \
                      -configuration Debug | grep "BUILT_PRODUCTS_DIR" | head -1 | awk '{print $3}')
                      
xcrun simctl install "$DEVICE" "$APP_PATH/PrivExpensIA.app" || error "Failed to install app"

# ====== LANGUAGE TESTS ======
log "🌍 Testing languages..."

# Create results file
RESULTS_FILE="$OUT/results_$TIMESTAMP.md"
echo "# i18n Test Results - $TIMESTAMP" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Language | Code | Locale | Screenshot | Status |" >> "$RESULTS_FILE"
echo "|----------|------|--------|------------|--------|" >> "$RESULTS_FILE"

# Test each language
for pair in "${langs[@]}"; do
  LANG="${pair%%:*}"
  LOCALE="${pair##*:}"
  LANG_NAME=""
  
  # Get language name
  case "$LANG" in
    "fr-CH") LANG_NAME="Français (Suisse)" ;;
    "de-CH") LANG_NAME="Deutsch (Schweiz)" ;;
    "it-CH") LANG_NAME="Italiano (Svizzera)" ;;
    "en") LANG_NAME="English" ;;
    "ja") LANG_NAME="日本語" ;;
    "ko") LANG_NAME="한국어" ;;
    "sk") LANG_NAME="Slovenčina" ;;
    "es") LANG_NAME="Español" ;;
  esac
  
  log "  Testing $LANG_NAME ($LANG / $LOCALE)..."
  
  # Terminate app if running
  xcrun simctl terminate "$DEVICE" "$APP_ID" 2>/dev/null || true
  
  # Launch with specific language
  xcrun simctl launch "$DEVICE" "$APP_ID" \
    --args -AppleLanguages "($LANG)" \
           -AppleLocale "$LOCALE" \
           -AppleTextDirection "natural" \
           -NSDoubleLocalizedStrings "NO"
  
  # Wait for UI to load
  sleep 3
  
  # Take screenshot
  SCREENSHOT="app_${LANG}_$TIMESTAMP.png"
  xcrun simctl io "$DEVICE" screenshot "$OUT/$SCREENSHOT"
  
  # Add to results
  echo "| $LANG_NAME | $LANG | $LOCALE | $SCREENSHOT | ✅ |" >> "$RESULTS_FILE"
  
  log "    ✅ Screenshot saved: $SCREENSHOT"
done

# ====== VALIDATION ======
log "📋 Creating validation checklist..."

cat << EOF > "$OUT/i18n_fix_notes_$TIMESTAMP.md"
# i18n Fix Notes - $TIMESTAMP

## Configuration
- Device: iPhone 16 Pro Max
- UDID: $DEVICE
- iOS: 18.6
- Bundle ID: $APP_ID

## Files Modified
- [ ] LocalizationManager.swift - Uses Bundle.main only
- [ ] All .lproj files added to Target Membership
- [ ] Debug prints added to PrivExpensIAApp.swift

## Localizable.strings Files
- [ ] Base.lproj/Localizable.strings
- [ ] fr.lproj/Localizable.strings ✅
- [ ] de.lproj/Localizable.strings
- [ ] it.lproj/Localizable.strings
- [ ] en.lproj/Localizable.strings
- [ ] ja.lproj/Localizable.strings
- [ ] ko.lproj/Localizable.strings
- [ ] sk.lproj/Localizable.strings
- [ ] es.lproj/Localizable.strings

## Test Results
See results_$TIMESTAMP.md for details.

## Validation Checklist
- [ ] No underscore keys visible
- [ ] All languages display correct translations
- [ ] Build succeeds without warnings
- [ ] Script runs without errors

## Debug Output
\`\`\`
TODO: Add debug prints output here
\`\`\`
EOF

# ====== SUMMARY ======
log "✅ i18n automation complete!"
log ""
log "📁 Results saved in: $OUT"
log "   - Screenshots: app_*_$TIMESTAMP.png"
log "   - Build log: build_log_$TIMESTAMP.txt"
log "   - Results: results_$TIMESTAMP.md"
log "   - Notes: i18n_fix_notes_$TIMESTAMP.md"
log ""
log "🎯 Next step: Review screenshots for any underscore keys"

# Open results folder
open "$OUT"

exit 0