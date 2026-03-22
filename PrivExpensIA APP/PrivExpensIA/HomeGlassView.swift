import SwiftUI
import Charts
import Combine
import VisionKit
import UIKit

// MARK: - Home Glass View uses existing ScannerGlassView for scanning

// MARK: - Home Glass View - Jony Ive Edition
// "The definition of simplicity is the ultimate sophistication" - Jonathan Ive
// Ultra-pure, essential-only design focusing on what matters most

struct HomeGlassView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var budgetManager = BudgetManager()
    @State private var showBudgetSetup = false
    @State private var heroAppear = false
    @State private var actionsAppear = false

    // Scan workflow states - 3 scan options on Home page
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var capturedImage: UIImage?
    @State private var isProcessingTransition = false  // Loading state during camera->scanner transition

    // Multi-scan state (Sprint 13) - for batch expense processing
    @State private var multiScanImages: [UIImage] = []
    @State private var currentMultiScanIndex: Int = 0
    @State private var isProcessingMultiScan = false

    // Document Archive scan (Sprint 13)
    @State private var showingDocumentScanner = false
    @State private var isProcessingDocument = false
    @State private var documentScanImage: UIImage?

    var body: some View {
        ZStack {
            // Jony Ive background - Ethereal, breathing space
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            // Processing transition overlay - hides Home during camera->scanner transition
            if isProcessingTransition {
                processingTransitionOverlay
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // HERO SECTION - The focal point of truth
                    heroBalance
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                        .scaleEffect(heroAppear ? 1 : 0.95)
                        .opacity(heroAppear ? 1 : 0)

                    // QUICK ACTIONS - Essential tools, nothing more
                    quickActions
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                        .offset(y: actionsAppear ? 0 : 20)
                        .opacity(actionsAppear ? 1 : 0)

                    // INSIGHTS - Intelligent, contextual information
                    if let insight = budgetManager.smartInsight {
                        insightCard(insight)
                            .padding(.top, 24)
                            .padding(.horizontal, 24)
                    }

                    // ACTIVITY PULSE - Minimal data visualization
                    activityPulse
                        .padding(.top, 32)
                        .padding(.horizontal, 24)

                    // Breathing space at bottom
                    Color.clear.frame(height: 120)
                }
            }
        }
        .onAppear {
            // Orchestrated appearance - like iPhone reveal
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                heroAppear = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                actionsAppear = true
            }
            viewModel.updateDateTime()
            viewModel.loadRecentExpenses()
        }
        .sheet(isPresented: $showBudgetSetup) {
            BudgetSetupModal(budgetManager: budgetManager, isPresented: $showBudgetSetup)
        }
        .sheet(isPresented: $showingCamera) {
            // VisionKit multi-page document scanner (Sprint 13)
            MultiPageDocumentScannerView { images in
                guard !images.isEmpty else {
                    // User cancelled or no images - do nothing
                    return
                }

                // Show loading overlay immediately
                self.isProcessingTransition = true

                if images.count == 1 {
                    // Single page - use existing flow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.capturedImage = images[0]
                    }
                } else {
                    // Multi-page - process batch sequentially
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.multiScanImages = images
                        self.currentMultiScanIndex = 0
                        self.isProcessingMultiScan = true
                        self.isProcessingTransition = false
                        // Process first image
                        self.capturedImage = images[0]
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: Binding(
                get: { [] },
                set: { newImages in
                    guard !newImages.isEmpty else { return }
                    isProcessingTransition = true

                    if newImages.count == 1 {
                        // Single photo - existing flow
                        capturedImage = newImages[0]
                    } else {
                        // Multi-photo - use batch multi-scan flow
                        multiScanImages = newImages
                        currentMultiScanIndex = 0
                        isProcessingMultiScan = true
                        isProcessingTransition = false
                        capturedImage = newImages[0]
                    }
                }
            ))
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                // Show loading overlay immediately
                self.isProcessingTransition = true
                // FIX: Delay to allow sheet dismiss animation to complete
                // before presenting fullScreenCover (SwiftUI sheet conflict fix)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        self.capturedImage = image
                    } else {
                        self.isProcessingTransition = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { capturedImage != nil },
            set: { if !$0 { capturedImage = nil } }
        )) {
            if let image = capturedImage {
                ScannerProcessingView(image: image, onDismiss: {
                    capturedImage = nil
                    isProcessingTransition = false

                    // Multi-scan: Check if more pages to process (Sprint 13)
                    if isProcessingMultiScan && currentMultiScanIndex < multiScanImages.count - 1 {
                        // Process next image
                        currentMultiScanIndex += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            capturedImage = multiScanImages[currentMultiScanIndex]
                        }
                    } else {
                        // All done - reset multi-scan state and navigate
                        isProcessingMultiScan = false
                        multiScanImages = []
                        currentMultiScanIndex = 0

                        // Navigate to Expenses tab after scan closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(AnimationManager.Springs.horizontalSmooth) {
                                selectedTab = 1  // Expenses tab
                            }
                        }
                    }
                })
                .onAppear {
                    // Hide loading overlay when scanner appears
                    isProcessingTransition = false
                }
            }
        }
        // MARK: - Document Archive Scanner (Sprint 13)
        .sheet(isPresented: $showingDocumentScanner) {
            DocumentScannerView { image in
                self.isProcessingDocument = true
                self.documentScanImage = image
                // Process document with classification
                processDocumentScan(image: image)
            }
        }
        .overlay {
            // Processing overlay for document scan
            if isProcessingDocument {
                documentProcessingOverlay
            }
        }
    }

    // MARK: - Document Processing (Sprint 13)

    private var documentProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(LocalizationManager.shared.localized("document.processing"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }

    private func processDocumentScan(image: UIImage) {
        // 1. Perform OCR using processImage
        OCRService.shared.processImage(image) { result in
            switch result {
            case .success(let extractedData):
                let rawText = extractedData.text

                // 2. Classify document using DocumentClassificationService (Sprint 14 - Dynamic Categories)
                DocumentClassificationService.shared.classifyDocument(rawText: rawText, image: image) { classification in
                    // 3. Save to CoreData Document entity with categoryId
                    CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: classification.categoryId,
                        title: classification.title,
                        summary: classification.summary,
                        rawText: rawText,
                        image: image,
                        amount: classification.amount,
                        currency: classification.currency
                    )

                    // 4. Reset states and navigate to Documents tab
                    DispatchQueue.main.async {
                        self.isProcessingDocument = false
                        self.documentScanImage = nil

                        // Navigate to Documents tab
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(AnimationManager.Springs.horizontalSmooth) {
                                self.selectedTab = 3  // Documents tab
                            }
                            LiquidGlassTheme.Haptics.success()
                        }
                    }
                }

            case .failure:
                // Fallback: save with first available category
                DispatchQueue.main.async {
                    let categories = CoreDataManager.shared.fetchDocumentCategories()
                    let defaultCategoryId = categories.first?.id ?? UUID()

                    CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: defaultCategoryId,
                        title: "Document",
                        summary: nil,
                        rawText: nil,
                        image: image,
                        amount: 0,
                        currency: "CHF"
                    )

                    self.isProcessingDocument = false
                    self.documentScanImage = nil

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(AnimationManager.Springs.horizontalSmooth) {
                            self.selectedTab = 3  // Documents tab
                        }
                        LiquidGlassTheme.Haptics.success()
                    }
                }
            }
        }
    }

    // MARK: - Hero Balance - The Centerpiece

    private var heroBalance: some View {
        VStack(spacing: 0) {
            // Personalized greeting with user's name
            if !UserProfileManager.shared.firstName.isEmpty {
                Text("\(viewModel.greeting), \(UserProfileManager.shared.firstName)")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.bottom, 12)
            }

            // Current balance - Compact but clear typography
            VStack(spacing: 2) {
                Text(LocalizationManager.shared.localized("home.today").uppercased())
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .tracking(1.0)

                Text(formatCurrency(viewModel.todaySpending))
                    .font(.system(size: 40, weight: .light, design: .default))
                    .foregroundColor(.primary)
                    .kerning(-1)
            }
            .padding(.bottom, 16)

            // Budget status - Visual truth at a glance
            if budgetManager.monthlyBudget > 0 {
                budgetStatusView
            } else {
                budgetSetupPrompt
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LiquidGlassBackground(
                cornerRadius: 24,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.9
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.primary.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private var budgetStatusView: some View {
        VStack(spacing: 16) {
            // Progress visualization - Minimal, informative
            HStack(spacing: 0) {
                // Used portion
                RoundedRectangle(cornerRadius: 2)
                    .fill(budgetManager.budgetStatus.color)
                    .frame(width: CGFloat(budgetManager.budgetPercentage / 100) * 200, height: 4)

                // Remaining portion
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 200 - CGFloat(budgetManager.budgetPercentage / 100) * 200, height: 4)
            }
            .frame(width: 200, height: 4)

            // Budget details - Essential information only
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationManager.shared.localized("budget.used"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(budgetManager.currentSpending))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(LocalizationManager.shared.localized("budget.remaining"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(formatCurrency(budgetManager.budgetRemaining))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(budgetManager.budgetRemaining >= 0 ? .primary : .red)
                }
            }
            .frame(maxWidth: 200)

            // Budget status message
            Text(budgetManager.budgetStatus.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(budgetManager.budgetStatus.color)
        }
    }

    private var budgetSetupPrompt: some View {
        Button(action: { showBudgetSetup = true }) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.secondary)

                Text(LocalizationManager.shared.localized("budget.set_monthly"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Quick Scan Actions - 3 scan options accessible with thumb

    private var quickActions: some View {
        HStack(spacing: 16) {
            // Camera scan (VisionKit with auto-detection)
            ScanIconButton(
                icon: "camera.fill",
                color: LiquidGlassTheme.Colors.accent,
                action: { showingCamera = true }
            )

            // Photo library
            ScanIconButton(
                icon: "photo.fill",
                color: LiquidGlassTheme.Colors.primary,
                action: { showingImagePicker = true }
            )

            // Document picker (files)
            ScanIconButton(
                icon: "doc.fill",
                color: .orange,
                action: { showingDocumentPicker = true }
            )

            // Document Archive scan (Sprint 13) - archivebox icon
            ScanIconButton(
                icon: "archivebox.fill",
                color: .purple,
                action: { showingDocumentScanner = true }
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight Card - Contextual Intelligence

    private func insightCard(_ insight: String) -> some View {
        HStack(spacing: 12) {
            // Insight icon
            Circle()
                .fill(.orange.opacity(0.7))
                .frame(width: 8, height: 8)

            // Insight text
            Text(insight)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.orange.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Activity Pulse - Minimal Data Visualization

    private var activityPulse: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title + month total
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizationManager.shared.localized("home.current_report"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.unreportedExpenses.count) \(viewModel.unreportedExpenses.count == 1 ? "item" : "items")")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatCurrency(viewModel.currentMonthUnreportedTotal))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            if viewModel.unreportedExpenses.isEmpty {
                Text(LocalizationManager.shared.localized("expenses_empty_title"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Unreported expense items (current month, max 5)
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.unreportedExpenses.prefix(5))) { expense in
                        activityItem(expense)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            LiquidGlassBackground(
                cornerRadius: 24,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.8
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private func activityItem(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            // Category indicator
            Circle()
                .fill(categoryColor(expense.category ?? "Other"))
                .frame(width: 8, height: 8)

            // Expense details
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text(expense.category ?? "Other")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(formatCurrency(expense.amount))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper Functions

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.currency
        formatter.maximumFractionDigits = amount < 100 ? 2 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "CHF 0"
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "food", "restaurant": return .orange
        case "transport": return .blue
        case "shopping": return .purple
        case "entertainment": return .pink
        case "health": return .green
        default: return .gray
        }
    }

    // MARK: - Navigation Actions
    // All scanner functionality now handled by existing ScannerGlassView via tab navigation

    // MARK: - Processing Transition Overlay
    private var processingTransitionOverlay: some View {
        ZStack {
            // Full screen background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            // Processing indicator
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.primary.opacity(0.1), radius: 20, x: 0, y: 10)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                        .rotationEffect(.degrees(isProcessingTransition ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 2).repeatForever(autoreverses: false),
                            value: isProcessingTransition
                        )
                }

                Text(LocalizationManager.shared.localized("processing_receipt"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
        .transition(.opacity)
        .zIndex(100)  // Ensure it's on top
    }
}

// MARK: - Action Button - Jony Ive Minimalism

struct ActionButton: View {
    let icon: String
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(isPrimary ? Color.primary : Color(.secondarySystemBackground))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isPrimary ? Color(.systemBackground) : .primary.opacity(0.7))
                }

                // Title
                Text(LocalizationManager.shared.localized("action.\(title.lowercased())"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scan Icon Button - Compact scan action
struct ScanIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.medium()
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(color)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scanner Processing View - Wrapper for processing scanned image
struct ScannerProcessingView: View {
    let image: UIImage
    let onDismiss: () -> Void
    @State private var isScanning = true

    var body: some View {
        ScannerGlassView(isScanning: $isScanning, autoStartCamera: false, initialImage: image)
            .onChange(of: isScanning) { oldValue, newValue in
                if !newValue {
                    onDismiss()
                }
            }
    }
}

// MARK: - Preview
// NOTE: All scanning functionality is handled by ScannerGlassView.swift

// MARK: - Budget Manager (consolidated - file not in Xcode project)
class BudgetManager: ObservableObject {
    @Published var monthlyBudget: Double = 0
    @Published var currentSpending: Double = 0
    private let userDefaults = UserDefaults.standard

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

    init() {
        monthlyBudget = userDefaults.double(forKey: "monthlyBudget")
        calculateCurrentSpending()
    }

    var budgetRemaining: Double { monthlyBudget - currentSpending }
    var budgetPercentage: Double {
        guard monthlyBudget > 0 else { return 0 }
        return (currentSpending / monthlyBudget) * 100
    }
    var budgetStatus: BudgetStatus {
        let p = budgetPercentage
        switch p {
        case 0..<50: return .excellent
        case 50..<80: return .good
        case 80..<100: return .warning
        default: return .danger
        }
    }
    var smartInsight: String? {
        let p = budgetPercentage
        if p > 90 { return LocalizationManager.shared.localized("budget.insight.limit_reached") }
        else if p > 80 { return LocalizationManager.shared.localized("budget.insight.approaching") }
        return nil
    }

    func setBudget(_ amount: Double) {
        monthlyBudget = amount
        userDefaults.set(amount, forKey: "monthlyBudget")
        objectWillChange.send()
    }

    private func calculateCurrentSpending() {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        currentSpending = CoreDataManager.shared.getTotalSpending(from: startOfMonth, to: Date())
    }
}

// MARK: - Budget Setup Modal
struct BudgetSetupModal: View {
    @ObservedObject var budgetManager: BudgetManager
    @State private var budgetAmount: String = ""
    @Binding var isPresented: Bool
    private let presets: [Double] = [500, 1000, 1500, 2000, 2500, 3000]

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 40) {
                Text(LocalizationManager.shared.localized("budget.monthly"))
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                VStack(spacing: 20) {
                    HStack {
                        Text(getCurrencySymbol())
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("0", text: $budgetAmount)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                    }
                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                }
                .padding(.horizontal, 40)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(presets, id: \.self) { amount in
                        Button(action: { budgetAmount = String(Int(amount)) }) {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text("\(getCurrencySymbol())\(Int(amount))")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .padding(.horizontal, 40)
                Spacer()
                VStack(spacing: 16) {
                    Button(action: {
                        if let amount = Double(budgetAmount), amount > 0 {
                            budgetManager.setBudget(amount)
                            isPresented = false
                        }
                    }) {
                        Text(LocalizationManager.shared.localized("action.save"))
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
                        Text(LocalizationManager.shared.localized("action.cancel"))
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

    private func getCurrencySymbol() -> String {
        let currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "CHF"
        switch currency {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "
        case "JPY", "CNY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        default: return currency + " "
        }
    }
}

// MARK: - HomeViewModel & Data Models

class HomeViewModel: ObservableObject {
    @Published var greeting = LocalizationManager.shared.localized("home.good_morning")
    @Published var dateText = ""
    @Published var todaySpending: Double = 0
    @Published var currency: String = "CHF"
    @Published var recentExpenses: [Expense] = []
    @Published var unreportedExpenses: [Expense] = []
    @Published var currentMonthUnreportedTotal: Double = 0
    @Published var currentMonthName: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        currency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "CHF"
        loadRecentExpenses()
    }

    func updateDateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        dateText = formatter.string(from: Date())

        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            greeting = LocalizationManager.shared.localized("home.good_morning")
        } else if hour < 18 {
            greeting = LocalizationManager.shared.localized("home.good_afternoon")
        } else {
            greeting = LocalizationManager.shared.localized("home.good_evening")
        }

        // Current month name
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        currentMonthName = monthFormatter.string(from: Date()).capitalized
    }

    func loadRecentExpenses() {
        recentExpenses = CoreDataManager.shared.fetchRecentExpenses(limit: 5)

        // Calculate today's spending
        let calendar = Calendar.current
        let todayExpenses = recentExpenses.filter {
            guard let date = $0.date else { return false }
            return calendar.isDateInToday(date)
        }
        todaySpending = todayExpenses.reduce(0) { $0 + $1.amount }

        // Load unreported expenses (reportId == nil) for "Rapport courant"
        loadUnreportedExpenses()
    }

    private func loadUnreportedExpenses() {
        let allExpenses = CoreDataManager.shared.fetchExpenses()

        // Filter: all unreported expenses (buffer)
        unreportedExpenses = allExpenses
            .filter { $0.reportId == nil }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        currentMonthUnreportedTotal = unreportedExpenses.reduce(0) { $0 + $1.amount }
    }

    func updateTodaysSpending() {
        let calendar = Calendar.current
        let todayExpenses = recentExpenses.filter {
            guard let date = $0.date else { return false }
            return calendar.isDateInToday(date)
        }
        todaySpending = todayExpenses.reduce(0) { $0 + $1.amount }
    }
}

struct HomeGlassView_Previews: PreviewProvider {
    static var previews: some View {
        HomeGlassView(selectedTab: .constant(0))
    }
}