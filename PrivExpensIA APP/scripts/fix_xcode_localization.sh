#!/usr/bin/env bash
# 🔧 Fix Xcode Localization Bundle Resources
# Corrige le problème des fichiers .lproj non inclus dans le bundle

set -euo pipefail

PROJECT_DIR="~/moulinsart/PrivExpensIA"
PROJECT_FILE="$PROJECT_DIR/PrivExpensIA.xcodeproj/project.pbxproj"
BACKUP_FILE="$PROJECT_FILE.backup_$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔧 Fixing Xcode Localization Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create backup
echo "📦 Creating backup..."
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "✅ Backup saved to: $BACKUP_FILE"

# Step 1: Remove the incorrect localization reference
echo ""
echo "🗑️ Removing incorrect '(localization).lproj' reference..."

# Use Ruby to properly modify the Xcode project
ruby << 'RUBY_SCRIPT'
require 'xcodeproj'
require 'pathname'

project_path = "~/moulinsart/PrivExpensIA/PrivExpensIA.xcodeproj"
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == "PrivExpensIA" }
if target.nil?
  puts "❌ Could not find PrivExpensIA target"
  exit 1
end

# Remove any existing Localizable.strings from resources
resources_phase = target.resources_build_phase
resources_phase.files.delete_if do |file|
  if file.file_ref
    file.file_ref.path&.include?("Localizable.strings") || 
    file.file_ref.path&.include?("localization")
  end
end

# Find or create the localization group
main_group = project.main_group
app_group = main_group.groups.find { |g| g.name == "PrivExpensIA" } || main_group

# Remove old localization references
app_group.children.delete_if do |child|
  child.path&.include?("Localizable.strings") || 
  child.path&.include?(".lproj")
end

# Create proper localization variant group
strings_group = app_group.new_variant_group("Localizable.strings")

# Language codes and their lproj directories
languages = {
  "Base" => "Base.lproj",
  "en" => "en.lproj",
  "fr-CH" => "fr-CH.lproj",
  "de-CH" => "de-CH.lproj",
  "it-CH" => "it-CH.lproj",
  "de" => "de.lproj",
  "it" => "it.lproj",
  "ja" => "ja.lproj",
  "ko" => "ko.lproj",
  "sk" => "sk.lproj",
  "es" => "es.lproj"
}

# Add each localization
languages.each do |lang_name, lproj_dir|
  file_path = "#{lproj_dir}/Localizable.strings"
  full_path = "~/moulinsart/PrivExpensIA/PrivExpensIA/#{file_path}"
  
  if File.exist?(full_path)
    ref = strings_group.new_reference(file_path)
    ref.name = lang_name
    puts "✅ Added #{lang_name}: #{file_path}"
  else
    puts "⚠️ File not found: #{full_path}"
  end
end

# Add the variant group to resources build phase
resources_phase.add_file_reference(strings_group)
puts "✅ Added Localizable.strings to Copy Bundle Resources"

# Save the project
project.save
puts "✅ Project saved successfully"

RUBY_SCRIPT

if [ $? -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✅ SUCCESS!${NC} Xcode project fixed."
  echo ""
  echo "📝 Next steps:"
  echo "1. Clean build folder: Cmd+Shift+K"
  echo "2. Build project: Cmd+B"
  echo "3. Run on simulator: Cmd+R"
  echo ""
  echo "🔍 To verify in Xcode:"
  echo "1. Open PrivExpensIA.xcodeproj"
  echo "2. Select PrivExpensIA target"
  echo "3. Go to Build Phases → Copy Bundle Resources"
  echo "4. You should see 'Localizable.strings' with multiple languages"
else
  echo -e "${RED}❌ FAILED${NC} to fix project"
  echo "Restoring backup..."
  mv "$BACKUP_FILE" "$PROJECT_FILE"
  exit 1
fi

# Test that localizations will be found
echo ""
echo "🧪 Testing localization setup..."

# Check if files exist
MISSING=0
for lang in Base en fr-CH de-CH it-CH ja ko sk es; do
  FILE="$PROJECT_DIR/PrivExpensIA/${lang}.lproj/Localizable.strings"
  if [ -f "$FILE" ]; then
    echo "  ✅ ${lang}.lproj/Localizable.strings exists"
  else
    echo "  ❌ ${lang}.lproj/Localizable.strings MISSING"
    MISSING=$((MISSING + 1))
  fi
done

if [ $MISSING -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}⚠️ WARNING:${NC} $MISSING localization files are missing"
  echo "The project is fixed but some translations may not work"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Done! Now rebuild the app in Xcode."