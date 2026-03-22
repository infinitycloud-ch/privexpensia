#!/usr/bin/env bash
# 🚦 CHECKPOINT SPRINT 2 - Localization Gate
# Script unique qui valide TOUT avant de passer au Sprint 3
# Échoue si un seul test ne passe pas

set -euo pipefail

# Configuration
PROJECT_DIR="~/moulinsart/PrivExpensIA"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
PROOF_DIR="$PROJECT_DIR/proof"
REPORT_HTML="$PROOF_DIR/checkpoint_sprint2_report.html"
DEVICE_UDID="9D1B772E-7D9B-4934-A7F4-D2829CEB0065"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Scores
TOTAL_TESTS=4
PASSED_TESTS=0
FAILED_TESTS=0

# Arrays for results
declare -a TEST_RESULTS
declare -a TEST_MESSAGES

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          🚦 CHECKPOINT SPRINT 2 - LOCALIZATION        ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Project:${NC} $PROJECT_DIR"
echo -e "${BOLD}Time:${NC} $(date)"
echo -e "${BOLD}Device:${NC} $DEVICE_UDID"
echo ""

# Create proof directory
mkdir -p "$PROOF_DIR"

# Helper function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_num="$3"
    
    echo -e "${BOLD}[$test_num/$TOTAL_TESTS] Running: $test_name${NC}"
    
    if eval "$test_command" > "$PROOF_DIR/test_${test_num}_output.txt" 2>&1; then
        echo -e "  ${GREEN}✅ PASSED${NC}"
        TEST_RESULTS+=("PASS")
        TEST_MESSAGES+=("$test_name: PASSED")
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "  ${RED}❌ FAILED${NC}"
        TEST_RESULTS+=("FAIL")
        TEST_MESSAGES+=("$test_name: FAILED - See $PROOF_DIR/test_${test_num}_output.txt")
        ((FAILED_TESTS++))
        return 1
    fi
}

echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}STEP 1: BUILD VERIFICATION${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 1: Build the project
run_test "Xcode Build" \
    "cd '$PROJECT_DIR' && xcodegen generate && xcodebuild -project PrivExpensIA.xcodeproj -scheme PrivExpensIA -destination 'platform=iOS Simulator,id=$DEVICE_UDID' -sdk iphonesimulator clean build" \
    1

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}STEP 2: LOCALIZATION CHECKS${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 2: Check for hardcoded strings
chmod +x "$SCRIPTS_DIR/localization_guard.sh"
run_test "Hardcoded Strings Detection" \
    "'$SCRIPTS_DIR/localization_guard.sh' '$PROJECT_DIR'" \
    2

# Test 3: Validate XCStrings keys
chmod +x "$SCRIPTS_DIR/xcstrings_validator.sh"
run_test "XCStrings Key Validation" \
    "'$SCRIPTS_DIR/xcstrings_validator.sh' '$PROJECT_DIR'" \
    3

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}STEP 3: MULTI-LANGUAGE SNAPSHOTS${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 4: Generate i18n snapshots
chmod +x "$SCRIPTS_DIR/i18n_snapshots.sh"
run_test "Multi-Language Screenshots" \
    "'$SCRIPTS_DIR/i18n_snapshots.sh'" \
    4

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}GENERATING HTML REPORT${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Generate comprehensive HTML report
cat > "$REPORT_HTML" << 'HTML_CONTENT'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Sprint 2 Checkpoint - Localization Gate</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  
  body { 
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Arial, sans-serif; 
    background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
    min-height: 100vh;
    padding: 40px 20px;
  }
  
  .container {
    max-width: 1200px;
    margin: 0 auto;
  }
  
  .header {
    background: white;
    border-radius: 20px;
    padding: 40px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    margin-bottom: 30px;
    text-align: center;
  }
  
  h1 {
    font-size: 36px;
    color: #1a1a1a;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 15px;
  }
  
  .status-badge {
    display: inline-block;
    padding: 10px 24px;
    border-radius: 50px;
    font-size: 16px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin: 20px 0;
  }
  
  .status-pass {
    background: linear-gradient(135deg, #2ecc71, #27ae60);
    color: white;
    box-shadow: 0 4px 15px rgba(46, 204, 113, 0.3);
  }
  
  .status-fail {
    background: linear-gradient(135deg, #e74c3c, #c0392b);
    color: white;
    box-shadow: 0 4px 15px rgba(231, 76, 60, 0.3);
  }
  
  .meta {
    color: #666;
    font-size: 14px;
    margin: 5px 0;
  }
  
  .test-grid {
    display: grid;
    gap: 20px;
    margin-bottom: 30px;
  }
  
  .test-card {
    background: white;
    border-radius: 16px;
    padding: 25px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.1);
    border-left: 5px solid #ddd;
    transition: all 0.3s ease;
  }
  
  .test-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 15px 40px rgba(0,0,0,0.15);
  }
  
  .test-card.passed {
    border-left-color: #2ecc71;
  }
  
  .test-card.failed {
    border-left-color: #e74c3c;
  }
  
  .test-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 15px;
  }
  
  .test-name {
    font-size: 18px;
    font-weight: 600;
    color: #2c3e50;
  }
  
  .test-status {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
    padding: 5px 12px;
    border-radius: 20px;
  }
  
  .test-status.pass {
    background: #d4f1e0;
    color: #27ae60;
  }
  
  .test-status.fail {
    background: #fde2e2;
    color: #e74c3c;
  }
  
  .test-details {
    color: #666;
    font-size: 14px;
    line-height: 1.6;
  }
  
  .screenshots-section {
    background: white;
    border-radius: 20px;
    padding: 30px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.15);
  }
  
  .screenshots-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin-top: 20px;
  }
  
  .screenshot-card {
    text-align: center;
    cursor: pointer;
    transition: transform 0.2s;
  }
  
  .screenshot-card:hover {
    transform: scale(1.05);
  }
  
  .screenshot-img {
    width: 100%;
    border-radius: 12px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
  }
  
  .screenshot-label {
    margin-top: 10px;
    font-size: 14px;
    font-weight: 600;
    color: #2c3e50;
  }
  
  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 20px;
    margin: 30px 0;
  }
  
  .summary-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 20px;
    border-radius: 12px;
    text-align: center;
  }
  
  .summary-number {
    font-size: 32px;
    font-weight: 700;
    margin-bottom: 5px;
  }
  
  .summary-label {
    font-size: 14px;
    opacity: 0.9;
  }
  
  pre {
    background: #f5f5f5;
    padding: 15px;
    border-radius: 8px;
    overflow-x: auto;
    font-size: 12px;
    margin-top: 10px;
  }
  
  .icon-pass { color: #2ecc71; }
  .icon-fail { color: #e74c3c; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>🚦 Sprint 2 Checkpoint - Localization Gate</h1>
    <div class="status-badge STATUS_CLASS">OVERALL_STATUS</div>
    <div class="meta">Generated: TIMESTAMP</div>
    <div class="meta">Project: ~/moulinsart/PrivExpensIA</div>
    <div class="meta">Device: tintin (9D1B772E-7D9B-4934-A7F4-D2829CEB0065)</div>
  </div>
  
  <div class="summary-grid">
    <div class="summary-card">
      <div class="summary-number">TOTAL_TESTS</div>
      <div class="summary-label">Total Tests</div>
    </div>
    <div class="summary-card" style="background: linear-gradient(135deg, #2ecc71, #27ae60);">
      <div class="summary-number">PASSED_COUNT</div>
      <div class="summary-label">Passed</div>
    </div>
    <div class="summary-card" style="background: linear-gradient(135deg, #e74c3c, #c0392b);">
      <div class="summary-number">FAILED_COUNT</div>
      <div class="summary-label">Failed</div>
    </div>
    <div class="summary-card" style="background: linear-gradient(135deg, #3498db, #2980b9);">
      <div class="summary-number">SUCCESS_RATE%</div>
      <div class="summary-label">Success Rate</div>
    </div>
  </div>
  
  <div class="test-grid">
    TEST_CARDS_HTML
  </div>
  
  <div class="screenshots-section">
    <h2 style="margin-bottom: 20px; color: #2c3e50;">📸 Multi-Language Screenshots</h2>
    <div class="screenshots-grid">
      SCREENSHOTS_HTML
    </div>
  </div>
</div>
</body>
</html>
HTML_CONTENT

# Calculate success rate
SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

# Determine overall status
if [[ $FAILED_TESTS -eq 0 ]]; then
    OVERALL_STATUS="✅ ALL TESTS PASSED"
    STATUS_CLASS="status-pass"
else
    OVERALL_STATUS="❌ CHECKPOINT FAILED"
    STATUS_CLASS="status-fail"
fi

# Generate test cards HTML
TEST_CARDS_HTML=""
for i in "${!TEST_MESSAGES[@]}"; do
    test_msg="${TEST_MESSAGES[$i]}"
    test_result="${TEST_RESULTS[$i]}"
    test_name=$(echo "$test_msg" | cut -d: -f1)
    
    if [[ "$test_result" == "PASS" ]]; then
        card_class="passed"
        status_class="pass"
        status_text="✅ Passed"
    else
        card_class="failed"
        status_class="fail"
        status_text="❌ Failed"
    fi
    
    TEST_CARDS_HTML+="<div class='test-card $card_class'><div class='test-header'><div class='test-name'>$test_name</div><div class='test-status $status_class'>$status_text</div></div><div class='test-details'>Test $(($i + 1)) of $TOTAL_TESTS completed</div></div>"
done

# Generate screenshots HTML (if they exist)
SCREENSHOTS_HTML=""
if [[ -d "$PROOF_DIR/i18n" ]]; then
    for lang in fr-CH de-CH it-CH en ja ko sk es; do
        latest_screenshot=$(ls -t "$PROOF_DIR/i18n/app_${lang}_"*.png 2>/dev/null | head -1)
        if [[ -f "$latest_screenshot" ]]; then
            filename=$(basename "$latest_screenshot")
            SCREENSHOTS_HTML+="<div class='screenshot-card' onclick='window.open(\"i18n/$filename\", \"_blank\")'><img src='i18n/$filename' class='screenshot-img' alt='$lang'><div class='screenshot-label'>$lang</div></div>"
        fi
    done
fi

# Replace placeholders in HTML
sed -i '' "s|STATUS_CLASS|$STATUS_CLASS|g" "$REPORT_HTML"
sed -i '' "s|OVERALL_STATUS|$OVERALL_STATUS|g" "$REPORT_HTML"
sed -i '' "s|TIMESTAMP|$(date)|g" "$REPORT_HTML"
sed -i '' "s|TOTAL_TESTS|$TOTAL_TESTS|g" "$REPORT_HTML"
sed -i '' "s|PASSED_COUNT|$PASSED_TESTS|g" "$REPORT_HTML"
sed -i '' "s|FAILED_COUNT|$FAILED_TESTS|g" "$REPORT_HTML"
sed -i '' "s|SUCCESS_RATE|$SUCCESS_RATE|g" "$REPORT_HTML"
sed -i '' "s|TEST_CARDS_HTML|$TEST_CARDS_HTML|g" "$REPORT_HTML"
sed -i '' "s|SCREENSHOTS_HTML|$SCREENSHOTS_HTML|g" "$REPORT_HTML"

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    FINAL RESULTS                      ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Tests Run:${NC} $TOTAL_TESTS"
echo -e "${BOLD}Passed:${NC} ${GREEN}$PASSED_TESTS${NC}"
echo -e "${BOLD}Failed:${NC} ${RED}$FAILED_TESTS${NC}"
echo -e "${BOLD}Success Rate:${NC} $SUCCESS_RATE%"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║     ✅ CHECKPOINT PASSED - READY FOR SPRINT 3!        ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${BOLD}${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║     ❌ CHECKPOINT FAILED - FIX ISSUES BEFORE SPRINT 3 ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BOLD}📄 HTML Report:${NC} $REPORT_HTML"
echo ""

# Open the HTML report
open "$REPORT_HTML"

# Exit with appropriate code
if [[ $FAILED_TESTS -eq 0 ]]; then
    exit 0
else
    exit 1
fi