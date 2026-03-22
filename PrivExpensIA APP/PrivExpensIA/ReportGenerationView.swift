import SwiftUI

// MARK: - Report Generation View (Automatic - All buffer expenses)
struct ReportGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportManager = ReportManager.shared

    @State private var isLoading = false
    @State private var bufferExpenses: [Expense] = []

    // Computed properties for auto-generated values
    private var reportTitle: String {
        guard !bufferExpenses.isEmpty else { return "-" }
        let dates = bufferExpenses.compactMap { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return "-" }
        return formatDateRange(from: minDate, to: maxDate)
    }

    private var dateRangeText: String {
        guard !bufferExpenses.isEmpty else { return "-" }
        let dates = bufferExpenses.compactMap { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return "-" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: minDate)) → \(formatter.string(from: maxDate))"
    }

    private var totalAmount: Double {
        bufferExpenses.reduce(0) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Summary card
                    summarySection

                    // Expenses preview
                    expensesPreviewSection

                    Spacer()

                    // Generate button
                    generateButtonSection
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchAllBufferExpenses()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text(LocalizationManager.shared.localized("button.cancel"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3))
                    )
            }

            Spacer()

            Text(LocalizationManager.shared.localized("expenses.reports.generate"))
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 80, height: 28)
        }
        .padding(.top, 20)
    }

    // MARK: - Summary Section
    private var summarySection: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Report icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)

                // Auto-generated title
                Text(reportTitle)
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Date range
                Text(dateRangeText)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                Divider()
                    .background(LiquidGlassTheme.Colors.textTertiary.opacity(0.3))

                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(bufferExpenses.count)")
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                            .fontWeight(.bold)
                        Text(LocalizationManager.shared.localized("expenses_title"))
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }

                    VStack(spacing: 4) {
                        Text(CurrencyManager.shared.formatAmount(totalAmount))
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(LiquidGlassTheme.Colors.primary)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Expenses Preview Section
    private var expensesPreviewSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizationManager.shared.localized("expenses.reports.included"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                if bufferExpenses.isEmpty {
                    Text(LocalizationManager.shared.localized("expenses_empty_title"))
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(bufferExpenses.prefix(5), id: \.self) { expense in
                            HStack {
                                Text(expense.merchant ?? "?")
                                    .font(LiquidGlassTheme.Typography.body)
                                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(CurrencyManager.shared.formatAmount(expense.totalAmount))
                                    .font(LiquidGlassTheme.Typography.body)
                                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                            }
                        }

                        if bufferExpenses.count > 5 {
                            Text("+ \(bufferExpenses.count - 5) autres...")
                                .font(LiquidGlassTheme.Typography.caption1)
                                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Generate Button Section
    private var generateButtonSection: some View {
        Button(action: generateReport) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                }

                Text(isLoading
                    ? LocalizationManager.shared.localized("expenses.reports.generating")
                    : LocalizationManager.shared.localized("expenses.reports.confirm"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: bufferExpenses.isEmpty
                        ? [Color.gray, Color.gray.opacity(0.8)]
                        : [LiquidGlassTheme.Colors.accent, LiquidGlassTheme.Colors.accent.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(
                color: bufferExpenses.isEmpty ? .clear : LiquidGlassTheme.Colors.accent.opacity(0.3),
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(bufferExpenses.isEmpty || isLoading)
    }

    // MARK: - Helper Methods

    private func fetchAllBufferExpenses() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]

        do {
            bufferExpenses = try context.fetch(request)
        } catch {
            bufferExpenses = []
        }
    }

    private func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        let sameDay = calendar.isDate(startDate, inSameDayAs: endDate)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if sameDay {
            return formatter.string(from: startDate)
        }

        let sameMonth = calendar.isDate(startDate, equalTo: endDate, toGranularity: .month)
        let sameYear = calendar.isDate(startDate, equalTo: endDate, toGranularity: .year)

        if sameMonth {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d"
            let monthYearFormatter = DateFormatter()
            monthYearFormatter.dateFormat = "MMMM yyyy"
            return "\(dayFormatter.string(from: startDate)) - \(dayFormatter.string(from: endDate)) \(monthYearFormatter.string(from: endDate))"
        } else if sameYear {
            let dayMonthFormatter = DateFormatter()
            dayMonthFormatter.dateFormat = "d MMM"
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            return "\(dayMonthFormatter.string(from: startDate)) - \(dayMonthFormatter.string(from: endDate)) \(yearFormatter.string(from: endDate))"
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    private func generateReport() {
        guard !bufferExpenses.isEmpty else { return }

        isLoading = true
        LiquidGlassTheme.Haptics.medium()

        // Get date range from expenses
        let dates = bufferExpenses.compactMap { $0.date }
        let startDate = dates.min() ?? Date()
        let endDate = dates.max() ?? Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Generate report with all buffer expenses
            _ = reportManager.generateReport(
                title: reportTitle,
                from: startDate,
                to: endDate,
                expenses: bufferExpenses
            )

            isLoading = false
            LiquidGlassTheme.Haptics.success()

            // Dismiss
            dismiss()
        }
    }
}