import Foundation
import UIKit

// MARK: - Expense Parser
class ExpenseParser {
    static let shared = ExpenseParser()
    
    private let tvaCalculator = TVACalculator.shared
    
    private init() {}
    
    // MARK: - Parse from OCR Result
    func parseFromOCRResult(_ ocrData: ExtractedData) -> ParsedExpense {
        let text = ocrData.text
        return parseExpense(from: text)
    }
    
    // MARK: - Main Parser
    func parseExpense(from text: String) -> ParsedExpense {
        var parsed = ParsedExpense()

        // Detect country first for VAT calculation
        parsed.country = tvaCalculator.detectCountryFromText(text)

        // Extract merchant
        parsed.merchant = extractMerchant(from: text)

        // Extract date
        parsed.date = extractDate(from: text)

        // Detect category - with merchant override for known stores
        parsed.category = detectCategoryWithMerchantOverride(merchant: parsed.merchant, text: text)
        
        // Extract amounts and currency
        let (amounts, currency) = extractAmounts(from: text)
        parsed.currency = currency
        
        // Find total amount (usually the largest amount)
        if let total = amounts.max() {
            parsed.totalAmount = total
            
            // Calculate VAT
            let vatCalc = tvaCalculator.calculateVAT(
                amount: total,
                country: parsed.country,
                category: parsed.category,
                isInclusive: true
            )
            
            parsed.vatAmount = vatCalc.vatAmount
            parsed.netAmount = vatCalc.netAmount
            parsed.vatRate = vatCalc.vatRate
        }
        
        // Extract items
        parsed.items = extractItems(from: text, amounts: amounts)
        
        // Detect payment method
        parsed.paymentMethod = detectPaymentMethod(from: text)
        
        return parsed
    }
    
    // MARK: - Merchant Extraction (delegated to TextExtractionUtils)
    private func extractMerchant(from text: String) -> String {
        return TextExtractionUtils.shared.extractMerchant(from: text)
    }
    
    // MARK: - Date Extraction (Swiss/European Priority)
    private func extractDate(from text: String) -> Date {
        // Detect if context is European/Swiss (default for this app)
        let isEuropeanContext = detectEuropeanContext(from: text)

        // Pattern 1: DD.MM.YYYY or DD/MM/YYYY with capture groups
        let europeanPattern = #"(\d{1,2})[./](\d{1,2})[./](\d{2,4})"#
        if let regex = try? NSRegularExpression(pattern: europeanPattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            if let g1Range = Range(match.range(at: 1), in: text),
               let g2Range = Range(match.range(at: 2), in: text),
               let g3Range = Range(match.range(at: 3), in: text) {

                let part1 = Int(text[g1Range]) ?? 0
                let part2 = Int(text[g2Range]) ?? 0
                var year = Int(text[g3Range]) ?? 0

                // Normalize 2-digit year
                if year < 100 {
                    year += (year > 50) ? 1900 : 2000
                }

                // Smart DD/MM vs MM/DD detection
                let (day, month) = resolveEuropeanDate(part1: part1, part2: part2, isEuropean: isEuropeanContext)

                if let date = createDate(day: day, month: month, year: year) {
                    return date
                }
            }
        }

        // Pattern 2: YYYY-MM-DD (ISO format - unambiguous)
        let isoPattern = #"(\d{4})-(\d{1,2})-(\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: isoPattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            if let yearRange = Range(match.range(at: 1), in: text),
               let monthRange = Range(match.range(at: 2), in: text),
               let dayRange = Range(match.range(at: 3), in: text) {

                let year = Int(text[yearRange]) ?? 0
                let month = Int(text[monthRange]) ?? 0
                let day = Int(text[dayRange]) ?? 0

                if let date = createDate(day: day, month: month, year: year) {
                    return date
                }
            }
        }

        // Pattern 3: DD Month YYYY (multilingual - unique keys only)
        let monthNames: [String: Int] = [
            // English (unique)
            "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
            "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
            // French (unique additions)
            "Janv": 1, "Févr": 2, "Mars": 3, "Avr": 4, "Mai": 5, "Juin": 6,
            "Juil": 7, "Août": 8, "Sept": 9, "Déc": 12,
            // German (unique additions)
            "Mär": 3, "Okt": 10, "Dez": 12
        ]

        let monthPattern = #"(\d{1,2})[\s.]+([A-Za-zéûô]+)[\s.,]+(\d{2,4})"#
        if let regex = try? NSRegularExpression(pattern: monthPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            if let dayRange = Range(match.range(at: 1), in: text),
               let monthRange = Range(match.range(at: 2), in: text),
               let yearRange = Range(match.range(at: 3), in: text) {

                let day = Int(text[dayRange]) ?? 0
                let monthStr = String(text[monthRange]).prefix(4).lowercased().capitalized
                var year = Int(text[yearRange]) ?? 0

                if year < 100 { year += 2000 }

                if let month = monthNames.first(where: { monthStr.hasPrefix($0.key) })?.value,
                   let date = createDate(day: day, month: month, year: year) {
                    return date
                }
            }
        }

        return Date()
    }

    // MARK: - European Context Detection
    private func detectEuropeanContext(from text: String) -> Bool {
        let europeanIndicators = [
            "CHF", "Fr.", "EUR", "€", "Suisse", "Schweiz", "Svizzera",
            "France", "Deutschland", "Italia", "Genève", "Zürich", "Bern",
            "TVA", "MwSt", "IVA", "MWST"
        ]
        let usIndicators = ["USD", "$", "USA", "US"]

        let lowercased = text.lowercased()
        let europeanScore = europeanIndicators.filter { lowercased.contains($0.lowercased()) }.count
        let usScore = usIndicators.filter { lowercased.contains($0.lowercased()) }.count

        // Default to European for Swiss app
        return europeanScore >= usScore
    }

    // MARK: - Resolve DD/MM vs MM/DD
    private func resolveEuropeanDate(part1: Int, part2: Int, isEuropean: Bool) -> (day: Int, month: Int) {
        // Unambiguous cases: one value > 12 must be day
        if part1 > 12 && part2 <= 12 {
            return (day: part1, month: part2)  // DD/MM
        }
        if part2 > 12 && part1 <= 12 {
            return (day: part2, month: part1)  // MM/DD
        }

        // Both <= 12: use context (European = DD/MM first)
        if isEuropean {
            return (day: part1, month: part2)  // DD/MM (European)
        } else {
            return (day: part2, month: part1)  // MM/DD (US)
        }
    }

    // MARK: - Create Date Safely
    private func createDate(day: Int, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = 12  // Noon to avoid timezone issues

        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)
    }
    
    // MARK: - Enhanced Amount Extraction with Swiss Fallback
    private func extractAmounts(from text: String) -> ([Double], String) {
        var amounts: [Double] = []

        // 🚀 OPTIMISATION: Vérifier la devise configurée par l'utilisateur
        let userCurrency = CurrencyManager.shared.currentCurrency

        // 🚀 CHECK IMMÉDIAT: Si CHF dans le texte OU devise utilisateur = CHF → Parser suisse uniquement
        let hasCHF = text.contains("CHF") || text.contains("Fr.")
        let isSwissUser = (userCurrency == "CHF")

        if hasCHF || isSwissUser {
            // 🇨🇭 MODE SUISSE: Parser CHF uniquement, pas besoin de chercher EUR

            if let swissAmount = extractSwissDeterministicAmount(from: text) {
                amounts.append(swissAmount)
                return (amounts, "CHF")
            }

            // Fallback: chercher n'importe quel montant avec pattern standard
            // Continue to standard extraction below but keep CHF as currency
            return extractStandardAmounts(from: text, defaultCurrency: "CHF")
        }

        // 🇪🇺 MODE EUROPÉEN: Seulement si pas de CHF et utilisateur pas en Suisse
        if let euroAmount = extractEuropeanDeterministicAmount(from: text) {
            amounts.append(euroAmount)
            return (amounts, "EUR")
        }

        // Fallback standard
        return extractStandardAmounts(from: text, defaultCurrency: userCurrency)
    }

    // MARK: - Standard Amount Extraction (fallback)
    private func extractStandardAmounts(from text: String, defaultCurrency: String) -> ([Double], String) {
        var amounts: [Double] = []
        let currency = defaultCurrency  // Respecter la devise par défaut, pas de détection auto


        // Standard amount patterns (enhanced)
        let amountPatterns = [
            #"(\d{1,4})[.,](\d{2})"#,           // 123.45 or 123,45
            #"(\d{1,4})\s*[.,]\s*(\d{2})"#,     // 123 . 45 (with spaces)
            #"[€$£¥]\s*(\d{1,4})[.,](\d{2})"#,  // €123.45
            #"(\d{1,4})[.,](\d{2})\s*[€$£¥]"#,  // 123.45€
            #"CHF\s*(\d{1,4})[.,](\d{2})"#,     // CHF 123.45
            #"Fr[.]?\s*(\d{1,4})[.,](\d{2})"#   // Fr. 123.45
        ]
        
        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    let amountString = String(text[Range(match.range, in: text)!])
                    
                    // Extract numeric value
                    let cleanedString = amountString
                        .replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                        .replacingOccurrences(of: ",", with: ".")
                    
                    if let amount = Double(cleanedString), amount > 0 {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        amounts = Array(Set(amounts)).sorted()
        
        return (amounts, currency)
    }
    
    // MARK: - Item Extraction
    private func extractItems(from text: String, amounts: [Double]) -> [String] {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Look for lines with amounts (likely to be items)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and headers
            if trimmed.isEmpty || trimmed.count < 3 {
                continue
            }
            
            // Check if line contains an amount
            for amount in amounts {
                let amountStr = String(format: "%.2f", amount)
                if line.contains(amountStr) || line.contains(amountStr.replacingOccurrences(of: ".", with: ",")) {
                    // Extract item name (text before the amount)
                    if let range = line.range(of: amountStr) {
                        let itemName = String(line[..<range.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: #"^\d+\s*"#, with: "", options: .regularExpression) // Remove leading quantity
                        
                        if !itemName.isEmpty && itemName.count > 2 {
                            items.append(itemName)
                        }
                    }
                    break
                }
            }
        }
        
        // If no items found, try to extract product-like words
        if items.isEmpty {
            let productKeywords = ["pizza", "café", "sandwich", "burger", "salade", "pasta",
                                  "billet", "ticket", "chambre", "room", "service", "tartare", "saumon"]
            
            for line in lines {
                let lowercased = line.lowercased()
                for keyword in productKeywords {
                    if lowercased.contains(keyword) {
                        items.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
                        break
                    }
                }
                if items.count >= 3 { break } // Limit to 3 items
            }
        }
        
        return items
    }
    
    // MARK: - Payment Method Detection (delegated to TextExtractionUtils)
    private func detectPaymentMethod(from text: String) -> String {
        return TextExtractionUtils.shared.detectPaymentMethod(from: text)
    }

    // MARK: - Category Detection with Merchant Override
    /// Known merchants have priority over text-based detection
    private func detectCategoryWithMerchantOverride(merchant: String, text: String) -> String {
        let merchantLower = merchant.lowercased()

        // 🏪 RÈGLE PRIORITAIRE: Marchands connus → Catégorie forcée
        let merchantToCategory: [(keywords: [String], category: String)] = [
            // Supermarchés → Groceries (JAMAIS Sante même si produits santé)
            (["migros", "coop", "denner", "aldi", "lidl", "spar", "volg"], "Groceries"),
            // Cafés
            (["starbucks"], "Coffee"),
            // Restaurants
            (["mcdonald", "burger king", "subway", "kfc", "five guys"], "Restaurant"),
            // Stations essence
            (["shell", "bp", "avia", "migrol", "agrola", "esso"], "Gas"),
            // Transport
            (["sbb", "cff", "uber", "taxi", "parking"], "Transport"),
        ]

        for (keywords, category) in merchantToCategory {
            if keywords.contains(where: { merchantLower.contains($0) }) {
                return category
            }
        }

        // Fallback: détection par texte
        return tvaCalculator.detectCategoryFromText(text)
    }

    // MARK: - 🇨🇭 Swiss Deterministic Fallback (Sprint 3)
    // NEVER returns 0.00 if Swiss patterns are found
    // Max amount filter: 50000 CHF (for Digitec, electronics stores)
    private let maxAmountFilter: Double = 50000

    private func extractSwissDeterministicAmount(from text: String) -> Double? {

        // ============================================================
        // 🎯 APPROCHE PRIORITAIRE:
        // 1. D'ABORD: Chercher "Total CHF XX.XX" sur même ligne
        // 2. ENSUITE: Chercher "TOTAL CHF" suivi de montant (même avec newline)
        // 3. ENSUITE: Chercher juste "TOTAL" suivi d'un montant
        // 4. FALLBACK: MAX des CHF (excluant Espèces, Rendu, sur XX)
        // ============================================================

        // 🎯 PRIORITÉ 1: Patterns "Total CHF" sur même ligne
        let totalPatterns = [
            #"(?i)Total\s+CHF\s+(\d+['\s]?\d*[.,]\d{2})"#,           // Total CHF 53.05
            #"(?i)Total\s*CHF\s*(\d+['\s]?\d*[.,]\d{2})"#,           // TotalCHF53.05
            #"(?i)Total-EFT\s*CHF[:\s]*(\d+['\s]?\d*[.,]\d{2})"#,    // Total-EFT CHF: 53.05
            #"(?i)Montant\s+dû\s*CHF\s*(\d+['\s]?\d*[.,]\d{2})"#,    // Montant dû CHF
            #"(?i)À\s*payer\s*CHF\s*(\d+['\s]?\d*[.,]\d{2})"#,       // À payer CHF
        ]

        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range])
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr), amount > 0 && amount < maxAmountFilter {
                    return amount
                }
            }
        }


        // 🎯 PRIORITÉ 2: "TOTAL CHF" suivi de montant avec espaces/newlines
        // Pour: "TOTAL CHF           163.35" ou "TOTAL CHF\n163.35"
        let multilinePatterns = [
            #"(?i)TOTAL\s+CHF[\s\n]+(\d+['\s]?\d*[.,]\d{2})"#,       // TOTAL CHF [newline/spaces] 163.35
            #"(?i)TOTAL[\s\n]+CHF[\s\n]+(\d+['\s]?\d*[.,]\d{2})"#,   // TOTAL [newline] CHF [newline] 163.35
            #"(?i)TOTAL[\s\n]+(\d+['\s]?\d*[.,]\d{2})"#,             // TOTAL [newline] 163.35 (sans CHF)
        ]

        for pattern in multilinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range])
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr), amount > 0 && amount < maxAmountFilter {
                    return amount
                }
            }
        }


        // 🎯 FALLBACK: Chercher tous les "CHF XX.XX" et prendre le MAX
        // EXCLURE: Espèces (cash donné), Rendu (monnaie), "sur XX" (base HT), Arrondi
        var allCHFAmounts: [Double] = []
        let lowercasedText = text.lowercased()

        // Pattern pour "CHF XX.XX" suivi d'un espace ou fin de ligne
        let chfPattern = #"CHF\s*(\d+[.,]\d{2})(?:\s|$|[^\d])"#

        if let regex = try? NSRegularExpression(pattern: chfPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                if let range = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")

                    // Vérifier le contexte (30 chars avant) pour exclure certains montants
                    let startIndex = text.index(fullRange.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                    let context = String(text[startIndex..<fullRange.lowerBound]).lowercased()

                    // Exclure si contexte contient des mots à ignorer
                    let excludeWords = ["espèces", "especes", "rendu", "arrondi", "sur ", "change"]
                    let shouldExclude = excludeWords.contains { context.contains($0) }

                    if let amount = Double(amountStr), amount > 0 && amount < maxAmountFilter && !shouldExclude {
                        allCHFAmounts.append(amount)
                    } else if shouldExclude {
                    }
                }
            }
        }

        if let maxAmount = allCHFAmounts.max() {
            return maxAmount
        }

        return nil
    }

    // Legacy patterns kept as backup (not used in simplified version)
    private func extractSwissDeterministicAmountLegacy(from text: String) -> Double? {

        // 🚀 FUSÉE ÉTAGE 1: Patterns Swiss prioritaires (selon reçus test)
        // Supports amounts with thousands separator (3'770.00) up to 50000 CHF
        let swissPatterns = [
            // PRIORITÉ 1: "Total CHF" avec espaces flexibles (très commun)
            #"(?i)Total\s+CHF\s+([0-9]+[.,][0-9]{2})"#,
            #"(?i)Total\s*CHF\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 1b: Large amounts with thousands separator (Digitec: 3'770.00)
            #"(?i)Total\s*CHF\s*([0-9]{1,2}['\s]?[0-9]{3}[.,][0-9]{2})"#,
            #"(?i)(?:Rechnungsbetrag|Invoice Total)\s*:?\s*CHF\s*([0-9]{1,2}['\s]?[0-9]{3}[.,][0-9]{2})"#,

            // PRIORITÉ 2: Patterns les plus fiables (Total + Devise) - OPERA ITALIANA
            #"(?i)(?:Montant dû|Total à payer|Total-EFT)\s*CHF\s+([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 3: Cas où "Total" est un mot isolé - MIGROS/COOP
            #"(?i)(?:Total|TOTAL)\s*CHF\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 4: Pattern inversé CHF en premier
            #"(?i)CHF\s*([0-9]+[.,][0-9]{2})\s*(?:Total|TOTAL|Montant|MONTANT)"#,

            // PRIORITÉ 5: Patterns multilingues Swiss
            #"(?i)(?:Zu zahlen|À payer|Da pagare)\s*:?\s*CHF\s*([0-9]+[.,][0-9]{2})"#,
            #"(?i)(?:Betrag|Montant|Importo)\s*:?\s*CHF\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 6: "Payé" + CHF (confirmation de paiement)
            #"(?i)Pay[ée]\s+(?:\w+\s+)?CHF\s+([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 7: Patterns legacy et fallback
            #"(?i)(?:TOTAL EFT|Total-EFT)\s*:?\s*CHF\s*([0-9]+[.,][0-9]{2})"#,
            #"(?i)(?:Cumulus|Supercard)\s*.*CHF\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 8: Simple CHF amount at end of line
            #"CHF\s+([0-9]+[.,][0-9]{2})\s*$"#
        ]

        for (index, pattern) in swissPatterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let amountString = String(text[range])
                            .replacingOccurrences(of: "'", with: "")  // Remove thousands separator
                            .replacingOccurrences(of: " ", with: "")  // Remove spaces
                            .replacingOccurrences(of: ",", with: ".")

                        if let amount = Double(amountString), amount > 0 && amount < maxAmountFilter {
                            return amount
                        }
                    }
                }
            } catch {
            }
        }

        // Advanced Swiss receipt heuristics
        if let heuristicAmount = extractSwissHeuristicAmount(from: text) {
            return heuristicAmount
        }

        return nil
    }

    // MARK: - Swiss Heuristic Amount Extraction
    private func extractSwissHeuristicAmount(from text: String) -> Double? {

        let lines = text.components(separatedBy: .newlines)
        var candidates: [(amount: Double, confidence: Int)] = []

        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Look for CHF amounts in each line
            let chfPattern = #"CHF\s*([0-9]+[.,][0-9]{2})"#
            if let regex = try? NSRegularExpression(pattern: chfPattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let range = Range(match.range(at: 1), in: trimmedLine) {

                let amountString = String(trimmedLine[range]).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountString), amount > 0 && amount < maxAmountFilter {

                    var confidence = 1
                    let lowerLine = trimmedLine.lowercased()

                    // Increase confidence for total indicators
                    if lowerLine.contains("total") || lowerLine.contains("montant") {
                        confidence += 3
                    }

                    // Increase confidence for payment indicators
                    if lowerLine.contains("dû") || lowerLine.contains("payer") || lowerLine.contains("zahlen") {
                        confidence += 2
                    }

                    // Increase confidence if near end of receipt
                    if lineIndex > lines.count - 10 {
                        confidence += 1
                    }

                    // Decrease confidence for change/returned money
                    if lowerLine.contains("change") || lowerLine.contains("rendu") || lowerLine.contains("rückgeld") {
                        confidence -= 2
                    }

                    candidates.append((amount: amount, confidence: confidence))
                }
            }
        }

        // Return highest confidence amount
        if let bestCandidate = candidates.max(by: { $0.confidence < $1.confidence }) {
            return bestCandidate.amount
        }

        return nil
    }

    // MARK: - 🇪🇺 European Deterministic Amount Extraction (France, etc.)
    // Note: Cette fonction n'est appelée que si pas de CHF détecté (check fait en amont)
    private func extractEuropeanDeterministicAmount(from text: String) -> Double? {

        // French/European total patterns - improved whitespace handling
        let europeanPatterns = [
            // PRIORITÉ 1: SOUSTOTAL patterns (French receipts) - flexible whitespace
            #"(?i)SOUSTOTAL\s+([0-9]+[.,][0-9]{2})"#,
            #"(?i)SOUS[- ]?TOTAL\s+([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 2: TOTAL patterns (most common) - very flexible whitespace
            #"(?i)TOTAL\s+([0-9]+[.,][0-9]{2})"#,
            #"(?i)(?:TOTAL|SOUSTOTAL|SOUS-TOTAL|SOUS TOTAL)\s*:?\s*€?\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 3: NET patterns
            #"(?i)(?:NET\s*[AÀ]\s*PAYER|[AÀ]\s*PAYER|MONTANT\s*D[ÛU])\s*:?\s*€?\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 4: Euro symbol patterns
            #"(?i)TOTAL\s*:?\s*€\s*([0-9]+[.,][0-9]{2})"#,
            #"€\s*([0-9]+[.,][0-9]{2})\s*(?:TOTAL|TTC)"#,

            // PRIORITÉ 5: TTC patterns (Toutes Taxes Comprises)
            #"(?i)(?:TTC|TOTAL\s*TTC)\s*:?\s*€?\s*([0-9]+[.,][0-9]{2})"#,

            // PRIORITÉ 6: Amount followed by € at end of line
            #"([0-9]+[.,][0-9]{2})\s*€\s*$"#
        ]

        for (index, pattern) in europeanPatterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let amountString = String(text[range])
                            .replacingOccurrences(of: ",", with: ".")

                        if let amount = Double(amountString), amount > 0 && amount < maxAmountFilter {
                            return amount
                        }
                    }
                }
            } catch {
            }
        }

        // Heuristic fallback for European receipts
        if let heuristicAmount = extractEuropeanHeuristicAmount(from: text) {
            return heuristicAmount
        }

        return nil
    }

    // MARK: - European Heuristic Amount Extraction
    private func extractEuropeanHeuristicAmount(from text: String) -> Double? {

        let lines = text.components(separatedBy: .newlines)
        var candidates: [(amount: Double, confidence: Int, line: String)] = []

        // Generic amount pattern (works without € symbol)
        let amountPattern = #"([0-9]+[.,][0-9]{2})"#

        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerLine = trimmedLine.lowercased()

            guard let regex = try? NSRegularExpression(pattern: amountPattern),
                  let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
                  let range = Range(match.range(at: 1), in: trimmedLine) else {
                continue
            }

            let amountString = String(trimmedLine[range]).replacingOccurrences(of: ",", with: ".")
            guard let amount = Double(amountString), amount > 0 else { continue }

            var confidence = 0

            // Strong total indicators
            if lowerLine.contains("total") || lowerLine.contains("soustotal") || lowerLine.contains("sous-total") {
                confidence += 5
            }

            // Payment indicators
            if lowerLine.contains("payer") || lowerLine.contains("net") || lowerLine.contains("ttc") {
                confidence += 3
            }

            // Euro indicator
            if trimmedLine.contains("€") || lowerLine.contains("eur") {
                confidence += 2
            }

            // Position: near end of receipt (totals usually at bottom)
            if lineIndex > lines.count / 2 {
                confidence += 1
            }
            if lineIndex > lines.count - 8 {
                confidence += 1
            }

            // Larger amounts more likely to be totals
            if amount > 50 { confidence += 1 }
            if amount > 100 { confidence += 1 }

            // Negative indicators
            if lowerLine.contains("tva") || lowerLine.contains("ht ") {
                confidence -= 2  // TVA lines are not the total
            }
            if lowerLine.contains("rendu") || lowerLine.contains("monnaie") {
                confidence -= 3  // Change/return lines
            }

            // 🚀 FIX: Filter out addresses and non-amount lines
            let addressKeywords = ["av ", "av.", "avenue", "rue ", "bd ", "bd.", "boulevard",
                                   "pl ", "pl.", "place", "chemin", "route", "allée", "impasse"]
            if addressKeywords.contains(where: { lowerLine.contains($0) }) {
                confidence -= 10  // Definitely not an amount
            }
            if lowerLine.contains("siret") || lowerLine.contains("siren") || lowerLine.contains("tel") || lowerLine.contains("tél") {
                confidence -= 10  // Administrative info, not amounts
            }
            // Filter postal codes (5 digits alone or with city name)
            if lowerLine.range(of: #"\b\d{5}\b"#, options: .regularExpression) != nil &&
               (lowerLine.contains("paris") || lowerLine.contains("genève") || lowerLine.contains("lyon") || lowerLine.contains("marseille")) {
                confidence -= 10
            }

            if confidence > 0 {
                candidates.append((amount: amount, confidence: confidence, line: trimmedLine))
            }
        }

        // Return highest confidence amount
        if let bestCandidate = candidates.max(by: { $0.confidence < $1.confidence }) {
            return bestCandidate.amount
        }

        return nil
    }

    // MARK: - Create ExpenseData
    func createExpenseData(from parsed: ParsedExpense) -> ExpenseData {
        return ExpenseData(
            id: UUID(),
            date: parsed.date,
            merchant: parsed.merchant,
            amount: parsed.totalAmount,
            tax: parsed.vatAmount,
            category: parsed.category,
            items: parsed.items,
            paymentMethod: parsed.paymentMethod
        )
    }
}

// MARK: - Parsed Expense Model
struct ParsedExpense {
    var merchant: String = "Unknown"
    var totalAmount: Double = 0
    var netAmount: Double = 0
    var vatAmount: Double = 0
    var vatRate: Double = 0
    var currency: String = "CHF"
    var date: Date = Date()
    var category: String = "Other"
    var items: [String] = []
    var paymentMethod: String = "Card"
    var country: String = "CH"
    
    var formattedTotal: String {
        let symbol = getCurrencySymbol(currency)
        return "\(symbol)\(String(format: "%.2f", totalAmount))"
    }
    
    var formattedVAT: String {
        return String(format: "%.2f", vatAmount)
    }
    
    var formattedVATRate: String {
        return String(format: "%.1f%%", vatRate)
    }
    
    private func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "
        case "JPY": return "¥"
        default: return currency + " "
        }
    }
}