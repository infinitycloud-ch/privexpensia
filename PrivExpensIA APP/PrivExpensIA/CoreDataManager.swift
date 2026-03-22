import Foundation
import CoreData
import UIKit

// MARK: - Core Data Manager avec VRAIE persistance
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "PrivExpensIA")

        // Enable lightweight migration for schema changes (new attributes, etc.)
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
            } else {
            }
        }
        return container
    }()

    private init() {
        // Singleton
    }

    // MARK: - Core Data Operations

    func saveContext() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
            }
        }
    }

    // MARK: - Expense Operations

    func createExpense(
        merchant: String,
        amount: Double,
        tax: Double,
        category: String,
        date: Date = Date(),
        items: [String] = [],
        paymentMethod: String = "Card",
        notes: String = "",
        receiptImage: UIImage? = nil,
        rawOCRText: String? = nil
    ) -> Expense {
        let context = persistentContainer.viewContext
        let expense = Expense(context: context)

        expense.id = UUID()
        expense.merchant = merchant
        expense.amount = amount
        expense.taxAmount = tax
        expense.category = category
        expense.date = date
        expense.items = items
        expense.paymentMethod = paymentMethod
        expense.notes = notes
        expense.currency = "CHF"
        expense.confidence = 1.0
        expense.createdAt = Date()

        // Sprint 5: Sauvegarder texte OCR brut pour Enhance AI
        expense.rawOCRText = rawOCRText
        expense.userCorrected = false

        // Sauvegarder l'image si fournie
        if let image = receiptImage {
            expense.receiptImageData = image.jpegData(compressionQuality: 0.8)
        }

        saveContext()

        // Post notification for UI update
        NotificationCenter.default.post(name: .expenseAdded, object: expense)

        return expense
    }

    // SPRINT 3: Nouvelle fonction qui fait CONFIANCE aux données parsées
    // Sprint 5: Ajout rawOCRText pour Enhance AI
    @discardableResult
    func saveExpense(merchant: String, amount: Double, tax: Double, category: String,
                    date: Date, items: [String], paymentMethod: String, image: UIImage?,
                    rawOCRText: String? = nil) -> Expense {

        return createExpense(
            merchant: merchant,
            amount: amount,
            tax: tax,
            category: category,
            date: date,
            items: items,
            paymentMethod: paymentMethod,
            notes: "",
            receiptImage: image,
            rawOCRText: rawOCRText
        )
    }

    // ANCIENNE FONCTION - DÉPRÉCIÉE - Cause du double-parsing
    func saveOCRResult(extractedData: Any, image: UIImage?) {

        // Fallback temporaire - utilise uniquement le parser enhanced
        if let data = extractedData as? ExtractedData {
            let parsed = ExpenseParser.shared.parseFromOCRResult(data)

            _ = createExpense(
                merchant: parsed.merchant,
                amount: parsed.totalAmount,
                tax: parsed.vatAmount,
                category: parsed.category,
                date: parsed.date,
                items: parsed.items,
                paymentMethod: parsed.paymentMethod.isEmpty ? "Card" : parsed.paymentMethod,
                notes: "",
                receiptImage: image
            )

        }
    }

    func fetchExpenses() -> [Expense] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let expenses = try context.fetch(request)
            return expenses
        } catch {
            return []
        }
    }

    func fetchRecentExpenses(limit: Int = 10) -> [Expense] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    func deleteExpense(_ expense: Expense) {
        let context = persistentContainer.viewContext
        context.delete(expense)
        saveContext()
    }

    func deleteAllExpenses() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = Expense.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
        }
    }

    // MARK: - Budget & Analytics Support

    func getTotalSpending(from startDate: Date, to endDate: Date) -> Double {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()

        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)

        do {
            let expenses = try context.fetch(request)
            return expenses.reduce(0) { $0 + $1.amount }
        } catch {
            return 0
        }
    }

    func getSpendingByCategory(from startDate: Date, to endDate: Date) -> [String: Double] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()

        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)

        do {
            let expenses = try context.fetch(request)
            var categoryTotals: [String: Double] = [:]

            for expense in expenses {
                let category = expense.category ?? "Other"
                categoryTotals[category, default: 0] += expense.amount
            }

            return categoryTotals
        } catch {
            return [:]
        }
    }

    // MARK: - Cleanup Test Data (one-time)

    /// Removes test data that was previously auto-created. Runs only once.
    func cleanupTestDataIfNeeded() {
        let cleanupKey = "testDataCleanedUp_v1"
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else {
            return // Already cleaned up
        }

        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()

        // Find test expenses by their exact characteristics
        let testMerchants = ["Migros", "Coop", "SBB CFF"]
        request.predicate = NSPredicate(format: "merchant IN %@", testMerchants)

        do {
            let testExpenses = try context.fetch(request)

            // Only delete if they match the original test amounts
            let testAmounts: [String: Double] = ["Migros": 45.50, "Coop": 32.20, "SBB CFF": 68.00]

            var deletedCount = 0
            for expense in testExpenses {
                if let merchant = expense.merchant,
                   let expectedAmount = testAmounts[merchant],
                   abs(expense.amount - expectedAmount) < 0.01 {
                    context.delete(expense)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
            }
        } catch {
        }

        // Mark as done so it doesn't run again
        UserDefaults.standard.set(true, forKey: cleanupKey)
    }

    // MARK: - Document Operations (Sprint 13)

    /// Create a new document in the archive
    @discardableResult
    func createDocument(
        type: String,
        title: String,
        summary: String? = nil,
        rawText: String? = nil,
        image: UIImage? = nil,
        amount: Double = 0,
        currency: String = "CHF"
    ) -> Document {
        // Ensure we're on main thread for CoreData
        let context = persistentContainer.viewContext

        var document: Document!

        context.performAndWait {
            document = Document(context: context)

            document.id = UUID()
            document.type = type
            document.title = title
            document.summary = summary
            document.rawText = rawText
            document.amount = amount
            document.currency = currency
            document.createdAt = Date()

            // Save image if provided - use lower compression for reliability
            if let image = image {
                // Resize if too large (max 1500px width)
                let maxSize: CGFloat = 1500
                var finalImage = image
                if image.size.width > maxSize || image.size.height > maxSize {
                    let scale = min(maxSize / image.size.width, maxSize / image.size.height)
                    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                        finalImage = resized
                    }
                    UIGraphicsEndImageContext()
                }
                document.imageData = finalImage.jpegData(compressionQuality: 0.7)
            }

            do {
                try context.save()
            } catch {
                print("Error saving document: \(error)")
            }
        }

        // Post notification for UI update on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentAdded, object: document)
        }

        return document
    }

    /// Fetch all documents, optionally filtered by type
    func fetchDocuments(type: String? = nil) -> [Document] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        if let type = type {
            request.predicate = NSPredicate(format: "type == %@", type)
        }

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Fetch recent documents with limit
    func fetchRecentDocuments(limit: Int = 10) -> [Document] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Delete a document
    func deleteDocument(_ document: Document) {
        let context = persistentContainer.viewContext
        context.delete(document)
        saveContext()
    }

    /// Delete a document by its UUID (used by bidirectional sync)
    func deleteDocumentById(_ id: UUID) {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let doc = try? context.fetch(request).first {
            context.delete(doc)
            saveContext()
        }
    }

    /// Remove duplicate documents (same title + same categoryId). Keeps the oldest.
    /// Returns the number of duplicates removed.
    @discardableResult
    func removeDuplicateDocuments() -> Int {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let allDocs = try context.fetch(request)
            var seen: [String: Document] = [:]  // "title|categoryId" → first occurrence
            var deletedCount = 0

            for doc in allDocs {
                let title = doc.title ?? ""
                let catId = doc.categoryId?.uuidString ?? "none"
                let key = "\(title)|\(catId)"

                if seen[key] != nil {
                    // Duplicate — delete this one (keep the oldest)
                    context.delete(doc)
                    deletedCount += 1
                } else {
                    seen[key] = doc
                }
            }

            if deletedCount > 0 {
                try context.save()
            }
            return deletedCount
        } catch {
            return 0
        }
    }

    /// Delete all documents
    func deleteAllDocuments() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = Document.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
        }
    }

    // MARK: - DocumentCategory Operations (Sprint 14)

    /// Create a new document category
    @discardableResult
    func createDocumentCategory(
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        classificationPrompt: String? = nil,
        summaryPrompt: String? = nil,
        order: Int32 = 0,
        parentId: UUID? = nil
    ) -> DocumentCategory {
        let context = persistentContainer.viewContext
        let category = DocumentCategory(context: context)

        category.id = UUID()
        category.parentId = parentId
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        category.classificationPrompt = classificationPrompt
        category.summaryPrompt = summaryPrompt
        category.order = order
        category.createdAt = Date()

        saveContext()

        // Notify UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentCategoryChanged, object: nil)
        }

        return category
    }

    /// Fetch all document categories ordered by order field
    func fetchDocumentCategories() -> [DocumentCategory] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<DocumentCategory> = DocumentCategory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Fetch a specific category by ID
    func fetchDocumentCategory(id: UUID) -> DocumentCategory? {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<DocumentCategory> = DocumentCategory.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            return nil
        }
    }

    /// Update a document category
    func updateDocumentCategory(
        _ category: DocumentCategory,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        classificationPrompt: String? = nil,
        summaryPrompt: String? = nil,
        order: Int32? = nil
    ) {
        if let name = name { category.name = name }
        if let icon = icon { category.icon = icon }
        if let colorHex = colorHex { category.colorHex = colorHex }
        if let classificationPrompt = classificationPrompt { category.classificationPrompt = classificationPrompt }
        if let summaryPrompt = summaryPrompt { category.summaryPrompt = summaryPrompt }
        if let order = order { category.order = order }

        saveContext()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentCategoryChanged, object: nil)
        }
    }

    /// Delete a document category
    func deleteDocumentCategory(_ category: DocumentCategory) {
        let context = persistentContainer.viewContext
        context.delete(category)
        saveContext()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentCategoryChanged, object: nil)
        }
    }

    // MARK: - Category Hierarchy

    /// Fetch child categories of a given parent (nil = root categories)
    func fetchChildCategories(parentId: UUID?) -> [DocumentCategory] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<DocumentCategory> = DocumentCategory.fetchRequest()

        if let parentId = parentId {
            request.predicate = NSPredicate(format: "parentId == %@", parentId as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "parentId == nil")
        }

        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Build the path from root to the given category (for breadcrumbs)
    func fetchCategoryPath(for category: DocumentCategory) -> [DocumentCategory] {
        var path: [DocumentCategory] = [category]
        var current = category

        while let parentId = current.parentId,
              let parent = fetchDocumentCategory(id: parentId) {
            path.insert(parent, at: 0)
            current = parent
        }

        return path
    }

    /// Recursively collect all descendant category IDs (for document counting)
    func fetchDescendantCategoryIds(of categoryId: UUID) -> [UUID] {
        var allIds: [UUID] = [categoryId]
        let children = fetchChildCategories(parentId: categoryId)

        for child in children {
            if let childId = child.id {
                allIds.append(contentsOf: fetchDescendantCategoryIds(of: childId))
            }
        }

        return allIds
    }

    /// Count documents in a category including all subcategories
    func countDocuments(inCategoryAndDescendants categoryId: UUID) -> Int {
        let allIds = fetchDescendantCategoryIds(of: categoryId)
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.predicate = NSPredicate(format: "categoryId IN %@", allIds)

        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }

    /// Create default categories if none exist
    func ensureDefaultCategoriesExist() {
        let categories = fetchDocumentCategories()
        guard categories.isEmpty else { return }

        // Default category 1: Personnel
        createDocumentCategory(
            name: "Personnel",
            icon: "person.fill",
            colorHex: "#5856D6",
            classificationPrompt: "Documents personnels: factures maison, santé, impôts, assurances personnelles, courriers administratifs privés",
            summaryPrompt: "Résume en 1 phrase avec la date et l'objet principal du document",
            order: 0
        )

        // Default category 2: Infinity Cloud (Société)
        createDocumentCategory(
            name: "Infinity Cloud",
            icon: "cloud.fill",
            colorHex: "#007AFF",
            classificationPrompt: "Documents de la société Infinity Cloud: factures clients, devis, contrats, documents comptables, correspondance professionnelle",
            summaryPrompt: "Extrait: client/fournisseur, montant, date d'échéance si présente",
            order: 1
        )
    }

    /// Fetch documents by category ID
    func fetchDocuments(categoryId: UUID) -> [Document] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.predicate = NSPredicate(format: "categoryId == %@", categoryId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }

    /// Create document with category (new method for Sprint 14)
    @discardableResult
    func createDocumentWithCategory(
        categoryId: UUID,
        title: String,
        summary: String? = nil,
        rawText: String? = nil,
        image: UIImage? = nil,
        pdfData: Data? = nil,
        amount: Double = 0,
        currency: String = "CHF"
    ) -> Document {
        let context = persistentContainer.viewContext

        var document: Document!

        context.performAndWait {
            document = Document(context: context)

            document.id = UUID()
            document.categoryId = categoryId
            document.type = nil  // Deprecated - use categoryId
            document.title = title
            document.summary = summary
            document.rawText = rawText
            document.amount = amount
            document.currency = currency
            document.createdAt = Date()

            // Save image if provided
            if let image = image {
                let maxSize: CGFloat = 1500
                var finalImage = image
                if image.size.width > maxSize || image.size.height > maxSize {
                    let scale = min(maxSize / image.size.width, maxSize / image.size.height)
                    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                        finalImage = resized
                    }
                    UIGraphicsEndImageContext()
                }
                document.imageData = finalImage.jpegData(compressionQuality: 0.7)
            }

            // Save PDF data if provided (multi-page documents)
            document.pdfData = pdfData

            do {
                try context.save()
            } catch {
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .documentAdded, object: document)
        }

        // Auto-sync to configured folder
        DocumentSyncService.shared.syncDocument(document)

        return document
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let documentAdded = Notification.Name("documentAdded")
    static let documentCategoryChanged = Notification.Name("documentCategoryChanged")
}

// MARK: - Expense Entity Extension
extension Expense {
    // Computed properties for compatibility
    var totalAmount: Double {
        get { amount }
        set { amount = newValue }
    }

    // Note: taxAmount est maintenant une propriété @NSManaged native

    // Convert items from NSObject to [String]
    var itemsList: [String] {
        get {
            items ?? []
        }
        set {
            items = newValue
        }
    }

    // Convenience initializer for SwiftUI previews
    static func createPreview(context: NSManagedObjectContext) -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.merchant = "Sample Merchant"
        expense.amount = 100.0
        expense.taxAmount = 8.1
        expense.category = "Alimentation"
        expense.date = Date()
        expense.paymentMethod = "Card"
        expense.currency = "CHF"
        expense.confidence = 1.0
        expense.createdAt = Date()
        return expense
    }
}

// MARK: - ExpenseData for compatibility
struct ExpenseData: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var merchant: String
    var amount: Double
    var tax: Double
    var category: String
    var items: [String] = []
    var totalAmount: Double {
        get { amount }
        set { amount = newValue }
    }
    var taxAmount: Double { tax }
    var paymentMethod: String? = "Card"
    var notes: String = ""

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExpenseData, rhs: ExpenseData) -> Bool {
        lhs.id == rhs.id
    }

    // Conversion from Core Data Expense
    init(from expense: Expense) {
        self.id = expense.id ?? UUID()
        self.date = expense.date ?? Date()
        self.merchant = expense.merchant ?? "Unknown"
        self.amount = expense.amount
        self.tax = expense.taxAmount
        self.category = expense.category ?? "Divers"
        self.items = expense.itemsList
        self.paymentMethod = expense.paymentMethod
        self.notes = expense.notes ?? ""
    }

    // Direct initializer
    init(id: UUID, date: Date, merchant: String, amount: Double, tax: Double, category: String, items: [String] = [], paymentMethod: String? = "Card") {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.tax = tax
        self.category = category
        self.items = items
        self.paymentMethod = paymentMethod
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let expenseAdded = Notification.Name("expenseAdded")
}

// MARK: - ExtractedData (si pas déjà défini dans OCRService.swift)
struct CoreDataExtractedData {
    let text: String
    let lines: [String]
    let boundingBoxes: [CGRect]
}