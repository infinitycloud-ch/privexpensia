import SwiftUI
import CoreData
import VisionKit
import PhotosUI
import PDFKit

// MARK: - Document Archive View (Sprint 14)
// Dynamic categories with user-defined filters + Magic Dropbox

struct DocumentArchiveView: View {
    @State private var documents: [Document] = []
    @State private var categories: [DocumentCategory] = []
    @State private var selectedCategoryId: UUID? = nil  // nil = "All"
    @State private var searchText = ""
    @State private var selectedDocument: Document?

    // Sheet management with enum
    enum ActiveSheet: Identifiable {
        case categoriesManager
        case scanner
        case filePicker
        case magicDropbox
        case resultPopup
        case editDocument

        var id: Int { hashValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var documentToEdit: Document?

    // Photo picker (uses its own modifier)
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    // Processing states
    @State private var isProcessing = false
    @State private var processingMessage = ""

    // Result document
    @State private var createdDocument: Document?

    var filteredDocuments: [Document] {
        var result = documents

        // Filter by category
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.categoryId == categoryId }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.summary ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            // Background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Action Buttons (Scan, Photos, Files, Magic Dropbox)
                actionButtonsRow
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Dynamic Filter Picker
                dynamicFilterPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Document List
                if filteredDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentList
                }
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .documentAdded)) { _ in
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .documentCategoryChanged)) { _ in
            loadData()
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document, categories: categories)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .categoriesManager:
                CategoriesListView()
            case .scanner:
                DocumentScannerViewForArchive { images in
                    activeSheet = nil
                    if let firstImage = images.first {
                        processScannedImage(firstImage)
                    }
                }
            case .filePicker:
                DocumentPickerForArchive { url in
                    activeSheet = nil
                    processFileFromURL(url)
                }
            case .magicDropbox:
                MagicDropboxView(categories: categories) { document in
                    createdDocument = document
                    activeSheet = nil
                    loadData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeSheet = .resultPopup
                    }
                }
            case .resultPopup:
                if let document = createdDocument {
                    DocumentCreatedPopupView(document: document, category: categoryFor(document: document)) {
                        activeSheet = nil
                        createdDocument = nil
                    }
                }
            case .editDocument:
                if let document = documentToEdit {
                    DocumentEditView(document: document, categories: categories) {
                        activeSheet = nil
                        documentToEdit = nil
                        loadData()
                    }
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            handlePhotoSelection(newItems)
        }
    }

    // MARK: - Action Buttons Row
    private var actionButtonsRow: some View {
        HStack(spacing: 16) {
            // Camera scan
            actionButton(icon: "camera.fill", color: .blue, label: LocalizationManager.shared.localized("action.scan")) {
                if VNDocumentCameraViewController.isSupported {
                    activeSheet = .scanner
                } else {
                    // Fallback to photo picker if scanner not supported
                    showingPhotoPicker = true
                }
            }

            // Photo library
            actionButton(icon: "photo.fill", color: .purple, label: LocalizationManager.shared.localized("action.photos")) {
                showingPhotoPicker = true
            }

            // File picker
            actionButton(icon: "doc.fill", color: .orange, label: LocalizationManager.shared.localized("action.file")) {
                activeSheet = .filePicker
            }

            // Magic Dropbox
            actionButton(icon: "wand.and.stars", color: .green, label: LocalizationManager.shared.localized("action.text")) {
                activeSheet = .magicDropbox
            }
        }
    }

    @ViewBuilder
    private func actionButton(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            LiquidGlassTheme.Haptics.light()
            action()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .shadow(color: color.opacity(0.4), radius: 4, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(processingMessage.isEmpty ? "Traitement..." : processingMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }

    // MARK: - Header
    @ObservedObject private var syncService = DocumentSyncService.shared

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(LocalizationManager.shared.localized("document.archive.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                // Sync button
                if syncService.hasSyncFolder {
                    Button(action: { syncService.syncAllDocuments() }) {
                        ZStack {
                            if syncService.isSyncingAll {
                                // Progress indicator
                                Circle()
                                    .trim(from: 0, to: syncService.syncProgress.total > 0
                                        ? CGFloat(syncService.syncProgress.current) / CGFloat(syncService.syncProgress.total)
                                        : 0)
                                    .stroke(LiquidGlassTheme.Colors.accent, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                                    .rotationEffect(.degrees(-90))

                                Text("\(syncService.syncProgress.current)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(syncService.isOnWiFi || !syncService.wifiOnlyEnabled ? .secondary : .secondary.opacity(0.4))
                            }
                        }
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                    }
                    .disabled(syncService.isSyncingAll || (syncService.wifiOnlyEnabled && !syncService.isOnWiFi))
                }

                // Manage categories button
                Button(action: { activeSheet = .categoriesManager }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }

                // Document count badge
                Text("\(documents.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LiquidGlassTheme.Colors.accent))
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(LocalizationManager.shared.localized("search"), text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Dynamic Filter Picker
    private var dynamicFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" filter
                filterButton(
                    name: "Tous",
                    icon: "doc.on.doc",
                    color: LiquidGlassTheme.Colors.accent,
                    isSelected: selectedCategoryId == nil
                ) {
                    selectedCategoryId = nil
                }

                // Dynamic category filters
                ForEach(categories, id: \.id) { category in
                    filterButton(
                        name: category.name ?? "?",
                        icon: category.icon ?? "folder.fill",
                        color: Color(hex: category.colorHex ?? "#007AFF"),
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
                    }
                }
            }
        }
    }

    private func filterButton(name: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                action()
            }
            LiquidGlassTheme.Haptics.light()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(name)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Document List
    private var documentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredDocuments, id: \.id) { document in
                    DocumentRowView(
                        document: document,
                        category: categoryFor(document: document),
                        onTap: {
                            selectedDocument = document
                        },
                        onDelete: {
                            deleteDocument(document)
                        },
                        onEdit: {
                            documentToEdit = document
                            activeSheet = .editDocument
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(LocalizationManager.shared.localized("document.empty"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.localized("document.empty.hint"))
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Data Methods
    private func loadData() {
        categories = CoreDataManager.shared.fetchDocumentCategories()

        // Ensure default categories exist
        if categories.isEmpty {
            CoreDataManager.shared.ensureDefaultCategoriesExist()
            categories = CoreDataManager.shared.fetchDocumentCategories()
        }

        documents = CoreDataManager.shared.fetchDocuments()
    }

    private func categoryFor(document: Document) -> DocumentCategory? {
        guard let categoryId = document.categoryId else { return nil }
        return categories.first { $0.id == categoryId }
    }

    private func deleteDocument(_ document: Document) {
        if let docId = document.id {
            DocumentSyncService.shared.deleteExportedFile(for: docId)
        }
        withAnimation {
            CoreDataManager.shared.deleteDocument(document)
            loadData()
        }
    }

    // MARK: - Process Scanned Image
    private func processScannedImage(_ image: UIImage) {
        isProcessing = true
        processingMessage = "Analyse du document..."

        OCRService.shared.processImage(image) { result in
            switch result {
            case .success(let extractedData):
                let rawText = extractedData.text
                processingMessage = "Classification IA..."

                DocumentClassificationService.shared.classifyDocument(rawText: rawText, image: image) { classification in
                    let document = CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: classification.categoryId,
                        title: classification.title,
                        summary: classification.summary,
                        rawText: rawText,
                        image: image,
                        amount: classification.amount,
                        currency: classification.currency
                    )

                    DispatchQueue.main.async {
                        isProcessing = false
                        createdDocument = document
                        loadData()
                        activeSheet = .resultPopup
                    }
                }

            case .failure:
                DispatchQueue.main.async {
                    isProcessing = false
                    // Save without classification
                    let categories = CoreDataManager.shared.fetchDocumentCategories()
                    let defaultCategoryId = categories.first?.id ?? UUID()

                    let document = CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: defaultCategoryId,
                        title: "Document",
                        summary: nil,
                        rawText: nil,
                        image: image,
                        amount: 0,
                        currency: "CHF"
                    )

                    createdDocument = document
                    loadData()
                    activeSheet = .resultPopup
                }
            }
        }
    }

    // MARK: - Handle Photo Selection
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }

        isProcessing = true
        processingMessage = "Chargement de l'image..."

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                selectedPhotoItems = []

                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        processScannedImage(image)
                    } else {
                        isProcessing = false
                    }
                case .failure:
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - Process File from URL
    private func processFileFromURL(_ url: URL) {
        isProcessing = true
        processingMessage = "Lecture du fichier..."

        DispatchQueue.global(qos: .userInitiated).async {
            var rawText: String? = nil
            var image: UIImage? = nil

            // Try to read as image first
            if let imageData = try? Data(contentsOf: url),
               let loadedImage = UIImage(data: imageData) {
                image = loadedImage

                // Also get text via OCR
                OCRService.shared.processImage(loadedImage) { result in
                    if case .success(let extractedData) = result {
                        rawText = extractedData.text
                    }

                    DispatchQueue.main.async {
                        processFileContent(rawText: rawText, image: image)
                    }
                }
            }
            // Try to read as text/PDF
            else if let textContent = try? String(contentsOf: url, encoding: .utf8) {
                rawText = textContent

                DispatchQueue.main.async {
                    processFileContent(rawText: rawText, image: nil)
                }
            }
            else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
            }
        }
    }

    private func processFileContent(rawText: String?, image: UIImage?) {
        guard let text = rawText, !text.isEmpty else {
            isProcessing = false
            return
        }

        processingMessage = "Classification IA..."

        DocumentClassificationService.shared.classifyDocument(rawText: text, image: image) { classification in
            let document = CoreDataManager.shared.createDocumentWithCategory(
                categoryId: classification.categoryId,
                title: classification.title,
                summary: classification.summary,
                rawText: text,
                image: image,
                amount: classification.amount,
                currency: classification.currency
            )

            DispatchQueue.main.async {
                isProcessing = false
                createdDocument = document
                loadData()
                activeSheet = .resultPopup
            }
        }
    }
}

// MARK: - Document Row View - Jony Ive Edition
// Aligned with ExpenseCardGlass design language
struct DocumentRowView: View {
    let document: Document
    let category: DocumentCategory?
    let onTap: () -> Void
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil

    @State private var showDeleteConfirmation = false
    @State private var isPressed = false

    private var categoryColor: Color {
        Color(hex: category?.colorHex ?? "#007AFF")
    }

    var body: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.light()
            onTap()
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Left column: icon + date (fixed width, always aligned)
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.12))
                            .frame(width: 38, height: 38)

                        Image(systemName: category?.icon ?? "doc.fill")
                            .font(.system(size: 17))
                            .foregroundColor(categoryColor)
                    }

                    Text(formatDateCompact(document.createdAt))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(categoryColor.opacity(0.8))
                }
                .frame(width: 58)

                // Center: title + summary
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title ?? "Document")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let summary = document.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(category?.name ?? "Document")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Amount (right-aligned)
                if document.amount > 0 {
                    Text(formatCurrency(document.amount, currency: document.currency ?? "CHF"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
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
                            }
                          },
                          perform: {})
        .contextMenu {
            Button(action: onTap) {
                Label(LocalizationManager.shared.localized("document.view"), systemImage: "eye")
            }

            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label(LocalizationManager.shared.localized("button.edit"), systemImage: "pencil")
                }
            }

            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label(LocalizationManager.shared.localized("button.delete"), systemImage: "trash")
            }
        }
        .confirmationDialog(
            LocalizationManager.shared.localized("delete.confirmation.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizationManager.shared.localized("button.delete"), role: .destructive) {
                LiquidGlassTheme.Haptics.warning()
                onDelete()
            }
            Button(LocalizationManager.shared.localized("button.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Formatters
    private func formatDateCompact(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

// MARK: - Document Detail View - Jony Ive Precision
// Aligned with ExpenseResultView design language
struct DocumentDetailView: View {
    let document: Document
    let categories: [DocumentCategory]
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: UIImage?
    @State private var imageLoadError: String?
    @State private var showFullscreenImage = false
    @State private var showShareSheet = false
    @State private var appearanceOffset: CGFloat = 30
    @State private var appearanceOpacity: Double = 0

    var category: DocumentCategory? {
        guard let categoryId = document.categoryId else { return nil }
        return categories.first { $0.id == categoryId }
    }

    private var categoryColor: Color {
        Color(hex: category?.colorHex ?? "#007AFF")
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Document image/PDF viewer
                    documentImageView
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    // Hero section: category badge + title + amount
                    heroSection
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    // Details card
                    detailsCard
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    // Summary card (if present)
                    if let summary = document.summary, !summary.isEmpty {
                        summaryCard(summary)
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(LiquidGlassTheme.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle(document.title ?? "Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if loadedImage != nil || (document.pdfData != nil && !document.pdfData!.isEmpty) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = document.pdfData, !pdfData.isEmpty,
                   let tempURL = writePDFToTemp(pdfData) {
                    ShareSheet(items: [tempURL])
                } else if let image = loadedImage {
                    ShareSheet(items: [image])
                }
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                if let pdfData = document.pdfData, !pdfData.isEmpty {
                    FullscreenPDFView(pdfData: pdfData)
                } else if let image = loadedImage {
                    FullscreenImageView(image: image)
                }
            }
            .onAppear {
                loadImage()
                withAnimation(.easeOut(duration: 0.6)) {
                    appearanceOffset = 0
                    appearanceOpacity = 1
                }
            }
        }
        .offset(y: appearanceOffset)
        .opacity(appearanceOpacity)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            // Category badge capsule
            HStack(spacing: 6) {
                Image(systemName: category?.icon ?? "doc.fill")
                    .font(.system(size: 13))
                Text(category?.name ?? "Document")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(categoryColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(categoryColor.opacity(0.1))
            )

            // Title
            Text(document.title ?? "Document")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Amount (hero style)
            if document.amount > 0 {
                Text(formatCurrency(document.amount, currency: document.currency ?? "CHF"))
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundColor(categoryColor)
                    .kerning(-1)
            }
        }
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(spacing: 16) {
            detailRow(
                LocalizationManager.shared.localized("expense.field.date"),
                formatDate(document.createdAt)
            )
            detailRow(
                LocalizationManager.shared.localized("expense.category"),
                category?.name ?? "Document"
            )
            if document.amount > 0 {
                detailRow(
                    LocalizationManager.shared.localized("expense.field.amount"),
                    formatCurrency(document.amount, currency: document.currency ?? "CHF")
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(
            LiquidGlassBackground(
                cornerRadius: 24,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.8
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Summary Card
    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationManager.shared.localized("document.summary"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Text(summary)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LiquidGlassBackground(
                cornerRadius: 16,
                material: LiquidGlassTheme.LiquidGlass.thin,
                intensity: 0.8
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Document Image View
    @ViewBuilder
    private var documentImageView: some View {
        if let pdfData = document.pdfData, !pdfData.isEmpty {
            PDFViewRepresentable(data: pdfData)
                .frame(height: 500)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .onTapGesture { showFullscreenImage = true }
        } else if let image = loadedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 400)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .onTapGesture { showFullscreenImage = true }
        } else if let error = imageLoadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Chargement...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }

    // MARK: - Load Image
    private func loadImage() {
        guard let imageData = document.imageData else {
            imageLoadError = "Aucune image (imageData nil)"
            return
        }

        guard !imageData.isEmpty else {
            imageLoadError = "Image vide (0 bytes)"
            return
        }

        guard let uiImage = UIImage(data: imageData) else {
            imageLoadError = "Format invalide (\(imageData.count) bytes)"
            return
        }

        loadedImage = uiImage
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    private func writePDFToTemp(_ data: Data) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document.pdf")
        try? data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Document Edit View
struct DocumentEditView: View {
    let document: Document
    let categories: [DocumentCategory]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String = ""
    @State private var selectedCategoryId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized("document.title"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        TextField(LocalizationManager.shared.localized("document.title"), text: $editedTitle)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .padding(.horizontal, 20)

                    // Category Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized("expense.category"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                                Button(action: { selectedCategoryId = category.id }) {
                                    HStack {
                                        Image(systemName: category.icon ?? "folder.fill")
                                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                            .frame(width: 24)
                                        Text(category.name ?? "Category")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedCategoryId == category.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                }
                                if index < categories.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
            .background(LiquidGlassTheme.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle(LocalizationManager.shared.localized("button.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationManager.shared.localized("button.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("button.save")) {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                editedTitle = document.title ?? ""
                selectedCategoryId = document.categoryId
            }
        }
    }

    private func saveChanges() {
        document.title = editedTitle.trimmingCharacters(in: .whitespaces)
        if let newCategoryId = selectedCategoryId {
            document.categoryId = newCategoryId
        }
        CoreDataManager.shared.saveContext()
        NotificationCenter.default.post(name: .documentCategoryChanged, object: nil)
        onSave()
        dismiss()
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Document Scanner for Archive
struct DocumentScannerViewForArchive: UIViewControllerRepresentable {
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
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) {
                self.completion(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.completion([])
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.completion([])
            }
        }
    }
}

// MARK: - Document Picker for Archive
struct DocumentPickerForArchive: UIViewControllerRepresentable {
    let completion: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .pdf, .text, .plainText])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (URL) -> Void

        init(completion: @escaping (URL) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Start security scoped access
            _ = url.startAccessingSecurityScopedResource()
            completion(url)
            url.stopAccessingSecurityScopedResource()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Do nothing
        }
    }
}

// MARK: - Magic Dropbox View
struct MagicDropboxView: View {
    let categories: [DocumentCategory]
    let onDocumentCreated: (Document) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @FocusState private var isTextFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Instructions
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text(LocalizationManager.shared.localized("magic_dropbox.title"))
                            .font(.system(size: 24, weight: .bold))

                        Text(LocalizationManager.shared.localized("magic_dropbox.description"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

                    // Text input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized("magic_dropbox.your_text"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        TextEditor(text: $inputText)
                            .frame(minHeight: 200)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                            )
                            .focused($isTextFocused)

                        // Character count
                        HStack {
                            Spacer()
                            Text(String(format: LocalizationManager.shared.localized("magic_dropbox.characters"), inputText.count))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Process button
                    Button(action: processText) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isProcessing ? processingMessage : LocalizationManager.shared.localized("magic_dropbox.create_document"))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing
                                      ? AnyShapeStyle(Color.gray)
                                      : AnyShapeStyle(Color.green.gradient))
                        )
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationManager.shared.localized("button.cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-focus text field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFocused = true
                }
            }
        }
    }

    private func processText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isProcessing = true
        processingMessage = LocalizationManager.shared.localized("magic_dropbox.classifying")

        // Use DocumentClassificationService to process the text
        DocumentClassificationService.shared.classifyDocument(rawText: text, image: nil) { classification in
            processingMessage = LocalizationManager.shared.localized("magic_dropbox.creating")

            // Create the document with today's date
            let document = CoreDataManager.shared.createDocumentWithCategory(
                categoryId: classification.categoryId,
                title: classification.title,
                summary: classification.summary,
                rawText: text,
                image: nil,
                amount: classification.amount,
                currency: classification.currency
            )

            DispatchQueue.main.async {
                isProcessing = false
                LiquidGlassTheme.Haptics.success()
                onDocumentCreated(document)
            }
        }
    }
}

// MARK: - Document Created Popup View
struct DocumentCreatedPopupView: View {
    let document: Document
    let category: DocumentCategory?
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 30)

                    // Title
                    Text(LocalizationManager.shared.localized("document.created_success"))
                        .font(.system(size: 24, weight: .bold))

                    // Document info card
                    VStack(alignment: .leading, spacing: 16) {
                        // Category
                        HStack {
                            Image(systemName: category?.icon ?? "doc.fill")
                                .foregroundColor(Color(hex: category?.colorHex ?? "#007AFF"))
                            Text(category?.name ?? LocalizationManager.shared.localized("document.default_name"))
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }

                        Divider()

                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizationManager.shared.localized("document.title"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(document.title ?? LocalizationManager.shared.localized("document.default_name"))
                                .font(.system(size: 16, weight: .semibold))
                        }

                        // Amount (if present)
                        if document.amount > 0 {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizationManager.shared.localized("expense.amount"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(document.amount, currency: document.currency ?? "CHF"))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: category?.colorHex ?? "#007AFF"))
                            }
                        }

                        // Summary
                        if let summary = document.summary, !summary.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizationManager.shared.localized("document.summary"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(summary)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                        }

                        // Date
                        Divider()
                        HStack {
                            Text(LocalizationManager.shared.localized("expense.date"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(document.createdAt))
                                .font(.system(size: 14))
                        }
                    }
                    .padding(20)
                    .background(
                        LiquidGlassBackground(
                            cornerRadius: 16,
                            material: LiquidGlassTheme.LiquidGlass.regular,
                            intensity: 0.8
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    Spacer()

                    // OK Button
                    Button(action: {
                        dismiss()
                        onDismiss()
                    }) {
                        Text(LocalizationManager.shared.localized("button.ok"))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.green.gradient)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

// MARK: - Fullscreen Image View (with share/save)
// MARK: - PDF View Representable (PDFKit wrapper)
struct PDFViewRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Fullscreen PDF View
struct FullscreenPDFView: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PDFViewRepresentable(data: pdfData)
                .ignoresSafeArea(edges: .bottom)

            // Top bar
            VStack {
                HStack {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                Spacer()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let tempURL = writePDFToTemp() {
                ShareSheet(items: [tempURL])
            }
        }
    }

    private func writePDFToTemp() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document.pdf")
        try? pdfData.write(to: tempURL)
        return tempURL
    }
}

struct FullscreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showShareSheet = false
    @State private var savedToPhotos = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in scale = lastScale * value }
                        .onEnded { value in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation { scale = 1.0; lastScale = 1.0 }
                            }
                        }
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation {
                                if scale > 1.0 { scale = 1.0; lastScale = 1.0 }
                                else { scale = 2.5; lastScale = 2.5 }
                            }
                        }
                )

            // Top bar
            VStack {
                HStack {
                    // Share button
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }

                    // Save to Photos
                    Button(action: saveToPhotos) {
                        Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "arrow.down.to.line")
                            .font(.system(size: 20))
                            .foregroundColor(savedToPhotos ? .green : .white.opacity(0.9))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }

                    Spacer()

                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                Spacer()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
    }

    private func saveToPhotos() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        LiquidGlassTheme.Haptics.success()
    }
}

// MARK: - Preview
#Preview {
    DocumentArchiveView()
}
