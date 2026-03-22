import Foundation
import SwiftUI

// MARK: - Expense Report Model
struct ExpenseReport: Identifiable, Codable {
    let id: UUID
    let title: String
    let dateRange: DateInterval
    let expenseIds: [UUID]
    let totalAmount: Double
    let createdAt: Date
    var thumbnail: Data? // Preview image for report

    init(title: String, from startDate: Date, to endDate: Date, expenses: [Expense]) {
        self.id = UUID()
        self.title = title
        self.dateRange = DateInterval(start: startDate, end: endDate)
        self.expenseIds = expenses.compactMap { $0.id }
        self.totalAmount = expenses.reduce(0) { $0 + $1.totalAmount }
        self.createdAt = Date()
        self.thumbnail = nil
    }
}

// MARK: - View Mode Enum
enum ExpenseViewMode: String, CaseIterable {
    case list = "list"
    case thumbnails = "thumbnails"

    var localizedTitle: String {
        switch self {
        case .list:
            return LocalizationManager.shared.localized("expenses.view_mode.list")
        case .thumbnails:
            return LocalizationManager.shared.localized("expenses.view_mode.thumbnails")
        }
    }

    var icon: String {
        switch self {
        case .list:
            return "list.bullet"
        case .thumbnails:
            return "square.grid.2x2"
        }
    }
}

// MARK: - Report Manager
class ReportManager: ObservableObject {
    static let shared = ReportManager()

    @Published var reports: [ExpenseReport] = []

    private init() {
        loadReports()
    }

    // MARK: - Public Methods

    func generateReport(title: String, from startDate: Date, to endDate: Date, expenses: [Expense]) -> ExpenseReport {
        let report = ExpenseReport(title: title, from: startDate, to: endDate, expenses: expenses)

        // Add to reports list
        reports.append(report)

        // Archive expenses (move them to archived state or mark them)
        archiveExpenses(expenses, in: report)

        // Save reports
        saveReports()

        return report
    }

    // Nouvelle fonction pour générer automatiquement un rapport avec toutes les dépenses ouvertes
    func generateAutomaticReport(title: String? = nil) -> ExpenseReport? {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND reportId == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]

        do {
            let openExpenses = try context.fetch(request)

            guard !openExpenses.isEmpty else {
                return nil
            }

            // Dates automatiques basées sur les dépenses
            let dates = openExpenses.compactMap { $0.date }
            let startDate = dates.min() ?? Date()
            let endDate = dates.max() ?? Date()

            // Titre automatique
            let reportTitle = title ?? "Rapport \(formatDate(Date()))"


            return generateReport(title: reportTitle, from: startDate, to: endDate, expenses: openExpenses)

        } catch {
            return nil
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func archiveExpenses(_ expenses: [Expense], in report: ExpenseReport) {
        let context = CoreDataManager.shared.persistentContainer.viewContext

        for expense in expenses {
            expense.isArchived = true
            expense.reportId = report.id
        }

        do {
            try context.save()
        } catch {
        }
    }

    func deleteReport(_ report: ExpenseReport) {
        reports.removeAll { $0.id == report.id }
        saveReports()
    }

    func getExpensesForReport(_ report: ExpenseReport) -> [Expense] {
        // Fetch expenses that have this report's ID (set during archiving)
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        // Filter by reportId which is set in archiveExpenses()
        request.predicate = NSPredicate(format: "reportId == %@", report.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]

        do {
            let expenses = try context.fetch(request)
            return expenses
        } catch {
            return []
        }
    }

    // MARK: - Private Methods

    private func saveReports() {
        if let encoded = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(encoded, forKey: "expense_reports")
        }
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: "expense_reports"),
              let decoded = try? JSONDecoder().decode([ExpenseReport].self, from: data) else {
            return
        }
        reports = decoded

        // Migration one-time: sync archive status for existing reports
        syncArchiveStatus()
    }

    /// One-time migration to fix expenses that were added to reports before the archiving fix
    private func syncArchiveStatus() {
        let migrationKey = "archive_sync_v1_done"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let context = CoreDataManager.shared.persistentContainer.viewContext
        let allExpenses = CoreDataManager.shared.fetchExpenses()

        var migrated = 0
        for report in reports {
            for expenseId in report.expenseIds {
                if let expense = allExpenses.first(where: { $0.id == expenseId }) {
                    if !expense.isArchived || expense.reportId != report.id {
                        expense.isArchived = true
                        expense.reportId = report.id
                        migrated += 1
                    }
                }
            }
        }

        if migrated > 0 {
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}

// MARK: - Helper Extensions
extension ExpenseReport {
    var formattedDateRange: String {
        let calendar = Calendar.current
        let start = dateRange.start
        let end = dateRange.end

        // Check if it's the same month
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let sameYear = calendar.isDate(start, equalTo: end, toGranularity: .year)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        let fullFormatter = DateFormatter()
        fullFormatter.dateStyle = .medium

        // If same month: "January 2026" or "13-19 January 2026"
        if sameMonth {
            let daysDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            if daysDiff <= 7 {
                // Week format: "13-19 January 2026"
                return "\(dayFormatter.string(from: start))-\(dayFormatter.string(from: end)) \(monthFormatter.string(from: start))"
            } else {
                // Full month or partial: "January 2026"
                return monthFormatter.string(from: start)
            }
        } else if sameYear {
            // Different months same year: "Jan - Feb 2026"
            let shortMonthFormatter = DateFormatter()
            shortMonthFormatter.dateFormat = "MMM"
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            return "\(shortMonthFormatter.string(from: start)) - \(shortMonthFormatter.string(from: end)) \(yearFormatter.string(from: end))"
        } else {
            // Different years: full format
            return "\(fullFormatter.string(from: start)) - \(fullFormatter.string(from: end))"
        }
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "CHF"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "CHF 0"
    }
}