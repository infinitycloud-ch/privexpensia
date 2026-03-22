#!/usr/bin/env bash
# 🔍 XCStrings Validator - Vérification des clés utilisées vs déclarées
# Détecte les clés manquantes et les clés inutilisées

set -euo pipefail

PROJECT_DIR="${1:-~/moulinsart/PrivExpensIA}"
SWIFT_DIR="$PROJECT_DIR/PrivExpensIA"
STRINGS_DIR="$PROJECT_DIR/PrivExpensIA"
REPORT_FILE="$PROJECT_DIR/proof/xcstrings_validation_report.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 XCStrings Validator - Checking localization keys..."
echo "📁 Project: $PROJECT_DIR"
echo ""

mkdir -p "$PROJECT_DIR/proof"

# Initialize arrays
declare -a DECLARED_KEYS=()
declare -a USED_KEYS=()
declare -a MISSING_KEYS=()
declare -a UNUSED_KEYS=()

# Clear report
> "$REPORT_FILE"

echo "=== XCSTRINGS VALIDATION REPORT ===" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Project: $PROJECT_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Step 1: Extract all declared keys from .strings files
echo "📚 Extracting declared keys from .strings files..."
echo "" >> "$REPORT_FILE"
echo "DECLARED KEYS:" >> "$REPORT_FILE"

# Find all Localizable.strings files
while IFS= read -r -d '' strings_file; do
    echo "  Reading: $(basename "$(dirname "$strings_file")")/$(basename "$strings_file")" >> "$REPORT_FILE"
    
    # Extract keys (format: "key" = "value";)
    while IFS= read -r key; do
        # Clean the key
        clean_key=$(echo "$key" | sed 's/^"//;s/"$//')
        if [[ -n "$clean_key" ]] && [[ ${#DECLARED_KEYS[@]} -eq 0 || ! " ${DECLARED_KEYS[@]} " =~ " ${clean_key} " ]]; then
            DECLARED_KEYS+=("$clean_key")
        fi
    done < <(grep -oE '^"[^"]*"' "$strings_file" 2>/dev/null || true)
done < <(find "$STRINGS_DIR" -name "Localizable.strings" -type f -print0)

echo "  Total declared keys: ${#DECLARED_KEYS[@]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Step 2: Extract all used keys from Swift files
echo "📱 Extracting used keys from Swift code..."
echo "USED KEYS:" >> "$REPORT_FILE"

# Patterns for localization usage in Swift
PATTERNS=(
    '\.localized\('
    'LocalizedStringKey\("([^"]*)"\)'
    'String\(localized: *"([^"]*)"\)'
    'NSLocalizedString\("([^"]*)"'
    'localized\("([^"]*)"\)'
    '"\([^"]*\)"\.localized'
)

# Scan Swift files for localization keys
while IFS= read -r -d '' swift_file; do
    # Skip test files
    if [[ "$swift_file" == *"Test"* ]] || [[ "$swift_file" == *"Mock"* ]]; then
        continue
    fi
    
    # Look for .localized usage
    while IFS= read -r line; do
        # Extract key from patterns like "key".localized or localized("key")
        if echo "$line" | grep -qE '"[^"]*"\.localized'; then
            key=$(echo "$line" | grep -oE '"[^"]*"\.localized' | sed 's/"//;s/"\.localized//')
            if [[ -n "$key" ]] && [[ ${#USED_KEYS[@]} -eq 0 || ! " ${USED_KEYS[@]} " =~ " ${key} " ]]; then
                USED_KEYS+=("$key")
            fi
        elif echo "$line" | grep -qE 'localized\("[^"]*"\)'; then
            key=$(echo "$line" | grep -oE 'localized\("[^"]*"\)' | sed 's/localized("//;s/")//')
            if [[ -n "$key" ]] && [[ ${#USED_KEYS[@]} -eq 0 || ! " ${USED_KEYS[@]} " =~ " ${key} " ]]; then
                USED_KEYS+=("$key")
            fi
        elif echo "$line" | grep -qE 'String\(localized: *"[^"]*"\)'; then
            key=$(echo "$line" | grep -oE 'String\(localized: *"[^"]*"\)' | sed 's/String(localized: *"//;s/")//')
            if [[ -n "$key" ]] && [[ ${#USED_KEYS[@]} -eq 0 || ! " ${USED_KEYS[@]} " =~ " ${key} " ]]; then
                USED_KEYS+=("$key")
            fi
        fi
    done < <(grep -h '\.localized\|String(localized:\|NSLocalizedString' "$swift_file" 2>/dev/null || true)
done < <(find "$SWIFT_DIR" -name "*.swift" -type f -print0)

echo "  Total used keys: ${#USED_KEYS[@]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Step 3: Find missing keys (used but not declared)
echo "🔍 Checking for missing keys..."
echo "MISSING KEYS (used but not declared):" >> "$REPORT_FILE"

if [[ ${#USED_KEYS[@]} -gt 0 ]]; then
  for used_key in "${USED_KEYS[@]}"; do
    if [[ ! " ${DECLARED_KEYS[@]} " =~ " ${used_key} " ]]; then
        MISSING_KEYS+=("$used_key")
        echo "  ❌ $used_key" >> "$REPORT_FILE"
    fi
  done
fi

if [[ ${#MISSING_KEYS[@]} -eq 0 ]]; then
    echo "  ✅ None - all used keys are declared!" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# Step 4: Find unused keys (declared but not used)
echo "🗑️ Checking for unused keys..."
echo "UNUSED KEYS (declared but not used):" >> "$REPORT_FILE"

if [[ ${#DECLARED_KEYS[@]} -gt 0 ]]; then
  for declared_key in "${DECLARED_KEYS[@]}"; do
    if [[ ${#USED_KEYS[@]} -eq 0 || ! " ${USED_KEYS[@]} " =~ " ${declared_key} " ]]; then
        UNUSED_KEYS+=("$declared_key")
        echo "  ⚠️ $declared_key" >> "$REPORT_FILE"
    fi
  done
fi

if [[ ${#UNUSED_KEYS[@]} -eq 0 ]]; then
    echo "  ✅ None - all declared keys are used!" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# Summary
echo "=== SUMMARY ===" >> "$REPORT_FILE"
echo "Declared keys: ${#DECLARED_KEYS[@]}" >> "$REPORT_FILE"
echo "Used keys: ${#USED_KEYS[@]}" >> "$REPORT_FILE"
echo "Missing keys: ${#MISSING_KEYS[@]}" >> "$REPORT_FILE"
echo "Unused keys: ${#UNUSED_KEYS[@]}" >> "$REPORT_FILE"

# Console output
echo ""
echo "📊 Results:"
echo "  Declared keys: ${#DECLARED_KEYS[@]}"
echo "  Used keys: ${#USED_KEYS[@]}"
echo -e "  ${RED}Missing keys: ${#MISSING_KEYS[@]}${NC}"
echo -e "  ${YELLOW}Unused keys: ${#UNUSED_KEYS[@]}${NC}"
echo ""

# Determine pass/fail
if [[ ${#MISSING_KEYS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ SUCCESS: All used keys are properly declared!${NC}"
    if [[ ${#UNUSED_KEYS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ WARNING: Found ${#UNUSED_KEYS[@]} unused keys (consider cleaning up)${NC}"
    fi
    echo "PASS" >> "$REPORT_FILE"
    exit 0
else
    echo -e "${RED}❌ FAILED: Found ${#MISSING_KEYS[@]} missing keys!${NC}"
    echo -e "${YELLOW}📄 See detailed report: $REPORT_FILE${NC}"
    echo ""
    echo "Missing keys that need to be added:"
    for key in "${MISSING_KEYS[@]:0:5}"; do
        echo "  - $key"
    done
    if [[ ${#MISSING_KEYS[@]} -gt 5 ]]; then
        echo "  ... and $((${#MISSING_KEYS[@]} - 5)) more"
    fi
    echo "FAIL" >> "$REPORT_FILE"
    exit 1
fi