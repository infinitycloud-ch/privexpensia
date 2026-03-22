import SwiftUI

// MARK: - Expense Result View - Jony Ive Precision
// Clean, focused presentation of scanned expense data

struct ExpenseResultView: View {
    let data: ExtractedExpenseData
    let onSave: (ExtractedExpenseData) -> Void
    let onCancel: () -> Void

    @State private var editedData: ExtractedExpenseData
    @State private var appearanceOffset: CGFloat = 30
    @State private var appearanceOpacity: Double = 0

    init(data: ExtractedExpenseData, onSave: @escaping (ExtractedExpenseData) -> Void, onCancel: @escaping () -> Void) {
        self.data = data
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedData = State(initialValue: data)
    }

    var body: some View {
        ZStack {
            // Jony Ive background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header - Confidence Badge
                    confidenceHeader
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                    // Main Details Card
                    mainDetailsCard
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    // Items Breakdown
                    if let items = editedData.items, !items.isEmpty {
                        itemsCard
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    // Action Buttons
                    actionButtons
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearanceOffset = 0
                appearanceOpacity = 1
            }
        }
        .offset(y: appearanceOffset)
        .opacity(appearanceOpacity)
    }

    // MARK: - Confidence Header

    private var confidenceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.shared.localized("scan.complete_title"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))

                Text(LocalizationManager.shared.localized("scan.complete_message"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
            }

            Spacer()

            // Confidence badge
            HStack(spacing: 6) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)

                Text("\(Int(editedData.confidence * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(confidenceColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(confidenceColor.opacity(0.1))
            )
        }
    }

    private var confidenceColor: Color {
        if editedData.confidence >= 0.9 { return .green }
        else if editedData.confidence >= 0.7 { return .orange }
        else { return .red }
    }

    // MARK: - Main Details Card

    private var mainDetailsCard: some View {
        VStack(spacing: 20) {
            // Merchant & Amount - Hero section
            VStack(spacing: 8) {
                Text(editedData.merchant)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text(formatCurrency(editedData.totalAmount))
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundColor(.black)
                    .kerning(-1)
            }
            .padding(.bottom, 8)

            // Details Grid
            VStack(spacing: 16) {
                detailRow(LocalizationManager.shared.localized("expense.field.date"), formatDate(editedData.date))
                detailRow(LocalizationManager.shared.localized("expense.field.category"), editedData.category)
                if let paymentMethod = editedData.paymentMethod {
                    detailRow(LocalizationManager.shared.localized("expense.field.payment"), paymentMethod)
                }
                if editedData.taxAmount > 0 {
                    detailRow(LocalizationManager.shared.localized("expense.field.tax"), formatCurrency(editedData.taxAmount))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(
            Color.white.opacity(0.95),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
        }
    }

    // MARK: - Items Card

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationManager.shared.localized("expense.field.items"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)

            Text(editedData.items ?? "")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.white.opacity(0.9),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save Button - Primary
            Button(action: {
                onSave(editedData)
            }) {
                Text(LocalizationManager.shared.localized("expense.save_button"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 27))
            }

            // Cancel Button - Secondary
            Button(action: onCancel) {
                Text(LocalizationManager.shared.localized("button.cancel"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black.opacity(0.7))
            }
        }
    }

    // MARK: - Helper Functions

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "CHF"
        formatter.maximumFractionDigits = amount < 100 ? 2 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "CHF 0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}