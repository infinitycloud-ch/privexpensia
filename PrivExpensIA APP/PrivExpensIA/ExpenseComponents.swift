import SwiftUI

// MARK: - Expense Thumbnail Card
struct ExpenseThumbnailCard: View {
    let expense: Expense
    let onTap: () -> Void

    @EnvironmentObject var currencyManager: CurrencyManager
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Receipt image or placeholder
                ZStack {
                    if let imageData = expense.receiptImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 100)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LiquidGlassTheme.Colors.glassLight)
                            .frame(width: 120, height: 100)
                            .overlay(
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                            )
                    }
                }

                // Info section
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.merchant ?? "Unknown")
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(currencyManager.formatAmount(expense.totalAmount))
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .fontWeight(.medium)

                    Text(formatDate(expense.date ?? Date()))
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
                .padding(8)
                .frame(width: 120, alignment: .leading)
            }
            .frame(width: 120, height: 160)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            LiquidGlassBackground(
                cornerRadius: 12,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.8
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(AnimationManager.Gestures.tapFeedback) {
                                isPressed = pressing
                                if pressing {
                                    LiquidGlassTheme.Haptics.light()
                                }
                            }
                          },
                          perform: {})
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

// MARK: - Report Thumbnail
struct ReportThumbnail: View {
    let report: ExpenseReport
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Report icon and stats
                VStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)

                    Text(report.formattedTotal)
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .fontWeight(.semibold)

                    Text("\(report.expenseIds.count) items")
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }

                // Report title and date
                VStack(spacing: 2) {
                    Text(report.title)
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(formatDateRange(report.dateRange))
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(width: 100, height: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            LiquidGlassBackground(
                cornerRadius: 12,
                material: LiquidGlassTheme.LiquidGlass.thick,
                intensity: 1.0
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LiquidGlassTheme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(AnimationManager.Gestures.tapFeedback) {
                                isPressed = pressing
                                if pressing {
                                    LiquidGlassTheme.Haptics.light()
                                }
                            }
                          },
                          perform: {})
    }

    private func formatDateRange(_ dateInterval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let start = formatter.string(from: dateInterval.start)
        let end = formatter.string(from: dateInterval.end)
        return "\(start)-\(end)"
    }
}

// MARK: - View Mode Toggle
struct ViewModeToggle: View {
    @Binding var selectedMode: ExpenseViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ExpenseViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedMode = mode
                        LiquidGlassTheme.Haptics.selection()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .medium))

                        Text(mode.localizedTitle)
                            .font(LiquidGlassTheme.Typography.caption1)
                    }
                    .foregroundColor(
                        selectedMode == mode
                            ? LiquidGlassTheme.Colors.accent
                            : LiquidGlassTheme.Colors.textSecondary
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if selectedMode == mode {
                                LiquidGlassBackground(
                                    cornerRadius: 20,
                                    material: LiquidGlassTheme.LiquidGlass.regular,
                                    intensity: 1.0
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            LiquidGlassBackground(
                cornerRadius: 24,
                material: LiquidGlassTheme.LiquidGlass.ultraThin,
                intensity: 0.8
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Reports Carousel
struct ReportsCarousel: View {
    let reports: [ExpenseReport]
    let onReportTap: (ExpenseReport) -> Void
    let onGenerateReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizationManager.shared.localized("expenses.reports.title"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Spacer()

                Button(action: onGenerateReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))

                        Text(LocalizationManager.shared.localized("expenses.reports.generate"))
                            .font(LiquidGlassTheme.Typography.caption1)
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)

            if reports.isEmpty {
                Text(LocalizationManager.shared.localized("expenses.reports.empty"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(reports) { report in
                            ReportThumbnail(report: report) {
                                onReportTap(report)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}