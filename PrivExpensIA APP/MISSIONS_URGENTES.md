# MISSIONS URGENTES - OPÉRATION "POLI DE VERRE"
Date: 14 Septembre 2025, 02:40 - MISE À JOUR
De: NESTOR
Priorité: CRITIQUE

## 🔴 TÂCHE 1: CORRECTION LOCALISATION (DUPONT1)
**Mission:** Corriger TOUTES les chaînes non traduites

### Problèmes identifiés:
- ✅ CORRIGÉ: "Bonjour"/"Good Morning" fonctionne
- ❌ À CORRIGER: "Budget restant" reste partiellement en français
- ❌ À CORRIGER: Labels des stats cards
- ❌ À CORRIGER: Certains boutons dans Settings

### Actions immédiates:
1. Vérifier que TOUTES les vues utilisent `LocalizationManager.shared.localized()`
2. NE PAS utiliser `String(localized:)` - remplacer partout
3. Forcer le refresh des vues avec `objectWillChange.send()`
4. Tester le changement de langue EN TEMPS RÉEL dans Settings

### Fichiers à corriger:
- HomeGlassView.swift - StatCards
- SettingsGlassView.swift - Tous les labels
- ExpenseListGlassView.swift - Titres et boutons
- StatsGlassView.swift - Labels des graphiques

## 🟡 TÂCHE 2: VALIDATION RENFORCÉE (TINTIN)
**Mission:** Créer une garde automatique anti-échec

### Script de validation avec OCR:
```bash
#!/bin/bash
# Ajouter dans auto_localization_test.sh

check_for_keys() {
    local image=$1
    # Utiliser tesseract pour extraire le texte
    tesseract "$image" - 2>/dev/null | grep -E "(home\.|settings\.|\.title|\.label)" && {
        echo "❌ ÉCHEC: Clés de localisation détectées!"
        return 1
    }
    return 0
}
```

### Rapport amélioré:
- Marquer en ROUGE les screenshots avec des clés
- Lister TOUTES les chaînes non traduites trouvées
- Bloquer si une seule clé est détectée

## 🟢 TÂCHE 3: VUE DÉTAIL (DUPONT2)
**Mission:** Créer ExpenseDetailGlassView

### Fonctionnalités requises:
1. Afficher TOUTES les infos de l'Expense
2. **CRITIQUE:** Afficher l'image du reçu depuis `receiptImageData`
3. Permettre l'édition des champs
4. Sauvegarder dans CoreData

### Structure:
```swift
struct ExpenseDetailGlassView: View {
    @ObservedObject var expense: Expense
    @State private var isEditing = false

    // Afficher l'image:
    if let imageData = expense.receiptImageData,
       let uiImage = UIImage(data: imageData) {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
    }
}
```

## 📊 STATUT ACTUEL
- Localisation: 60% fonctionnelle
- Validation: Scripts créés, OCR à intégrer
- Vue détail: À développer

## ⏰ DEADLINE
L'Oracle attend des résultats IMMÉDIATS. Pas de repos tant que ce n'est pas parfait.

---
NESTOR - Chef d'orchestre