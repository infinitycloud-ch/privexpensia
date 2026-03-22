# 🌍 PrivExpensIA - Localization Guide

## Adding a New Language

### 1. Create Language Directory
```bash
# Create new .lproj directory
mkdir -p resources/i18n/[language-code].lproj
# Example: resources/i18n/pt-BR.lproj for Brazilian Portuguese
```

### 2. Create Localizable.strings
Copy template from existing language and translate all keys:
```bash
cp resources/i18n/en.lproj/Localizable.strings \
   resources/i18n/[new-language].lproj/Localizable.strings
```

### 3. Required Translation Keys (125 minimum)

#### Navigation & Menus (6 keys)
- `app.title`
- `menu.home`, `menu.expenses`, `menu.reports`, `menu.settings`, `menu.logout`

#### Actions (16 keys)
- `action.add`, `action.edit`, `action.delete`, `action.save`
- `action.cancel`, `action.submit`, `action.approve`, `action.reject`
- Plus 8 more action keys...

#### Expense Form (14 keys)
- `expense.title`, `expense.amount`, `expense.date`
- `expense.category`, `expense.merchant`, `expense.description`
- Plus VAT and currency related keys...

#### Categories (17 keys)
- All expense categories from `category.food` to `category.other`

#### Status Messages (6 keys)
- From `status.draft` to `status.processing`

### 4. Update Supporting Files

#### CategoryTemplates.json
Add translations for each category:
```json
"translations": {
  "fr-CH": "Alimentation",
  "en": "Food",
  "[new-language]": "[Translation]"
}
```

#### FAQ_Multilingual.json
Add new language to questions and answers:
```json
"question": {
  "fr-CH": "Question en français",
  "en": "Question in English",
  "[new-language]": "[Translated question]"
}
```

#### UserGuide_Multilingual.md
Add new section with translated guide:
```markdown
## 🇧🇷 Português Brasileiro
### Começando
1. **Escanear Recibo**: ...
```

### 5. Date & Currency Formatting

#### Date Formats by Region
- **European**: `dd.MM.yyyy` or `dd/MM/yyyy`
- **American**: `MM/dd/yyyy`
- **Asian**: `yyyy年MM月dd日` (Japanese), `yyyy-MM-dd` (Korean)

#### Currency Symbol Position
```swift
// Before amount
"format.currency.usd" = "$ %@";
// After amount
"format.currency.eur" = "%@ €";
```

### 6. Testing Checklist

- [ ] All 125+ keys translated
- [ ] No missing translations (grep for English text)
- [ ] Date format appropriate for region
- [ ] Currency format correct
- [ ] Numbers use correct decimal separator (. vs ,)
- [ ] Text direction (LTR vs RTL for Arabic/Hebrew)
- [ ] Special characters display correctly
- [ ] UI doesn't break with longer translations

### 7. Validation Script

Create a validation script to check completeness:
```bash
#!/bin/bash
# Check if all keys are present
REFERENCE="en.lproj/Localizable.strings"
NEW_LANG="[new-language].lproj/Localizable.strings"

for key in $(grep '^"' $REFERENCE | cut -d'"' -f2); do
  if ! grep -q "\"$key\"" $NEW_LANG; then
    echo "Missing key: $key"
  fi
done
```

### 8. Regional Considerations

#### Switzerland (CH)
- 4 official languages: German, French, Italian, Romansh
- Use formal address (Sie/Vous)
- Currency: CHF

#### Germany/Austria (DE/AT)
- Formal vs informal (Sie vs Du)
- Different terms in Austria vs Germany
- Currency: EUR

#### Japan (JP)
- Honorifics and politeness levels
- Full-width vs half-width characters
- Currency: ¥ (JPY)

#### Right-to-Left Languages
For Arabic, Hebrew, Persian:
- Mirror UI layout
- Align text right
- Reverse navigation direction

### 9. Common Translation Issues

#### Text Expansion
- German: ~30% longer than English
- Russian: ~20% longer
- Japanese/Chinese: Can be shorter

#### Avoid These Mistakes
- ❌ Machine translation without review
- ❌ Direct word-for-word translation
- ❌ Ignoring cultural context
- ❌ Using same translation for different contexts

### 10. Resources

#### Translation Services
- Professional: Native speakers with app localization experience
- Tools: Crowdin, Lokalise, POEditor

#### Style Guides
- [Apple Localization Guide](https://developer.apple.com/localization/)
- [Google Material Design i18n](https://material.io/design/usability/bidirectionality.html)

#### Testing Tools
- iOS Simulator with different languages
- Pseudo-localization for UI testing
- Screenshot testing for all languages

## File Structure Summary

```
resources/
├── i18n/
│   ├── en.lproj/Localizable.strings (Reference)
│   ├── fr-CH.lproj/Localizable.strings
│   ├── de-CH.lproj/Localizable.strings
│   └── [new-language].lproj/Localizable.strings
├── CategoryTemplates.json
├── FAQ_Multilingual.json
├── UserGuide_Multilingual.md
├── TVAConfig.json
└── ReceiptExamples.json
```

## Maintenance

- Review translations with each app update
- Keep English as reference language
- Document any context-specific translations
- Version control all language files
- Regular testing with native speakers

---

**Last Updated**: January 11, 2025
**Version**: 1.0.0