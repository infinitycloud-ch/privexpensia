import SwiftUI
import Foundation
import Combine

// MARK: - Budget Manager - Jony Ive Minimalist Approach
// "Simplicity is the ultimate sophistication" - Leonardo da Vinci

class BudgetManager: ObservableObject {
    @Published var monthlyBudget: Double = 0
    @Published var currentSpending: Double = 0
    @Published var budgetType: BudgetType = .monthly
    @Published var budgetCategories: [BudgetCategory] = []

    private let userDefaults = UserDefaults.standard
    private let coreDataManager = CoreDataManager.shared

    enum BudgetType: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"

        var localizedTitle: String {
            switch self {
            case .daily: return LocalizationManager.shared.localized("budget.type.daily")
            case .weekly: return LocalizationManager.shared.localized("budget.type.weekly")
            case .monthly: return LocalizationManager.shared.localized("budget.type.monthly")
            case .yearly: return LocalizationManager.shared.localized("budget.type.yearly")
            }
        }
    }

    struct BudgetCategory {
        let id = UUID()
        let name: String
        let allocated: Double
        let spent: Double
        let icon: String
        let color: Color

        var remaining: Double { allocated - spent }
        var percentage: Double { spent / allocated }
        var isOverBudget: Bool { spent > allocated }
    }

    init() {
        loadBudgetSettings()
        calculateCurrentSpending()
    }

    // MARK: - Pure Functions - No Side Effects

    var budgetRemaining: Double {
        monthlyBudget - currentSpending
    }

    var budgetPercentage: Double {
        guard monthlyBudget > 0 else { return 0 }
        return (currentSpending / monthlyBudget) * 100
    }

    var budgetStatus: BudgetStatus {
        let percentage = budgetPercentage
        switch percentage {
        case 0..<50: return .excellent
        case 50..<80: return .good
        case 80..<100: return .warning
        default: return .danger
        }
    }

    var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let today = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
        return calendar.dateComponents([.day], from: today, to: endOfMonth).day ?? 0
    }

    var dailyBudgetRemaining: Double {
        guard daysLeftInMonth > 0 else { return 0 }
        return budgetRemaining / Double(daysLeftInMonth)
    }

    enum BudgetStatus {
        case excellent, good, warning, danger

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .warning: return .orange
            case .danger: return .red
            }
        }

        var message: String {
            switch self {
            case .excellent: return LocalizationManager.shared.localized("budget.status.excellent")
            case .good: return LocalizationManager.shared.localized("budget.status.good")
            case .warning: return LocalizationManager.shared.localized("budget.status.warning")
            case .danger: return LocalizationManager.shared.localized("budget.status.danger")
            }
        }
    }

    // MARK: - Actions - Minimal Interface

    func setBudget(_ amount: Double) {
        monthlyBudget = amount
        saveBudgetSettings()
        objectWillChange.send()
    }

    func adjustBudget(by amount: Double) {
        monthlyBudget = max(0, monthlyBudget + amount)
        saveBudgetSettings()
        objectWillChange.send()
    }

    func resetBudget() {
        monthlyBudget = 0
        currentSpending = 0
        saveBudgetSettings()
        objectWillChange.send()
    }

    // MARK: - Private Implementation

    private func loadBudgetSettings() {
        monthlyBudget = userDefaults.double(forKey: "monthlyBudget")
        if let typeString = userDefaults.string(forKey: "budgetType") {
            budgetType = BudgetType(rawValue: typeString) ?? .monthly
        }
    }

    private func saveBudgetSettings() {
        userDefaults.set(monthlyBudget, forKey: "monthlyBudget")
        userDefaults.set(budgetType.rawValue, forKey: "budgetType")
    }

    private func calculateCurrentSpending() {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()

        currentSpending = coreDataManager.getTotalSpending(
            from: startOfMonth,
            to: Date()
        )
    }

    // MARK: - Smart Insights - AI-Driven Recommendations

    var smartInsight: String? {
        let percentage = budgetPercentage
        let daysIntoMonth = Calendar.current.component(.day, from: Date())
        let expectedPercentage = Double(daysIntoMonth) / 30.0 * 100

        if percentage > expectedPercentage + 20 {
            return LocalizationManager.shared.localized("budget.insight.spending_fast")
        } else if percentage < expectedPercentage - 20 {
            return LocalizationManager.shared.localized("budget.insight.great_savings")
        } else if dailyBudgetRemaining < 10 {
            return LocalizationManager.shared.localized("budget.insight.low_daily")
        }

        return nil
    }

    var projectedMonthEnd: Double {
        let daysIntoMonth = Calendar.current.component(.day, from: Date())
        guard daysIntoMonth > 0 else { return currentSpending }

        let dailyAverage = currentSpending / Double(daysIntoMonth)
        return dailyAverage * 30
    }
}

// MARK: - Budget Quick Setup Modal - Jony Ive Aesthetic

struct BudgetSetupModal: View {
    @ObservedObject var budgetManager: BudgetManager
    @State private var budgetAmount: String = ""
    @State private var selectedPreset: Double? = nil
    @Binding var isPresented: Bool

    private let presetAmounts: [Double] = [500, 1000, 1500, 2000, 2500, 3000]

    var body: some View {
        ZStack {
            // Pure black background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Minimalist header
                VStack(spacing: 8) {
                    Text(LocalizationManager.shared.localized("budget.setup.title"))
                        .font(.system(size: 28, weight: .light, design: .default))
                        .foregroundColor(.white)

                    Text(LocalizationManager.shared.localized("budget.setup.subtitle"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Amount input - Ultra clean
                VStack(spacing: 20) {
                    HStack {
                        Text(CurrencyManager.shared.symbol)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.5))

                        TextField("0", text: $budgetAmount)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                    }

                    // Subtle line
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Preset amounts - Grid of circles
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        Button(action: {
                            selectedPreset = amount
                            budgetAmount = String(Int(amount))
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(selectedPreset == amount ? Color.white : Color.clear)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text(CurrencyManager.shared.formatAmount(amount, showSymbol: true))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedPreset == amount ? .black : .white)
                                    )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Actions - Minimal
                VStack(spacing: 16) {
                    Button(action: saveBudget) {
                        Text(LocalizationManager.shared.localized("budget.setup.set_button"))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 27))
                    }
                    .disabled(budgetAmount.isEmpty)
                    .opacity(budgetAmount.isEmpty ? 0.5 : 1)

                    Button(action: { isPresented = false }) {
                        Text(LocalizationManager.shared.localized("button.cancel"))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if budgetManager.monthlyBudget > 0 {
                budgetAmount = String(Int(budgetManager.monthlyBudget))
            }
        }
    }

    private func saveBudget() {
        guard let amount = Double(budgetAmount), amount > 0 else { return }
        budgetManager.setBudget(amount)
        isPresented = false
    }
}