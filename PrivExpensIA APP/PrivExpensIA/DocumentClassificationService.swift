import Foundation
import UIKit

// MARK: - Document Classification Service (Sprint 14)
// Dynamic classification using user-defined categories with AI instructions

class DocumentClassificationService {
    static let shared = DocumentClassificationService()

    private init() {}

    // MARK: - Classification Result
    struct ClassificationResult {
        let categoryId: UUID
        let categoryName: String
        let title: String
        let summary: String?
        let amount: Double
        let currency: String
        let rawText: String
    }

    // MARK: - Main Classification Method (Dynamic Categories)
    func classifyDocument(rawText: String, image: UIImage?, completion: @escaping (ClassificationResult) -> Void) {
        // 1. Fetch all categories
        let categories = CoreDataManager.shared.fetchDocumentCategories()

        // Ensure default categories exist
        if categories.isEmpty {
            CoreDataManager.shared.ensureDefaultCategoriesExist()
            let newCategories = CoreDataManager.shared.fetchDocumentCategories()
            classifyWithCategories(rawText: rawText, categories: newCategories, completion: completion)
        } else {
            classifyWithCategories(rawText: rawText, categories: categories, completion: completion)
        }
    }

    private func classifyWithCategories(rawText: String, categories: [DocumentCategory], completion: @escaping (ClassificationResult) -> Void) {
        // 2. Extract amount first (for context)
        let amountResult = detectAmount(in: rawText)

        // 2.5. Try keyword pre-classification before LLM (faster + more reliable)
        let keywordMatch = classifyByKeywords(rawText: rawText, categories: categories)

        // 3. Use keyword match if confident, else fall back to LLM
        let classificationHandler: (DocumentCategory) -> Void = { matchedCategory in
            // 4. Generate summary using category's summaryPrompt
            self.generateSummaryWithLLM(rawText: rawText, category: matchedCategory) { summary in
                // 5. Generate title with LLM
                self.generateTitleWithLLM(rawText: rawText, category: matchedCategory, amount: amountResult.amount) { title in
                    let result = ClassificationResult(
                        categoryId: matchedCategory.id ?? UUID(),
                        categoryName: matchedCategory.name ?? "Document",
                        title: title,
                        summary: summary,
                        amount: amountResult.amount,
                        currency: amountResult.currency,
                        rawText: rawText
                    )

                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
        }

        if let keywordCategory = keywordMatch {
            classificationHandler(keywordCategory)
        } else {
            classifyWithLLM(rawText: rawText, categories: categories, amount: amountResult.amount, completion: classificationHandler)
        }
    }

    // MARK: - Keyword Pre-Classification
    /// Fast keyword matching: if the document text clearly mentions a category name, use it directly.
    /// This avoids LLM misclassification for obvious cases like "Infinity Cloud" docs.
    private func classifyByKeywords(rawText: String, categories: [DocumentCategory]) -> DocumentCategory? {
        let lowText = rawText.lowercased()

        // Score each category by keyword matches in document text
        var scores: [(category: DocumentCategory, score: Int)] = []

        for category in categories {
            var score = 0
            let catName = (category.name ?? "").lowercased()

            // Skip very generic names (1-2 words like "personnel", "divers")
            let isSpecificName = catName.contains(" ") && catName.count > 6

            // Check if category name appears in document text
            if isSpecificName && lowText.contains(catName) {
                // Count occurrences - more = stronger signal
                var searchRange = lowText.startIndex..<lowText.endIndex
                while let range = lowText.range(of: catName, range: searchRange) {
                    score += 10
                    searchRange = range.upperBound..<lowText.endIndex
                }
            }

            // Also check classificationPrompt keywords
            if let prompt = category.classificationPrompt {
                // Extract company/org names from prompt (words starting with uppercase, multi-word)
                let keywords = extractKeywordsFromPrompt(prompt)
                for keyword in keywords {
                    if lowText.contains(keyword.lowercased()) {
                        score += 5
                    }
                }
            }

            if score > 0 {
                scores.append((category: category, score: score))
            }
        }

        // Only return if one category clearly wins (score >= 10 = name appears in text)
        let sorted = scores.sorted { $0.score > $1.score }
        if let best = sorted.first, best.score >= 10 {
            // Make sure it's significantly better than second best
            if sorted.count < 2 || best.score > sorted[1].score * 2 {
                return best.category
            }
        }

        return nil // No confident keyword match, fall back to LLM
    }

    /// Extract meaningful keywords from a classificationPrompt
    private func extractKeywordsFromPrompt(_ prompt: String) -> [String] {
        // Look for proper nouns / company names (capitalized multi-word sequences)
        var keywords: [String] = []
        let words = prompt.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Extract capitalized words that look like proper nouns (not common French words)
        let commonWords = Set(["Documents", "Documents", "Factures", "Contrats", "Devis",
                               "Courriers", "Correspondance", "Personnels", "Professionnelle",
                               "Comptables", "Administratifs", "Assurances", "Santé",
                               "Impôts", "Maison", "Privés", "Clients", "Fournisseurs"])
        for word in words {
            if word.first?.isUppercase == true && word.count > 3 && !commonWords.contains(word) {
                keywords.append(word)
            }
        }
        return keywords
    }

    // MARK: - LLM Classification
    private func classifyWithLLM(rawText: String, categories: [DocumentCategory], amount: Double, completion: @escaping (DocumentCategory) -> Void) {
        // Build hierarchical category tree with numbered paths
        var indexedCategories: [(path: String, category: DocumentCategory)] = []
        let treeDescription = buildCategoryTree(categories: categories, parentId: nil, prefix: "", indexedCategories: &indexedCategories)

        let prompt = """
        Classifie ce document dans la catégorie la plus appropriée.

        RÈGLE IMPORTANTE: Si le document mentionne le NOM d'une catégorie (ex: nom d'entreprise), classe-le dans CETTE catégorie.
        Choisis la catégorie la plus SPÉCIFIQUE (feuille) qui correspond.

        CATÉGORIES DISPONIBLES:
        \(treeDescription)

        DOCUMENT (extrait):
        \(String(rawText.prefix(1500)))

        \(amount > 0 ? "Ce document contient un montant de \(String(format: "%.2f", amount))" : "")

        Réponds UNIQUEMENT avec le numéro de la catégorie (ex: 1, 2, 1.2).
        """

        ExpenseRAGService.shared.askLLMDirect(prompt) { result in
            switch result {
            case .success(let response):
                let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".:;-() "))

                // Try exact path match first
                if let match = indexedCategories.first(where: { $0.path == trimmedResponse }) {
                    completion(match.category)
                    return
                }

                // Try partial match (e.g. "1" matches "1")
                let numbers = trimmedResponse.components(separatedBy: CharacterSet(charactersIn: "., "))
                    .filter { !$0.isEmpty }
                    .joined(separator: ".")

                if let match = indexedCategories.first(where: { $0.path == numbers }) {
                    completion(match.category)
                    return
                }

                // Try simple number as flat index
                if let number = Int(trimmedResponse.filter { $0.isNumber }.prefix(2)),
                   number >= 1 && number <= categories.count {
                    completion(categories[number - 1])
                } else {
                    completion(categories.first ?? self.createFallbackCategory())
                }

            case .failure:
                completion(categories.first ?? self.createFallbackCategory())
            }
        }
    }

    /// Build a hierarchical tree string and populate indexed categories
    private func buildCategoryTree(categories: [DocumentCategory], parentId: UUID?, prefix: String, indexedCategories: inout [(path: String, category: DocumentCategory)]) -> String {
        let children = categories.filter { $0.parentId == parentId }
            .sorted { $0.order < $1.order }

        var lines: [String] = []
        for (index, child) in children.enumerated() {
            let path = prefix.isEmpty ? "\(index + 1)" : "\(prefix).\(index + 1)"
            let name = child.name ?? "Catégorie"
            let rules = child.classificationPrompt ?? "Documents généraux"
            let indent = String(repeating: "   ", count: path.components(separatedBy: ".").count - 1)

            lines.append("\(indent)\(path). \(name): \(rules)")
            indexedCategories.append((path: path, category: child))

            // Recurse for children
            let childTree = buildCategoryTree(categories: categories, parentId: child.id, prefix: path, indexedCategories: &indexedCategories)
            if !childTree.isEmpty {
                lines.append(childTree)
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - LLM Summary Generation
    private func generateSummaryWithLLM(rawText: String, category: DocumentCategory, completion: @escaping (String?) -> Void) {
        guard let summaryPrompt = category.summaryPrompt, !summaryPrompt.isEmpty else {
            // No custom summary prompt - use heuristic
            let summary = extractKeyInfoFromText(rawText)
            completion(summary)
            return
        }

        let prompt = """
        \(summaryPrompt)

        DOCUMENT:
        \(String(rawText.prefix(2000)))

        Résumé (2-3 phrases max):
        """

        ExpenseRAGService.shared.askLLMDirect(prompt) { result in
            switch result {
            case .success(let response):
                let summary = response.trimmingCharacters(in: .whitespacesAndNewlines)
                if summary.isEmpty || summary.lowercased().contains("erreur") || summary.count < 10 {
                    // Fallback to heuristic if LLM fails
                    completion(self.extractKeyInfoFromText(rawText))
                } else {
                    completion(summary)
                }

            case .failure:
                // LLM failed - use heuristic fallback
                completion(self.extractKeyInfoFromText(rawText))
            }
        }
    }

    // MARK: - Title Generation with LLM
    private func generateTitleWithLLM(rawText: String, category: DocumentCategory, amount: Double, completion: @escaping (String) -> Void) {
        let categoryName = category.name ?? "Document"

        let prompt = """
        Génère un titre court et descriptif pour ce document (max 40 caractères).
        Le titre doit être parlant et identifier clairement le document.

        Catégorie: \(categoryName)
        \(amount > 0 ? "Montant: \(String(format: "%.2f", amount)) CHF" : "")

        DOCUMENT (extrait):
        \(String(rawText.prefix(1000)))

        RÈGLES:
        - Jamais de codes ou numéros alphanumériques longs
        - Inclure le nom de l'entreprise/organisme si présent
        - Format: "Type - Entreprise" ou "Sujet principal"
        - Si facture: "Facture Entreprise Mois" ou "Entreprise - Date"
        - Si administratif: "Type de document - Contexte"

        Réponds UNIQUEMENT avec le titre, sans guillemets ni explication.
        """

        ExpenseRAGService.shared.askLLMDirect(prompt) { result in
            switch result {
            case .success(let response):
                let title = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")

                // Validate the title - reject if it looks like alphanumeric code
                if self.isValidTitle(title) {
                    completion(title.count > 50 ? String(title.prefix(47)) + "..." : title)
                } else {
                    // Fallback to heuristic
                    completion(self.generateTitleHeuristic(from: rawText, category: category, amount: amount))
                }

            case .failure:
                // LLM failed - use heuristic
                completion(self.generateTitleHeuristic(from: rawText, category: category, amount: amount))
            }
        }
    }

    private func isValidTitle(_ title: String) -> Bool {
        // Reject if title is empty or too short
        guard title.count >= 3 else { return false }

        // Reject if it's mostly numbers/alphanumeric codes
        let alphanumericOnly = title.filter { $0.isNumber || $0.isLetter }
        let numberCount = title.filter { $0.isNumber }.count
        let letterCount = title.filter { $0.isLetter }.count

        // If more than 50% numbers and title is long, it's probably a code
        if title.count > 8 && Double(numberCount) / Double(alphanumericOnly.count) > 0.5 {
            return false
        }

        // Reject if it contains long sequences of numbers (like 12+ digits)
        let longNumberPattern = #"\d{10,}"#
        if title.range(of: longNumberPattern, options: .regularExpression) != nil {
            return false
        }

        return true
    }

    // MARK: - Title Generation Heuristic (Fallback)
    private func generateTitleHeuristic(from text: String, category: DocumentCategory, amount: Double) -> String {
        let categoryName = category.name ?? "Document"

        // Extract merchant/company name
        let merchantName = extractMerchantName(from: text)

        // Extract date
        let dateStr = extractDateString(from: text)

        if amount > 0 {
            // It's an invoice-type document
            if let merchant = merchantName {
                return "\(merchant) - \(dateStr)"
            } else {
                return "\(categoryName) - \(dateStr)"
            }
        } else {
            // Administrative document
            if let merchant = merchantName {
                return "\(merchant) - \(dateStr)"
            } else {
                // Try to extract a meaningful title from document type keywords
                let docType = extractDocumentType(from: text)
                if docType != "Document" {
                    return "\(docType) - \(dateStr)"
                }
                return "\(categoryName) - \(dateStr)"
            }
        }
    }

    private func extractDocumentType(from text: String) -> String {
        let lowercaseText = text.lowercased()
        let typeKeywords: [(String, String)] = [
            ("attestation", "Attestation"),
            ("certificat", "Certificat"),
            ("confirmation", "Confirmation"),
            ("avis", "Avis"),
            ("contrat", "Contrat"),
            ("courrier", "Courrier"),
            ("lettre", "Lettre"),
            ("facture", "Facture"),
            ("devis", "Devis"),
            ("rapport", "Rapport"),
            ("relevé", "Relevé"),
            ("bulletin", "Bulletin"),
            ("déclaration", "Déclaration"),
            ("notification", "Notification"),
            ("récépissé", "Récépissé"),
            ("reçu", "Reçu"),
            ("quittance", "Quittance"),
            ("bon de commande", "Bon de commande"),
            ("bordereau", "Bordereau")
        ]

        for (key, value) in typeKeywords {
            if lowercaseText.contains(key) {
                return value
            }
        }

        return "Document"
    }

    // MARK: - Helper Methods

    private func createFallbackCategory() -> DocumentCategory {
        // Create a temporary in-memory category for fallback
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let category = DocumentCategory(context: context)
        category.id = UUID()
        category.name = "Divers"
        category.icon = "folder.fill"
        category.colorHex = "#8E8E93"
        return category
    }

    private func extractMerchantName(from text: String) -> String? {
        let merchantPatterns = [
            // Common Swiss merchants
            #"(Swisscom|Sunrise|Salt|UPC|Migros|Coop|Manor|Denner|Lidl|Aldi)"#,
            // Insurance companies
            #"(CSS|Swica|Helsana|Visana|Sanitas|Concordia|Groupe Mutuel)"#,
            // Utilities
            #"(SIG|SIL|ewz|BKW|Axpo|EWZ|Services Industriels)"#,
            // Banks
            #"(UBS|Credit Suisse|PostFinance|Raiffeisen|BCGE|BCV)"#,
            // Company patterns
            #"(Infinity Cloud)"#,
            // Generic company with suffix
            #"([A-Z][A-Za-zÀ-ÿ\s&.,-]+(?:SA|AG|GmbH|Sàrl|Ltd))"#
        ]

        for pattern in merchantPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    private func extractDateString(from text: String) -> String {
        let datePatterns = [
            #"(\d{1,2})[./](\d{1,2})[./](\d{2,4})"#,
            #"(\d{1,2})\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s+(\d{4})"#
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if match.numberOfRanges >= 3,
                   let monthRange = Range(match.range(at: 2), in: text),
                   let yearRange = Range(match.range(at: 3), in: text) {
                    let month = String(text[monthRange])
                    let year = String(text[yearRange])
                    if let monthNum = Int(month), monthNum >= 1 && monthNum <= 12 {
                        let monthNames = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin",
                                        "Juil", "Août", "Sep", "Oct", "Nov", "Déc"]
                        return monthNames[monthNum - 1] + " " + (year.count == 2 ? "20" + year : year)
                    } else {
                        return month.capitalized + " " + year
                    }
                }
            }
        }

        // Return current date if not found
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Amount Detection
    private func detectAmount(in text: String) -> (amount: Double, currency: String) {
        let patterns = [
            #"(?:CHF|Fr\.|SFr\.?)\s*(\d+['\s]?\d*[.,]\d{2})"#,
            #"(\d+['\s]?\d*[.,]\d{2})\s*(?:CHF|Fr\.|SFr\.?)"#,
            #"(?:EUR|€)\s*(\d+['\s]?\d*[.,]\d{2})"#,
            #"(\d+['\s]?\d*[.,]\d{2})\s*(?:EUR|€)"#,
            #"(?:Total|TOTAL|Betrag|Montant|Somme)[:\s]+(\d+['\s]?\d*[.,]\d{2})"#
        ]

        var maxAmount: Double = 0
        var detectedCurrency = "CHF"

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    if let amountRange = Range(match.range(at: 1), in: text) {
                        var amountStr = String(text[amountRange])
                        amountStr = amountStr.replacingOccurrences(of: "'", with: "")
                        amountStr = amountStr.replacingOccurrences(of: " ", with: "")
                        amountStr = amountStr.replacingOccurrences(of: ",", with: ".")

                        if let amount = Double(amountStr), amount > maxAmount {
                            maxAmount = amount
                            if text.contains("EUR") || text.contains("€") {
                                detectedCurrency = "EUR"
                            }
                        }
                    }
                }
            }
        }

        return (maxAmount, detectedCurrency)
    }

    // MARK: - Heuristic Extraction (Fallback)
    private func extractKeyInfoFromText(_ text: String) -> String {
        var infos: [String] = []

        // Organization names
        let orgPatterns = [
            #"(?:SA|AG|GmbH|Sàrl|Ltd|Inc|SARL|SAS)[\s.,]"#,
            #"(?:Assurance|Insurance|Bank|Banque|Caisse|Office|Service)"#
        ]
        for pattern in orgPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                let lines = text.components(separatedBy: .newlines)
                for line in lines.prefix(10) where line.range(of: pattern, options: .regularExpression) != nil {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.count > 5 && trimmed.count < 60 {
                        infos.append(trimmed)
                        break
                    }
                }
                break
            }
        }

        // Dates
        let datePatterns = [
            #"\d{1,2}[./]\d{1,2}[./]\d{2,4}"#,
            #"\d{1,2}\s+(?:janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s+\d{4}"#
        ]
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                infos.append("Date: \(text[range])")
                break
            }
        }

        // References
        let refPatterns = [
            #"(?:Réf|Ref|N°|Nr|Numéro|Dossier)[.:\s]*([A-Z0-9-/]+)"#
        ]
        for pattern in refPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                infos.append("Réf: \(text[range])")
                break
            }
        }

        if infos.isEmpty {
            return generateHeuristicSummary(from: text)
        }
        return infos.joined(separator: " • ")
    }

    private func generateHeuristicSummary(from text: String) -> String {
        let keywords = [
            "attestation": "Attestation",
            "certificat": "Certificat",
            "confirmation": "Confirmation",
            "avis": "Avis",
            "contrat": "Contrat",
            "courrier": "Courrier",
            "lettre": "Lettre",
            "facture": "Facture",
            "devis": "Devis"
        ]

        let lowercaseText = text.lowercased()
        for (key, value) in keywords {
            if lowercaseText.contains(key) {
                return "\(value)"
            }
        }

        return "Document"
    }

    private func extractFirstMeaningfulLine(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 3 }

        let skipPatterns = ["page", "date", "ref", "n°", "nr", "tel", "fax", "email", "www"]

        for line in lines.prefix(5) {
            let lowercaseLine = line.lowercased()
            let shouldSkip = skipPatterns.contains { lowercaseLine.hasPrefix($0) }
            if !shouldSkip && line.count > 5 {
                if line.count > 50 {
                    return String(line.prefix(47)) + "..."
                }
                return line
            }
        }

        return "Document"
    }
}
