# Documentation CoreData - PrivExpensIA

## 📊 Vue d'ensemble

L'implémentation CoreData pour PrivExpensIA fournit une persistance robuste des données de dépenses, avec synchronisation temps réel et intégration complète avec l'extraction IA.

## 🏗️ Architecture

### Composants principaux

1. **CoreDataManager** (`CoreDataManager.swift`)
   - Singleton gérant toute la persistance
   - NSPersistentContainer pour la stack CoreData
   - Méthodes CRUD complètes pour les dépenses

2. **Entité Expense** (`PrivExpensIA.xcdatamodeld`)
   - Modèle de données complet pour les dépenses
   - Propriétés: id, merchant, amount, tax, category, date, items, paymentMethod, notes

3. **Classes CoreData**
   - `Expense+CoreDataClass.swift` - Classe managée
   - `Expense+CoreDataProperties.swift` - Propriétés @NSManaged

## 🔄 Flux de données

```
Scanner/Photo → OCR → IA Extraction → CoreDataManager → CoreData → @FetchRequest → UI
```

### Pipeline détaillé

1. **Capture**: L'utilisateur scanne ou sélectionne un reçu
2. **OCR**: Extraction du texte via Vision framework
3. **IA**: AIExtractionService analyse et structure les données
4. **Sauvegarde**: CoreDataManager.saveOCRResult() persiste les données
5. **UI**: @FetchRequest met à jour automatiquement la liste

## 📝 API CoreDataManager

### Création de dépense
```swift
func createExpense(
    merchant: String,
    amount: Double,
    tax: Double,
    category: String,
    date: Date = Date(),
    items: [String] = [],
    paymentMethod: String = "Card",
    notes: String = ""
) -> Expense
```

### Sauvegarde depuis OCR
```swift
func saveOCRResult(extractedData: Any, image: UIImage?)
```
- Accepte ExtractedData ou String
- Parse automatique via ExpenseParser
- Création d'entité Expense persistée

### Récupération des dépenses
```swift
func fetchExpenses() -> [Expense]  // Toutes les dépenses
func fetchRecentExpenses(limit: Int) -> [Expense]  // Limitées
```

### Suppression
```swift
func deleteExpense(_ expense: Expense)
func deleteAllExpenses()
```

## 🎯 Intégration SwiftUI

### @FetchRequest dans les vues
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
    animation: .default
)
private var expenses: FetchedResults<Expense>
```

### Passage du contexte
```swift
// Dans PrivExpensIAApp
.environment(\.managedObjectContext, persistenceController.persistentContainer.viewContext)
```

## ✅ Tests

### Tests unitaires (`CoreDataTests.swift`)
- Création de dépense
- Lecture et filtrage
- Suppression
- Persistance après save
- Sauvegarde OCR
- Performance en masse

### Tests UI (`FetchRequestTestView.swift`)
- Mise à jour temps réel
- Tri et filtrage
- Suppression interactive
- Statistiques dynamiques

## 🚀 Optimisations

1. **Batch operations**: NSBatchDeleteRequest pour suppression en masse
2. **Lazy loading**: @FetchRequest charge à la demande
3. **Animations**: Transitions fluides avec SwiftUI
4. **Notifications**: Post pour synchronisation UI

## 🔒 Sécurité et fiabilité

- Singleton pattern pour éviter les conflits
- Gestion d'erreurs complète
- Validation des données avant sauvegarde
- Migration automatique des données de test

## 📊 Modèle de données

### Expense Entity
| Attribut | Type | Description |
|----------|------|-------------|
| id | UUID | Identifiant unique |
| merchant | String | Nom du marchand |
| amount | Double | Montant total |
| tax | Double | Montant TVA |
| category | String | Catégorie de dépense |
| date | Date | Date de la dépense |
| items | Transformable | Liste des articles |
| paymentMethod | String? | Méthode de paiement |
| notes | String? | Notes additionnelles |

## 🔄 Migration et compatibilité

- Support ExpenseData struct pour compatibilité
- Migration automatique des données test au premier lancement
- Conversion bidirectionnelle Expense ↔ ExpenseData

## 📈 Performance

- Tests de performance: 100 créations < 0.1s
- FetchRequest optimisé avec predicates
- Tri et filtrage côté base de données

## 🎨 Bonnes pratiques

1. Toujours utiliser CoreDataManager.shared
2. @FetchRequest pour UI réactive
3. saveContext() après modifications groupées
4. Gestion erreurs avec do-catch
5. Tests isolés avec tearDown cleanup

## 🐛 Troubleshooting

### Données non persistées
- Vérifier saveContext() appelé
- Confirmer managedObjectContext passé aux vues

### @FetchRequest non mis à jour
- Vérifier environment injection
- Confirmer animation: .default

### Erreurs de migration
- Supprimer app et réinstaller
- Nettoyer dérivés Xcode

## 📚 Références

- [Apple Core Data Documentation](https://developer.apple.com/documentation/coredata)
- [SwiftUI @FetchRequest](https://developer.apple.com/documentation/swiftui/fetchrequest)
- [NSPersistentContainer](https://developer.apple.com/documentation/coredata/nspersistentcontainer)