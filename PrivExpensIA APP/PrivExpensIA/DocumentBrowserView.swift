import SwiftUI
import CoreData
import VisionKit
import PhotosUI
import PDFKit

// MARK: - Category Reference for NavigationPath
struct CategoryRef: Hashable, Codable {
    let id: UUID
}

// MARK: - Document Browser View (NavigationStack Wrapper)
struct DocumentBrowserView: View {
    // Sheet management
    enum ActiveSheet: Identifiable {
        case categoriesManager
        case scanner(parentCategoryId: UUID?)
        case filePicker(parentCategoryId: UUID?)
        case magicDropbox(parentCategoryId: UUID?)
        case resultPopup
        case editDocument(document: Document)
        case newSubfolder(parentCategoryId: UUID?)

        var id: String {
            switch self {
            case .categoriesManager: return "categoriesManager"
            case .scanner: return "scanner"
            case .filePicker: return "filePicker"
            case .magicDropbox: return "magicDropbox"
            case .resultPopup: return "resultPopup"
            case .editDocument(let doc): return "editDocument-\(doc.objectID)"
            case .newSubfolder: return "newSubfolder"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?

    // Photo picker
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoPickerCategoryId: UUID?

    // Processing states
    @State private var isProcessing = false
    @State private var processingMessage = ""

    // Result
    @State private var createdDocument: Document?
    @State private var selectedDocument: Document?

    var body: some View {
        NavigationStack {
            DocumentFolderView(
                category: nil,
                onScan: { categoryId in activeSheet = .scanner(parentCategoryId: categoryId) },
                onPhotoPicker: { categoryId in
                    photoPickerCategoryId = categoryId
                    showingPhotoPicker = true
                },
                onFilePicker: { categoryId in activeSheet = .filePicker(parentCategoryId: categoryId) },
                onMagicDropbox: { categoryId in activeSheet = .magicDropbox(parentCategoryId: categoryId) },
                onSettings: { activeSheet = .categoriesManager },
                onNewSubfolder: { parentId in activeSheet = .newSubfolder(parentCategoryId: parentId) },
                onSelectDocument: { doc in selectedDocument = doc },
                onEditDocument: { doc in
                    activeSheet = .editDocument(document: doc)
                }
            )
        }
        .overlay {
            if isProcessing {
                processingOverlay
            }
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(
                document: document,
                categories: CoreDataManager.shared.fetchDocumentCategories()
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .categoriesManager:
                CategoriesListView()
            case .scanner(let categoryId):
                DocumentScannerViewForArchive { images in
                    activeSheet = nil
                    if !images.isEmpty {
                        processScannedImages(images, targetCategoryId: categoryId)
                    }
                }
            case .filePicker(let categoryId):
                DocumentPickerForArchive { url in
                    activeSheet = nil
                    processFileFromURL(url, targetCategoryId: categoryId)
                }
            case .magicDropbox(let categoryId):
                MagicDropboxView(categories: CoreDataManager.shared.fetchDocumentCategories()) { document in
                    createdDocument = document
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeSheet = .resultPopup
                    }
                }
            case .resultPopup:
                if let document = createdDocument {
                    let categories = CoreDataManager.shared.fetchDocumentCategories()
                    let category = categories.first { $0.id == document.categoryId }
                    DocumentCreatedPopupView(document: document, category: category) {
                        activeSheet = nil
                        createdDocument = nil
                    }
                }
            case .editDocument(let document):
                DocumentEditView(
                    document: document,
                    categories: CoreDataManager.shared.fetchDocumentCategories()
                ) {
                    activeSheet = nil
                }
            case .newSubfolder(let parentId):
                let parentCat = parentId.flatMap { CoreDataManager.shared.fetchDocumentCategory(id: $0) }
                CategoryEditorView(existingCategory: nil, parentCategory: parentCat) {
                    activeSheet = nil
                    NotificationCenter.default.post(name: .documentCategoryChanged, object: nil)
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            handlePhotoSelection(newItems)
        }
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

    // MARK: - Document Processing

    private func processScannedImages(_ images: [UIImage], targetCategoryId: UUID?) {
        isProcessing = true
        let totalPages = images.count

        // Create PDF from all scanned pages
        let pdfData = createPDFFromImages(images)

        // OCR each page and concatenate
        var allTexts: [String] = []
        let group = DispatchGroup()

        for (index, image) in images.enumerated() {
            group.enter()
            DispatchQueue.main.async {
                processingMessage = "OCR page \(index + 1)/\(totalPages)..."
            }
            OCRService.shared.processImage(image) { result in
                if case .success(let extractedData) = result {
                    allTexts.append(extractedData.text)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let rawText = allTexts.joined(separator: "\n\n")
            processingMessage = "Classification IA..."

            if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DocumentClassificationService.shared.classifyDocument(rawText: rawText, image: images.first) { classification in
                    let categoryId = targetCategoryId ?? classification.categoryId

                    let document = CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: categoryId,
                        title: classification.title,
                        summary: classification.summary,
                        rawText: rawText,
                        image: images.first,
                        pdfData: pdfData,
                        amount: classification.amount,
                        currency: classification.currency
                    )

                    isProcessing = false
                    createdDocument = document
                    activeSheet = .resultPopup
                }
            } else {
                let categories = CoreDataManager.shared.fetchDocumentCategories()
                let defaultCategoryId = targetCategoryId ?? categories.first?.id ?? UUID()

                let document = CoreDataManager.shared.createDocumentWithCategory(
                    categoryId: defaultCategoryId,
                    title: "Document",
                    summary: nil,
                    rawText: nil,
                    image: images.first,
                    pdfData: pdfData,
                    amount: 0,
                    currency: "CHF"
                )

                isProcessing = false
                createdDocument = document
                activeSheet = .resultPopup
            }
        }
    }

    private func createPDFFromImages(_ images: [UIImage]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for image in images {
                let pageRect = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                image.draw(in: pageRect)
            }
        }
    }

    private func processFileFromURL(_ url: URL, targetCategoryId: UUID?) {
        isProcessing = true
        processingMessage = "Lecture du fichier..."

        DispatchQueue.global(qos: .userInitiated).async {
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async { isProcessing = false }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let ext = url.pathExtension.lowercased()

            if ext == "pdf" {
                // Native PDF: store raw data + extract thumbnail
                guard let pdfFileData = try? Data(contentsOf: url),
                      let pdfDocument = PDFDocument(data: pdfFileData) else {
                    DispatchQueue.main.async { isProcessing = false }
                    return
                }

                // Extract text from all pages
                var texts: [String] = []
                for i in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: i), let text = page.string {
                        texts.append(text)
                    }
                }
                let rawText = texts.joined(separator: "\n")

                // Extract first page as thumbnail
                var thumbnail: UIImage?
                if let firstPage = pdfDocument.page(at: 0) {
                    let pageRect = firstPage.bounds(for: .mediaBox)
                    let imgRenderer = UIGraphicsImageRenderer(size: pageRect.size)
                    thumbnail = imgRenderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(pageRect)
                        ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                        ctx.cgContext.scaleBy(x: 1, y: -1)
                        firstPage.draw(with: .mediaBox, to: ctx.cgContext)
                    }
                }

                DispatchQueue.main.async {
                    processingMessage = "Classification IA..."
                    let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !trimmedText.isEmpty {
                        DocumentClassificationService.shared.classifyDocument(rawText: trimmedText, image: thumbnail) { classification in
                            let categoryId = targetCategoryId ?? classification.categoryId

                            let document = CoreDataManager.shared.createDocumentWithCategory(
                                categoryId: categoryId,
                                title: classification.title,
                                summary: classification.summary,
                                rawText: trimmedText,
                                image: thumbnail,
                                pdfData: pdfFileData,
                                amount: classification.amount,
                                currency: classification.currency
                            )

                            isProcessing = false
                            createdDocument = document
                            activeSheet = .resultPopup
                        }
                    } else {
                        let categories = CoreDataManager.shared.fetchDocumentCategories()
                        let defaultCategoryId = targetCategoryId ?? categories.first?.id ?? UUID()
                        let fileName = url.deletingPathExtension().lastPathComponent

                        let document = CoreDataManager.shared.createDocumentWithCategory(
                            categoryId: defaultCategoryId,
                            title: fileName,
                            summary: nil,
                            rawText: nil,
                            image: thumbnail,
                            pdfData: pdfFileData,
                            amount: 0,
                            currency: "CHF"
                        )

                        isProcessing = false
                        createdDocument = document
                        activeSheet = .resultPopup
                    }
                }
            } else {
                // Image file
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        processScannedImages([image], targetCategoryId: targetCategoryId)
                    }
                } else {
                    DispatchQueue.main.async { isProcessing = false }
                }
            }
        }
    }

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }

        isProcessing = true
        processingMessage = "Chargement de la photo..."

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                selectedPhotoItems = []

                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        processScannedImages([image], targetCategoryId: photoPickerCategoryId)
                    } else {
                        isProcessing = false
                    }
                case .failure:
                    isProcessing = false
                }
            }
        }
    }
}
