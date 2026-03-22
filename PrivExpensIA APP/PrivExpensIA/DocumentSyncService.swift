import Foundation
import UIKit
import PDFKit
import Network
import Vision

/// Service for automatic document synchronization to a user-selected folder
/// Uses security-scoped bookmarks for persistent folder access
/// Supports WiFi-only sync with automatic retry when connection changes
class DocumentSyncService: ObservableObject {
    static let shared = DocumentSyncService()

    // MARK: - Published Properties
    @Published var syncEnabled: Bool = false
    @Published var wifiOnlyEnabled: Bool = true
    @Published var syncFolderName: String = ""
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var pendingCount: Int = 0
    @Published var isOnWiFi: Bool = false
    @Published var importedCount: Int = 0

    // MARK: - Private Properties
    private let defaults = UserDefaults.standard
    private let bookmarkKey = "documentSync.folderBookmark"
    private let enabledKey = "documentSync.enabled"
    private let wifiOnlyKey = "documentSync.wifiOnly"
    private let lastSyncKey = "documentSync.lastSync"
    private let pendingKey = "documentSync.pendingDocuments"
    private let importedFilesKey = "documentSync.importedFiles"
    private let exportedPathsKey = "documentSync.exportedPaths"

    private var securityScopedURL: URL?
    private var pendingDocumentIDs: [UUID] = []
    private var importedFileNames: Set<String> = []
    private var exportedDocumentPaths: [String: String] = [:]  // docID.uuidString → relative path

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.privexpensia.networkMonitor")

    // MARK: - Initialization
    private init() {
        loadSettings()
        startNetworkMonitoring()
        observeAppLifecycle()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnWiFi = self?.isOnWiFi ?? false
                self?.isOnWiFi = path.usesInterfaceType(.wifi)

                // If we just connected to WiFi, try to sync pending documents
                if self?.isOnWiFi == true && !wasOnWiFi {
                    self?.syncPendingDocuments()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appWillEnterForeground() {
        // Sync pending documents when app comes to foreground on WiFi
        if isOnWiFi && !pendingDocumentIDs.isEmpty {
            syncPendingDocuments()
        }

        // Check for new files to import from sync folder
        if hasSyncFolder && syncEnabled {
            importFromSyncFolder()
        }
    }

    // MARK: - Settings Management

    private func loadSettings() {
        syncEnabled = defaults.bool(forKey: enabledKey)
        wifiOnlyEnabled = defaults.object(forKey: wifiOnlyKey) as? Bool ?? true
        lastSyncDate = defaults.object(forKey: lastSyncKey) as? Date

        // Load pending document IDs
        if let data = defaults.data(forKey: pendingKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            pendingDocumentIDs = ids
            pendingCount = ids.count
        }

        // Load imported file names
        if let savedNames = defaults.stringArray(forKey: importedFilesKey) {
            importedFileNames = Set(savedNames)
        }

        // Load exported document paths
        if let data = defaults.data(forKey: exportedPathsKey),
           let paths = try? JSONDecoder().decode([String: String].self, from: data) {
            exportedDocumentPaths = paths
        }

        // Try to restore bookmarked URL
        if let bookmarkData = defaults.data(forKey: bookmarkKey) {
            restoreBookmark(from: bookmarkData)
        }
    }

    private func saveSettings() {
        defaults.set(syncEnabled, forKey: enabledKey)
        defaults.set(wifiOnlyEnabled, forKey: wifiOnlyKey)
        if let date = lastSyncDate {
            defaults.set(date, forKey: lastSyncKey)
        }

        // Save pending document IDs
        if let data = try? JSONEncoder().encode(pendingDocumentIDs) {
            defaults.set(data, forKey: pendingKey)
        }

        // Save imported file names
        defaults.set(Array(importedFileNames), forKey: importedFilesKey)

        // Save exported document paths
        if let data = try? JSONEncoder().encode(exportedDocumentPaths) {
            defaults.set(data, forKey: exportedPathsKey)
        }
    }

    // MARK: - Folder Selection

    /// Check if a sync folder is configured
    var hasSyncFolder: Bool {
        return securityScopedURL != nil
    }

    /// Save the selected folder as a security-scoped bookmark
    func setSyncFolder(url: URL) -> Bool {
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                syncError = "Cannot access folder"
                return false
            }

            // Create bookmark data for persistent access
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Save bookmark
            defaults.set(bookmarkData, forKey: bookmarkKey)

            // Update state
            securityScopedURL = url
            syncFolderName = url.lastPathComponent
            syncEnabled = true
            syncError = nil
            saveSettings()

            // Stop accessing (we'll access again when needed)
            url.stopAccessingSecurityScopedResource()

            return true
        } catch {
            syncError = "Failed to save folder: \(error.localizedDescription)"
            return false
        }
    }

    /// Restore bookmark from saved data
    private func restoreBookmark(from data: Data) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, need to re-select folder
                clearSyncFolder()
                return
            }

            securityScopedURL = url
            syncFolderName = url.lastPathComponent
        } catch {
            clearSyncFolder()
        }
    }

    /// Clear the sync folder configuration
    func clearSyncFolder() {
        defaults.removeObject(forKey: bookmarkKey)
        securityScopedURL = nil
        syncFolderName = ""
        syncEnabled = false
        saveSettings()
    }

    // MARK: - Document Sync

    /// Sync a document to the configured folder
    /// Called automatically when a new document is created
    func syncDocument(_ document: Document) {
        guard syncEnabled, hasSyncFolder else {
            return
        }

        // Check WiFi requirement
        if wifiOnlyEnabled && !isOnWiFi {
            // Queue for later sync
            if let id = document.id, !pendingDocumentIDs.contains(id) {
                pendingDocumentIDs.append(id)
                pendingCount = pendingDocumentIDs.count
                saveSettings()
            }
            return
        }

        // Sync immediately
        performSyncForDocument(document)
    }

    /// Sync all pending documents (called when WiFi becomes available)
    private func syncPendingDocuments() {
        guard syncEnabled, hasSyncFolder, isOnWiFi, !pendingDocumentIDs.isEmpty else {
            return
        }

        // Fetch documents from CoreData
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let fetchRequest = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", pendingDocumentIDs)

        do {
            let documents = try context.fetch(fetchRequest)
            for document in documents {
                performSyncForDocument(document)
            }
        } catch {
            syncError = "Failed to fetch pending documents"
        }
    }

    /// Sync ALL content: Documents + Expenses (receipts)
    /// Creates subfolders: Documents/, Receipts/
    @Published var isSyncingAll: Bool = false
    @Published var syncProgress: (current: Int, total: Int) = (0, 0)

    func syncAllDocuments() {
        guard hasSyncFolder else {
            syncError = "No sync folder configured"
            return
        }

        // Check WiFi requirement
        if wifiOnlyEnabled && !isOnWiFi {
            syncError = "WiFi required for sync"
            return
        }

        isSyncingAll = true
        syncError = nil

        let context = CoreDataManager.shared.persistentContainer.viewContext

        // Fetch all documents
        let docFetchRequest = Document.fetchRequest()
        docFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]

        // Fetch all expenses with images
        let expenseFetchRequest = Expense.fetchRequest()
        expenseFetchRequest.predicate = NSPredicate(format: "receiptImageData != nil")
        expenseFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]

        do {
            let documents = try context.fetch(docFetchRequest)
            let expenses = try context.fetch(expenseFetchRequest)
            let totalItems = documents.count + expenses.count

            syncProgress = (0, totalItems)

            guard totalItems > 0 else {
                isSyncingAll = false
                return
            }

            // Sync in background
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self, let folderURL = self.securityScopedURL else { return }

                guard folderURL.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        self.syncError = "Cannot access sync folder"
                        self.isSyncingAll = false
                    }
                    return
                }

                defer {
                    folderURL.stopAccessingSecurityScopedResource()
                }

                // Create subfolders
                let documentsFolder = folderURL.appendingPathComponent("Documents")
                let receiptsFolder = folderURL.appendingPathComponent("Receipts")

                try? FileManager.default.createDirectory(at: documentsFolder, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(at: receiptsFolder, withIntermediateDirectories: true)

                var currentIndex = 0

                // Sync documents into category-hierarchy subfolders
                for document in documents {
                    let categoryFolder = self.categorySubfolder(for: document, baseURL: documentsFolder)
                    try? FileManager.default.createDirectory(at: categoryFolder, withIntermediateDirectories: true)
                    self.performSyncBlocking(document: document, to: categoryFolder)
                    currentIndex += 1
                    DispatchQueue.main.async {
                        self.syncProgress = (currentIndex, totalItems)
                    }
                }

                // Sync expenses (receipts)
                for expense in expenses {
                    self.performSyncBlocking(expense: expense, to: receiptsFolder)
                    currentIndex += 1
                    DispatchQueue.main.async {
                        self.syncProgress = (currentIndex, totalItems)
                    }
                }

                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                    self.isSyncingAll = false
                    self.saveSettings()

                    // After export, check for new files to import
                    self.importFromSyncFolder()
                }
            }
        } catch {
            syncError = "Failed to fetch data"
            isSyncingAll = false
        }
    }

    /// Blocking sync for Document
    private func performSyncBlocking(document: Document, to folderURL: URL) {
        // Skip if this document already has a tracked file that still exists
        if let docId = document.id,
           let existingPath = exportedDocumentPaths[docId.uuidString],
           let baseURL = securityScopedURL {
            let existingURL = baseURL.appendingPathComponent(existingPath)
            if FileManager.default.fileExists(atPath: existingURL.path) {
                return  // Already synced, don't create duplicate
            }
        }

        let filename = generateFilename(for: document)
        let destinationURL = folderURL.appendingPathComponent(filename)

        do {
            if let originalPDF = document.pdfData {
                // Prefer original PDF data (preserves multi-page)
                try originalPDF.write(to: destinationURL)
                trackExportedFile(documentId: document.id, fileURL: destinationURL)
            } else if let imageData = document.imageData, let image = UIImage(data: imageData) {
                // Fallback: create single-page PDF from image
                let pdfData = createPDF(from: image, document: document)
                try pdfData.write(to: destinationURL)
                trackExportedFile(documentId: document.id, fileURL: destinationURL)
            } else if let rawText = document.rawText {
                let textFilename = filename.replacingOccurrences(of: ".pdf", with: ".txt")
                let textURL = folderURL.appendingPathComponent(textFilename)
                try rawText.write(to: textURL, atomically: true, encoding: .utf8)
                trackExportedFile(documentId: document.id, fileURL: textURL)
            }
        } catch {
            // Continue with other files
        }
    }

    /// Blocking sync for Expense (receipt)
    private func performSyncBlocking(expense: Expense, to folderURL: URL) {
        let filename = generateFilename(for: expense)
        let destinationURL = folderURL.appendingPathComponent(filename)

        do {
            if let imageData = expense.receiptImageData, let image = UIImage(data: imageData) {
                let pdfData = createPDF(from: image, expense: expense)
                try pdfData.write(to: destinationURL)
            }
        } catch {
            // Continue with other files
        }
    }

    /// Generate filename for Expense
    private func generateFilename(for expense: Expense) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateString = dateFormatter.string(from: expense.date ?? Date())
        let merchant = expense.merchant?.replacingOccurrences(of: "/", with: "-")
                                        .replacingOccurrences(of: ":", with: "-")
                                        .prefix(30) ?? "Receipt"
        let amount = String(format: "%.2f", expense.amount)

        return "\(dateString)_\(merchant)_\(amount)CHF.pdf"
    }

    /// Create PDF from Expense
    private func createPDF(from image: UIImage, expense: Expense) -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: image.size))

        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            image.draw(at: .zero)
        }

        return data
    }

    private func performSyncForDocument(_ document: Document) {
        guard let folderURL = securityScopedURL else { return }

        // Run sync in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performSync(document: document, to: folderURL)
        }
    }

    private func performSync(document: Document, to folderURL: URL) {
        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                self.syncError = "Cannot access sync folder"
            }
            return
        }

        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }

        // Generate filename
        let filename = generateFilename(for: document)
        let destinationURL = folderURL.appendingPathComponent(filename)

        do {
            if let originalPDF = document.pdfData {
                // Prefer original PDF data (preserves multi-page)
                try originalPDF.write(to: destinationURL)
                trackExportedFile(documentId: document.id, fileURL: destinationURL)
            } else if let imageData = document.imageData, let image = UIImage(data: imageData) {
                // Fallback: create single-page PDF from image
                let pdfData = createPDF(from: image, document: document)
                try pdfData.write(to: destinationURL)
                trackExportedFile(documentId: document.id, fileURL: destinationURL)
            } else if let rawText = document.rawText {
                // Export as text file if no image
                let textFilename = filename.replacingOccurrences(of: ".pdf", with: ".txt")
                let textURL = folderURL.appendingPathComponent(textFilename)
                try rawText.write(to: textURL, atomically: true, encoding: .utf8)
                trackExportedFile(documentId: document.id, fileURL: textURL)
            }

            // Remove from pending list and mark as known file (prevent re-import)
            DispatchQueue.main.async {
                self.importedFileNames.insert(destinationURL.path)
                if let id = document.id {
                    self.pendingDocumentIDs.removeAll { $0 == id }
                    self.pendingCount = self.pendingDocumentIDs.count
                }
                self.lastSyncDate = Date()
                self.syncError = nil
                self.saveSettings()
            }
        } catch {
            DispatchQueue.main.async {
                self.syncError = "Sync failed: \(error.localizedDescription)"
            }
        }
    }

    /// Get the category hierarchy subfolder for a document
    /// e.g., Documents/Personnel/Santé/ for a document in Personnel > Santé
    private func categorySubfolder(for document: Document, baseURL: URL) -> URL {
        guard let categoryId = document.categoryId,
              let category = CoreDataManager.shared.fetchDocumentCategory(id: categoryId) else {
            return baseURL
        }

        let path = CoreDataManager.shared.fetchCategoryPath(for: category)
        var url = baseURL
        for cat in path {
            let folderName = (cat.name ?? "Category")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            url = url.appendingPathComponent(folderName)
        }
        return url
    }

    /// Get category subfolder by category UUID (thread-safe, no CoreData object needed)
    private func categorySubfolderById(categoryId: UUID, baseURL: URL) -> URL {
        // Fetch category path on main thread via semaphore
        var folderNames: [String] = []
        let sem = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            if let category = CoreDataManager.shared.fetchDocumentCategory(id: categoryId) {
                let path = CoreDataManager.shared.fetchCategoryPath(for: category)
                folderNames = path.map { ($0.name ?? "Category")
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                }
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)

        var url = baseURL
        for name in folderNames {
            url = url.appendingPathComponent(name)
        }
        return url
    }

    /// Generate a filename for the document
    private func generateFilename(for document: Document) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateString = dateFormatter.string(from: document.createdAt ?? Date())
        let title = document.title?.replacingOccurrences(of: "/", with: "-")
                                   .replacingOccurrences(of: ":", with: "-")
                                   .prefix(50) ?? "Document"

        return "\(dateString)_\(title).pdf"
    }

    /// Create a PDF from image and document metadata
    private func createPDF(from image: UIImage, document: Document) -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: image.size))

        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            image.draw(at: .zero)
        }

        return data
    }

    // MARK: - Import from Sync Folder (Inbox Workflow)

    /// Scan the ROOT of sync folder for new files (inbox).
    /// Files at root are imported, classified by AI, then MOVED to the appropriate
    /// category subfolder (Documents/Personnel/, Documents/Infinity Cloud/, etc.).
    /// Files already in subfolders are NEVER touched (except deletion tracking).
    func importFromSyncFolder() {
        guard hasSyncFolder, let folderURL = securityScopedURL else { return }

        guard folderURL.startAccessingSecurityScopedResource() else {
            syncError = "Cannot access sync folder"
            return
        }

        // Detect files deleted from subfolders → remove from app
        detectDeletedFiles()

        // Clean up stale import tracking for failed imports
        cleanupStaleImportedNames(folderURL: folderURL)

        let supportedExtensions = Set(["pdf", "png", "jpg", "jpeg", "heic", "tiff"])

        // Build set of paths exported by the app (to avoid re-importing our own exports)
        let exportedFullPaths = Set(exportedDocumentPaths.values.map {
            folderURL.appendingPathComponent($0).path
        })

        // ONLY scan root folder (inbox) — subfolders are organized, don't touch
        var inboxFiles: [(url: URL, fileName: String)] = []

        if let rootContents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for fileURL in rootContents {
                // Skip directories
                if fileURL.hasDirectoryPath { continue }

                let ext = fileURL.pathExtension.lowercased()
                guard supportedExtensions.contains(ext) else { continue }

                // Skip already imported files
                guard !importedFileNames.contains(fileURL.path) else { continue }

                // Skip files exported by the app (prevents re-import loop)
                guard !exportedFullPaths.contains(fileURL.path) else { continue }

                inboxFiles.append((fileURL.standardizedFileURL, fileURL.lastPathComponent))
            }
        }

        guard !inboxFiles.isEmpty else {
            folderURL.stopAccessingSecurityScopedResource()
            return
        }

        isSyncingAll = true
        importedCount = 0
        syncProgress = (0, inboxFiles.count)

        // Keep security-scoped access alive through the entire background work
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                folderURL.stopAccessingSecurityScopedResource()
                return
            }

            for (index, file) in inboxFiles.enumerated() {
                self.importFile(at: file.url, fileName: file.fileName)

                DispatchQueue.main.async {
                    self.syncProgress = (index + 1, inboxFiles.count)
                    self.importedCount = index + 1
                }
            }

            // Release security-scoped access after all work is done
            folderURL.stopAccessingSecurityScopedResource()

            DispatchQueue.main.async {
                self.isSyncingAll = false
                self.lastSyncDate = Date()
                self.saveSettings()
                NotificationCenter.default.post(name: .documentAdded, object: nil)
            }
        }
    }

    private func importFile(at url: URL, fileName: String) {
        let ext = url.pathExtension.lowercased()

        var image: UIImage?
        var rawText: String?
        var pdfFileData: Data?

        if ext == "pdf" {
            // Read the raw PDF data for multi-page storage
            pdfFileData = try? Data(contentsOf: url)

            // Extract first page as image and text from PDF
            if let pdfDocument = PDFDocument(url: url) {
                // Extract text from all pages
                var texts: [String] = []
                for i in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: i),
                       let text = page.string {
                        texts.append(text)
                    }
                }
                rawText = texts.joined(separator: "\n")

                // Extract first page as thumbnail image
                if let firstPage = pdfDocument.page(at: 0) {
                    let pageRect = firstPage.bounds(for: .mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                    image = renderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(pageRect)
                        ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                        ctx.cgContext.scaleBy(x: 1, y: -1)
                        firstPage.draw(with: .mediaBox, to: ctx.cgContext)
                    }
                }
            }
        } else {
            // Image file
            if let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
            }
        }

        // OCR if we have image but no text
        if let img = image, (rawText == nil || rawText?.isEmpty == true) {
            rawText = performOCR(on: img)
        }

        let finalText = (rawText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Need at least an image or text to create a document
        guard image != nil || !finalText.isEmpty else {
            DispatchQueue.main.async {
                self.importedFileNames.insert(url.path)
            }
            return
        }

        // Classify and create document on main thread
        let semaphore = DispatchSemaphore(value: 0)
        var resultDocId: UUID?
        var resultCategoryId: UUID?
        var resultTitle: String?
        var resultDate: Date?

        DispatchQueue.main.async {
            let titleFromFileName = fileName
                .replacingOccurrences(of: ".pdf", with: "")
                .replacingOccurrences(of: ".PDF", with: "")

            if !finalText.isEmpty {
                // Has text: classify with AI
                DocumentClassificationService.shared.classifyDocument(rawText: finalText, image: image) { classification in
                    let doc = CoreDataManager.shared.createDocumentWithCategory(
                        categoryId: classification.categoryId,
                        title: classification.title,
                        summary: classification.summary,
                        rawText: finalText,
                        image: image,
                        pdfData: pdfFileData,
                        amount: classification.amount,
                        currency: classification.currency
                    )

                    // Capture values for background thread (CoreData objects aren't thread-safe)
                    resultDocId = doc.id
                    resultCategoryId = doc.categoryId
                    resultTitle = doc.title
                    resultDate = doc.createdAt
                    semaphore.signal()
                }
            } else {
                // Image only (no text): use "Divers" fallback category
                let diversCategory = self.findOrCreateDiversCategory()

                let doc = CoreDataManager.shared.createDocumentWithCategory(
                    categoryId: diversCategory,
                    title: titleFromFileName,
                    summary: nil,
                    rawText: nil,
                    image: image,
                    pdfData: pdfFileData,
                    amount: 0,
                    currency: "CHF"
                )

                resultDocId = doc.id
                resultCategoryId = doc.categoryId
                resultTitle = doc.title
                resultDate = doc.createdAt
                semaphore.signal()
            }
        }

        // Wait for classification to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 30)

        // Move file from inbox (root) to category subfolder + rename
        if let docId = resultDocId, let catId = resultCategoryId {
            moveToCategory(file: url, docId: docId, categoryId: catId, title: resultTitle, date: resultDate)
        }
    }

    /// Map a folder path to an existing category, creating intermediate categories if needed
    /// e.g., ["Personnel", "Santé"] → finds or creates Personnel > Santé category chain
    private func findOrCreateCategoryByPath(_ path: [String]) -> UUID? {
        guard !path.isEmpty else { return nil }

        var currentParentId: UUID? = nil

        for folderName in path {
            // Look for existing category with this name under current parent
            let children = CoreDataManager.shared.fetchChildCategories(parentId: currentParentId)
            if let existing = children.first(where: {
                ($0.name ?? "").localizedCaseInsensitiveCompare(folderName) == .orderedSame
            }) {
                currentParentId = existing.id
            } else {
                // Create new category at this level
                let newCat = CoreDataManager.shared.createDocumentCategory(
                    name: folderName,
                    parentId: currentParentId
                )
                currentParentId = newCat.id
            }
        }

        return currentParentId
    }

    /// Perform OCR on an image using Vision framework
    private func performOCR(on image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let semaphore = DispatchSemaphore(value: 0)
        var recognizedText: String?

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                semaphore.signal()
                return
            }

            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            recognizedText = texts.joined(separator: "\n")
            semaphore.signal()
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR", "en-US", "de-DE"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        _ = semaphore.wait(timeout: .now() + 10)
        return recognizedText
    }

    // MARK: - Bidirectional Sync Deletion

    /// Track an exported file path relative to the sync folder
    private func trackExportedFile(documentId: UUID?, fileURL: URL) {
        guard let docId = documentId, let folderURL = securityScopedURL else { return }
        let relativePath = fileURL.path.replacingOccurrences(of: folderURL.path + "/", with: "")
        exportedDocumentPaths[docId.uuidString] = relativePath
    }

    /// Track an imported file so it won't be re-exported with a different name
    private func trackImportedFile(documentId: UUID?, fileURL: URL) {
        guard let docId = documentId, let folderURL = securityScopedURL else { return }
        let relativePath = fileURL.path.replacingOccurrences(of: folderURL.path + "/", with: "")
        exportedDocumentPaths[docId.uuidString] = relativePath
    }

    /// Move imported file from inbox (root) to the appropriate category subfolder
    /// and rename it with the AI-generated title.
    /// Uses thread-safe values (not CoreData objects) to avoid cross-thread issues.
    private func moveToCategory(file url: URL, docId: UUID, categoryId: UUID, title: String?, date: Date?) {
        guard let folderURL = securityScopedURL else { return }

        // Build destination: Documents/{CategoryPath}/
        let documentsFolder = folderURL.appendingPathComponent("Documents")
        let categoryFolder = categorySubfolderById(categoryId: categoryId, baseURL: documentsFolder)
        try? FileManager.default.createDirectory(at: categoryFolder, withIntermediateDirectories: true)

        // Generate filename from passed values
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date ?? Date())
        let safeTitle = (title ?? "Document")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(50)
        let newFilename = "\(dateString)_\(safeTitle).pdf"
        var destinationURL = categoryFolder.appendingPathComponent(newFilename)

        // Avoid overwriting — append number if needed
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = newFilename.replacingOccurrences(of: ".pdf", with: " (\(counter)).pdf")
            destinationURL = categoryFolder.appendingPathComponent(name)
            counter += 1
        }

        do {
            try FileManager.default.moveItem(at: url, to: destinationURL)

            // Track new location
            let relativePath = destinationURL.path.replacingOccurrences(of: folderURL.path + "/", with: "")
            exportedDocumentPaths[docId.uuidString] = relativePath

            // Update importedFileNames with new path
            importedFileNames.remove(url.path)
            importedFileNames.insert(destinationURL.path)
        } catch {
            // Move failed — track original location as fallback
            let relativePath = url.path.replacingOccurrences(of: folderURL.path + "/", with: "")
            exportedDocumentPaths[docId.uuidString] = relativePath
            importedFileNames.insert(url.path)
        }
        saveSettings()
    }

    /// Find or create the "Divers" fallback category for unclassifiable documents
    private func findOrCreateDiversCategory() -> UUID {
        let categories = CoreDataManager.shared.fetchDocumentCategories()

        // Look for existing "Divers" root category
        if let divers = categories.first(where: {
            $0.parentId == nil && ($0.name ?? "").localizedCaseInsensitiveCompare("Divers") == .orderedSame
        }) {
            return divers.id ?? UUID()
        }

        // Create it
        let newCat = CoreDataManager.shared.createDocumentCategory(
            name: "Divers",
            icon: "tray.fill",
            colorHex: "#8E8E93",
            classificationPrompt: "Documents divers qui ne correspondent à aucune autre catégorie",
            summaryPrompt: "Résume brièvement le contenu du document",
            order: 999
        )
        return newCat.id ?? UUID()
    }

    /// Delete the exported file for a document (App → File sync deletion)
    func deleteExportedFile(for documentId: UUID) {
        let key = documentId.uuidString
        guard let relativePath = exportedDocumentPaths[key],
              let folderURL = securityScopedURL else { return }

        guard folderURL.startAccessingSecurityScopedResource() else { return }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let fileURL = folderURL.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: fileURL)

        exportedDocumentPaths.removeValue(forKey: key)
        importedFileNames.remove(fileURL.path)
        saveSettings()
    }

    /// Detect files deleted from sync folder and remove corresponding documents (File → App)
    private func detectDeletedFiles() {
        guard let folderURL = securityScopedURL, !exportedDocumentPaths.isEmpty else { return }

        var deletedDocIds: [String] = []

        for (docId, relativePath) in exportedDocumentPaths {
            let fileURL = folderURL.appendingPathComponent(relativePath)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                deletedDocIds.append(docId)
            }
        }

        guard !deletedDocIds.isEmpty else { return }

        for docIdString in deletedDocIds {
            guard let uuid = UUID(uuidString: docIdString) else { continue }
            CoreDataManager.shared.deleteDocumentById(uuid)
            exportedDocumentPaths.removeValue(forKey: docIdString)
        }

        saveSettings()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentAdded, object: nil)
        }
    }

    /// Remove stale entries from importedFileNames for files that exist on disk
    /// but were never actually imported (e.g. failed OCR/text extraction).
    /// Skips files that are known app exports (tracked in exportedDocumentPaths).
    private func cleanupStaleImportedNames(folderURL: URL) {
        // Build set of known exported file paths
        let exportedPaths = Set(exportedDocumentPaths.values.map {
            folderURL.appendingPathComponent($0).path
        })

        // Also build set of all app-exported filename patterns in importedFileNames
        // that match the YYYY-MM-DD_ export pattern — these are legitimate skips
        var staleNames: [String] = []

        for path in importedFileNames {
            // Skip if it's a known export
            if exportedPaths.contains(path) { continue }

            // Skip if file no longer exists (already cleaned)
            guard FileManager.default.fileExists(atPath: path) else {
                staleNames.append(path)
                continue
            }

            // Check if filename matches app-export pattern
            let fileName = (path as NSString).lastPathComponent
            let isAppExported = fileName.range(of: #"^\d{4}-\d{2}-\d{2}_"#, options: .regularExpression) != nil
            if isAppExported { continue }

            // This file exists, wasn't exported by us, and is in importedFileNames
            // It was likely a failed import — allow retry
            staleNames.append(path)
        }

        if !staleNames.isEmpty {
            for name in staleNames {
                importedFileNames.remove(name)
            }
            saveSettings()
        }
    }

    // MARK: - Toggle Settings

    func toggleSync(enabled: Bool) {
        if enabled && !hasSyncFolder {
            return
        }
        syncEnabled = enabled
        saveSettings()
    }

    func toggleWiFiOnly(enabled: Bool) {
        wifiOnlyEnabled = enabled
        saveSettings()

        // If WiFi only is disabled and we have pending documents, sync them now
        if !enabled && !pendingDocumentIDs.isEmpty {
            syncPendingDocuments()
        }
    }
}
