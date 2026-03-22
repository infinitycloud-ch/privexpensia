import SwiftUI

// MARK: - Report Detail View
struct ReportDetailView: View {
    let report: ExpenseReport
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportManager = ReportManager.shared

    @State private var reportExpenses: [Expense] = []
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header with report info
                        headerSection

                        // Stats section
                        statsSection

                        // Expenses in report
                        expensesSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadReportExpenses()
            }
        }
        .alert("Delete Report", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteReport()
            }
        } message: {
            Text("This will permanently delete the report. Expenses will remain in your main list.")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }

                Spacer()

                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(LiquidGlassTheme.Colors.error)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)

                    Text(report.title)
                        .font(LiquidGlassTheme.Typography.title1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(report.formattedDateRange)
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                    Text("Created: \(formatDate(report.createdAt))")
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                }
                .padding(24)
            }
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Text("Report Summary")
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("\(reportExpenses.count)")
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                            .fontWeight(.bold)

                        Text("Expenses")
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }

                    VStack(spacing: 8) {
                        Text(report.formattedTotal)
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(LiquidGlassTheme.Colors.primary)
                            .fontWeight(.bold)

                        Text("Total Amount")
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }

                    VStack(spacing: 8) {
                        let avgAmount = reportExpenses.isEmpty ? 0 : report.totalAmount / Double(reportExpenses.count)

                        Text(CurrencyManager.shared.formatAmount(avgAmount))
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(LiquidGlassTheme.Colors.secondary)
                            .fontWeight(.bold)

                        Text(LocalizationManager.shared.localized("statistics.average"))
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Expenses Section
    private var expensesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Expenses in Report")
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                if reportExpenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(LiquidGlassTheme.Colors.textTertiary)

                        Text("No expenses found for this report")
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(reportExpenses, id: \.self) { expense in
                            ExpenseCardGlass(expense: expense) {
                                // Could navigate to expense detail if needed
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helper Methods
    private func loadReportExpenses() {
        reportExpenses = reportManager.getExpensesForReport(report)
    }

    private func deleteReport() {
        reportManager.deleteReport(report)
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    let sampleReport = ExpenseReport(
        title: "October 2024 Report",
        from: Date(),
        to: Date(),
        expenses: []
    )

    return ReportDetailView(report: sampleReport)
}