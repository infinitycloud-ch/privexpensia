import SwiftUI
import VisionKit
import PhotosUI

// MARK: - Extraction Method Tag
enum ExtractionMethodTag: String {
    case parser = "Parser"
    case qwenAI = "Qwen AI"
    case groqVision = "Groq Vision"
    case openAIVision = "OpenAI Vision"
    case visionFramework = "Vision OCR"
    case unknown = "Unknown"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .parser: return "function"
        case .qwenAI: return "brain"
        case .groqVision: return "bolt.fill"
        case .openAIVision: return "brain.head.profile"
        case .visionFramework: return "eye"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .parser: return .blue
        case .qwenAI: return .purple
        case .groqVision: return .orange
        case .openAIVision: return .green
        case .visionFramework: return .cyan
        case .unknown: return .gray
        }
    }
}

// MARK: - Extracted Expense Data for UI
struct ExtractedExpenseData {
    var merchant: String
    var totalAmount: Double
    var taxAmount: Double
    var date: Date
    var category: String
    var items: String?
    var paymentMethod: String?
    var confidence: Double
    var rawOCRText: String?  // Sprint 5: Pour Enhance AI
    var extractionMethod: ExtractionMethodTag = .unknown  // Tag for which method was used
}

// MARK: - Scanner View with Glass UI
// Simplified: scan options moved to Home page, this view only handles processing
struct ScannerGlassView: View {
    @Binding var isScanning: Bool
    var autoStartCamera: Bool = false
    var initialImage: UIImage? = nil  // Image passed from Home page scan

    @State private var showingResult = false
    @State private var extractedData: ExtractedExpenseData?
    @State private var currentImage: UIImage?
    @State private var isProcessing = false
    @State private var scanProgress: Double = 0
    @State private var extractionFailed = false
    @State private var extractionErrorMessage: String = ""
    @State private var lastSavedExpense: Expense?  // Track last auto-saved expense for deletion

    var body: some View {
        ZStack {
            // Background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            if isProcessing {
                processingView
            } else if extractionFailed {
                extractionErrorView
            } else if showingResult, let data = extractedData {
                ResultGlassView(data: data, receiptImage: currentImage, onSave: { _ in
                    closeResultView()
                }, onRetry: retry, onDelete: deleteLastSavedExpense)
            } else {
                // Waiting for image or showing processing
                processingView
            }
        }
        .onAppear {
            // Process initial image immediately (from Home page scan)
            if let image = initialImage {
                isProcessing = true
                processScannedImage(image)
            }
        }
    }
    
    // MARK: - Processing View (scan options now on Home page)
    private var processingView: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing32) {
            Spacer()
            
            // Animated Scanner Icon
            ZStack {
                Circle()
                    .fill(LiquidGlassTheme.Colors.glassBase)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .rotationEffect(.degrees(scanProgress * 360))
                    .animation(
                        Animation.linear(duration: 2)
                            .repeatForever(autoreverses: false),
                        value: scanProgress
                    )
            }
            
            VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("processing_receipt"))
                    .font(LiquidGlassTheme.Typography.title1)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Text(LocalizationManager.shared.localized("processing_receipt_ai"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            }
            
            // Progress Bar
            ProgressView(value: scanProgress)
                .progressViewStyle(GlassProgressViewStyle())
                .frame(width: 200)
            
            Spacer()
        }
        .onAppear {
            withAnimation {
                scanProgress = 1.0
            }
        }
    }

    // MARK: - Extraction Error View
    private var extractionErrorView: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing24) {
            Spacer()

            // Error Icon
            ZStack {
                Circle()
                    .fill(LiquidGlassTheme.Colors.error.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(LiquidGlassTheme.Colors.error)
            }

            // Error Title
            Text(LocalizationManager.shared.localized("extraction.error.title"))
                .font(LiquidGlassTheme.Typography.title1)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            // Error Message
            Text(extractionErrorMessage.isEmpty
                ? LocalizationManager.shared.localized("extraction.error.message")
                : extractionErrorMessage)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Tips Card
            GlassCard {
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                    Text(LocalizationManager.shared.localized("extraction.error.tips_title"))
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        tipRow(icon: "sun.max.fill", text: LocalizationManager.shared.localized("extraction.error.tip_lighting"))
                        tipRow(icon: "rectangle.dashed", text: LocalizationManager.shared.localized("extraction.error.tip_frame"))
                        tipRow(icon: "hand.raised.fill", text: LocalizationManager.shared.localized("extraction.error.tip_steady"))
                        tipRow(icon: "doc.plaintext", text: LocalizationManager.shared.localized("extraction.error.tip_readable"))
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Action Button - Return to Home to retry
            VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                Button(action: {
                    // Close scanner and return to Home page to retry
                    extractionFailed = false
                    extractionErrorMessage = ""
                    isScanning = false
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(LocalizationManager.shared.localized("extraction.error.retry_camera"))
                    }
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LiquidGlassTheme.Colors.accent)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 24)
            Text(text)
                .font(LiquidGlassTheme.Typography.footnote)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
    }

    // MARK: - Actions
    private func processScannedImage(_ image: UIImage) {
        currentImage = image  // Stocker l'image pour la sauvegarde
        isProcessing = true
        scanProgress = 0

        // 🚀 CRITICAL: Clear cache before new scan to prevent stale results (fix bug 220.9)
        QwenModelManager.shared.clearCacheForNewScan()


        // SPRINT 3: Utilisation du pipeline unifié qui gère tout
        processWithUnifiedPipeline(image)
    }

    // 🚀 SPRINT 9: Pipeline unifié simplifié
    private func processWithUnifiedPipeline(_ image: UIImage) {
        // Start animated progress
        withAnimation(.linear(duration: 1.5)) {
            scanProgress = 0.3
        }

        // 🚀 Sprint 9: Mode d'extraction simplifié
        // - Si Cloud Vision configuré: .forceCloud (Groq/OpenAI direct)
        // - Sinon: .auto (Parser → Cloud fallback si disponible)
        let cloudConfigured = CloudVisionService.shared.isEnabled && CloudVisionService.shared.isConfigured
        let extractionMode: ExtractionMode = cloudConfigured ? .forceCloud : .auto

        // 🚀 SPRINT 9: Utiliser le UnifiedPipelineManager avec Cloud Vision
        let unifiedPipeline = UnifiedPipelineManager.shared
        unifiedPipeline.extractExpense(from: image, extractionMode: extractionMode) { result in
            DispatchQueue.main.async {
                self.handleUnifiedPipelineResult(result)
            }
        }
    }

    // 🚀 SPRINT 3.2: Gestionnaire de résultat du pipeline unifié
    private func handleUnifiedPipelineResult(_ result: Result<UnifiedPipelineManager.UnifiedResult, Error>) {
        withAnimation(.linear(duration: 0.3)) {
            scanProgress = 1.0
        }

        switch result {
        case .success(let unifiedResult):
            // 🔍 DEBUG: Afficher les logs dans la console Xcode
            print("═══════════════════════════════════════════")
            print("🎯 PIPELINE RESULT - \(unifiedResult.pipelineUsed)")
            print("═══════════════════════════════════════════")
            print("📊 Confidence: \(String(format: "%.1f%%", unifiedResult.confidence * 100))")
            print("⏱️ Processing Time: \(String(format: "%.2fs", unifiedResult.processingTime))")
            print("🏪 Merchant: \(unifiedResult.extractedData.merchant)")
            print("💰 Amount: \(unifiedResult.extractedData.totalAmount) \(unifiedResult.extractedData.currency)")
            print("📅 Date: \(unifiedResult.extractedData.date)")
            print("🏷️ Category: \(unifiedResult.extractedData.category)")
            print("───────────────────────────────────────────")
            print("📝 LOGS (\(unifiedResult.logs.count) entries):")
            for log in unifiedResult.logs.suffix(20) {
                print("   \(log)")
            }
            print("═══════════════════════════════════════════")

            // Convertir UnifiedResult vers ExtractedExpenseData pour l'UI
            let extractedData = ExtractedExpenseData(
                merchant: unifiedResult.extractedData.merchant,
                totalAmount: unifiedResult.extractedData.totalAmount,
                taxAmount: unifiedResult.extractedData.taxAmount,
                date: unifiedResult.extractedData.date,
                category: unifiedResult.extractedData.category,
                items: nil,  // 🚀 UnifiedExpenseData n'a pas items
                paymentMethod: nil,  // 🚀 UnifiedExpenseData n'a pas paymentMethod
                confidence: unifiedResult.confidence,
                rawOCRText: unifiedResult.extractedData.rawText,  // Sprint 5: Pour Enhance AI
                extractionMethod: self.parseExtractionMethod(unifiedResult.pipelineUsed)
            )

            withAnimation(AnimationManager.Glass.fadeIn) {
                self.extractedData = extractedData
                self.isProcessing = false

                // AUTO-SAVE: Sauvegarder immédiatement après extraction
                self.autoSaveExpense(extractedData)

                self.showingResult = true
            }

        case .failure(let error):
            // 🔍 DEBUG: Afficher l'erreur dans la console
            print("═══════════════════════════════════════════")
            print("❌ PIPELINE ERROR")
            print("═══════════════════════════════════════════")
            print("Error: \(error.localizedDescription)")
            print("═══════════════════════════════════════════")

            // Fallback vers l'ancien système en cas d'erreur
            self.performFallbackExtraction(from: self.currentImage ?? UIImage())
        }
    }

    // Fonction de transition utilisant le parser amélioré avec Swiss fallback
    private func processWithEnhancedParser(_ image: UIImage) {
        let ocrService = OCRService.shared

        withAnimation(.linear(duration: 0.8)) {
            scanProgress = 0.5
        }

        ocrService.processImage(image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrData):

                    withAnimation(.linear(duration: 0.5)) {
                        self.scanProgress = 0.8
                    }

                    // SPRINT 3: Utiliser le parser amélioré avec Swiss fallback
                    let expenseParser = ExpenseParser.shared
                    let parsedExpense = expenseParser.parseFromOCRResult(ocrData)


                    // Convert to UI format
                    let extractedData = ExtractedExpenseData(
                        merchant: parsedExpense.merchant,
                        totalAmount: parsedExpense.totalAmount,
                        taxAmount: parsedExpense.vatAmount,
                        date: parsedExpense.date,
                        category: parsedExpense.category,
                        items: parsedExpense.items.joined(separator: ", "),
                        paymentMethod: parsedExpense.paymentMethod,
                        confidence: 0.75,
                        rawOCRText: ocrData.text,
                        extractionMethod: .parser
                    )

                    withAnimation(AnimationManager.Glass.fadeIn) {
                        self.extractedData = extractedData
                        self.isProcessing = false

                        // AUTO-SAVE: Sauvegarder immédiatement après extraction
                        self.autoSaveExpense(extractedData)

                        self.showingResult = true
                        self.scanProgress = 1.0

                        // Success haptic
                        LiquidGlassTheme.Haptics.success()
                    }

                case .failure(let error):
                    self.performFallbackExtraction(from: image)
                }
            }
        }
    }

    // SUPPRIMÉ: processImageSimpleMode - remplacé par processWithUnifiedPipeline

// Fallback extraction using ExpenseParser
    private func performFallbackExtraction(from image: UIImage) {
        // Use OCR directly with fallback parser
        let ocrService = OCRService.shared

        ocrService.processImage(image) { result in

            DispatchQueue.main.async {
                switch result {
                case .success(let ocrData):
                    // Use ExpenseParser as backup
                    let parser = ExpenseParser.shared
                    let parsed = parser.parseExpense(from: ocrData.text)

                    let extractedData = ExtractedExpenseData(
                        merchant: parsed.merchant,
                        totalAmount: parsed.totalAmount,
                        taxAmount: parsed.vatAmount,
                        date: parsed.date,
                        category: parsed.category,
                        items: nil,
                        paymentMethod: parsed.paymentMethod,
                        confidence: 0.6,
                        rawOCRText: ocrData.text,
                        extractionMethod: .visionFramework  // Fallback uses Vision OCR
                    )

                    withAnimation(AnimationManager.Glass.fadeIn) {
                        self.extractedData = extractedData
                        self.isProcessing = false

                        // AUTO-SAVE: Sauvegarder immédiatement après extraction
                        self.autoSaveExpense(extractedData)

                        self.showingResult = true

                        // Light haptic for fallback
                        LiquidGlassTheme.Haptics.light()
                    }

                case .failure(let error):
                    // Complete failure - show user-friendly error view
                    self.isProcessing = false
                    self.extractionFailed = true
                    self.extractionErrorMessage = error.localizedDescription

                    // Error haptic
                    LiquidGlassTheme.Haptics.error()
                }
            }
        }
    }
    
    // AUTO-SAVE: Sauvegarde automatique après extraction (sans reset UI)
    private func autoSaveExpense(_ data: ExtractedExpenseData) {
        let coreDataManager = CoreDataManager.shared

        let expense = coreDataManager.saveExpense(
            merchant: data.merchant,
            amount: data.totalAmount,
            tax: data.taxAmount,
            category: data.category,
            date: data.date,
            items: (data.items ?? "").components(separatedBy: ", "),
            paymentMethod: data.paymentMethod ?? "Card",
            image: currentImage,
            rawOCRText: data.rawOCRText
        )

        // Store for potential deletion
        lastSavedExpense = expense
    }

    // DELETE: Supprimer la dernière dépense sauvegardée
    private func deleteLastSavedExpense() {
        guard let expense = lastSavedExpense else { return }

        CoreDataManager.shared.deleteExpense(expense)
        lastSavedExpense = nil

        // Haptic feedback
        LiquidGlassTheme.Haptics.success()

        // Close and return
        closeResultView()
    }

    private func saveExpense(editedData: ExtractedExpenseData) {
        // SPRINT 3: Utiliser les données éditées par l'utilisateur
        let coreDataManager = CoreDataManager.shared

        // Sauvegarder avec les données potentiellement modifiées par l'utilisateur
        // Sprint 5: Inclut rawOCRText pour Enhance AI
        coreDataManager.saveExpense(
            merchant: editedData.merchant,
            amount: editedData.totalAmount,
            tax: editedData.taxAmount,
            category: editedData.category,
            date: editedData.date,
            items: (editedData.items ?? "").components(separatedBy: ", "),
            paymentMethod: editedData.paymentMethod ?? "Card",
            image: currentImage,
            rawOCRText: editedData.rawOCRText
        )

        // Success feedback
        LiquidGlassTheme.Haptics.success()

        // Log success with currency

        // Reset UI
        isScanning = false
        showingResult = false
        extractedData = nil
    }
    
    // AUTO-SAVE: Fermer la vue résultat sans re-sauvegarder
    private func closeResultView() {
        LiquidGlassTheme.Haptics.light()
        isScanning = false
        showingResult = false
        extractedData = nil
    }

    private func retry() {
        showingResult = false
        extractedData = nil
    }

    // Parse pipeline string to ExtractionMethodTag
    private func parseExtractionMethod(_ pipelineUsed: String) -> ExtractionMethodTag {
        let lower = pipelineUsed.lowercased()
        if lower.contains("parser") || lower.contains("regex") || lower.contains("heuristic") {
            return .parser
        } else if lower.contains("qwen") {
            return .qwenAI
        } else if lower.contains("groq") {
            return .groqVision
        } else if lower.contains("openai") || lower.contains("gpt") {
            return .openAIVision
        } else if lower.contains("vision") || lower.contains("ocr") {
            return .visionFramework
        }
        return .unknown
    }

    private func loadImage(from url: URL) -> UIImage? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url) {
            if let image = UIImage(data: data) {
                return image
            } else if let pdfImage = convertPDFToImage(data: data) {
                return pdfImage
            }
        }
        return nil
    }

    private func convertPDFToImage(data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let pdfPage = pdfDoc.page(at: 1) else {
            return nil
        }

        let pageRect = pdfPage.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(pdfPage)
        }

        return image
    }
}

// ScanOptionCard removed - scan options now on Home page

// MARK: - Result View
struct ResultGlassView: View {
    let data: ExtractedExpenseData
    let receiptImage: UIImage?
    let onSave: (ExtractedExpenseData) -> Void
    let onRetry: () -> Void
    var onEnhanceWithAI: ((UIImage) -> Void)? = nil  // Optional AI enhancement callback
    var onDelete: (() -> Void)? = nil  // Delete callback to remove auto-saved expense

    @State private var editedMerchant: String
    @State private var editedAmount: String
    @State private var editedTax: String
    @State private var editedCategory: String
    @State private var editedPayment: String
    @State private var isEditing = false
    @State private var showFullScreenReceipt = false
    @State private var showDeleteConfirmation = false

    // Countdown states
    @State private var countdownSeconds: Int = 4
    @State private var countdownActive: Bool = true
    @State private var countdownTimer: Timer?

    private let categories = ["Food", "Restaurant", "Transport", "Shopping", "Health", "Entertainment", "Hotel", "Other"]

    init(data: ExtractedExpenseData, receiptImage: UIImage? = nil, onSave: @escaping (ExtractedExpenseData) -> Void, onRetry: @escaping () -> Void, onEnhanceWithAI: ((UIImage) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.data = data
        self.receiptImage = receiptImage
        self.onSave = onSave
        self.onRetry = onRetry
        self.onEnhanceWithAI = onEnhanceWithAI
        self.onDelete = onDelete
        self._editedMerchant = State(initialValue: data.merchant)
        self._editedAmount = State(initialValue: String(format: "%.2f", data.totalAmount))
        self._editedTax = State(initialValue: String(format: "%.2f", data.taxAmount))
        self._editedCategory = State(initialValue: data.category)
        self._editedPayment = State(initialValue: data.paymentMethod ?? "Card")
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                    // Header with confidence indicator and countdown
                    headerSection

                    // Editable Data Card
                    GlassCard {
                        VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                            // Merchant
                            editableRow(
                                label: LocalizationManager.shared.localized("expense.field.merchant"),
                                text: $editedMerchant,
                                icon: "storefront"
                            )
                            Divider().background(LiquidGlassTheme.Colors.textQuaternary)

                            // Amount
                            editableAmountRow(
                                label: LocalizationManager.shared.localized("expense.field.amount"),
                                text: $editedAmount,
                                icon: "banknote"
                            )
                            Divider().background(LiquidGlassTheme.Colors.textQuaternary)

                            // Tax
                            editableAmountRow(
                                label: LocalizationManager.shared.localized("expense.field.tax"),
                                text: $editedTax,
                                icon: "percent"
                            )
                            Divider().background(LiquidGlassTheme.Colors.textQuaternary)

                            // Category (Picker when editing)
                            categoryRow
                            Divider().background(LiquidGlassTheme.Colors.textQuaternary)

                            // Payment
                            editableRow(
                                label: LocalizationManager.shared.localized("expense.field.payment"),
                                text: $editedPayment,
                                icon: "creditcard"
                            )
                        }
                    }

                    // Actions
                    actionButtons

                    // Receipt Image Preview - For visual verification
                    if let image = receiptImage {
                        receiptPreviewSection(image: image)
                    }
                }
            }

            // Countdown overlay - tap anywhere to cancel
            if countdownActive {
                countdownOverlay
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            cancelCountdown()
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
        .fullScreenCover(isPresented: $showFullScreenReceipt) {
            if let image = receiptImage {
                FullScreenReceiptView(image: image, isPresented: $showFullScreenReceipt)
            }
        }
    }

    // MARK: - Countdown Overlay (top-left corner)
    private var countdownOverlay: some View {
        VStack {
            HStack {
                // Top-left countdown pill
                HStack(spacing: 8) {
                    Text("\(countdownSeconds)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizationManager.shared.localized("result.auto_close"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Text(LocalizationManager.shared.localized("result.tap_to_stay"))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                )

                Spacer()
            }
            .padding(.leading, 20)
            .padding(.top, 60)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Countdown Functions
    private func startCountdown() {
        countdownActive = true
        countdownSeconds = 4  // 4 seconds countdown

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownSeconds > 1 {
                countdownSeconds -= 1
            } else {
                timer.invalidate()
                // Auto-close and save
                let editedData = ExtractedExpenseData(
                    merchant: editedMerchant,
                    totalAmount: Double(editedAmount) ?? data.totalAmount,
                    taxAmount: Double(editedTax) ?? data.taxAmount,
                    date: data.date,
                    category: editedCategory,
                    items: data.items,
                    paymentMethod: editedPayment,
                    confidence: data.confidence,
                    rawOCRText: data.rawOCRText
                )
                onSave(editedData)
            }
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownActive = false
        LiquidGlassTheme.Haptics.light()
    }

    // MARK: - Receipt Preview Section
    private func receiptPreviewSection(image: UIImage) -> some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            // Header
            HStack {
                Image(systemName: "doc.text.image")
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                Text(LocalizationManager.shared.localized("receipt.preview.title"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Spacer()

                // Tap to expand hint
                Button(action: {
                    showFullScreenReceipt = true
                    LiquidGlassTheme.Haptics.light()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                        Text(LocalizationManager.shared.localized("receipt.preview.expand"))
                            .font(LiquidGlassTheme.Typography.caption1)
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)

            // Receipt Image - Scrollable and tappable
            Button(action: {
                showFullScreenReceipt = true
                LiquidGlassTheme.Haptics.light()
            }) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                            .stroke(LiquidGlassTheme.Colors.glassBase, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)

            // Verification hint
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(LiquidGlassTheme.Colors.success)
                Text(LocalizationManager.shared.localized("receipt.preview.verify_hint"))
                    .font(LiquidGlassTheme.Typography.caption1)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            }
            .padding(.bottom, LiquidGlassTheme.Layout.spacing20)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(LiquidGlassTheme.Colors.success)

            Text("Dépense enregistrée")
                .font(LiquidGlassTheme.Typography.title1)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            // Badges row: Confidence + Extraction Method
            HStack(spacing: 8) {
                // Confidence Badge
                confidenceBadge

                // Extraction Method Badge
                extractionMethodBadge
            }
        }
        .padding(.top, LiquidGlassTheme.Layout.spacing20)
    }

    // MARK: - Extraction Method Badge
    private var extractionMethodBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: data.extractionMethod.icon)
                .font(.system(size: 12, weight: .medium))

            Text(data.extractionMethod.displayName)
                .font(LiquidGlassTheme.Typography.caption1)
                .fontWeight(.medium)
        }
        .foregroundColor(data.extractionMethod.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(data.extractionMethod.color.opacity(0.15))
        )
    }

    // MARK: - Confidence Badge (Task 652)
    private var confidenceBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            Text(confidenceText)
                .font(LiquidGlassTheme.Typography.caption1)
                .fontWeight(.medium)

            Text("(\(Int(data.confidence * 100))%)")
                .font(LiquidGlassTheme.Typography.caption2)
        }
        .foregroundColor(confidenceColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(confidenceColor.opacity(0.15))
        )
    }

    private var confidenceColor: Color {
        if data.confidence >= 0.8 { return .green }
        else if data.confidence >= 0.5 { return .orange }
        else { return .red }
    }

    private var confidenceText: String {
        if data.confidence >= 0.8 {
            return LocalizationManager.shared.localized("confidence.high")
        } else if data.confidence >= 0.5 {
            return LocalizationManager.shared.localized("confidence.medium")
        } else {
            return LocalizationManager.shared.localized("confidence.low")
        }
    }

    // MARK: - Editable Rows
    private func editableRow(label: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 24)

            Text(label)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

            Spacer()

            if isEditing {
                TextField(label, text: text)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(PlainTextFieldStyle())
            } else {
                Text(text.wrappedValue)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            }
        }
    }

    private func editableAmountRow(label: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 24)

            Text(label)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                Text(CurrencyManager.shared.symbol)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(isEditing ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textPrimary)

                if isEditing {
                    TextField("0.00", text: text)
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 80)
                } else {
                    Text(text.wrappedValue)
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                }
            }
        }
    }

    // MARK: - Category Row
    private var categoryRow: some View {
        HStack {
            Image(systemName: "tag")
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 24)

            Text(LocalizationManager.shared.localized("expense.field.category"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

            Spacer()

            if isEditing {
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) {
                            editedCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Text(editedCategory)
                            .font(LiquidGlassTheme.Typography.headline)
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                    }
                }
            } else {
                Text(editedCategory)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            // AUTO-SAVE: La dépense est déjà sauvegardée, ce bouton ferme juste la vue
            GlassButton(LocalizationManager.shared.localized("button.done"), icon: "checkmark.circle.fill") {
                countdownTimer?.invalidate()
                let editedData = ExtractedExpenseData(
                    merchant: editedMerchant,
                    totalAmount: Double(editedAmount) ?? data.totalAmount,
                    taxAmount: Double(editedTax) ?? data.taxAmount,
                    date: data.date,
                    category: editedCategory,
                    items: data.items,
                    paymentMethod: editedPayment,
                    confidence: data.confidence,
                    rawOCRText: data.rawOCRText
                )
                onSave(editedData)
            }

            HStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                Button(action: {
                    cancelCountdown()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                        Text(isEditing
                            ? LocalizationManager.shared.localized("button.done")
                            : LocalizationManager.shared.localized("edit.button"))
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing12)
                    .background(
                        LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium, material: LiquidGlassTheme.LiquidGlass.regular)
                            .opacity(0.5)
                    )
                }

                Button(action: {
                    cancelCountdown()
                    onRetry()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(LocalizationManager.shared.localized("button_retry"))
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing12)
                    .background(
                        LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium, material: LiquidGlassTheme.LiquidGlass.regular)
                            .opacity(0.5)
                    )
                }
            }

            // Process with AI button (only shown when countdown cancelled and image available)
            if !countdownActive, let image = receiptImage, onEnhanceWithAI != nil {
                Button(action: {
                    onEnhanceWithAI?(image)
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text(LocalizationManager.shared.localized("result.enhance_with_ai"))
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(LiquidGlassTheme.Layout.cornerRadiusMedium)
                }
            }

            // Delete button (only shown when countdown cancelled)
            if !countdownActive, onDelete != nil {
                Button(action: {
                    showDeleteConfirmation = true
                    LiquidGlassTheme.Haptics.warning()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text(LocalizationManager.shared.localized("button.delete"))
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing12)
                    .background(
                        LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium, material: LiquidGlassTheme.LiquidGlass.regular)
                            .opacity(0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                            .stroke(LiquidGlassTheme.Colors.error.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
        .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
        .alert(LocalizationManager.shared.localized("delete.confirmation.title"), isPresented: $showDeleteConfirmation) {
            Button(LocalizationManager.shared.localized("button.cancel"), role: .cancel) { }
            Button(LocalizationManager.shared.localized("button.delete"), role: .destructive) {
                onDelete?()
            }
        } message: {
            Text(LocalizationManager.shared.localized("delete.confirmation.message"))
        }
    }
}

// MARK: - Data Row
struct DataRow: View {
    let label: String
    let value: String
    @Binding var isEditing: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            
            Spacer()
            
            if isEditing {
                // TODO: Make editable
                Text(value)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
            } else {
                Text(value)
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            }
        }
    }
}

// MARK: - Document Scanner View (Single Page)
struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (UIImage) -> Void

        init(completion: @escaping (UIImage) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                completion(image)
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Multi-Page Document Scanner View (Sprint 13)
// Scans multiple pages and returns all images for batch expense processing
struct MultiPageDocumentScannerView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: ([UIImage]) -> Void

        init(completion: @escaping ([UIImage]) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Collect ALL scanned pages
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }

            if !images.isEmpty {
                completion(images)
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Image Picker (Multi-select)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // 0 = unlimited
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(images: $images)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var images: [UIImage]

        init(images: Binding<[UIImage]>) {
            _images = images
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            var loadedImages: [(Int, UIImage)] = []

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

                group.enter()
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            loadedImages.append((index, uiImage))
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                // Delay to allow sheet dismiss animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Sort by original selection order
                    self.images = loadedImages.sorted { $0.0 < $1.0 }.map { $0.1 }
                }
            }
        }
    }
}

// MARK: - Glass Progress View Style
struct GlassProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusSmall)
                .fill(LiquidGlassTheme.Colors.glassBase)
                .frame(height: 8)

            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusSmall)
                .fill(
                    LinearGradient(
                        colors: [
                            LiquidGlassTheme.Colors.accent,
                            LiquidGlassTheme.Colors.primary
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: CGFloat(configuration.fractionCompleted ?? 0) * 200, height: 8)
                .animation(AnimationManager.Springs.horizontalSmooth, value: configuration.fractionCompleted)
        }
    }
}

// MARK: - Full Screen Receipt View
struct FullScreenReceiptView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Zoomable & Pannable Receipt Image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation(.spring()) {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                            if scale <= 1 {
                                withAnimation(.spring()) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                        LiquidGlassTheme.Haptics.light()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()

                // Zoom hint
                if scale == 1 {
                    HStack {
                        Image(systemName: "hand.pinch")
                        Text(LocalizationManager.shared.localized("receipt.fullscreen.zoom_hint"))
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 40)
                }
            }
        }
    }
}