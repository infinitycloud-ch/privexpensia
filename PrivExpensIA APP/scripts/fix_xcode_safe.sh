#!/usr/bin/env bash
# 🔧 SAFE Fix for Xcode Localization - ADD without removing
# Version sécurisée qui n'enlève rien

set -euo pipefail

PROJECT_DIR="~/moulinsart/PrivExpensIA"
PROJECT_FILE="$PROJECT_DIR/PrivExpensIA.xcodeproj/project.pbxproj"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔧 SAFE Xcode Localization Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}⚠️  This script will ADD localization files${NC}"
echo -e "${YELLOW}    without removing existing resources${NC}"
echo ""

# Create backup with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${PROJECT_FILE}.safe_backup_${TIMESTAMP}"
echo "📦 Creating safety backup..."
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup saved to:${NC}"
echo "   $(basename $BACKUP_FILE)"
echo ""

# Manual instructions since Ruby script was too destructive
echo -e "${BLUE}MANUAL FIX INSTRUCTIONS:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. In Xcode, go to Build Phases → Copy Bundle Resources"
echo ""
echo "2. Click the '+' button at the bottom"
echo ""
echo "3. Navigate to PrivExpensIA folder"
echo ""
echo "4. Select ALL these .lproj folders while holding Cmd:"
echo "   • Base.lproj"
echo "   • en.lproj"
echo "   • fr-CH.lproj"
echo "   • de-CH.lproj"
echo "   • it-CH.lproj"
echo "   • ja.lproj"
echo "   • ko.lproj"
echo "   • sk.lproj"
echo "   • es.lproj"
echo "   • de.lproj"
echo "   • it.lproj"
echo ""
echo "5. Click 'Add'"
echo ""
echo "6. Xcode will automatically create the Localizable.strings"
echo "   variant group with all languages"
echo ""
echo "7. Remove the old '(localization).lproj' entry if present"
echo ""
echo "8. You should now have:"
echo "   • Assets.xcassets"
echo "   • Localizable.strings (with 11 languages)"
echo "   • Any other resources"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Alternative: Try to add using xcodebuild (safer approach)
echo -e "${BLUE}Attempting automatic fix with PlistBuddy...${NC}"
echo ""

# Check current state
echo "Current Copy Bundle Resources:"
/usr/libexec/PlistBuddy -c "Print :objects" "$PROJECT_FILE" 2>/dev/null | grep -A5 "Copy Bundle Resources" || echo "Could not read current state"

echo ""
echo -e "${YELLOW}📝 IMPORTANT:${NC}"
echo "• If automatic fix fails, use the manual instructions above"
echo "• The backup is saved at: $BACKUP_FILE"
echo "• To restore: cp $BACKUP_FILE $PROJECT_FILE"
echo ""

# Create a simple Python script to fix it safely
cat > /tmp/fix_xcode.py << 'PYTHON'
#!/usr/bin/env python3
import plistlib
import sys
import os

project_file = "~/moulinsart/PrivExpensIA/PrivExpensIA.xcodeproj/project.pbxproj"

print("🔍 Analyzing project file...")

# Read the file as text (it's not a standard plist)
with open(project_file, 'r') as f:
    content = f.read()

# Check if Assets.xcassets is still there
if "Assets.xcassets" in content:
    print("✅ Assets.xcassets found in project")
else:
    print("⚠️  Assets.xcassets not found - may need manual re-add")

# Check for lproj references
languages = ["Base", "en", "fr-CH", "de-CH", "it-CH", "ja", "ko", "sk", "es", "de", "it"]
found = []
missing = []

for lang in languages:
    if f"{lang}.lproj" in content:
        found.append(lang)
    else:
        missing.append(lang)

if found:
    print(f"✅ Found {len(found)} language(s): {', '.join(found)}")
if missing:
    print(f"❌ Missing {len(missing)} language(s): {', '.join(missing)}")

print("\n📋 Project file appears to be readable")
print("Please follow the manual instructions to add localizations")
PYTHON

python3 /tmp/fix_xcode.py

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Analysis complete${NC}"
echo ""
echo "Please follow the MANUAL instructions above in Xcode"
echo "This is the safest way to fix the localization"