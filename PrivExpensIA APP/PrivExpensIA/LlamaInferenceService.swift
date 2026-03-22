import Foundation

// MARK: - Llama Inference Service
// Real AI inference using LlamaWrapperInternal (llama.cpp)

class LlamaInferenceService {
    static let shared = LlamaInferenceService()

    // Model configuration
    private let modelName = "Qwen2.5-0.5B-Instruct-Q4_K_M"
    private let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

    // State
    private var modelURL: URL?
    private var isLoading = false

    private init() {
        setupModelPath()
    }

    // MARK: - Model Path Setup

    private func setupModelPath() {

        // Priority 1: Check Bundle (for distribution)
        if let bundlePath = Bundle.main.path(forResource: "qwen2.5-0.5b-instruct-q4_k_m", ofType: "gguf") {
            modelURL = URL(fileURLWithPath: bundlePath)
            return
        } else {
            if let bundleURL = Bundle.main.resourceURL {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: bundleURL.path) {
                    let ggufFiles = contents.filter { $0.hasSuffix(".gguf") }
                }
            }
        }

        // Priority 2: Check Documents folder (for development/download)
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let modelsDir = documentsPath.appendingPathComponent("models")
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let documentsModelPath = modelsDir.appendingPathComponent(modelFileName)
        if FileManager.default.fileExists(atPath: documentsModelPath.path) {
            modelURL = documentsModelPath
            return
        }

        modelURL = documentsModelPath
    }

    // MARK: - Model Status

    var isModelAvailable: Bool {
        guard let url = modelURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var modelPath: String {
        modelURL?.path ?? ""
    }

    var isLlamaFrameworkAvailable: Bool {
        return true  // LlamaWrapper is always available now
    }

    var isModelLoaded: Bool {
        return LlamaWrapperInternal.shared.isModelLoaded
    }

    // MARK: - Model Loading

    func loadModel() async throws {
        guard let url = modelURL else {
            throw LlamaError.modelPathNotSet
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LlamaError.modelNotFound(path: url.path)
        }

        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try LlamaWrapperInternal.shared.loadModel(from: url)
        } catch {
            throw LlamaError.modelLoadFailed(error)
        }
    }

    // MARK: - Inference

    func runInference(ocrText: String) async throws -> ExpenseExtractionResult {
        // Try real LLM inference first
        if LlamaWrapperInternal.shared.isModelLoaded {
            do {
                let response = try LlamaWrapperInternal.shared.extractExpense(from: ocrText)

                return ExpenseExtractionResult(
                    merchant: response.merchant,
                    totalAmount: response.totalAmount,
                    taxAmount: response.taxAmount,
                    date: response.date ?? Date(),
                    category: response.category,
                    currency: response.currency,
                    confidence: response.confidence,
                    extractionMethod: response.method,
                    inferenceTime: response.inferenceTime
                )
            } catch {
            }
        } else {
            // Try to load model if available but not loaded
            if isModelAvailable && !isLoading {
                do {
                    try await loadModel()
                    return try await runInference(ocrText: ocrText)  // Retry with loaded model
                } catch {
                }
            }
        }

        // Fallback to pattern extraction
        return performPatternExtraction(from: ocrText)
    }

    // MARK: - Fallback Pattern Extraction

    private func performPatternExtraction(from text: String) -> ExpenseExtractionResult {
        let startTime = Date()

        // Use TextExtractionUtils for smart merchant detection (known patterns + scoring)
        let merchant = TextExtractionUtils.shared.extractMerchant(from: text)

        // Consolidated amount patterns - case insensitive, priority order
        let totalAmount = extractAmountPrioritized(from: text)

        // Tax patterns - Swiss TVA (7.7%, 8.1%), German MwSt, French TVA
        let taxAmount = extractAmount(from: text, patterns: [
            #"(?:TVA|MwSt|USt|Tax|Taxe)[:\s]+(?:CHF|EUR|Fr\.?|[\$€])?\s*(\d+[.,]\d{2})"#,
            #"(?:7[.,]7|8[.,]1)\s*%[:\s]*(?:CHF|EUR|Fr\.?)?\s*(\d+[.,]\d{2})"#
        ])

        let category = detectCategory(from: text)
        let currency = detectCurrency(from: text)
        let date = extractDate(from: text)

        let inferenceTime = Date().timeIntervalSince(startTime)

        return ExpenseExtractionResult(
            merchant: merchant,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            date: date,
            category: category,
            currency: currency,
            confidence: totalAmount > 0 ? 0.7 : 0.3,
            extractionMethod: "PatternFallback",
            inferenceTime: inferenceTime
        )
    }

    private func extractAmount(from text: String, patterns: [String]) -> Double {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: ".")
                return Double(amountString) ?? 0
            }
        }
        return 0
    }

    /// Prioritized amount extraction for Swiss/European receipts
    /// Priority: Explicit total keywords > Currency-prefixed amounts > Generic amounts
    private func extractAmountPrioritized(from text: String) -> Double {
        // PRIORITY 1: Explicit total keywords (most reliable)
        let totalKeywordPatterns = [
            // Multi-language TOTAL variants (case-insensitive via regex option)
            #"(?:TOTAL|TOTALE|GESAMT|SUMME|SOMME)\s*(?:CHF|EUR|Fr\.?|[\$€])?\s*:?\s*(\d+[.,]\d{2})"#,
            #"(?:TOTAL|TOTALE|GESAMT|SUMME|SOMME)\s*:?\s*(?:CHF|EUR|Fr\.?|[\$€])?\s*(\d+[.,]\d{2})"#,
            // Payment keywords
            #"(?:A PAYER|À PAYER|ZU ZAHLEN|NET|NETTO|MONTANT|BETRAG|AMOUNT|DUE|BALANCE)\s*:?\s*(?:CHF|EUR|Fr\.?|[\$€])?\s*(\d+[.,]\d{2})"#,
            // "Total CHF" or "CHF Total" patterns
            #"(?:CHF|EUR|Fr\.?)\s*(?:TOTAL|TOTALE)?\s*:?\s*(\d+[.,]\d{2})"#
        ]

        for pattern in totalKeywordPatterns {
            if let amount = extractFirstAmount(from: text, pattern: pattern), amount > 0 {
                return amount
            }
        }

        // PRIORITY 2: Currency-suffixed amounts (e.g., "125.50 CHF")
        let currencySuffixPattern = #"(\d+[.,]\d{2})\s*(?:CHF|EUR|Fr\.?|Francs?)"#
        if let amount = extractFirstAmount(from: text, pattern: currencySuffixPattern), amount > 0 {
            return amount
        }

        // PRIORITY 3: Last large amount in text (often the total)
        // Find all amounts and return the largest that appears after "---" or at end
        let allAmountsPattern = #"(\d+[.,]\d{2})"#
        if let regex = try? NSRegularExpression(pattern: allAmountsPattern),
           let matches = Optional(regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))),
           !matches.isEmpty {

            var amounts: [(value: Double, position: Int)] = []
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                    if let value = Double(amountStr), value > 0 {
                        amounts.append((value, match.range.location))
                    }
                }
            }

            // Return the largest amount (likely the total)
            if let maxAmount = amounts.max(by: { $0.value < $1.value }) {
                return maxAmount.value
            }
        }

        return 0
    }

    private func extractFirstAmount(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let amountString = String(text[range]).replacingOccurrences(of: ",", with: ".")
        return Double(amountString)
    }

    private func extractDate(from text: String) -> Date {
        // SWISS/EUROPEAN DATE EXTRACTION - DD.MM.YYYY format priority

        // 1. Try text month formats first (most reliable - no DD/MM ambiguity)
        let textMonthPatterns: [(pattern: String, format: String)] = [
            // "15 janvier 2026", "15 jan 2026", "15 jan. 2026"
            (#"(\d{1,2})\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|jan|fév|mar|avr|mai|jun|jul|aoû|sep|oct|nov|déc)\.?\s+(\d{2,4})"#, "dd MMMM yyyy"),
            // "15 January 2026", "15 Jan 2026"
            (#"(\d{1,2})\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\.?\s+(\d{2,4})"#, "dd MMMM yyyy"),
            // "15. Januar 2026" (German)
            (#"(\d{1,2})\.?\s+(januar|februar|märz|april|mai|juni|juli|august|september|oktober|november|dezember)\.?\s+(\d{2,4})"#, "dd MMMM yyyy")
        ]

        for (pattern, _) in textMonthPatterns {
            if let date = parseTextMonthDate(from: text, pattern: pattern) {
                return date
            }
        }

        // 2. Try numeric formats - ALWAYS interpret as DD.MM.YYYY (European)
        // Pattern captures: day, month, year separately for validation
        let numericPattern = #"(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})"#

        if let regex = try? NSRegularExpression(pattern: numericPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {

            if let dayRange = Range(match.range(at: 1), in: text),
               let monthRange = Range(match.range(at: 2), in: text),
               let yearRange = Range(match.range(at: 3), in: text) {

                var day = Int(text[dayRange]) ?? 0
                var month = Int(text[monthRange]) ?? 0
                var year = Int(text[yearRange]) ?? 0

                // Convert 2-digit year to 4-digit (26 → 2026, 99 → 1999)
                if year < 100 {
                    year = year > 50 ? 1900 + year : 2000 + year
                }

                // Validate and swap if needed (European = DD.MM)
                // If day > 12 and month <= 12, it's definitely DD.MM
                // If month > 12 and day <= 12, swap (was MM.DD by mistake)
                if month > 12 && day <= 12 {
                    swap(&day, &month)
                }

                // Final validation
                if day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= 2100 {
                    var components = DateComponents()
                    components.day = day
                    components.month = month
                    components.year = year
                    components.calendar = Calendar(identifier: .gregorian)

                    if let date = components.date {
                        return date
                    }
                }
            }
        }

        // 3. Try ISO format YYYY-MM-DD (unambiguous)
        let isoPattern = #"(\d{4})[/\.\-](\d{1,2})[/\.\-](\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: isoPattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {

            if let yearRange = Range(match.range(at: 1), in: text),
               let monthRange = Range(match.range(at: 2), in: text),
               let dayRange = Range(match.range(at: 3), in: text) {

                let year = Int(text[yearRange]) ?? 0
                let month = Int(text[monthRange]) ?? 0
                let day = Int(text[dayRange]) ?? 0

                if day >= 1 && day <= 31 && month >= 1 && month <= 12 {
                    var components = DateComponents()
                    components.day = day
                    components.month = month
                    components.year = year

                    if let date = Calendar(identifier: .gregorian).date(from: components) {
                        return date
                    }
                }
            }
        }

        return Date()
    }

    private func parseTextMonthDate(from text: String, pattern: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else {
            return nil
        }

        guard match.numberOfRanges >= 4,
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let yearRange = Range(match.range(at: 3), in: text) else {
            return nil
        }

        let day = Int(text[dayRange]) ?? 0
        let monthStr = String(text[monthRange]).lowercased()
        var year = Int(text[yearRange]) ?? 0

        // Convert 2-digit year
        if year < 100 {
            year = year > 50 ? 1900 + year : 2000 + year
        }

        // Map month name to number (unique keys only)
        let monthMap: [String: Int] = [
            // French full
            "janvier": 1, "février": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
            "juillet": 7, "août": 8, "septembre": 9, "octobre": 10, "novembre": 11, "décembre": 12,
            // French short (unique)
            "fév": 2, "avr": 4, "aoû": 8, "déc": 12,
            // English full
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
            // English short (shared)
            "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
            // German full
            "januar": 1, "februar": 2, "märz": 3, "juni": 6,
            "juli": 7, "oktober": 10, "dezember": 12
        ]

        guard let month = monthMap[monthStr], day >= 1 && day <= 31 else {
            return nil
        }

        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year

        return Calendar(identifier: .gregorian).date(from: components)
    }

    private func detectCategory(from text: String) -> String {
        let lowercased = text.lowercased()

        // Categories aligned with Constants.Categories.all - order matters!
        let categories: [(String, [String])] = [
            // Restaurant first (before Coffee/Groceries)
            ("Restaurant", ["restaurant", "bistro", "brasserie", "pizzeria", "mcdonald", "burger", "sushi", "grill"]),
            // Coffee specific
            ("Coffee", ["starbucks", "espresso bar", "tea room"]),
            // Groceries
            ("Groceries", ["migros", "coop", "denner", "aldi", "lidl", "spar", "supermarche", "boulangerie"]),
            // Gas
            ("Gas", ["essence", "shell", "bp", "avia", "migrol", "benzin"]),
            // Transport
            ("Transport", ["cff", "sbb", "tpg", "uber", "taxi", "parking", "bus", "train"]),
            // Health (specific medical terms)
            ("Health", ["pharmacie", "apotheke", "doctor", "medecin", "hopital", "clinic"]),
            // Shopping
            ("Shopping", ["manor", "fnac", "mediamarkt", "ikea", "h&m", "zara", "zalando"]),
            // Entertainment
            ("Entertainment", ["cinema", "theatre", "concert", "musee", "fitness"]),
            // Bills
            ("Bills", ["swisscom", "sunrise", "salt", "internet", "electric"]),
            // Coffee generic (last)
            ("Coffee", ["cafe", "café", "coffee", "kaffee"])
        ]

        for (category, keywords) in categories {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return category
            }
        }
        return "Other"
    }

    private func detectCurrency(from text: String) -> String {
        return TextExtractionUtils.shared.detectCurrency(from: text)
    }
}

// MARK: - Result Structure

struct ExpenseExtractionResult {
    let merchant: String
    let totalAmount: Double
    let taxAmount: Double
    let date: Date
    let category: String
    let currency: String
    let confidence: Double
    let extractionMethod: String
    let inferenceTime: TimeInterval

    var isFromRealAI: Bool {
        extractionMethod.contains("LLM") && extractionMethod.contains("Real")
    }

    func toJSON() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let json: [String: Any] = [
            "merchant": merchant,
            "total_amount": totalAmount,
            "tax_amount": taxAmount,
            "date": dateFormatter.string(from: date),
            "category": category,
            "currency": currency,
            "confidence": confidence,
            "extraction_method": extractionMethod,
            "inference_time_ms": Int(inferenceTime * 1000)
        ]

        if let data = try? JSONSerialization.data(withJSONObject: json),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}

// MARK: - Errors

enum LlamaError: LocalizedError {
    case modelPathNotSet
    case modelNotFound(path: String)
    case modelLoadFailed(Error)
    case inferenceFailed(Error)
    case invalidJSONResponse
    case jsonParsingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelPathNotSet:
            return "Model path not configured"
        case .modelNotFound(let path):
            return "Model file not found at: \(path)"
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .inferenceFailed(let error):
            return "Inference failed: \(error.localizedDescription)"
        case .invalidJSONResponse:
            return "Invalid JSON response from model"
        case .jsonParsingFailed(let error):
            return "Failed to parse JSON: \(error.localizedDescription)"
        }
    }
}

// MARK: - Model Download Helper

extension LlamaInferenceService {

    static let modelDownloadURL = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"

    func downloadModel(progress: @escaping (Double) -> Void) async throws -> URL {
        guard let destinationURL = modelURL else {
            throw LlamaError.modelPathNotSet
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        guard let url = URL(string: Self.modelDownloadURL) else {
            throw LlamaError.modelPathNotSet
        }


        let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LlamaError.modelLoadFailed(NSError(domain: "HTTP", code: -1))
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }
}
