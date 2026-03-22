import Foundation
import CoreData

// MARK: - Test de Persistance CoreData
class CoreDataPersistenceTest {

    static func runTest() {
        print("\n=== 🧪 TEST DE PERSISTANCE COREDATA ===\n")

        let manager = CoreDataManager.shared

        // 1. Nettoyer les données existantes
        print("1️⃣ Nettoyage des données existantes...")
        manager.deleteAllExpenses()

        // 2. Créer des données de test
        print("2️⃣ Création de 3 dépenses de test...")

        let expense1 = manager.createExpense(
            merchant: "TEST_Migros_\(Date().timeIntervalSince1970)",
            amount: 123.45,
            tax: 10.00,
            category: "Alimentation",
            items: ["Pain", "Lait", "Fromage"]
        )
        print("   ✅ Créé: \(expense1.merchant ?? "") - CHF \(expense1.amount)")

        let expense2 = manager.createExpense(
            merchant: "TEST_SBB_\(Date().timeIntervalSince1970)",
            amount: 68.00,
            tax: 5.50,
            category: "Transport",
            items: ["Billet Genève-Zurich"]
        )
        print("   ✅ Créé: \(expense2.merchant ?? "") - CHF \(expense2.amount)")

        let expense3 = manager.createExpense(
            merchant: "TEST_Coop_\(Date().timeIntervalSince1970)",
            amount: 45.90,
            tax: 3.71,
            category: "Alimentation",
            items: ["Fruits", "Légumes"]
        )
        print("   ✅ Créé: \(expense3.merchant ?? "") - CHF \(expense3.amount)")

        // 3. Forcer la sauvegarde
        print("3️⃣ Sauvegarde du contexte...")
        manager.saveContext()

        // 4. Vérifier la lecture
        print("4️⃣ Lecture des données...")
        let expenses = manager.fetchExpenses()
        print("   📊 Nombre de dépenses trouvées: \(expenses.count)")

        // 5. Afficher les IDs pour vérification ultérieure
        print("5️⃣ IDs des dépenses (pour vérification après redémarrage):")
        for expense in expenses {
            if let merchant = expense.merchant, merchant.hasPrefix("TEST_") {
                print("   - ID: \(expense.id?.uuidString ?? "nil") | \(merchant)")
            }
        }

        print("\n✅ TEST TERMINÉ - Redémarrez l'app pour vérifier la persistance!")
        print("===========================================\n")

        // Retourner un résumé
        let testExpenses = expenses.filter { $0.merchant?.hasPrefix("TEST_") ?? false }
        if !testExpenses.isEmpty {
            print("🎯 VALIDATION: \(testExpenses.count) dépenses TEST trouvées")
            print("   Si ce nombre reste identique après redémarrage = SUCCÈS!")
        }
    }

    static func verifyPersistence() {
        print("\n=== 🔍 VÉRIFICATION PERSISTANCE ===\n")

        let manager = CoreDataManager.shared
        let expenses = manager.fetchExpenses()

        let testExpenses = expenses.filter { $0.merchant?.hasPrefix("TEST_") ?? false }

        if testExpenses.isEmpty {
            print("❌ AUCUNE dépense TEST trouvée - La persistance ne fonctionne pas!")
        } else {
            print("✅ SUCCÈS! \(testExpenses.count) dépenses TEST persistées:")
            for expense in testExpenses {
                print("   - \(expense.merchant ?? "") | CHF \(expense.amount)")
            }
        }

        print("\n=================================\n")
    }
}