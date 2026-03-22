import SwiftUI
import CoreData

// MARK: - Expense Detail View with Glass Panels
struct ExpenseDetailGlassView: View {
    @State var expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyManager: CurrencyManager
    @State private var showDeleteConfirmation = false
    @State private var hasChanges = false
    @State private var panelAppear = false
    @State private var dragOffset: CGSize = .zero
    @State private var showFullScreenImage = false

    // Edit state
    @State private var editedMerchant: String = ""
    @State private var editedAmount: String = ""
    @State private var editedCategory: String = ""
    @State private var editedDate = Date()

    // Sprint 5: Enhance AI state
    @State private var showEnhanceAISheet = false
    @State private var selectedFieldsToCorrect: Set<EnhanceAIService.CorrectionField> = []
    @State private var isEnhancing = false
    @State private var enhanceResult: EnhanceAIService.CorrectionResult?
    @State private var showEnhanceResultAlert = false
    @State private var showEnhanceErrorAlert = false
    @State private var enhanceErrorMessage = ""

    // Cloud Vision state
    @State private var isCloudVisionProcessing = false
    @State private var cloudVisionResult: CloudVisionService.ExtractionResult?
    @State private var showCloudVisionResultAlert = false
    @State private var showCloudVisionErrorAlert = false
    @State private var cloudVisionErrorMessage = ""
    
    var body: some View {
        ZStack {
            // Full screen blur background
            backgroundView
            
            // Content with swipe gesture
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Layout.spacing20) {
                    // Header
                    headerSection
                    
                    // Receipt image panel (if available)
                    if let imageData = expense.receiptImageData,
                       let uiImage = UIImage(data: imageData) {
                        receiptImagePanel(uiImage)
                            .glassAppear(isVisible: panelAppear)
                            .animation(AnimationManager.chainedAnimation(step: 0), value: panelAppear)
                    }

                    // Main info panel
                    mainInfoPanel
                        .glassAppear(isVisible: panelAppear)
                        .animation(AnimationManager.chainedAnimation(step: 1), value: panelAppear)

                    // Details panel
                    detailsPanel
                        .glassAppear(isVisible: panelAppear)
                        .animation(AnimationManager.chainedAnimation(step: 2), value: panelAppear)
                    
                    // Items panel (if available)
                    if let items = expense.items, !items.isEmpty {
                        itemsPanel(items)
                            .glassAppear(isVisible: panelAppear)
                            .animation(AnimationManager.chainedAnimation(step: 4), value: panelAppear)
                    }
                    
                    // Actions
                    actionsSection
                        .glassAppear(isVisible: panelAppear)
                        .animation(AnimationManager.chainedAnimation(step: 3), value: panelAppear)
                }
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
                .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
            }
            .offset(x: dragOffset.width)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow left swipe (negative width)
                        if value.translation.width < 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        // If swiped far enough left, show delete confirmation
                        if value.translation.width < -100 {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                                showDeleteConfirmation = true
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
        }
        .onAppear {
            setupEditState()
            withAnimation(AnimationManager.Glass.cardAppear) {
                panelAppear = true
            }
        }
        .confirmationDialog("Delete Expense", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteExpense()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(LocalizationManager.shared.localized("delete_expense_confirmation"))
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            // Mesh gradient overlay
            GeometryReader { geometry in
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassTheme.Colors.meshColors[index].opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(
                            x: CGFloat.random(in: -100...geometry.size.width),
                            y: CGFloat.random(in: -100...geometry.size.height)
                        )
                        .blur(radius: 60)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button(action: {
                if hasChanges {
                    saveChanges()
                }
                dismiss()
            }) {
                HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                    Image(systemName: "chevron.left")
                    Text(LocalizationManager.shared.localized("button_back"))
                }
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            }

            Spacer()

            if hasChanges {
                Button(action: saveChanges) {
                    Text(LocalizationManager.shared.localized("save_changes"))
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
        }
        .padding(.vertical, LiquidGlassTheme.Layout.spacing16)
    }
    
    // MARK: - Main Info Panel
    private var mainInfoPanel: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                // Merchant - directly editable
                GlassTextField(placeholder: "Merchant", text: Binding(
                    get: { editedMerchant },
                    set: { editedMerchant = $0; hasChanges = true }
                ), icon: "storefront")

                Divider()
                    .background(LiquidGlassTheme.Colors.textQuaternary)

                // Amount - directly editable with currency prefix
                HStack {
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing4) {
                        Text(LocalizationManager.shared.localized("total_amount"))
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                            // Amount first, then currency (Swiss format: 43.50 CHF)
                            TextField("0.00", text: Binding(
                                get: { editedAmount },
                                set: { editedAmount = $0; hasChanges = true }
                            ))
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                            .keyboardType(.decimalPad)

                            // Currency suffix (e.g., "CHF") - same size, black
                            Text(currencyManager.symbol.trimmingCharacters(in: .whitespaces))
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        }
                        .padding(LiquidGlassTheme.Layout.spacing12)
                        .background(
                            LiquidGlassBackground(
                                cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                                material: LiquidGlassTheme.LiquidGlass.thin,
                                intensity: 0.5
                            )
                        )
                    }

                    Spacer()

                    if expense.taxAmount > 0 {
                        VStack(alignment: .trailing, spacing: LiquidGlassTheme.Layout.spacing4) {
                            Text(LocalizationManager.shared.localized("tax"))
                                .font(LiquidGlassTheme.Typography.caption2)
                                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)

                            // Tax: smaller amount with tiny CHF
                            HStack(spacing: 2) {
                                Text(String(format: "%.2f", expense.taxAmount))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                                Text(currencyManager.symbol.trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Receipt Image Panel
    private func receiptImagePanel(_ image: UIImage) -> some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                HStack {
                    Image(systemName: "doc.text.image.fill")
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                    Text("Receipt Image")
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LiquidGlassTheme.Colors.textQuaternary, lineWidth: 1)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFullScreenImage = true
                        }
                        LiquidGlassTheme.Haptics.light()
                    }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            FullScreenImageView(image: image, isPresented: $showFullScreenImage)
        }
    }

    // MARK: - Details Panel
    private var detailsPanel: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                // Category - directly editable
                HStack {
                    Label("Category", systemImage: categoryIcon(editedCategory))
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                    Spacer()

                    Menu {
                        ForEach(Constants.Categories.all, id: \.self) { category in
                            Button(action: {
                                editedCategory = category
                                hasChanges = true
                            }) {
                                Label(category, systemImage: categoryIcon(category))
                            }
                        }
                    } label: {
                        HStack {
                            Text(editedCategory)
                            Image(systemName: "chevron.down")
                        }
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                    }
                }

                Divider()
                    .background(LiquidGlassTheme.Colors.textQuaternary)

                // Date - directly editable
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                    Spacer()

                    DatePicker("", selection: Binding(
                        get: { editedDate },
                        set: { editedDate = $0; hasChanges = true }
                    ), displayedComponents: .date)
                        .labelsHidden()
                        .accentColor(LiquidGlassTheme.Colors.accent)
                }

                // Payment Method
                if let paymentMethod = expense.paymentMethod {
                    Divider()
                        .background(LiquidGlassTheme.Colors.textQuaternary)

                    HStack {
                        Label("Payment", systemImage: "creditcard")
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        Spacer()

                        Text(paymentMethod)
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - Items Panel
    private func itemsPanel(_ items: [String]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("items"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            // Sprint 5: Enhance AI Button (only if rawOCRText available)
            if expense.rawOCRText != nil && !expense.rawOCRText!.isEmpty {
                Button(action: { showEnhanceAISheet = true }) {
                    HStack {
                        if isEnhancing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LiquidGlassTheme.Colors.accent))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(expense.userCorrected ? "Déjà corrigé par IA" : "Corriger avec IA")
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(expense.userCorrected ? LiquidGlassTheme.Colors.textSecondary : LiquidGlassTheme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing16)
                    .background(
                        LiquidGlassBackground(
                            cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                            material: LiquidGlassTheme.LiquidGlass.thin,
                            intensity: 0.7
                        )
                    )
                }
                .disabled(isEnhancing)
            }

            // Cloud Vision Button (if configured and has image)
            if CloudVisionService.shared.isEnabled && CloudVisionService.shared.isConfigured,
               let imageData = expense.receiptImageData,
               let _ = UIImage(data: imageData) {
                Button(action: { analyzeWithCloudVision() }) {
                    HStack {
                        if isCloudVisionProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: CloudVisionService.shared.selectedProvider == .openai ? "brain.head.profile" : "bolt.fill")
                        }
                        Text("Analyser avec \(CloudVisionService.shared.selectedProvider.displayName)")
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(LiquidGlassTheme.Layout.spacing16)
                    .background(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                            .fill(
                                LinearGradient(
                                    colors: CloudVisionService.shared.selectedProvider == .openai ?
                                        [Color.green, Color.green.opacity(0.7)] :
                                        [Color.orange, Color.orange.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .disabled(isCloudVisionProcessing)
            }

            Button(action: { showDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text(LocalizationManager.shared.localized("delete_expense"))
                }
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(LiquidGlassTheme.Layout.spacing16)
                .background(
                    LiquidGlassBackground(
                        cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                        material: LiquidGlassTheme.LiquidGlass.thin,
                        intensity: 0.7
                    )
                )
            }
        }
        .sheet(isPresented: $showEnhanceAISheet) {
            EnhanceAISheetView(
                expense: expense,
                selectedFields: $selectedFieldsToCorrect,
                onEnhance: performEnhanceAI
            )
        }
        .alert(LocalizationManager.shared.localized("alert.corrections_applied"), isPresented: $showEnhanceResultAlert) {
            Button(LocalizationManager.shared.localized("common.ok")) {
                setupEditState()  // Refresh UI with new values
            }
        } message: {
            if let result = enhanceResult {
                Text(result.corrections.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
            }
        }
        .alert(LocalizationManager.shared.localized("alert.enhance_ai"), isPresented: $showEnhanceErrorAlert) {
            Button(LocalizationManager.shared.localized("common.ok"), role: .cancel) {}
        } message: {
            Text(enhanceErrorMessage)
        }
        .alert(LocalizationManager.shared.localized("alert.cloud_vision"), isPresented: $showCloudVisionResultAlert) {
            Button(LocalizationManager.shared.localized("common.ok")) {
                setupEditState()
            }
        } message: {
            if let result = cloudVisionResult {
                Text("\(LocalizationManager.shared.localized("alert.cloud_vision_success")) \(String(format: "%.1f", result.processingTime))s\n\n\(LocalizationManager.shared.localized("expense.field.merchant")): \(result.merchant)\n\(LocalizationManager.shared.localized("expense.field.amount")): \(String(format: "%.2f", result.amount)) \(result.currency)\n\(LocalizationManager.shared.localized("expense.field.category")): \(result.category)")
            }
        }
        .alert(LocalizationManager.shared.localized("alert.cloud_vision_error"), isPresented: $showCloudVisionErrorAlert) {
            Button(LocalizationManager.shared.localized("common.ok"), role: .cancel) {}
        } message: {
            Text(cloudVisionErrorMessage)
        }
    }
    
    // MARK: - Helper Methods
    private func setupEditState() {
        editedMerchant = expense.merchant ?? ""
        editedAmount = String(format: "%.2f", expense.totalAmount)
        editedCategory = expense.category ?? "Other"
        editedDate = expense.date ?? Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func saveChanges() {
        // Update expense
        expense.merchant = editedMerchant
        expense.totalAmount = Double(editedAmount) ?? 0
        expense.category = editedCategory
        expense.date = editedDate

        // Save to Core Data
        CoreDataManager.shared.saveContext()

        hasChanges = false
        LiquidGlassTheme.Haptics.success()
    }
    
    private func deleteExpense() {
        CoreDataManager.shared.deleteExpense(expense)
        LiquidGlassTheme.Haptics.medium()
        dismiss()
    }
    
    private func categoryIcon(_ category: String) -> String {
        Constants.Categories.icons[category] ?? "questionmark.circle"
    }

    // MARK: - Sprint 5: Enhance AI

    private func performEnhanceAI() {
        guard !selectedFieldsToCorrect.isEmpty else {
            return
        }

        // Check if we have rawOCRText, otherwise try to extract from image
        if let rawText = expense.rawOCRText, !rawText.isEmpty {
            // We have OCR text, proceed directly
            runEnhanceWithText(rawText)
        } else if let imageData = expense.receiptImageData, let image = UIImage(data: imageData) {
            // No OCR text but we have an image - run OCR first
            isEnhancing = true
            showEnhanceAISheet = false

            OCRService.shared.processImageSimple(image) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let extractedText):
                        // Save the OCR text for future use
                        self.expense.rawOCRText = extractedText
                        CoreDataManager.shared.saveContext()
                        // Now run enhancement
                        self.runEnhanceWithText(extractedText)

                    case .failure(let error):
                        self.isEnhancing = false
                        self.enhanceErrorMessage = "Impossible d'extraire le texte de l'image: \(error.localizedDescription)"
                        self.showEnhanceErrorAlert = true
                        LiquidGlassTheme.Haptics.error()
                    }
                }
            }
        } else {
            // No OCR text and no image
            enhanceErrorMessage = "Pas de texte OCR ni d'image disponible pour cette dépense"
            showEnhanceErrorAlert = true
            showEnhanceAISheet = false
            LiquidGlassTheme.Haptics.error()
            return
        }
    }

    private func runEnhanceWithText(_ rawText: String) {
        isEnhancing = true
        showEnhanceAISheet = false

        let request = EnhanceAIService.CorrectionRequest(
            expense: expense,
            fieldsToCorrect: Array(selectedFieldsToCorrect),
            rawOCRText: rawText
        )

        EnhanceAIService.shared.enhanceExpense(request: request) { result in
            DispatchQueue.main.async {
                self.isEnhancing = false

                switch result {
                case .success(let correctionResult):
                    if !correctionResult.corrections.isEmpty {
                        // Appliquer les corrections
                        EnhanceAIService.shared.applyCorrections(correctionResult, to: self.expense)
                        self.enhanceResult = correctionResult
                        self.showEnhanceResultAlert = true
                        LiquidGlassTheme.Haptics.success()
                    } else {
                        // Pas de corrections trouvées
                        self.enhanceErrorMessage = "Aucune correction trouvée pour les champs sélectionnés"
                        self.showEnhanceErrorAlert = true
                        LiquidGlassTheme.Haptics.light()
                    }

                case .failure(let error):
                    self.enhanceErrorMessage = "Erreur lors de la correction: \(error.localizedDescription)"
                    self.showEnhanceErrorAlert = true
                    LiquidGlassTheme.Haptics.error()
                }

                self.selectedFieldsToCorrect.removeAll()
            }
        }
    }

    // MARK: - Cloud Vision Analysis
    private func analyzeWithCloudVision() {
        guard let imageData = expense.receiptImageData,
              let image = UIImage(data: imageData) else {
            cloudVisionErrorMessage = "Pas d'image disponible"
            showCloudVisionErrorAlert = true
            return
        }

        isCloudVisionProcessing = true
        LiquidGlassTheme.Haptics.medium()


        CloudVisionService.shared.analyzeReceipt(image: image) { result in
            DispatchQueue.main.async {
                self.isCloudVisionProcessing = false

                switch result {
                case .success(let extraction):

                    // Apply the extraction results
                    self.applyCloudVisionResult(extraction)
                    self.cloudVisionResult = extraction
                    self.showCloudVisionResultAlert = true
                    LiquidGlassTheme.Haptics.success()

                case .failure(let error):
                    self.cloudVisionErrorMessage = error.localizedDescription
                    self.showCloudVisionErrorAlert = true
                    LiquidGlassTheme.Haptics.error()
                }
            }
        }
    }

    private func applyCloudVisionResult(_ result: CloudVisionService.ExtractionResult) {
        // Update the expense with cloud vision results
        expense.merchant = result.merchant
        expense.amount = result.amount
        expense.category = result.category
        expense.taxAmount = result.taxAmount
        if let date = result.date {
            expense.date = date
        }
        expense.userCorrected = true

        // Update edited fields for UI
        editedMerchant = result.merchant
        editedAmount = String(format: "%.2f", result.amount)
        editedCategory = result.category
        if let date = result.date {
            editedDate = date
        }

        // Save
        CoreDataManager.shared.saveContext()
        hasChanges = true
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
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
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Sprint 5: Enhance AI Sheet View
struct EnhanceAISheetView: View {
    let expense: Expense
    @Binding var selectedFields: Set<EnhanceAIService.CorrectionField>
    let onEnhance: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: LiquidGlassTheme.Layout.spacing20) {
                        // Header
                        VStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 48))
                                .foregroundColor(LiquidGlassTheme.Colors.accent)

                            Text("Correction IA")
                                .font(LiquidGlassTheme.Typography.title1)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                            Text("Sélectionnez les champs à corriger")
                                .font(LiquidGlassTheme.Typography.body)
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                        }
                        .padding(.top, LiquidGlassTheme.Layout.spacing20)

                        // Current Values Preview
                        GlassCard {
                            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                                Text("Valeurs actuelles")
                                    .font(LiquidGlassTheme.Typography.headline)
                                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                                infoRow("Marchand", value: expense.merchant ?? "?")
                                infoRow("Montant", value: String(format: "%.2f CHF", expense.amount))
                                infoRow("TVA", value: String(format: "%.2f CHF", expense.taxAmount))
                                infoRow("Catégorie", value: expense.category ?? "?")
                                infoRow("Date", value: formatDate(expense.date ?? Date()))
                            }
                        }

                        // Field Selection
                        GlassCard {
                            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                                Text("Champs à corriger")
                                    .font(LiquidGlassTheme.Typography.headline)
                                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                                ForEach(EnhanceAIService.CorrectionField.allCases, id: \.self) { field in
                                    fieldToggle(field)
                                }
                            }
                        }

                        // Action Button
                        Button(action: {
                            onEnhance()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Corriger avec Qwen")
                            }
                            .font(LiquidGlassTheme.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(LiquidGlassTheme.Layout.spacing16)
                            .background(
                                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                                    .fill(selectedFields.isEmpty ? Color.gray : LiquidGlassTheme.Colors.accent)
                            )
                        }
                        .disabled(selectedFields.isEmpty)
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
                    .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
        }
    }

    private func fieldToggle(_ field: EnhanceAIService.CorrectionField) -> some View {
        Button(action: {
            if selectedFields.contains(field) {
                selectedFields.remove(field)
            } else {
                selectedFields.insert(field)
            }
            LiquidGlassTheme.Haptics.light()
        }) {
            HStack {
                Image(systemName: selectedFields.contains(field) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedFields.contains(field) ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary)

                Text(field.displayName)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                Spacer()

                // Show current value
                Text(currentValue(for: field))
                    .font(LiquidGlassTheme.Typography.caption1)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }
            .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
        }
    }

    private func currentValue(for field: EnhanceAIService.CorrectionField) -> String {
        switch field {
        case .merchant: return expense.merchant ?? "?"
        case .amount: return String(format: "%.2f", expense.amount)
        case .tax: return String(format: "%.2f", expense.taxAmount)
        case .category: return expense.category ?? "?"
        case .date: return formatDate(expense.date ?? Date())
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}