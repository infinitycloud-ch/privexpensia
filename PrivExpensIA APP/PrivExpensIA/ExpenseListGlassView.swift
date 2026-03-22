import SwiftUI
import CoreData

// MARK: - Expense Report Model
struct ExpenseReport: Identifiable, Codable {
    let id: UUID
    let title: String
    let dateRange: DateInterval
    let expenseIds: [UUID]
    let totalAmount: Double
    let createdAt: Date
    var thumbnail: Data?

    init(title: String, from startDate: Date, to endDate: Date, expenses: [Expense]) {
        self.id = UUID()
        self.title = title
        self.dateRange = DateInterval(start: startDate, end: endDate)
        self.expenseIds = expenses.compactMap { $0.id }
        self.totalAmount = expenses.reduce(0) { $0 + $1.totalAmount }
        self.createdAt = Date()
        self.thumbnail = nil
    }

    var formattedDateRange: String {
        let calendar = Calendar.current
        let start = dateRange.start
        let end = dateRange.end
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let sameYear = calendar.isDate(start, equalTo: end, toGranularity: .year)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let fullFormatter = DateFormatter()
        fullFormatter.dateStyle = .medium

        if sameMonth {
            let daysDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            if daysDiff <= 7 {
                return "\(dayFormatter.string(from: start))-\(dayFormatter.string(from: end)) \(monthFormatter.string(from: start))"
            } else {
                return monthFormatter.string(from: start)
            }
        } else if sameYear {
            let shortMonthFormatter = DateFormatter()
            shortMonthFormatter.dateFormat = "MMM"
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            return "\(shortMonthFormatter.string(from: start)) - \(shortMonthFormatter.string(from: end)) \(yearFormatter.string(from: end))"
        } else {
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

// MARK: - View Mode Enum
enum ViewMode: String, CaseIterable {
    case list = "list"
    case thumbnails = "thumbnails"

    var localizedTitle: String {
        switch self {
        case .list: return LocalizationManager.shared.localized("expenses.view_mode.list")
        case .thumbnails: return LocalizationManager.shared.localized("expenses.view_mode.thumbnails")
        }
    }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .thumbnails: return "square.grid.2x2"
        }
    }
}

// MARK: - Report Manager
class ReportManager: ObservableObject {
    static let shared = ReportManager()
    @Published var reports: [ExpenseReport] = []

    private init() { loadReports() }

    func generateReport(title: String, from startDate: Date, to endDate: Date, expenses: [Expense]) -> ExpenseReport {
        let report = ExpenseReport(title: title, from: startDate, to: endDate, expenses: expenses)
        reports.append(report)
        saveReports()
        archiveExpenses(expenses, in: report)
        return report
    }

    func deleteReport(_ report: ExpenseReport) {
        reports.removeAll { $0.id == report.id }
        saveReports()
    }

    func generateAutomaticReport(title: String? = nil) -> ExpenseReport? {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND reportId == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]

        do {
            let openExpenses = try context.fetch(request)
            guard !openExpenses.isEmpty else { return nil }
            let dates = openExpenses.compactMap { $0.date }
            let startDate = dates.min() ?? Date()
            let endDate = dates.max() ?? Date()
            let reportTitle = title ?? "Rapport \(formatDate(Date()))"
            return generateReport(title: reportTitle, from: startDate, to: endDate, expenses: openExpenses)
        } catch {
            return nil
        }
    }

    func getExpensesForReport(_ report: ExpenseReport) -> [Expense] {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "reportId == %@", report.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func archiveExpenses(_ expenses: [Expense], in report: ExpenseReport) {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        for expense in expenses {
            expense.isArchived = true
            expense.reportId = report.id
        }
        try? context.save()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func saveReports() {
        if let encoded = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(encoded, forKey: "expense_reports")
        }
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: "expense_reports"),
              let decoded = try? JSONDecoder().decode([ExpenseReport].self, from: data) else { return }
        reports = decoded
        syncArchiveStatus()
    }

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
        if migrated > 0 { try? context.save() }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}

// MARK: - UI Components

// Expense Thumbnail Card
struct ExpenseThumbnailCardSimple: View {
    let expense: Expense
    let onTap: () -> Void
    @EnvironmentObject var currencyManager: CurrencyManager

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
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
                            .fill(LiquidGlassTheme.Colors.glassBase)
                            .frame(width: 120, height: 100)
                            .overlay(
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.merchant ?? "Unknown")
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(currencyManager.formatAmount(expense.totalAmount))
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .fontWeight(.medium)
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
    }
}

// View Mode Toggle
struct ViewModeToggle: View {
    @Binding var selectedMode: ViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
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

// Report Thumbnail
struct ReportThumbnailSimple: View {
    let report: ExpenseReport
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject var currencyManager: CurrencyManager

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)

                    Text(currencyManager.formatAmount(report.totalAmount))
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .fontWeight(.semibold)

                    Text(String(format: LocalizationManager.shared.localized("report.items_count"), report.expenseIds.count))
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }

                VStack(spacing: 2) {
                    Text(report.title)
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
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
        .contextMenu {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label(LocalizationManager.shared.localized("button.delete"), systemImage: "trash")
            }
        }
    }
}

// Report Detail View
struct ReportDetailSimple: View {
    let report: ExpenseReport
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currencyManager: CurrencyManager
    @State private var showDeleteAlert = false
    @State private var reportExpenses: [Expense] = []
    @State private var selectedImage: UIImage? = nil
    @State private var showFullscreenImage = false

    // Grid layout for receipt gallery
    private let imageColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // Expenses with images
    private var expensesWithImages: [(expense: Expense, image: UIImage)] {
        reportExpenses.compactMap { expense in
            guard let imageData = expense.receiptImageData,
                  let image = UIImage(data: imageData) else { return nil }
            return (expense, image)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card - Folder Style
                        VStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 40))
                                .foregroundColor(LiquidGlassTheme.Colors.accent)

                            Text(report.title)
                                .font(LiquidGlassTheme.Typography.title1)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                            Text(currencyManager.formatAmount(report.totalAmount))
                                .font(LiquidGlassTheme.Typography.largeTitle)
                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                                .fontWeight(.bold)

                            HStack(spacing: 16) {
                                Label(
                                    String(format: LocalizationManager.shared.localized("report.expenses_count"), report.expenseIds.count),
                                    systemImage: "doc.text"
                                )
                                if !expensesWithImages.isEmpty {
                                    Label(
                                        "\(expensesWithImages.count)",
                                        systemImage: "photo"
                                    )
                                }
                            }
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LiquidGlassBackground(
                                cornerRadius: 16,
                                material: LiquidGlassTheme.LiquidGlass.regular,
                                intensity: 0.8
                            )
                        )

                        // Receipt Gallery Section
                        if !expensesWithImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(LocalizationManager.shared.localized("report.receipts_gallery"))
                                }
                                .font(LiquidGlassTheme.Typography.headline)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                                .padding(.horizontal, 4)

                                LazyVGrid(columns: imageColumns, spacing: 8) {
                                    ForEach(expensesWithImages, id: \.expense.id) { item in
                                        ReceiptThumbnail(image: item.image)
                                            .onTapGesture {
                                                selectedImage = item.image
                                                showFullscreenImage = true
                                                LiquidGlassTheme.Haptics.selection()
                                            }
                                    }
                                }
                            }
                            .padding()
                            .background(
                                LiquidGlassBackground(
                                    cornerRadius: 16,
                                    material: LiquidGlassTheme.LiquidGlass.thin,
                                    intensity: 0.5
                                )
                            )
                        }

                        // Expenses List
                        if !reportExpenses.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                    Text(LocalizationManager.shared.localized("report.included_expenses"))
                                }
                                .font(LiquidGlassTheme.Typography.headline)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                                .padding(.horizontal, 4)

                                ForEach(reportExpenses, id: \.id) { expense in
                                    ReportExpenseRow(expense: expense)
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Delete button
                        Button(action: { showDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text(LocalizationManager.shared.localized("report.delete"))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(LiquidGlassTheme.Colors.error)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("report.details_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("button.done")) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationManager.shared.localized("report.delete_confirm_title"), isPresented: $showDeleteAlert) {
                Button(LocalizationManager.shared.localized("button.cancel"), role: .cancel) { }
                Button(LocalizationManager.shared.localized("button.delete"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(LocalizationManager.shared.localized("report.delete_confirm_message"))
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                FullscreenReceiptView(image: selectedImage, isPresented: $showFullscreenImage)
            }
            .onAppear {
                loadReportExpenses()
            }
        }
    }

    private func loadReportExpenses() {
        let allExpenses = CoreDataManager.shared.fetchExpenses()
        reportExpenses = allExpenses.filter { expense in
            guard let expenseId = expense.id else { return false }
            return report.expenseIds.contains(expenseId)
        }.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
}

// MARK: - Receipt Thumbnail for Gallery
struct ReceiptThumbnail: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 100)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LiquidGlassTheme.Colors.textSecondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Fullscreen Receipt View
struct FullscreenReceiptView: View {
    let image: UIImage?
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                    )
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onTapGesture {
            isPresented = false
        }
    }
}

// Row for expense in report detail
struct ReportExpenseRow: View {
    let expense: Expense
    @EnvironmentObject var currencyManager: CurrencyManager

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: categoryIcon(for: expense.category ?? "Other"))
                .font(.system(size: 18))
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(LiquidGlassTheme.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant ?? "Unknown")
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(formatDate(expense.date))
                    .font(LiquidGlassTheme.Typography.caption1)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            }

            Spacer()

            // Amount
            Text(currencyManager.formatAmount(expense.amount))
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
        }
        .padding(12)
        .background(
            LiquidGlassBackground(
                cornerRadius: 12,
                material: LiquidGlassTheme.LiquidGlass.thin,
                intensity: 0.5
            )
        )
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "food", "alimentation": return "cart.fill"
        case "restaurant": return "fork.knife"
        case "transport": return "car.fill"
        case "shopping": return "bag.fill"
        case "health", "santé": return "heart.fill"
        case "entertainment", "divertissement": return "gamecontroller.fill"
        case "hotel": return "bed.double.fill"
        default: return "tag.fill"
        }
    }
}

// MARK: - Report Generation View (Automatic - All buffer expenses)
struct ReportGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportManager = ReportManager.shared

    @State private var isLoading = false
    @State private var bufferExpenses: [Expense] = []

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
                    headerSection
                    summarySection
                    expensesPreviewSection
                    Spacer()
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

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text(LocalizationManager.shared.localized("button.cancel"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3)))
            }
            Spacer()
            Text(LocalizationManager.shared.localized("expenses.reports.generate"))
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            Spacer()
            Color.clear.frame(width: 80, height: 28)
        }
        .padding(.top, 20)
    }

    private var summarySection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)

                Text(reportTitle)
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(dateRangeText)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                Divider().background(LiquidGlassTheme.Colors.textTertiary.opacity(0.3))

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
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(bufferExpenses.isEmpty || isLoading)
    }

    private func fetchAllBufferExpenses() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND reportId == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        do {
            bufferExpenses = try context.fetch(request)
        } catch {
            bufferExpenses = []
        }
    }

    private func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
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
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    private func generateReport() {
        guard !bufferExpenses.isEmpty else { return }
        isLoading = true
        LiquidGlassTheme.Haptics.medium()
        let dates = bufferExpenses.compactMap { $0.date }
        let startDate = dates.min() ?? Date()
        let endDate = dates.max() ?? Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = reportManager.generateReport(
                title: reportTitle,
                from: startDate,
                to: endDate,
                expenses: bufferExpenses
            )
            isLoading = false
            LiquidGlassTheme.Haptics.success()
            dismiss()
        }
    }
}

// MARK: - Expense List View with Glass UI
struct ExpenseListGlassView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyManager: CurrencyManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
        predicate: NSPredicate(format: "isArchived == NO AND reportId == nil"),
        animation: .default)
    private var expenses: FetchedResults<Expense>

    @State private var isAddingExpense = false
    @State private var selectedExpense: Expense?
    @State private var refreshID = UUID()

    // New state for enhanced view
    @State private var viewMode: ViewMode = .list
    @State private var showingReportGeneration = false
    @State private var selectedReport: ExpenseReport?
    @StateObject private var reportManager = ReportManager.shared
    @ObservedObject private var syncService = DocumentSyncService.shared

    // Multi-select state
    @State private var isSelecting = false
    @State private var selectedExpenseIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header with padding fix
                headerSection

                // View mode toggle
                viewModeToggle
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Content based on view mode
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if expenses.isEmpty {
                            emptyStateView
                        } else {
                            switch viewMode {
                            case .list:
                                expensesList
                            case .thumbnails:
                                thumbnailsGrid
                            }
                        }

                        // Reports section at bottom
                        reportsSection
                        .padding(.top, 24)

                        // Bottom spacing for floating button
                        Spacer(minLength: 100)
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Floating Action Button (Add or Delete)
            VStack {
                Spacer()
                if isSelecting && !selectedExpenseIDs.isEmpty {
                    // Delete button when items selected - CENTERED and higher to avoid bot button
                    Button(action: {
                        showDeleteConfirmation = true
                        LiquidGlassTheme.Haptics.medium()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(LocalizationManager.shared.localized("expenses.delete_selected"))
                                .font(LiquidGlassTheme.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(LiquidGlassTheme.Colors.error)
                        )
                        .shadow(color: LiquidGlassTheme.Colors.error.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 120)  // Higher to avoid bot button overlap
                } else if !isSelecting {
                    // Add button when not selecting
                    HStack {
                        Spacer()
                        GlassFloatingActionButton(icon: "plus") {
                            isAddingExpense = true
                        }
                    }
                    .padding(LiquidGlassTheme.Layout.spacing24)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelecting)
            .animation(.easeInOut(duration: 0.2), value: selectedExpenseIDs.count)
        }
        .confirmationDialog(
            LocalizationManager.shared.localized("expenses.delete_confirmation_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(format: LocalizationManager.shared.localized("expenses.delete_count"), selectedExpenseIDs.count), role: .destructive) {
                deleteSelectedExpenses()
            }
            Button(LocalizationManager.shared.localized("button.cancel"), role: .cancel) {}
        } message: {
            Text(LocalizationManager.shared.localized("expenses.delete_confirmation_message"))
        }
        .sheet(isPresented: $isAddingExpense) {
            AddExpenseGlassView()
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailGlassView(expense: expense)
        }
        .sheet(isPresented: $showingReportGeneration) {
            ReportGenerationView()
        }
        .sheet(item: $selectedReport) { report in
            ReportDetailSimple(report: report) {
                reportManager.deleteReport(report)
            }
        }
        .onAppear {
            // App starts with empty database - no test data
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                Text(LocalizationManager.shared.localized("expenses_title"))
                    .font(LiquidGlassTheme.Typography.displaySmall)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                if isSelecting {
                    Text(String(format: LocalizationManager.shared.localized("expenses.selected_count"), selectedExpenseIDs.count))
                        .font(LiquidGlassTheme.Typography.title2)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                } else {
                    Text(String(format: LocalizationManager.shared.localized("expenses.total_format"), currencyManager.formatAmount(totalAmount)))
                        .font(LiquidGlassTheme.Typography.title2)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
            }

            Spacer()

            // Sync button
            if syncService.hasSyncFolder {
                Button(action: { syncService.syncAllDocuments() }) {
                    ZStack {
                        if syncService.isSyncingAll {
                            Circle()
                                .trim(from: 0, to: syncService.syncProgress.total > 0
                                    ? CGFloat(syncService.syncProgress.current) / CGFloat(syncService.syncProgress.total)
                                    : 0)
                                .stroke(LiquidGlassTheme.Colors.accent, lineWidth: 2)
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))

                            Text("\(syncService.syncProgress.current)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(syncService.isOnWiFi || !syncService.wifiOnlyEnabled ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textTertiary)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .disabled(syncService.isSyncingAll || (syncService.wifiOnlyEnabled && !syncService.isOnWiFi))
                .padding(.trailing, 8)
            }

            // Select / Cancel button
            if !expenses.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isSelecting {
                            // Cancel selection
                            isSelecting = false
                            selectedExpenseIDs.removeAll()
                        } else {
                            // Start selection mode
                            isSelecting = true
                        }
                    }
                    LiquidGlassTheme.Haptics.light()
                }) {
                    Text(isSelecting
                        ? LocalizationManager.shared.localized("button.cancel")
                        : LocalizationManager.shared.localized("expenses.select"))
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing20)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                
                Text(LocalizationManager.shared.localized("expenses_empty_title"))
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Text(LocalizationManager.shared.localized("expenses_empty_message"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(LiquidGlassTheme.Layout.spacing32)
        }
        .glassAppear(isVisible: true)
    }
    
    // MARK: - Expenses List
    private var expensesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(expenses.enumerated()), id: \.element) { index, expense in
                HStack(spacing: 12) {
                    // Checkbox when selecting
                    if isSelecting {
                        Button(action: {
                            toggleSelection(expense)
                        }) {
                            Image(systemName: selectedExpenseIDs.contains(expense.id ?? UUID()) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(selectedExpenseIDs.contains(expense.id ?? UUID()) ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }

                    ExpenseCardGlass(expense: expense) {
                        if isSelecting {
                            toggleSelection(expense)
                        } else {
                            withAnimation(AnimationManager.Glass.cardAppear) {
                                selectedExpense = expense
                            }
                        }
                    }
                }
                .glassAppear(isVisible: true)
                .animation(AnimationManager.staggeredAnimation(index: index, totalCount: expenses.count), value: refreshID)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteExpense(expense)
                    } label: {
                        Label(LocalizationManager.shared.localized("button.delete"), systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func toggleSelection(_ expense: Expense) {
        guard let id = expense.id else { return }
        if selectedExpenseIDs.contains(id) {
            selectedExpenseIDs.remove(id)
        } else {
            selectedExpenseIDs.insert(id)
        }
        LiquidGlassTheme.Haptics.light()
    }

    // MARK: - Thumbnails Grid
    private var thumbnailsGrid: some View {
        let expensesWithImages = expenses.filter { $0.receiptImageData != nil }

        return LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120), spacing: 12)
        ], spacing: 12) {
            if expensesWithImages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)

                    Text(LocalizationManager.shared.localized("expenses.thumbnails.empty"))
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(expensesWithImages.enumerated()), id: \.element) { index, expense in
                    ExpenseThumbnailCardSimple(expense: expense) {
                        withAnimation(AnimationManager.Glass.cardAppear) {
                            selectedExpense = expense
                        }
                    }
                    .glassAppear(isVisible: true)
                    .animation(AnimationManager.staggeredAnimation(index: index, totalCount: expensesWithImages.count), value: refreshID)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                deleteExpense(expense)
                            }
                            LiquidGlassTheme.Haptics.warning()
                        } label: {
                            Label(LocalizationManager.shared.localized("button.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Actions
    private func refreshExpenses() async {
        LiquidGlassTheme.Haptics.light()
        
        // Simulate refresh delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            // CoreData refresh automatique avec @FetchRequest
            refreshID = UUID()
            LiquidGlassTheme.Haptics.success()
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        withAnimation(AnimationManager.Springs.horizontalSmooth) {
            CoreDataManager.shared.deleteExpense(expense)
            LiquidGlassTheme.Haptics.medium()
        }
    }

    private func deleteSelectedExpenses() {
        withAnimation(AnimationManager.Springs.horizontalSmooth) {
            for expense in expenses where selectedExpenseIDs.contains(expense.id ?? UUID()) {
                CoreDataManager.shared.deleteExpense(expense)
            }
            selectedExpenseIDs.removeAll()
            isSelecting = false
            LiquidGlassTheme.Haptics.success()
        }
    }

    private var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.totalAmount }
    }

    // MARK: - Helper Functions

    // MARK: - View Mode Toggle
    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewMode = mode
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
                        viewMode == mode
                            ? LiquidGlassTheme.Colors.accent
                            : LiquidGlassTheme.Colors.textSecondary
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if viewMode == mode {
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

    // MARK: - Reports Section
    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizationManager.shared.localized("expenses.reports.title"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Spacer()

                Button(action: {
                    LiquidGlassTheme.Haptics.light()
                    showingReportGeneration = true
                }) {
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

            if reportManager.reports.isEmpty {
                Text(LocalizationManager.shared.localized("expenses.reports.empty"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(reportManager.reports) { report in
                            ReportThumbnailSimple(report: report, onTap: {
                                selectedReport = report
                            }, onDelete: {
                                reportManager.deleteReport(report)
                            })
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

// MARK: - Expense Card Glass
struct ExpenseCardGlass: View {
    let expense: Expense
    let onTap: () -> Void
    @EnvironmentObject var currencyManager: CurrencyManager
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3))
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon(expense.category ?? "Other"))
                        .font(.system(size: 20))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                }

                // Info
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing4) {
                    Text(expense.merchant ?? "Unknown")
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                    Text(formatRelativeDate(expense.date ?? Date()))
                        .font(LiquidGlassTheme.Typography.footnote)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: LiquidGlassTheme.Layout.spacing2) {
                    Text(currencyManager.formatAmount(expense.totalAmount))
                        .font(LiquidGlassTheme.Typography.title3)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                    if expense.taxAmount > 0 {
                        Text(String(format: LocalizationManager.shared.localized("expense.tax_format"), currencyManager.formatAmount(expense.taxAmount)))
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(LiquidGlassTheme.Layout.spacing16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            LiquidGlassBackground(
                cornerRadius: 16,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.8
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = pressing
                                if pressing {
                                    LiquidGlassTheme.Haptics.light()
                                }
                            }
                          },
                          perform: {})
    }

    private func categoryIcon(_ category: String) -> String {
        Constants.Categories.icons[category] ?? "questionmark.circle"
    }
}

// MARK: - Add Expense Glass View
struct AddExpenseGlassView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(LocalizationManager.shared.localized("expense.add_title"))
                        .font(LiquidGlassTheme.Typography.title1)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                    VStack(spacing: 16) {
                        Button(LocalizationManager.shared.localized("expense.scan_receipt")) {
                            // Navigate to scanner
                            dismiss()
                        }
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .padding()
                        .background(
                            LiquidGlassBackground(
                                cornerRadius: 12,
                                material: LiquidGlassTheme.LiquidGlass.regular,
                                intensity: 0.8
                            )
                        )

                        Button(LocalizationManager.shared.localized("expense.manual_entry")) {
                            // Manual entry
                            dismiss()
                        }
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .padding()
                        .background(
                            LiquidGlassBackground(
                                cornerRadius: 12,
                                material: LiquidGlassTheme.LiquidGlass.regular,
                                intensity: 0.8
                            )
                        )
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("button.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Functions
private func formatRelativeDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter.string(from: date)
}