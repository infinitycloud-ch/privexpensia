import SwiftUI
import Charts
import CoreData

// MARK: - Statistics Data Models
struct CategoryData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
}

struct DailyData: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let label: String
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let cumulativeAmount: Double
}

// MARK: - Statistics ViewModel
class StatisticsViewModel: ObservableObject {
    @Published var totalSpent: Double = 0
    @Published var previousPeriodTotal: Double = 0
    @Published var categoryData: [CategoryData] = []
    @Published var dailyData: [DailyData] = []
    @Published var trendData: [TrendData] = []
    @Published var dailyAverage: Double = 0
    @Published var expenseCount: Int = 0
    @Published var periodChangePercent: Double = 0

    private let categoryColors: [String: Color] = [
        "Alimentation": .orange,
        "Groceries": .orange,
        "Restaurant": .red,
        "Transport": .blue,
        "Shopping": .purple,
        "Health": .green,
        "Entertainment": .pink,
        "Coffee": .brown,
        "Gas": .yellow,
        "Bills": .indigo,
        "Other": .gray,
        "Divers": .gray
    ]

    func loadData(for periodIndex: Int) {
        let calendar = Calendar.current
        let now = Date()

        // Calculate date range based on period
        let (startDate, previousStartDate, previousEndDate, daysInPeriod) = calculateDateRange(periodIndex: periodIndex, calendar: calendar, now: now)

        // Fetch expenses for current period
        let currentExpenses = fetchExpenses(from: startDate, to: now)

        // Fetch expenses for previous period
        let previousExpenses = fetchExpenses(from: previousStartDate, to: previousEndDate)

        // Calculate totals
        totalSpent = currentExpenses.reduce(0) { $0 + $1.amount }
        previousPeriodTotal = previousExpenses.reduce(0) { $0 + $1.amount }
        expenseCount = currentExpenses.count

        // Calculate daily average
        dailyAverage = daysInPeriod > 0 ? totalSpent / Double(daysInPeriod) : 0

        // Calculate period change percentage
        if previousPeriodTotal > 0 {
            periodChangePercent = ((totalSpent - previousPeriodTotal) / previousPeriodTotal) * 100
        } else {
            periodChangePercent = totalSpent > 0 ? 100 : 0
        }

        // Group by category
        categoryData = groupByCategory(expenses: currentExpenses)

        // Create daily/weekly data for bar chart
        dailyData = createDailyData(expenses: currentExpenses, periodIndex: periodIndex, calendar: calendar, startDate: startDate)

        // Create trend data for line chart
        trendData = createTrendData(expenses: currentExpenses, calendar: calendar, startDate: startDate)

    }

    private func calculateDateRange(periodIndex: Int, calendar: Calendar, now: Date) -> (Date, Date, Date, Int) {
        var startDate: Date
        var previousStartDate: Date
        var previousEndDate: Date
        var daysInPeriod: Int

        switch periodIndex {
        case 0: // Week
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            previousStartDate = calendar.date(byAdding: .day, value: -14, to: now) ?? now
            previousEndDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            daysInPeriod = 7
        case 1: // Month
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            previousStartDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now
            previousEndDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            daysInPeriod = 30
        case 2: // Year
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            previousStartDate = calendar.date(byAdding: .year, value: -2, to: now) ?? now
            previousEndDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            daysInPeriod = 365
        default:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            previousStartDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now
            previousEndDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            daysInPeriod = 30
        }

        return (startDate, previousStartDate, previousEndDate, daysInPeriod)
    }

    private func fetchExpenses(from startDate: Date, to endDate: Date) -> [Expense] {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND isArchived == NO", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    private func groupByCategory(expenses: [Expense]) -> [CategoryData] {
        var categoryTotals: [String: Double] = [:]

        for expense in expenses {
            let category = expense.category ?? "Other"
            categoryTotals[category, default: 0] += expense.amount
        }

        return categoryTotals.map { category, amount in
            CategoryData(
                category: category,
                amount: amount,
                color: categoryColors[category] ?? .gray
            )
        }.sorted { $0.amount > $1.amount }
    }

    private func createDailyData(expenses: [Expense], periodIndex: Int, calendar: Calendar, startDate: Date) -> [DailyData] {
        var dailyTotals: [Date: Double] = [:]
        let formatter = DateFormatter()

        // Group expenses by day/week/month depending on period
        for expense in expenses {
            guard let date = expense.date else { continue }

            let groupDate: Date
            switch periodIndex {
            case 0: // Week - group by day
                groupDate = calendar.startOfDay(for: date)
            case 1: // Month - group by day
                groupDate = calendar.startOfDay(for: date)
            case 2: // Year - group by month
                let components = calendar.dateComponents([.year, .month], from: date)
                groupDate = calendar.date(from: components) ?? date
            default:
                groupDate = calendar.startOfDay(for: date)
            }

            dailyTotals[groupDate, default: 0] += expense.amount
        }

        // Format labels based on period
        switch periodIndex {
        case 0: // Week
            formatter.dateFormat = "E" // Mon, Tue, etc.
        case 1: // Month
            formatter.dateFormat = "d" // 1, 2, 3, etc.
        case 2: // Year
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        default:
            formatter.dateFormat = "d"
        }

        return dailyTotals.map { date, amount in
            DailyData(date: date, amount: amount, label: formatter.string(from: date))
        }.sorted { $0.date < $1.date }
    }

    private func createTrendData(expenses: [Expense], calendar: Calendar, startDate: Date) -> [TrendData] {
        let sortedExpenses = expenses.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        var cumulative: Double = 0
        var result: [TrendData] = []

        for expense in sortedExpenses {
            cumulative += expense.amount
            result.append(TrendData(date: expense.date ?? Date(), cumulativeAmount: cumulative))
        }

        return result
    }

    var top3Categories: [CategoryData] {
        Array(categoryData.prefix(3))
    }
}

// MARK: - Statistics View with Glass Charts
struct StatisticsGlassView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedPeriod = 1 // Default to month
    @State private var chartAppear = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var isExporting = false

    private var periods: [String] {
        [
            LocalizationManager.shared.localized("period.week"),
            LocalizationManager.shared.localized("period.month"),
            LocalizationManager.shared.localized("period.year")
        ]
    }

    var body: some View {
        ZStack {
            // Background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LiquidGlassTheme.Layout.spacing20) {
                    // Header
                    headerSection

                    // Period Selector
                    GlassSegmentedControl(items: periods, selection: $selectedPeriod)
                        .padding(.horizontal)
                        .onChange(of: selectedPeriod) { _ in
                            viewModel.loadData(for: selectedPeriod)
                        }

                    // Total Summary Card
                    totalSummaryCard
                        .glassAppear(isVisible: chartAppear)

                    // Category Pie Chart
                    if !viewModel.categoryData.isEmpty {
                        categoryChartCard
                            .glassAppear(isVisible: chartAppear)
                    }

                    // Daily Bar Chart
                    if !viewModel.dailyData.isEmpty {
                        dailyChartCard
                            .glassAppear(isVisible: chartAppear)
                    }

                    // Trend Line Chart
                    if !viewModel.trendData.isEmpty {
                        trendChartCard
                            .glassAppear(isVisible: chartAppear)
                    }

                    // Top 3 Categories
                    if !viewModel.top3Categories.isEmpty {
                        top3CategoriesCard
                            .glassAppear(isVisible: chartAppear)
                    }

                    // Export Section
                    exportSection
                }
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            viewModel.loadData(for: selectedPeriod)
            withAnimation(AnimationManager.Glass.cardAppear.delay(0.2)) {
                chartAppear = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(LocalizationManager.shared.localized("export.loading"))
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(LiquidGlassBackground(cornerRadius: 16, material: LiquidGlassTheme.LiquidGlass.regular))
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
            Text(LocalizationManager.shared.localized("statistics.title"))
                .font(LiquidGlassTheme.Typography.displaySmall)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            Text(LocalizationManager.shared.localized("statistics.current_period"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing20)
    }

    // MARK: - Total Summary Card
    private var totalSummaryCard: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                HStack(spacing: LiquidGlassTheme.Layout.spacing32) {
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                        Text(LocalizationManager.shared.localized("statistics.total_spent"))
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        Text(CurrencyManager.shared.formatAmount(viewModel.totalSpent))
                            .font(LiquidGlassTheme.Typography.displayMedium)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: LiquidGlassTheme.Layout.spacing4) {
                        // Period change indicator
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.periodChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            Text(String(format: "%.1f%%", abs(viewModel.periodChangePercent)))
                                .font(LiquidGlassTheme.Typography.caption1)
                        }
                        .foregroundColor(viewModel.periodChangePercent >= 0 ? .red : .green)

                        Text(LocalizationManager.shared.localized("statistics.vs_previous"))
                            .font(LiquidGlassTheme.Typography.caption2)
                            .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    }
                }

                // Stats row
                HStack {
                    StatMiniCard(
                        title: LocalizationManager.shared.localized("statistics.expenses_count"),
                        value: "\(viewModel.expenseCount)"
                    )

                    StatMiniCard(
                        title: LocalizationManager.shared.localized("statistics.daily_average"),
                        value: CurrencyManager.shared.formatAmount(viewModel.dailyAverage)
                    )
                }
            }
        }
    }

    // MARK: - Category Pie Chart
    private var categoryChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("statistics.by_category"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Chart(viewModel.categoryData) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(viewModel.categoryData.prefix(6)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(LiquidGlassTheme.Typography.caption2)
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyManager.shared.formatAmount(item.amount))
                                .font(LiquidGlassTheme.Typography.caption2)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Daily Bar Chart
    private var dailyChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("statistics.spending_over_time"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Chart(viewModel.dailyData) { item in
                    BarMark(
                        x: .value("Date", item.label),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(LiquidGlassTheme.Colors.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(CurrencyManager.shared.formatAmount(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trend Line Chart
    private var trendChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("statistics.cumulative_trend"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Chart(viewModel.trendData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Total", item.cumulativeAmount)
                    )
                    .foregroundStyle(LiquidGlassTheme.Colors.primary.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Total", item.cumulativeAmount)
                    )
                    .foregroundStyle(LiquidGlassTheme.Colors.primary.opacity(0.2).gradient)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }
        }
    }

    // MARK: - Top 3 Categories Card
    private var top3CategoriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("statistics.top_categories"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                ForEach(Array(viewModel.top3Categories.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.yellow : (index == 1 ? Color.gray : Color.orange))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        // Category info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category)
                                .font(LiquidGlassTheme.Typography.body)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(item.color)
                                        .frame(width: geo.size.width * (viewModel.totalSpent > 0 ? item.amount / viewModel.totalSpent : 0), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        Spacer()

                        // Amount
                        Text(CurrencyManager.shared.formatAmount(item.amount))
                            .font(LiquidGlassTheme.Typography.headline)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Export Section
    private var exportSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("export.title"))
                    .font(LiquidGlassTheme.Typography.title3)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                    Button(LocalizationManager.shared.localized("export.generate_auto_report")) {
                        generateAutomaticReport()
                    }
                    .padding()
                    .background(LiquidGlassTheme.Colors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                    HStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                        Button(LocalizationManager.shared.localized("export.pdf")) {
                            exportToPDF()
                        }
                        .padding()
                        .background(LiquidGlassTheme.Colors.accent.opacity(0.2))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .cornerRadius(12)

                        Button(LocalizationManager.shared.localized("export.csv")) {
                            exportToCSV()
                        }
                        .padding()
                        .background(LiquidGlassTheme.Colors.accent.opacity(0.2))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func generateAutomaticReport() {
        LiquidGlassTheme.Haptics.success()

        let reportManager = ReportManager.shared
        if let report = reportManager.generateAutomaticReport() {
        } else {
        }
    }

    private func exportToPDF() {
        guard !isExporting else { return }
        isExporting = true
        LiquidGlassTheme.Haptics.selection()

        let expenses = CoreDataManager.shared.fetchExpenses()

        ExportManager.shared.exportToPDF(expenses: expenses) { url in
            self.isExporting = false
            if let url = url {
                self.shareURL = url
                self.showShareSheet = true
                LiquidGlassTheme.Haptics.success()
            } else {
                LiquidGlassTheme.Haptics.error()
            }
        }
    }

    private func exportToCSV() {
        guard !isExporting else { return }
        isExporting = true
        LiquidGlassTheme.Haptics.selection()

        let expenses = CoreDataManager.shared.fetchExpenses()

        ExportManager.shared.exportToCSV(expenses: expenses) { url in
            self.isExporting = false
            if let url = url {
                self.shareURL = url
                self.showShareSheet = true
                LiquidGlassTheme.Haptics.success()
            } else {
                LiquidGlassTheme.Haptics.error()
            }
        }
    }
}

// MARK: - Stat Mini Card
struct StatMiniCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.accent)
            Text(title)
                .font(LiquidGlassTheme.Typography.caption2)
                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LiquidGlassTheme.Colors.glassBase.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    StatisticsGlassView()
}

// MARK: - Export Manager (Tasks 654-655)
class ExportManager {
    static let shared = ExportManager()

    private init() {}

    // MARK: - CSV Export
    func exportToCSV(expenses: [Expense], completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var csvContent = "Date,Merchant,Amount,Tax,Category,Payment Method,Currency\n"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for expense in expenses {
                let date = dateFormatter.string(from: expense.date ?? Date())
                let merchant = self.escapeCSV(expense.merchant ?? "Unknown")
                let amount = String(format: "%.2f", expense.amount)
                let tax = String(format: "%.2f", expense.taxAmount)
                let category = self.escapeCSV(expense.category ?? "Other")
                let paymentMethod = self.escapeCSV(expense.paymentMethod ?? "Card")
                let currency = expense.currency ?? "CHF"

                csvContent += "\(date),\(merchant),\(amount),\(tax),\(category),\(paymentMethod),\(currency)\n"
            }

            let fileName = "PrivExpenses_\(dateFormatter.string(from: Date())).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    completion(tempURL)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - PDF Export
    func exportToPDF(expenses: [Expense], completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pageWidth: CGFloat = 612
            let pageHeight: CGFloat = 792
            let margin: CGFloat = 50

            let pdfMetaData = [
                kCGPDFContextCreator: "PrivExpenses",
                kCGPDFContextAuthor: "PrivExpenses App",
                kCGPDFContextTitle: LocalizationManager.shared.localized("export.pdf.title")
            ]

            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = pdfMetaData as [String: Any]

            let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let data = renderer.pdfData { context in
                context.beginPage()

                var yPosition: CGFloat = margin

                // Title
                let titleFont = UIFont.boldSystemFont(ofSize: 24)
                let title = LocalizationManager.shared.localized("export.pdf.title")
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
                title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
                yPosition += 40

                // Date
                let subtitleFont = UIFont.systemFont(ofSize: 12)
                let subtitle = "\(LocalizationManager.shared.localized("export.pdf.generated")): \(dateFormatter.string(from: Date()))"
                let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: UIColor.gray]
                subtitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
                yPosition += 30

                // Summary
                let total = expenses.reduce(0.0) { $0 + $1.amount }
                let totalTax = expenses.reduce(0.0) { $0 + $1.taxAmount }
                let summaryFont = UIFont.boldSystemFont(ofSize: 14)
                let summaryText = "\(LocalizationManager.shared.localized("export.pdf.total")): \(CurrencyManager.shared.formatAmount(total)) | \(LocalizationManager.shared.localized("export.column.tax")): \(CurrencyManager.shared.formatAmount(totalTax)) | \(expenses.count) \(LocalizationManager.shared.localized("export.pdf.items"))"
                let summaryAttributes: [NSAttributedString.Key: Any] = [.font: summaryFont, .foregroundColor: UIColor.black]
                summaryText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: summaryAttributes)
                yPosition += 40

                // Table Header
                let headerFont = UIFont.boldSystemFont(ofSize: 10)
                let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.white]
                let headerRect = CGRect(x: margin, y: yPosition, width: pageWidth - (margin * 2), height: 25)
                context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
                context.cgContext.fill(headerRect)

                let columns = [(LocalizationManager.shared.localized("export.column.date"), margin + 5), (LocalizationManager.shared.localized("export.column.merchant"), margin + 80), (LocalizationManager.shared.localized("export.column.amount"), margin + 220), (LocalizationManager.shared.localized("export.column.tax"), margin + 300), (LocalizationManager.shared.localized("export.column.category"), margin + 370)]
                for (text, x) in columns {
                    text.draw(at: CGPoint(x: x, y: yPosition + 6), withAttributes: headerAttributes)
                }
                yPosition += 30

                // Rows
                let rowFont = UIFont.systemFont(ofSize: 9)
                let rowAttributes: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: UIColor.black]

                for (index, expense) in expenses.enumerated() {
                    if yPosition > pageHeight - margin - 20 {
                        context.beginPage()
                        yPosition = margin
                    }

                    if index % 2 == 0 {
                        let rowRect = CGRect(x: margin, y: yPosition, width: pageWidth - (margin * 2), height: 20)
                        context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
                        context.cgContext.fill(rowRect)
                    }

                    let rowData = [
                        (dateFormatter.string(from: expense.date ?? Date()), margin + 5),
                        (String((expense.merchant ?? LocalizationManager.shared.localized("export.unknown")).prefix(20)), margin + 80),
                        (CurrencyManager.shared.formatAmount(expense.amount), margin + 220),
                        (CurrencyManager.shared.formatAmount(expense.taxAmount), margin + 300),
                        (expense.category ?? LocalizationManager.shared.localized("export.other"), margin + 370)
                    ]

                    for (text, x) in rowData {
                        text.draw(at: CGPoint(x: x, y: yPosition + 4), withAttributes: rowAttributes)
                    }
                    yPosition += 20
                }

                // Footer
                let footerFont = UIFont.systemFont(ofSize: 8)
                let footerText = LocalizationManager.shared.localized("export.pdf.footer")
                let footerAttributes: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.lightGray]
                footerText.draw(at: CGPoint(x: margin, y: pageHeight - margin), withAttributes: footerAttributes)
            }

            let fileName = "PrivExpenses_\(dateFormatter.string(from: Date())).pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    completion(tempURL)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func escapeCSV(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}