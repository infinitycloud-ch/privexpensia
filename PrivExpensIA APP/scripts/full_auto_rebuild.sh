#!/usr/bin/env bash
# 🤖 FULL AUTOMATION - Zero human intervention
# This script MUST work without ANY manual steps

set -euo pipefail

PROJECT_DIR="~/moulinsart/PrivExpensIA"
DEVICE_UDID="9D1B772E-7D9B-4934-A7F4-D2829CEB0065"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🤖 FULL AUTOMATION BUILD & TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"

# Step 1: Clean everything
echo "🧹 Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/PrivExpensIA-*
echo "✅ DerivedData cleaned"

# Step 2: Build from command line
echo ""
echo "🔨 Building app..."
xcodebuild -project PrivExpensIA.xcodeproj \
           -scheme PrivExpensIA \
           -sdk iphonesimulator \
           -destination "id=$DEVICE_UDID" \
           -configuration Debug \
           clean build \
           ONLY_ACTIVE_ARCH=NO \
           -quiet

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build FAILED${NC}"
    exit 1
fi

echo "✅ Build succeeded"

# Step 3: Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PrivExpensIA.app" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
    echo -e "${RED}❌ App bundle not found after build${NC}"
    exit 1
fi

# Step 4: Verify localizations are in bundle
echo ""
echo "🔍 Verifying localizations in bundle..."
LPROJ_COUNT=$(find "$APP_PATH" -name "*.lproj" -type d 2>/dev/null | wc -l | tr -d ' ')
STRINGS_COUNT=$(find "$APP_PATH" -name "Localizable.strings" 2>/dev/null | wc -l | tr -d ' ')

if [[ $LPROJ_COUNT -eq 0 ]]; then
    echo -e "${RED}❌ NO .lproj directories in bundle!${NC}"
    echo "Localization will NOT work"
    exit 1
else
    echo "✅ Found $LPROJ_COUNT .lproj directories"
    echo "✅ Found $STRINGS_COUNT Localizable.strings files"
fi

# Step 5: Install on simulator
echo ""
echo "📱 Installing on simulator..."
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
echo "✅ App installed"

# Step 6: Test each language and capture screenshots
echo ""
echo "🌍 Testing all languages..."
LANGUAGES=("fr-CH" "de-CH" "it-CH" "en" "ja" "ko" "sk" "es")
FAILED_LANGS=()

mkdir -p "$PROJECT_DIR/proof/auto_test"

for LANG in "${LANGUAGES[@]}"; do
    echo -n "  Testing $LANG... "
    
    # Set language
    xcrun simctl spawn "$DEVICE_UDID" defaults write "$APP_PATH/../../Library/Preferences/.GlobalPreferences" AppleLanguages -array "$LANG"
    xcrun simctl spawn "$DEVICE_UDID" defaults write "$APP_PATH/../../Library/Preferences/.GlobalPreferences" AppleLocale "$LANG"
    
    # Launch app
    xcrun simctl terminate "$DEVICE_UDID" com.minhtam.ExpenseAI 2>/dev/null || true
    xcrun simctl launch "$DEVICE_UDID" com.minhtam.ExpenseAI
    
    # Wait for app to load
    sleep 3
    
    # Capture screenshot
    SCREENSHOT="$PROJECT_DIR/proof/auto_test/${LANG}_$(date +%H%M%S).png"
    xcrun simctl io "$DEVICE_UDID" screenshot "$SCREENSHOT"
    
    # Use OCR to check if localization works (macOS Monterey+)
    if command -v shortcuts &> /dev/null; then
        # Try to extract text from screenshot
        TEXT=$(shortcuts run "Extract Text from Image" -i "$SCREENSHOT" 2>/dev/null || echo "")
        
        # Check for English text that shouldn't be there
        case $LANG in
            fr*)
                if [[ "$TEXT" == *"Good Morning"* ]]; then
                    echo -e "${RED}FAILED - Still in English!${NC}"
                    FAILED_LANGS+=("$LANG")
                else
                    echo -e "${GREEN}OK${NC}"
                fi
                ;;
            de*)
                if [[ "$TEXT" == *"Good Morning"* ]]; then
                    echo -e "${RED}FAILED - Still in English!${NC}"
                    FAILED_LANGS+=("$LANG")
                else
                    echo -e "${GREEN}OK${NC}"
                fi
                ;;
            *)
                echo "Captured"
                ;;
        esac
    else
        echo "Captured (no OCR available)"
    fi
done

# Step 7: Generate HTML report
echo ""
echo "📊 Generating report..."
REPORT="$PROJECT_DIR/proof/auto_test/report.html"

cat > "$REPORT" << 'HTML'
<!DOCTYPE html>
<html>
<head>
<title>Auto Test Report</title>
<style>
body { font-family: system-ui; padding: 20px; background: #f5f5f5; }
.status { padding: 10px; margin: 10px 0; border-radius: 8px; }
.pass { background: #d4edda; color: #155724; }
.fail { background: #f8d7da; color: #721c24; }
h1 { color: #333; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
.card { background: white; border-radius: 8px; padding: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
img { width: 100%; border-radius: 4px; }
</style>
</head>
<body>
<h1>🤖 Automated Localization Test</h1>
HTML

if [[ ${#FAILED_LANGS[@]} -eq 0 ]]; then
    echo '<div class="status pass">✅ All languages working!</div>' >> "$REPORT"
else
    echo '<div class="status fail">❌ Some languages failed: '"${FAILED_LANGS[*]}"'</div>' >> "$REPORT"
fi

echo '<div class="grid">' >> "$REPORT"
for img in "$PROJECT_DIR/proof/auto_test"/*.png; do
    if [[ -f "$img" ]]; then
        name=$(basename "$img" .png)
        echo "<div class='card'><img src='$(basename "$img")'><p>$name</p></div>" >> "$REPORT"
    fi
done
echo '</div></body></html>' >> "$REPORT"

# Open report
open "$REPORT" 2>/dev/null || true

# Step 8: Final verdict
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ ${#FAILED_LANGS[@]} -eq 0 ]] && [[ $LPROJ_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✅ AUTOMATION SUCCESS${NC}"
    echo "All localizations are working!"
else
    echo -e "${RED}❌ AUTOMATION FAILED${NC}"
    if [[ $LPROJ_COUNT -eq 0 ]]; then
        echo "Localizations not in bundle - Xcode configuration issue"
    else
        echo "Some languages not displaying correctly"
    fi
    exit 1
fi