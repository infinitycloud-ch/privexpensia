import Foundation

// MARK: - Text Extraction Utilities
// Unified utility class to eliminate code duplication across:
// - ExpenseParser
// - AIExtractionService
// - QwenModelManager
// - LlamaInferenceService

final class TextExtractionUtils {
    static let shared = TextExtractionUtils()

    private init() {}

    // MARK: - Payment Method Detection (consolidated from 4 files)
    /// Detects payment method from receipt text
    /// - Parameter text: OCR text from receipt
    /// - Returns: Payment method string (Visa, Mastercard, Cash, Twint, etc.)
    func detectPaymentMethod(from text: String) -> String {
        let lowercased = text.lowercased()

        // Credit/Debit Cards
        if lowercased.contains("visa") {
            return "Visa"
        }
        if lowercased.contains("mastercard") || lowercased.contains("master card") {
            return "Mastercard"
        }
        if lowercased.contains("amex") || lowercased.contains("american express") {
            return "Amex"
        }

        // Cash
        if lowercased.contains("cash") || lowercased.contains("espèces") || lowercased.contains("bar") || lowercased.contains("comptant") {
            return "Cash"
        }

        // Swiss-specific: Twint
        if lowercased.contains("twint") {
            return "Twint"
        }

        // Digital Wallets
        if lowercased.contains("apple pay") {
            return "Apple Pay"
        }
        if lowercased.contains("google pay") {
            return "Google Pay"
        }
        if lowercased.contains("samsung pay") {
            return "Samsung Pay"
        }
        if lowercased.contains("paypal") {
            return "PayPal"
        }

        // Generic card types
        if lowercased.contains("debit") {
            return "Debit Card"
        }
        if lowercased.contains("credit") {
            return "Credit Card"
        }
        if lowercased.contains("carte") || lowercased.contains("card") || lowercased.contains("karte") {
            return "Card"
        }

        return "Unknown"
    }

    // MARK: - Currency Detection (consolidated from 4 files)
    /// Detects currency from receipt text with Swiss priority
    /// Swiss app = CHF default unless explicit foreign currency
    /// - Parameter text: OCR text from receipt
    /// - Returns: Currency code (CHF, EUR, USD, etc.)
    func detectCurrency(from text: String) -> String {
        let lowercased = text.lowercased()

        // STEP 1: Check for EXPLICIT foreign currency symbols/codes
        // Only return non-CHF if there's a clear indicator
        let hasExplicitEuro = text.contains("€") || lowercased.contains(" eur ") || lowercased.contains("eur:")
        let hasExplicitUSD = text.contains("$") && !text.contains("CHF") || lowercased.contains(" usd ")
        let hasExplicitGBP = text.contains("£") || lowercased.contains(" gbp ")

        // STEP 2: Check for Swiss indicators (these OVERRIDE foreign currency detection)
        let swissIndicators: [String] = [
            // Explicit CHF
            "chf", "fr.", "sfr", "francs",
            // Swiss merchants
            "migros", "coop", "denner", "manor", "globus", "jelmoli",
            "sbb", "cff", "ffs", "tpg", "tl ", "bls",
            "post", "swisscom", "sunrise", "salt", "wingo",
            "aldi suisse", "lidl suisse", "volg", "spar",
            "digitec", "galaxus", "brack", "microspot",
            // Swiss tax
            "mwst", "7.7%", "7,7%", "8.1%", "8,1%",
            // Swiss phone/address patterns
            "+41", "0041", " ch-", " ch ", "suisse", "schweiz", "svizzera",
            // Swiss cities/cantons
            "zürich", "genève", "bern", "basel", "lausanne", "luzern",
            "winterthur", "st. gallen", "lugano", "biel"
        ]

        let isSwissReceipt = swissIndicators.contains { lowercased.contains($0) }

        // If Swiss receipt detected, return CHF regardless of other symbols
        // (Swiss receipts sometimes show € for comparison but charge in CHF)
        if isSwissReceipt {
            return "CHF"
        }

        // STEP 3: Return explicit foreign currency if detected
        if hasExplicitEuro { return "EUR" }
        if hasExplicitUSD { return "USD" }
        if hasExplicitGBP { return "GBP" }

        // Japanese Yen
        if text.contains("¥") || lowercased.contains("jpy") || lowercased.contains("yen") {
            return "JPY"
        }

        // Default to CHF for Swiss app context
        return "CHF"
    }

    // MARK: - Merchant Extraction (consolidated from 3 files)
    /// Extracts merchant name from receipt text with improved accuracy
    /// - Parameter text: OCR text from receipt
    /// - Returns: Merchant name
    func extractMerchant(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return "Unknown" }

        // Known merchant patterns (Swiss + European focus)
        // Including OCR variants for commonly misread names
        let knownMerchants: [(pattern: String, name: String)] = [
            // Swiss Supermarkets
            ("migros", "Migros"),
            ("migrolino", "Migros"),
            ("m-budget", "Migros"),
            ("coop", "Coop"),
            ("denner", "Denner"),
            ("lidl", "Lidl"),
            ("aldi", "Aldi"),
            ("spar", "Spar"),
            ("volg", "Volg"),

            // Swiss Department Stores
            ("manor", "Manor"),
            ("globus", "Globus"),
            ("jelmoli", "Jelmoli"),

            // Swiss Electronics
            ("digitec galaxus", "Digitec Galaxus"),
            ("galaxus", "Digitec Galaxus"),
            ("digitec", "Digitec"),
            ("fust", "Fust"),
            ("dipl. ing. fust", "Fust"),
            ("media markt", "Media Markt"),
            ("mediamarkt", "Media Markt"),

            // Swiss Restaurants / Cafés (with OCR variants)
            ("luigia", "Luigia"),
            ("wigia", "Luigia"),           // OCR misread: L→W
            ("luigla", "Luigia"),          // OCR misread: i→l
            ("lutgia", "Luigia"),          // OCR misread: i→t
            ("lungla", "Luigia"),          // OCR misread
            ("holy cow", "Holy Cow"),
            ("holycow", "Holy Cow"),
            ("fluffy", "Fluffy Café"),
            ("tilleuls", "Les Tilleuls"),
            ("les tilleuls", "Les Tilleuls"),
            ("delice", "Café Délice"),
            ("cafe delice", "Café Délice"),
            ("nyala", "Nyala Barka"),
            ("barka", "Nyala Barka"),
            ("marcellina", "Marcellina"),
            ("kimchi", "Kimchi"),
            ("cam-on", "CAM-ON.ch"),
            ("camon", "CAM-ON.ch"),

            // Gas Stations
            ("tamoil", "Tamoil"),
            ("shell", "Shell"),
            ("bp station", "BP"),
            ("avia", "Avia"),
            ("migrol", "Migrol"),

            // Fast Food & Coffee
            ("starbucks", "Starbucks"),
            ("mcdonald", "McDonald's"),
            ("mc donald", "McDonald's"),
            ("burger king", "Burger King"),
            ("subway", "Subway"),

            // Transport
            ("sbb", "SBB"),
            ("cff", "CFF"),
            ("uber", "Uber"),
            ("bolt", "Bolt"),
            ("tpg", "TPG"),

            // Telecom
            ("swisscom", "Swisscom"),
            ("sunrise", "Sunrise"),
            ("salt", "Salt"),

            // Generic patterns
            ("restaurant", "Restaurant"),
            ("café", "Café"),
            ("cafe", "Café"),
            ("hotel", "Hotel"),
            ("pharmacy", "Pharmacy"),
            ("pharmacie", "Pharmacie"),
            ("apotheke", "Apotheke")
        ]

        // PRIORITY: Check entire text for known merchants (handles OCR where name appears anywhere)
        let fullTextLower = text.lowercased()
        for merchant in knownMerchants {
            if fullTextLower.contains(merchant.pattern) {
                return merchant.name
            }
        }

        // Fallback: Check first 5 lines for known merchants
        for i in 0..<min(5, lines.count) {
            let line = lines[i].lowercased()
            for merchant in knownMerchants {
                if line.contains(merchant.pattern) {
                    let originalLine = lines[i]
                    if originalLine.count < 50 {
                        return cleanMerchantName(originalLine)
                    }
                    return merchant.name
                }
            }
        }

        // Score-based merchant detection for better accuracy
        var bestCandidate: (line: String, score: Int) = ("", 0)

        for (index, line) in lines.prefix(5).enumerated() {
            var score = 0

            // Skip clearly non-merchant lines
            if isNonMerchantLine(line) { continue }

            // Position bonus: first lines are more likely to be merchant
            score += max(0, 5 - index)

            // Length bonus: merchant names are typically 3-30 chars
            if line.count >= 3 && line.count <= 30 { score += 3 }

            // ALL CAPS bonus: many receipts have merchant in caps
            if line == line.uppercased() && line.count > 2 { score += 2 }

            // French restaurant prefixes: LE, LA, AU, CHEZ, L'
            let frenchPrefixes = ["LE ", "LA ", "AU ", "L'", "CHEZ "]
            if frenchPrefixes.contains(where: { line.uppercased().hasPrefix($0) }) {
                score += 4
            }

            // Contains letters (not just numbers/symbols)
            if line.contains(where: { $0.isLetter }) { score += 1 }

            // Penalty for address-like patterns
            if line.contains(where: { $0.isNumber }) && line.lowercased().contains("rue") { score -= 3 }
            if line.lowercased().contains("tel:") || line.lowercased().contains("tél:") { score -= 5 }

            if score > bestCandidate.score {
                bestCandidate = (line, score)
            }
        }

        if bestCandidate.score > 0 {
            return cleanMerchantName(bestCandidate.line)
        }

        return cleanMerchantName(lines.first ?? "Unknown")
    }

    // MARK: - Non-Merchant Line Detection
    private func isNonMerchantLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Too short or too long
        if line.count < 2 || line.count > 60 { return true }

        // Email or URL
        if line.contains("@") || lowercased.contains("http") || lowercased.contains("www.") { return true }

        // Phone number patterns
        if lowercased.contains("tel:") || lowercased.contains("tél:") { return true }
        let phonePattern = #"^\+?\d[\d\s\-\.]{8,}$"#
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // Address patterns
        let addressPatterns = ["rue ", "avenue ", "av ", "boulevard ", "bd ", "place ", "chemin "]
        if addressPatterns.contains(where: { lowercased.contains($0) }) { return true }

        // Postal code patterns (5 digits at start)
        let postalPattern = #"^\d{4,5}\s"#
        if let regex = try? NSRegularExpression(pattern: postalPattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // SIRET/Company ID patterns
        if lowercased.contains("siret") || lowercased.contains("tva:") || lowercased.contains("siren") { return true }

        // Only numbers and punctuation
        if line.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == " " || $0 == "-" }) { return true }

        // Date patterns
        let datePattern = #"^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            return true
        }

        // Common receipt keywords (not merchant names)
        let nonMerchantKeywords = ["document", "facture", "ticket", "reçu", "total", "table", "couverts", "vendeur"]
        if nonMerchantKeywords.contains(where: { lowercased.contains($0) }) { return true }

        return false
    }

    // MARK: - Category Detection
    /// Detects expense category from text
    /// - Parameter text: OCR text from receipt
    /// - Returns: Category string matching Constants.Categories.all
    func detectCategory(from text: String) -> String {
        let lowercased = text.lowercased()

        // Categories aligned with Constants.Categories.all - order matters!
        let categories: [(category: String, keywords: [String])] = [
            // Restaurant first (before Coffee/Groceries)
            ("Restaurant", ["restaurant", "bistro", "brasserie", "pizzeria", "trattoria", "mcdonald", "burger", "sushi", "grill", "bar", "pub"]),
            // Coffee specific
            ("Coffee", ["starbucks", "espresso bar", "tea room"]),
            // Groceries
            ("Groceries", ["migros", "coop", "denner", "aldi", "lidl", "spar", "volg", "supermarché", "epicerie", "boulangerie"]),
            // Gas
            ("Gas", ["essence", "benzin", "fuel", "bp", "shell", "avia", "migrol"]),
            // Transport
            ("Transport", ["sbb", "cff", "tpg", "uber", "taxi", "parking", "bus", "train", "tram"]),
            // Health (specific medical terms)
            ("Health", ["pharmacie", "apotheke", "doctor", "médecin", "hôpital", "hospital", "clinic", "klinik"]),
            // Shopping
            ("Shopping", ["manor", "globus", "fnac", "mediamarkt", "ikea", "h&m", "zara", "boutique"]),
            // Entertainment
            ("Entertainment", ["cinema", "théâtre", "concert", "musée", "museum", "sport", "fitness"]),
            // Bills
            ("Bills", ["swisscom", "sunrise", "salt", "internet", "téléphone", "electric", "water"]),
            // Coffee generic (last)
            ("Coffee", ["café", "cafe", "coffee", "kaffee"])
        ]

        for (category, keywords) in categories {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return category
            }
        }

        return "Other"
    }

    // MARK: - Private Helpers

    private func cleanMerchantName(_ name: String) -> String {
        var cleaned = name

        // Remove common suffixes
        let removePatterns = ["Inc.", "LLC", "Ltd.", "SA", "AG", "GmbH", "Sàrl", "Corp.", "®", "™", "*"]
        for pattern in removePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }

        // Remove receipt artifacts
        cleaned = cleaned.replacingOccurrences(of: "---", with: "")
        cleaned = cleaned.replacingOccurrences(of: "***", with: "")

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize properly if all caps
        if cleaned == cleaned.uppercased() && cleaned.count > 3 {
            cleaned = cleaned.capitalized
        }

        return cleaned.isEmpty ? "Unknown" : cleaned
    }
}
