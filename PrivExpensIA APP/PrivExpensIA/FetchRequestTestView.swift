import SwiftUI
import CoreData

// MARK: - Test View pour vérifier @FetchRequest
struct FetchRequestTestView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Test 1: FetchRequest simple
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
        animation: .default
    )
    private var allExpenses: FetchedResults<Expense>

    // Test 2: FetchRequest avec predicate
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.amount, ascending: false)],
        predicate: NSPredicate(format: "amount > %@", NSNumber(value: 50.0)),
        animation: .default
    )
    private var largeExpenses: FetchedResults<Expense>

    // Test 3: FetchRequest par catégorie
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
        predicate: NSPredicate(format: "category == %@", "Alimentation"),
        animation: .default
    )
    private var foodExpenses: FetchedResults<Expense>

    @State private var showAddExpense = false
    @State private var testResults = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Test @FetchRequest")
                .font(.largeTitle)
                .padding()

            // Stats
            VStack(alignment: .leading, spacing: 10) {
                Text("📊 Statistiques:")
                    .font(.headline)

                Text("Total des dépenses: \(allExpenses.count)")
                Text("Dépenses > 50 CHF: \(largeExpenses.count)")
                Text("Dépenses Alimentation: \(foodExpenses.count)")
                Text("Montant total: \(totalAmount, format: .currency(code: "CHF"))")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Liste des dépenses
            List {
                Section("Toutes les dépenses") {
                    ForEach(allExpenses) { expense in
                        ExpenseRow(expense: expense)
                    }
                    .onDelete(perform: deleteExpenses)
                }
            }

            // Boutons de test
            HStack(spacing: 20) {
                Button("Ajouter Test") {
                    addTestExpense()
                }
                .buttonStyle(.borderedProminent)

                Button("Tester Temps Réel") {
                    testRealTimeUpdate()
                }
                .buttonStyle(.bordered)

                Button("Nettoyer") {
                    cleanAllExpenses()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()

            // Résultats des tests
            if !testResults.isEmpty {
                Text(testResults)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding()
            }
        }
    }

    private var totalAmount: Double {
        allExpenses.reduce(0) { $0 + $1.totalAmount }
    }

    private func addTestExpense() {
        withAnimation {
            let categories = ["Alimentation", "Transport", "Restaurant", "Divers"]
            let merchants = ["Migros", "Coop", "SBB", "Manor", "Restaurant XYZ"]

            _ = CoreDataManager.shared.createExpense(
                merchant: merchants.randomElement()!,
                amount: Double.random(in: 10...200),
                tax: Double.random(in: 1...20),
                category: categories.randomElement()!,
                items: ["Article test"]
            )

            testResults = "✅ Dépense ajoutée - Vérifiez la mise à jour automatique"
        }
    }

    private func testRealTimeUpdate() {
        // Test de mise à jour en temps réel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            _ = CoreDataManager.shared.createExpense(
                merchant: "Test Temps Réel",
                amount: 99.99,
                tax: 8.09,
                category: "Test",
                items: ["Test automatique"]
            )
            testResults = "✅ Mise à jour temps réel testée"
        }
    }

    private func deleteExpenses(offsets: IndexSet) {
        withAnimation {
            offsets.map { allExpenses[$0] }.forEach { expense in
                CoreDataManager.shared.deleteExpense(expense)
            }
            testResults = "✅ Suppression testée"
        }
    }

    private func cleanAllExpenses() {
        CoreDataManager.shared.deleteAllExpenses()
        testResults = "✅ Base de données nettoyée"
    }
}

// MARK: - Row View
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(expense.merchant ?? "Unknown")
                    .font(.headline)
                Text(expense.category ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(expense.totalAmount, format: .currency(code: "CHF"))")
                    .font(.subheadline)
                    .bold()
                Text("TVA: \(expense.taxAmount, format: .currency(code: "CHF"))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct FetchRequestTestView_Previews: PreviewProvider {
    static var previews: some View {
        FetchRequestTestView()
            .environment(\.managedObjectContext, CoreDataManager.shared.persistentContainer.viewContext)
    }
}