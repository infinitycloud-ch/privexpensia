import Foundation
import CoreData

// MARK: - Sprint 5: Enhance AI Service
// Utilise Qwen pour corriger les erreurs d'extraction signalées par l'utilisateur

class EnhanceAIService {
    static let shared = EnhanceAIService()

    private let qwenManager = QwenModelManager.shared

    private init() {}

    // MARK: - Correction de champs spécifiques

    struct CorrectionRequest {
        let expense: Expense
        let fieldsToCorrect: [CorrectionField]
        let rawOCRText: String
    }

    enum CorrectionField: String, CaseIterable {
        case merchant = "merchant"
        case amount = "amount"
        case tax = "tax"
        case category = "category"
        case date = "date"

        var displayName: String {
            switch self {
            case .merchant: return "Marchand"
            case .amount: return "Montant"
            case .tax: return "TVA"
            case .category: return "Catégorie"
            case .date: return "Date"
            }
        }
    }

    struct CorrectionResult {
        var merchant: String?
        var amount: Double?
        var tax: Double?
        var category: String?
        var date: Date?
        var confidence: Double
        var corrections: [String: String]  // Field -> "oldValue -> newValue"
    }

    // MARK: - Enhance with AI

    func enhanceExpense(request: CorrectionRequest, completion: @escaping (Result<CorrectionResult, Error>) -> Void) {
        guard !request.rawOCRText.isEmpty else {
            completion(.failure(EnhanceError.noOCRText))
            return
        }

        // Construire le prompt pour Qwen
        let prompt = buildEnhancePrompt(request: request)


        // D'abord essayer le fallback basé sur patterns (plus fiable pour les montants suisses)
        let fallbackResult = self.performFallbackCorrection(request: request)

        // Si le fallback a trouvé des corrections, l'utiliser directement
        if !fallbackResult.corrections.isEmpty {
            completion(.success(fallbackResult))
            return
        }

        // Sinon, essayer Qwen pour analyser
        qwenManager.runInference(prompt: prompt) { result in
            switch result {
            case .success(let response):
                let correctionResult = self.parseQwenResponse(response.extractedData, request: request)

                // Si Qwen n'a pas trouvé de corrections, utiliser le fallback
                if correctionResult.corrections.isEmpty {
                    completion(.success(fallbackResult))
                } else {
                    completion(.success(correctionResult))
                }

            case .failure(let error):
                completion(.success(fallbackResult))
            }
        }
    }

    // MARK: - Prompt Building

    private func buildEnhancePrompt(request: CorrectionRequest) -> String {
        let fieldsStr = request.fieldsToCorrect.map { $0.displayName }.joined(separator: ", ")

        var currentValues = "Valeurs actuelles (probablement incorrectes):\n"
        for field in request.fieldsToCorrect {
            switch field {
            case .merchant:
                currentValues += "- Marchand: \(request.expense.merchant ?? "inconnu")\n"
            case .amount:
                currentValues += "- Montant: \(request.expense.amount)\n"
            case .tax:
                currentValues += "- TVA: \(request.expense.taxAmount)\n"
            case .category:
                currentValues += "- Catégorie: \(request.expense.category ?? "Other")\n"
            case .date:
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy"
                currentValues += "- Date: \(formatter.string(from: request.expense.date ?? Date()))\n"
            }
        }

        // Pré-analyser le texte OCR pour identifier les montants clés
        let hints = analyzeOCRForHints(request.rawOCRText)

        return """
        Tu es un assistant pour corriger les erreurs d'extraction de tickets de caisse suisses.

        ATTENTION - FORMAT OCR SPÉCIAL:
        Le texte OCR est lu en colonnes. Les labels (TOTAL TTC) et les montants (220.90) sont sur des lignes DIFFÉRENTES.
        Tu dois associer le label "TOTAL TTC" avec le montant qui le SUIT (pas "Total HT").

        \(hints)

        Texte OCR du ticket:
        ---
        \(request.rawOCRText)
        ---

        \(currentValues)

        Champs à corriger: \(fieldsStr)

        RÈGLES CRITIQUES:
        1. TOTAL TTC = montant APRÈS taxes (le plus grand), c'est ce qu'on cherche
        2. Total HT = montant AVANT taxes (plus petit), NE PAS utiliser celui-ci
        3. Le montant TTC est généralement juste AVANT "Total HT" dans le texte
        4. Réponds UNIQUEMENT avec un JSON valide

        Format EXACT de réponse (nombres sans devise):
        {"merchant": "Nom", "amount": 123.45, "tax": 12.34, "category": "Restaurant", "date": "DD.MM.YYYY"}
        """
    }

    // Analyser le texte OCR pour donner des indices à Qwen
    private func analyzeOCRForHints(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var hints: [String] = []

        var totalHTIndex: Int? = nil

        // Trouver les indices importants
        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.contains("TOTAL TTC") {
                hints.append("⚠️ Ligne \(i+1) contient 'TOTAL TTC' (c'est le montant à trouver)")
            }
            if upper.contains("TOTAL HT") || (upper.contains("TOTAL") && upper.contains("HT")) {
                totalHTIndex = i
                hints.append("⚠️ Ligne \(i+1) contient 'Total HT' (NE PAS utiliser ce montant)")
            }
        }

        // Le montant TTC est juste avant Total HT
        if let htIndex = totalHTIndex, htIndex > 0 {
            for i in stride(from: htIndex - 1, through: 0, by: -1) {
                if let amount = extractAmountFromLine(lines[i]) {
                    hints.append("💡 INDICE: Le montant TTC probable est \(String(format: "%.2f", amount)) (ligne \(i+1), juste avant Total HT)")
                    break
                }
            }
        }

        if hints.isEmpty {
            return ""
        }

        return "INDICES DÉTECTÉS:\n" + hints.joined(separator: "\n")
    }

    // MARK: - Response Parsing

    private func parseQwenResponse(_ response: String, request: CorrectionRequest) -> CorrectionResult {
        var result = CorrectionResult(confidence: 0.7, corrections: [:])

        // Extraire le JSON de la réponse (peut être entouré de markdown ```json ... ```)
        let jsonString = extractJSON(from: response)

        // Essayer de parser le JSON
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            for field in request.fieldsToCorrect {
                switch field {
                case .merchant:
                    if let merchant = json["merchant"] as? String, !merchant.isEmpty {
                        let oldValue = request.expense.merchant ?? "inconnu"
                        if merchant != oldValue {
                            result.merchant = merchant
                            result.corrections["merchant"] = "\(oldValue) → \(merchant)"
                        }
                    }

                case .amount:
                    // Essayer plusieurs clés et formats
                    var amount = extractAmount(from: json, keys: ["amount", "total_amount", "total", "montant"])

                    // VALIDATION: Vérifier que Qwen n'a pas pris le Total HT au lieu du TTC
                    if let qwenAmount = amount {
                        let validatedAmount = validateAndCorrectAmount(qwenAmount, ocrText: request.rawOCRText)
                        if validatedAmount != qwenAmount {
                            amount = validatedAmount
                        }
                    }

                    if let amount = amount, amount > 0 {
                        let oldValue = request.expense.amount
                        if abs(amount - oldValue) > 0.01 {
                            result.amount = amount
                            result.corrections["amount"] = "\(String(format: "%.2f", oldValue)) → \(String(format: "%.2f", amount))"
                        }
                    }

                case .tax:
                    // Essayer plusieurs clés et formats
                    let tax = extractAmount(from: json, keys: ["tax", "tax_amount", "tva", "taxe"])
                    if let tax = tax {
                        let oldValue = request.expense.taxAmount
                        if abs(tax - oldValue) > 0.01 {
                            result.tax = tax
                            result.corrections["tax"] = "\(String(format: "%.2f", oldValue)) → \(String(format: "%.2f", tax))"
                        }
                    }

                case .category:
                    if let category = json["category"] as? String, !category.isEmpty {
                        let oldValue = request.expense.category ?? "Other"
                        // Normaliser la catégorie
                        let normalizedCategory = normalizeCategory(category)
                        if normalizedCategory != oldValue {
                            result.category = normalizedCategory
                            result.corrections["category"] = "\(oldValue) → \(normalizedCategory)"
                        }
                    }

                case .date:
                    if let dateStr = json["date"] as? String {
                        if let date = parseDate(dateStr) {
                            let oldDate = request.expense.date ?? Date()
                            if abs(date.timeIntervalSince(oldDate)) > 86400 {  // More than 1 day difference
                                result.date = date
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd.MM.yyyy"
                                result.corrections["date"] = "\(formatter.string(from: oldDate)) → \(formatter.string(from: date))"
                            }
                        }
                    }
                }
            }

            // Augmenter la confiance si des corrections ont été trouvées
            if !result.corrections.isEmpty {
                result.confidence = 0.85
            }
        }

        return result
    }

    // Extraire le JSON d'une réponse qui peut contenir du markdown
    private func extractJSON(from response: String) -> String {
        guard !response.isEmpty else { return "{}" }

        // Enlever les balises markdown si présentes
        var cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Chercher le premier { et le dernier }
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            if startIndex <= endIndex {
                return String(cleaned[startIndex...endIndex])
            }
        }

        return cleaned
    }

    // Extraire un montant depuis plusieurs clés possibles et formats
    private func extractAmount(from json: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = json[key] {
                // Si c'est déjà un nombre
                if let doubleValue = value as? Double {
                    return doubleValue
                }
                if let intValue = value as? Int {
                    return Double(intValue)
                }
                // Si c'est une string, extraire le nombre
                if let stringValue = value as? String {
                    // Enlever la devise et les espaces
                    let cleaned = stringValue
                        .replacingOccurrences(of: "CHF", with: "")
                        .replacingOccurrences(of: "EUR", with: "")
                        .replacingOccurrences(of: "€", with: "")
                        .replacingOccurrences(of: ",", with: ".")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let amount = Double(cleaned) {
                        return amount
                    }
                }
            }
        }
        return nil
    }

    // Valider et corriger le montant de Qwen si c'est le Total HT au lieu du TTC
    private func validateAndCorrectAmount(_ qwenAmount: Double, ocrText: String) -> Double {
        let lines = ocrText.components(separatedBy: .newlines)

        // Chercher si le montant de Qwen correspond au Total HT
        var totalHTIndex: Int? = nil
        var totalHTAmount: Double? = nil

        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            // Trouver la ligne Total HT
            if upper.contains("TOTAL HT") || (upper.contains("TOTAL") && upper.contains("HT") && !upper.contains("TTC")) {
                totalHTIndex = i
                // Extraire le montant sur cette ligne ou juste après
                if let amount = extractAmountFromLine(line) {
                    totalHTAmount = amount
                }
            }
        }

        // Si Qwen a extrait le montant HT, trouver le TTC
        if let htAmount = totalHTAmount, abs(qwenAmount - htAmount) < 0.05 {

            // Le TTC est juste avant la ligne Total HT
            if let htIndex = totalHTIndex, htIndex > 0 {
                for i in stride(from: htIndex - 1, through: 0, by: -1) {
                    if let amount = extractAmountFromLine(lines[i]) {
                        // TTC devrait être plus grand que HT
                        if amount > htAmount {
                            return amount
                        }
                    }
                }
            }

            // Fallback: chercher le plus grand montant après TOTAL TTC
            var ttcIndex: Int? = nil
            for (i, line) in lines.enumerated() {
                if line.uppercased().contains("TOTAL TTC") {
                    ttcIndex = i
                    break
                }
            }

            if let startIndex = ttcIndex {
                var maxAmount: Double = 0
                for i in (startIndex + 1)..<min(lines.count, startIndex + 10) {
                    if lines[i].uppercased().contains("TOTAL HT") { break }
                    if let amount = extractAmountFromLine(lines[i]), amount > maxAmount {
                        maxAmount = amount
                    }
                }
                if maxAmount > htAmount {
                    return maxAmount
                }
            }
        }

        // Pas de correction nécessaire
        return qwenAmount
    }

    // Normaliser les noms de catégories
    private func normalizeCategory(_ category: String) -> String {
        let lowercased = category.lowercased()
        let categoryMap: [String: String] = [
            "restaurant": "Restaurant",
            "sante": "Health",
            "santé": "Health",
            "health": "Health",
            "groceries": "Groceries",
            "alimentation": "Groceries",
            "transport": "Transport",
            "shopping": "Shopping",
            "coffee": "Coffee",
            "café": "Coffee",
            "gas": "Gas",
            "essence": "Gas",
            "entertainment": "Entertainment",
            "other": "Other"
        ]
        return categoryMap[lowercased] ?? category
    }

    // Parser une date dans différents formats
    private func parseDate(_ dateStr: String) -> Date? {
        let formats = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }

    // Extraire un montant d'une ligne de texte
    private func extractAmountFromLine(_ line: String) -> Double? {
        guard !line.isEmpty else { return nil }

        // Pattern simple: chercher des nombres comme 220.90 ou 220,90
        let pattern = #"(\d{1,6})[.,](\d{2})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        let matches = regex.matches(in: line, range: range)

        // Prendre le dernier match (le total est souvent à droite)
        guard let lastMatch = matches.last, lastMatch.numberOfRanges >= 3 else {
            return nil
        }

        let intRange = lastMatch.range(at: 1)
        let decRange = lastMatch.range(at: 2)

        guard intRange.location != NSNotFound, decRange.location != NSNotFound else {
            return nil
        }

        let intPart = nsLine.substring(with: intRange)
        let decPart = nsLine.substring(with: decRange)

        return Double("\(intPart).\(decPart)")
    }

    // MARK: - Fallback Correction

    private func performFallbackCorrection(request: CorrectionRequest) -> CorrectionResult {
        var result = CorrectionResult(confidence: 0.6, corrections: [:])
        let text = request.rawOCRText

        for field in request.fieldsToCorrect {
            switch field {
            case .merchant:
                // Prendre la première ligne non-vide
                let lines = text.components(separatedBy: .newlines)
                if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.count >= 3 && cleaned != request.expense.merchant {
                        result.merchant = cleaned
                        result.corrections["merchant"] = "\(request.expense.merchant ?? "?") → \(cleaned)"
                    }
                }

            case .amount:
                // Chercher le TOTAL TTC spécifiquement
                var foundAmount: Double? = nil
                let lines = text.components(separatedBy: .newlines)

                // Stratégie: trouver l'index de "TOTAL TTC" puis chercher le montant juste avant "Total HT"
                var totalTTCIndex: Int? = nil
                var totalHTIndex: Int? = nil

                for (i, line) in lines.enumerated() {
                    let upperLine = line.uppercased()
                    if upperLine.contains("TOTAL TTC") {
                        totalTTCIndex = i
                    }
                    if upperLine.contains("TOTAL HT") || (upperLine.contains("TOTAL") && upperLine.contains("HT")) {
                        totalHTIndex = i
                    }
                }

                // Si on a trouvé "Total HT", le montant TTC est juste avant
                if let htIndex = totalHTIndex, htIndex > 0 {
                    // Chercher le dernier montant avant "Total HT" qui n'est pas sur la même ligne
                    for i in stride(from: htIndex - 1, through: 0, by: -1) {
                        if let amount = extractAmountFromLine(lines[i]) {
                            // Vérifier que ce n'est pas un petit montant d'article
                            // Le total TTC devrait être le plus grand
                            if amount > 50 || foundAmount == nil {
                                foundAmount = amount
                                break
                            }
                        }
                    }
                }

                // Fallback: chercher le plus grand montant après "TOTAL TTC"
                if foundAmount == nil, let ttcIndex = totalTTCIndex {
                    var maxAmount: Double = 0
                    for i in (ttcIndex + 1)..<lines.count {
                        let line = lines[i]
                        // S'arrêter si on atteint "Total HT"
                        if line.uppercased().contains("TOTAL HT") { break }
                        if let amount = extractAmountFromLine(line), amount > maxAmount {
                            maxAmount = amount
                            foundAmount = amount
                        }
                    }
                }

                // Fallback 2: chercher "Gesamt" (allemand)
                if foundAmount == nil {
                    for line in lines {
                        if line.lowercased().contains("gesamt") && !line.lowercased().contains("zwischen") {
                            if let amount = extractAmountFromLine(line) {
                                foundAmount = amount
                                break
                            }
                        }
                    }
                }

                // Appliquer la correction si trouvée
                if let amount = foundAmount, abs(amount - request.expense.amount) > 0.01 {
                    result.amount = amount
                    result.corrections["amount"] = "\(String(format: "%.2f", request.expense.amount)) → \(String(format: "%.2f", amount))"
                }

            case .tax:
                // Chercher TVA/VAT pattern
                let taxPatterns = [
                    #"(?:TVA|VAT|MwSt)[:\s]+(?:CHF\s*)?(\d+[.,]\d{2})"#,
                    #"(?:TVA|VAT)\s+\d+[.,]\d+%[:\s]+(\d+[.,]\d{2})"#
                ]

                for pattern in taxPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
                       let range = Range(match.range(at: 1), in: text) {
                        let taxStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                        if let tax = Double(taxStr), abs(tax - request.expense.taxAmount) > 0.01 {
                            result.tax = tax
                            result.corrections["tax"] = "\(request.expense.taxAmount) → \(tax)"
                            break
                        }
                    }
                }

            case .category:
                // Utiliser la logique de catégorisation existante
                let category = inferCategory(from: text)
                if category != request.expense.category {
                    result.category = category
                    result.corrections["category"] = "\(request.expense.category ?? "?") → \(category)"
                }

            case .date:
                // Chercher une date dans le texte
                let datePattern = #"(\d{1,2})[./](\d{1,2})[./](\d{2,4})"#
                if let regex = try? NSRegularExpression(pattern: datePattern),
                   let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {

                    if let dayRange = Range(match.range(at: 1), in: text),
                       let monthRange = Range(match.range(at: 2), in: text),
                       let yearRange = Range(match.range(at: 3), in: text) {

                        let day = Int(text[dayRange]) ?? 1
                        let month = Int(text[monthRange]) ?? 1
                        var year = Int(text[yearRange]) ?? 2024
                        if year < 100 { year += 2000 }

                        var components = DateComponents()
                        components.day = day
                        components.month = month
                        components.year = year

                        if let date = Calendar.current.date(from: components) {
                            let oldDate = request.expense.date ?? Date()
                            if abs(date.timeIntervalSince(oldDate)) > 86400 {
                                result.date = date
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd.MM.yyyy"
                                result.corrections["date"] = "\(formatter.string(from: oldDate)) → \(formatter.string(from: date))"
                            }
                        }
                    }
                }
            }
        }

        return result
    }

    private func inferCategory(from text: String) -> String {
        let lowercased = text.lowercased()

        let categories: [(String, [String])] = [
            ("Restaurant", ["restaurant", "bistro", "brasserie", "pizzeria", "mcdonald", "burger",
                           "fondue", "raclette", "caquellon", "couverts", "plat", "menu",
                           "hamburger", "pizza", "café-restaurant", "auberge", "grill"]),
            ("Coffee", ["starbucks", "coffee", "café", "espresso", "tea", "thé"]),
            ("Groceries", ["migros", "coop", "denner", "aldi", "lidl", "supermarket", "manor food", "spar"]),
            ("Gas", ["shell", "bp", "avia", "essence", "benzin", "tamoil", "agrola"]),
            ("Transport", ["uber", "taxi", "sbb", "cff", "parking", "tpg", "tl", "billet"]),
            ("Health", ["pharmacy", "pharmacie", "apotheke", "doctor", "médecin", "amavita", "sunstore"]),
            ("Shopping", ["store", "shop", "zara", "h&m", "ikea", "manor", "globus"]),
            ("Entertainment", ["cinema", "movie", "theater", "concert", "pathé", "kino"])
        ]

        for (category, keywords) in categories {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return category
            }
        }

        return "Other"
    }

    // MARK: - Apply Corrections

    func applyCorrections(_ result: CorrectionResult, to expense: Expense) {
        let context = CoreDataManager.shared.persistentContainer.viewContext

        // Sauvegarder les valeurs originales avant correction
        var originalValues: [String: String] = [:]

        if let merchant = result.merchant {
            originalValues["merchant"] = expense.merchant ?? ""
            expense.merchant = merchant
        }

        if let amount = result.amount {
            originalValues["amount"] = String(expense.amount)
            expense.amount = amount
        }

        if let tax = result.tax {
            originalValues["tax"] = String(expense.taxAmount)
            expense.taxAmount = tax
        }

        if let category = result.category {
            originalValues["category"] = expense.category ?? ""
            expense.category = category
        }

        if let date = result.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            originalValues["date"] = formatter.string(from: expense.date ?? Date())
            expense.date = date
        }

        // Marquer comme corrigé par l'utilisateur
        expense.userCorrected = true
        expense.originalParsedValues = originalValues

        // Sauvegarder
        CoreDataManager.shared.saveContext()

    }

    // MARK: - Errors

    enum EnhanceError: Error, LocalizedError {
        case noOCRText
        case correctionFailed

        var errorDescription: String? {
            switch self {
            case .noOCRText:
                return "Pas de texte OCR disponible pour cette dépense"
            case .correctionFailed:
                return "La correction a échoué"
            }
        }
    }
}
