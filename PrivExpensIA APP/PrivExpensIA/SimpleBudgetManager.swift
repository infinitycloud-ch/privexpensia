import Foundation
import SwiftUI

// MARK: - Simple Budget Manager for Reports
class SimpleBudgetManager: ObservableObject {
    static let shared = SimpleBudgetManager()

    @Published var monthlyBudget: Double = 1000.0
    @Published var currentSpending: Double = 0.0

    private init() {
        loadBudget()
    }

    var remainingBudget: Double {
        return monthlyBudget - currentSpending
    }

    var budgetUsagePercentage: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(currentSpending / monthlyBudget, 1.0)
    }

    func updateSpending(with expenses: [Expense]) {
        currentSpending = expenses.reduce(0) { $0 + $1.totalAmount }
    }

    func setBudget(_ amount: Double) {
        monthlyBudget = amount
        saveBudget()
    }

    private func loadBudget() {
        monthlyBudget = UserDefaults.standard.double(forKey: "monthly_budget")
        if monthlyBudget == 0 {
            monthlyBudget = 1000.0 // Default budget
        }
    }

    private func saveBudget() {
        UserDefaults.standard.set(monthlyBudget, forKey: "monthly_budget")
    }
}