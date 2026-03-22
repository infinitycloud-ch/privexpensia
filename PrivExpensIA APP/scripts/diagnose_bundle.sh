#!/usr/bin/env bash
# 🔍 Diagnostic du bundle de l'app pour localisation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 DIAGNOSTIC BUNDLE LOCALISATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find the app in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PrivExpensIA.app" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
    echo -e "${RED}❌ App bundle not found!${NC}"
    echo "Please build the app first (Cmd+B in Xcode)"
    exit 1
fi

echo -e "${GREEN}✅ Found app bundle:${NC}"
echo "   $APP_PATH"
echo ""

# Check what's inside the bundle
echo -e "${BLUE}📦 Bundle Contents:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for .lproj directories
echo ""
echo "🌍 Localization directories (.lproj):"
if ls "$APP_PATH"/*.lproj 2>/dev/null 1>&2; then
    for lproj in "$APP_PATH"/*.lproj; do
        if [[ -d "$lproj" ]]; then
            name=$(basename "$lproj")
            echo -e "  ${GREEN}✅${NC} $name"
            # Check for Localizable.strings inside
            if [[ -f "$lproj/Localizable.strings" ]]; then
                size=$(wc -c < "$lproj/Localizable.strings")
                echo "      └─ Localizable.strings ($size bytes)"
            else
                echo -e "      ${RED}└─ NO Localizable.strings!${NC}"
            fi
        fi
    done
else
    echo -e "  ${RED}❌ NO .lproj directories found!${NC}"
fi

# Check for Localizable.strings at root
echo ""
echo "📄 Root level Localizable.strings:"
if [[ -f "$APP_PATH/Localizable.strings" ]]; then
    echo -e "  ${YELLOW}⚠️  Found at root (should be in .lproj folders)${NC}"
else
    echo "  ✅ Not at root (correct)"
fi

# Check Info.plist for localization settings
echo ""
echo "📋 Info.plist localization settings:"
if [[ -f "$APP_PATH/Info.plist" ]]; then
    # Try to read CFBundleDevelopmentRegion
    DEV_REGION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDevelopmentRegion" "$APP_PATH/Info.plist" 2>/dev/null || echo "Not set")
    echo "  Development Region: $DEV_REGION"
    
    # Check for CFBundleLocalizations
    if /usr/libexec/PlistBuddy -c "Print :CFBundleLocalizations" "$APP_PATH/Info.plist" 2>/dev/null; then
        echo "  Localizations array found"
    else
        echo -e "  ${YELLOW}⚠️  No CFBundleLocalizations key${NC}"
    fi
else
    echo -e "  ${RED}❌ Info.plist not found${NC}"
fi

# Test with actual Bundle.main simulation
echo ""
echo "🧪 Testing Bundle.main resource loading:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create a test Swift script
cat > /tmp/test_bundle.swift << 'SWIFT'
import Foundation

// Simulate what LocalizationManager does
let languages = ["fr-CH", "fr", "de-CH", "de", "it-CH", "it", "en", "ja", "ko", "sk", "es"]

print("\n🔍 Testing Bundle.main localization loading:\n")

for lang in languages {
    // Try exact match first
    if let url = Bundle.main.url(forResource: "Localizable", 
                                 withExtension: "strings",
                                 subdirectory: "\(lang).lproj") {
        print("✅ \(lang).lproj: Found at \(url.lastPathComponent)")
    } else {
        print("❌ \(lang).lproj: NOT FOUND")
    }
}

// Check Base.lproj
if let url = Bundle.main.url(forResource: "Localizable", 
                             withExtension: "strings",
                             subdirectory: "Base.lproj") {
    print("✅ Base.lproj: Found")
} else {
    print("❌ Base.lproj: NOT FOUND")
}

// List all bundle resources
print("\n📦 All .strings files in bundle:")
if let urls = Bundle.main.urls(forResourcesWithExtension: "strings", subdirectory: nil) {
    for url in urls {
        print("  • \(url.path)")
    }
} else {
    print("  ❌ No .strings files found")
}
SWIFT

# Compile and run the test
echo ""
if swiftc /tmp/test_bundle.swift -o /tmp/test_bundle 2>/dev/null; then
    cd "$APP_PATH"
    /tmp/test_bundle
else
    echo -e "${YELLOW}⚠️  Could not compile Swift test${NC}"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DIAGNOSTIC SUMMARY:"
echo ""

# Count .lproj directories
LPROJ_COUNT=$(find "$APP_PATH" -name "*.lproj" -type d 2>/dev/null | wc -l | tr -d ' ')

if [[ $LPROJ_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✅ $LPROJ_COUNT .lproj directories found${NC}"
    
    # Check if they have Localizable.strings
    STRINGS_COUNT=$(find "$APP_PATH" -name "Localizable.strings" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $STRINGS_COUNT -gt 0 ]]; then
        echo -e "${GREEN}✅ $STRINGS_COUNT Localizable.strings files found${NC}"
    else
        echo -e "${RED}❌ NO Localizable.strings files in .lproj folders${NC}"
        echo ""
        echo "🔧 SOLUTION: The .lproj folders are empty!"
        echo "   The build phase didn't copy the .strings files"
    fi
else
    echo -e "${RED}❌ NO .lproj directories in bundle${NC}"
    echo ""
    echo "🔧 SOLUTION: Build phases not configured correctly"
    echo "   Add the .lproj folders to Copy Bundle Resources"
fi

echo ""
echo "📝 Next steps:"
echo "1. If .lproj folders are missing: Add them in Xcode Build Phases"
echo "2. If .strings files are missing: Check file Target Membership"
echo "3. Clean build folder (Cmd+Shift+K) and rebuild"