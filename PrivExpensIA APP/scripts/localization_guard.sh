#!/usr/bin/env bash
# 🛡️ Localization Guard - Détection des strings hardcodées
# Bloque la compilation si des chaînes UI sont en dur dans le code Swift

set -euo pipefail

PROJECT_DIR="${1:-~/moulinsart/PrivExpensIA}"
SWIFT_DIR="$PROJECT_DIR/PrivExpensIA"
REPORT_FILE="$PROJECT_DIR/proof/localization_guard_report.txt"
VIOLATIONS_FILE="$PROJECT_DIR/proof/hardcoded_strings.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🛡️ Localization Guard - Scanning for hardcoded strings..."
echo "📁 Project: $PROJECT_DIR"
echo ""

mkdir -p "$PROJECT_DIR/proof"

# Patterns to detect hardcoded strings in Swift UI code
# Matches: Text("literal"), Label("literal"), Button("literal"), etc.
PATTERNS=(
    'Text\("[^"]*"\)'
    'Label\("[^"]*"'
    'Button\("[^"]*"'
    'NavigationTitle\("[^"]*"\)'
    'Alert.*title:.*"[^"]*"'
    'Alert.*message:.*"[^"]*"'
    '\.navigationTitle\("[^"]*"\)'
    '\.tabItem.*Text\("[^"]*"\)'
    '\.placeholder\("[^"]*"\)'
)

# Exceptions (OK to have hardcoded)
EXCEPTIONS=(
    'Text\(""\)'  # Empty string
    'Text\(" "\)' # Space
    'Text\("\+"'  # Plus sign
    'Text\("-"'   # Minus sign
    'Text\("/"'   # Slash
    'Text\("\."'  # Dot
    'Text\("€"'   # Currency symbols
    'Text\("$"'
    'Text\("£"'
    'Text\("¥"'
    'Text\("CHF"'
    'Text\("%"'   # Percent
    'Text\("[0-9]' # Numbers
    'print\('     # Debug prints
    'fatalError\(' # Error messages
    '.systemImage\(' # SF Symbols
)

# Initialize counters
total_violations=0
total_files_checked=0
files_with_violations=0

# Clear previous reports
> "$REPORT_FILE"
> "$VIOLATIONS_FILE"

echo "=== LOCALIZATION GUARD REPORT ===" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Project: $PROJECT_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to check if string matches any exception
is_exception() {
    local line="$1"
    for exception in "${EXCEPTIONS[@]}"; do
        if echo "$line" | grep -qE "$exception"; then
            return 0
        fi
    done
    return 1
}

# Function to extract the hardcoded string value
extract_string() {
    local line="$1"
    # Extract text between quotes
    echo "$line" | sed -n 's/.*"\([^"]*\)".*/\1/p' | head -1
}

# Scan all Swift files
echo "Scanning Swift files..." >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

while IFS= read -r -d '' file; do
    ((total_files_checked++))
    filename=$(basename "$file")
    
    # Skip test files and generated files
    if [[ "$file" == *"Test"* ]] || [[ "$file" == *"Mock"* ]] || [[ "$file" == *".generated."* ]]; then
        continue
    fi
    
    file_violations=0
    file_report=""
    
    # Check each pattern
    for pattern in "${PATTERNS[@]}"; do
        while IFS= read -r line_content; do
            # Get line number
            line_num=$(grep -n "$line_content" "$file" | head -1 | cut -d: -f1)
            
            # Check if it's an exception
            if ! is_exception "$line_content"; then
                # Extract the hardcoded string
                hardcoded_string=$(extract_string "$line_content")
                
                # Skip if string is empty or just whitespace
                if [[ -n "$hardcoded_string" ]] && [[ "$hardcoded_string" != " " ]]; then
                    ((file_violations++))
                    ((total_violations++))
                    
                    # Add to file report
                    file_report+="  Line $line_num: \"$hardcoded_string\""$'\n'
                    file_report+="    Code: $(echo "$line_content" | xargs)"$'\n'
                    
                    # Add to violations file
                    echo "$file:$line_num: \"$hardcoded_string\"" >> "$VIOLATIONS_FILE"
                fi
            fi
        done < <(grep -h "$pattern" "$file" 2>/dev/null || true)
    done
    
    # If violations found in this file, add to report
    if [[ $file_violations -gt 0 ]]; then
        ((files_with_violations++))
        echo "❌ $filename ($file_violations violations)" >> "$REPORT_FILE"
        echo "$file_report" >> "$REPORT_FILE"
    fi
    
done < <(find "$SWIFT_DIR" -name "*.swift" -type f -print0)

# Summary
echo "" >> "$REPORT_FILE"
echo "=== SUMMARY ===" >> "$REPORT_FILE"
echo "Files checked: $total_files_checked" >> "$REPORT_FILE"
echo "Files with violations: $files_with_violations" >> "$REPORT_FILE"
echo "Total violations: $total_violations" >> "$REPORT_FILE"

# Console output
echo ""
echo "📊 Results:"
echo "  Files checked: $total_files_checked"
echo "  Files with violations: $files_with_violations"
echo "  Total violations: $total_violations"
echo ""

if [[ $total_violations -eq 0 ]]; then
    echo -e "${GREEN}✅ SUCCESS: No hardcoded strings found!${NC}"
    echo "PASS" >> "$REPORT_FILE"
    exit 0
else
    echo -e "${RED}❌ FAILED: Found $total_violations hardcoded strings!${NC}"
    echo -e "${YELLOW}📄 See detailed report: $REPORT_FILE${NC}"
    echo -e "${YELLOW}📋 Violations list: $VIOLATIONS_FILE${NC}"
    echo "FAIL" >> "$REPORT_FILE"
    
    # Show first 5 violations
    echo ""
    echo "First violations:"
    head -5 "$VIOLATIONS_FILE" | while IFS= read -r line; do
        echo "  - $line"
    done
    
    exit 1
fi