import Foundation
import CoreML
import Vision

// MLX Service for AI Model Integration
// Now using LlamaInferenceService with Qwen2.5-0.5B-Instruct for REAL AI inference
// Falls back to regex patterns if model not available

class MLXService {
    static let shared = MLXService()

    private var modelLoaded = false
    private var modelPath: URL?

    // Real LLM inference service
    private let llamaService = LlamaInferenceService.shared

    private init() {
        // Check if real model is available
        if llamaService.isModelAvailable {
        } else {
        }
    }

    // Model Configuration
    struct ModelConfig {
        static let modelName = "Qwen2.5-0.5B-Instruct"
        static let quantization = "Q4_K_M"
        static let maxTokens = 512
        static let temperature = 0.2
        static let topP = 0.9
    }

    // Initialize Model - Now uses LlamaInferenceService
    func initializeModel(completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            do {
                // Try to load real LLM model
                if llamaService.isModelAvailable {
                    try await llamaService.loadModel()
                    await MainActor.run {
                        self.modelLoaded = true
                        completion(.success(true))
                    }
                } else {
                    // Model file not present - DON'T set modelLoaded=true so auto-load can try later
                    await MainActor.run {
                        completion(.success(true))
                    }
                }
            } catch {
                await MainActor.run {
                    // DON'T set modelLoaded=true so auto-load can retry
                    completion(.success(true))
                }
            }
        }
    }

    // Run inference - Now tries REAL AI first, then falls back to patterns
    func runInference(prompt: String, completion: @escaping (Result<AIExtractedData, Error>) -> Void) {
        Task {
            do {
                // 🚀 FIX: Load model if available but not yet loaded
                if llamaService.isModelAvailable && !modelLoaded {
                    try await llamaService.loadModel()
                    self.modelLoaded = true
                } else if !llamaService.isModelAvailable {
                } else {
                }

                // Try real LLM inference
                let result = try await llamaService.runInference(ocrText: prompt)

                let aiData = AIExtractedData(
                    merchant: result.merchant,
                    totalAmount: result.totalAmount,
                    taxAmount: result.taxAmount,
                    date: result.date,
                    category: result.category,
                    items: [],
                    confidence: result.confidence,
                    processingTime: result.inferenceTime,
                    modelUsed: result.extractionMethod
                )

                await MainActor.run {
                    completion(.success(aiData))
                }

            } catch {
                // This shouldn't happen as LlamaService has its own fallback
                // But just in case, use local pattern extraction
                await MainActor.run {
                    let fallbackData = self.extractWithPatterns(from: prompt)
                    completion(.success(fallbackData))
                }
            }
        }
    }

    // Create structured prompt for LLM
    private func createStructuredPrompt(from text: String) -> String {
        return """
        Extract expense information from the following receipt text.
        Return a JSON object with these fields:
        - merchant: string
        - total_amount: number
        - tax_amount: number
        - date: string (ISO format)
        - category: string (Restaurant/Groceries/Transport/Shopping/Entertainment/Health/Bills/Coffee/Gas/Other)
        - items: array of {name: string, price: number}

        Receipt text:
        \(text)

        JSON output:
        """
    }

    // Pattern-based extraction (fallback when MLX not available)
    private func extractWithPatterns(from text: String) -> AIExtractedData {
        var data = AIExtractedData()

        // Extract merchant (first non-empty line)
        let lines = text.components(separatedBy: .newlines)
        data.merchant = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "Unknown"

        // Extract amounts
        data.totalAmount = extractAmount(from: text, patterns: [
            #"TOTAL[:\s]+(?:[\$€£¥])?(\d+[.,]\d{2})"#,
            #"Total[:\s]+(?:[\$€£¥])?(\d+[.,]\d{2})"#
        ])

        data.taxAmount = extractAmount(from: text, patterns: [
            #"(?:TVA|TAX|Tax)[:\s]+(?:[\$€£¥])?(\d+[.,]\d{2})"#
        ])

        // Extract date
        data.date = extractDate(from: text)

        // Detect category
        data.category = detectCategory(from: text)

        // Extract items
        data.items = extractItems(from: text)

        data.confidence = calculateConfidence(data)

        return data
    }

    private func extractAmount(from text: String, patterns: [String]) -> Double {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: ".")
                return Double(amountString) ?? 0
            }
        }
        return 0
    }

    private func extractDate(from text: String) -> Date {
        let patterns = [
            #"(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4})"#,
            #"(\d{4}[/\-]\d{1,2}[/\-]\d{1,2})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text) {
                let dateString = String(text[range])

                let formatters = [
                    "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd",
                    "dd-MM-yyyy", "MM-dd-yyyy"
                ]

                for format in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }

        return Date()
    }

    private func detectCategory(from text: String) -> String {
        let lowercased = text.lowercased()

        // Categories aligned with Constants.Categories.all - order matters!
        let categoryKeywords: [(String, [String])] = [
            // Restaurant first (before Coffee/Groceries)
            ("Restaurant", ["restaurant", "bistro", "brasserie", "pizzeria", "mcdonald", "burger", "sushi", "grill"]),
            // Coffee specific
            ("Coffee", ["starbucks", "espresso bar", "tea room"]),
            // Groceries
            ("Groceries", ["migros", "coop", "denner", "aldi", "lidl", "supermarket", "bakery", "grocery"]),
            // Gas
            ("Gas", ["gas", "fuel", "essence", "shell", "bp", "avia"]),
            // Transport
            ("Transport", ["uber", "lyft", "taxi", "parking", "sbb", "train", "bus"]),
            // Health (specific medical terms)
            ("Health", ["pharmacy", "pharmacie", "apotheke", "doctor", "medical", "hospital", "clinic"]),
            // Shopping
            ("Shopping", ["store", "shop", "mall", "retail", "ikea", "h&m", "zara"]),
            // Entertainment
            ("Entertainment", ["cinema", "movie", "theater", "concert", "museum"]),
            // Bills
            ("Bills", ["electric", "water", "internet", "phone", "swisscom"]),
            // Coffee generic (last)
            ("Coffee", ["cafe", "café", "coffee", "kaffee"])
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return category
            }
        }

        return "Other"
    }

    private func extractItems(from text: String) -> [ExpenseItem] {
        var items: [ExpenseItem] = []
        let lines = text.components(separatedBy: .newlines)

        let itemPattern = #"^(.+?)\s+(?:[\$€£¥])?(\d+[.,]\d{2})$"#
        let regex = try? NSRegularExpression(pattern: itemPattern)

        for line in lines {
            if let match = regex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
               let nameRange = Range(match.range(at: 1), in: line),
               let priceRange = Range(match.range(at: 2), in: line) {

                let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                let priceString = String(line[priceRange]).replacingOccurrences(of: ",", with: ".")

                if let price = Double(priceString),
                   !name.lowercased().contains("total"),
                   !name.lowercased().contains("tax") {
                    items.append(ExpenseItem(name: name, price: price))
                }
            }
        }

        return items
    }

    private func calculateConfidence(_ data: AIExtractedData) -> Double {
        var confidence = 0.0
        var factors = 0

        if !data.merchant.isEmpty && data.merchant != "Unknown" {
            confidence += 0.2
            factors += 1
        }

        if data.totalAmount > 0 {
            confidence += 0.3
            factors += 1
        }

        if data.taxAmount > 0 {
            confidence += 0.1
            factors += 1
        }

        if data.category != "Other" {
            confidence += 0.2
            factors += 1
        }

        if !data.items.isEmpty {
            confidence += 0.2
            factors += 1
        }

        return factors > 0 ? confidence : 0.5
    }

    // Download model (placeholder implementation)
    private func downloadModel(completion: @escaping (Result<Bool, Error>) -> Void) {
        // In production, this would download from Hugging Face or custom CDN
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            completion(.success(true))
        }
    }
}

// Data structures
struct AIExtractedData {
    var merchant: String = ""
    var totalAmount: Double = 0
    var taxAmount: Double = 0
    var date: Date = Date()
    var category: String = "Other"
    var items: [ExpenseItem] = []
    var confidence: Double = 0
    var processingTime: TimeInterval = 0
    var modelUsed: String = ""
}

struct ExpenseItem {
    let name: String
    let price: Double
}

// Errors
enum MLXError: LocalizedError {
    case modelNotLoaded
    case initializationFailed
    case inferenceFailed
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Le modèle MLX n'est pas chargé"
        case .initializationFailed:
            return "Échec de l'initialisation du modèle"
        case .inferenceFailed:
            return "Échec de l'inférence"
        case .downloadFailed:
            return "Échec du téléchargement du modèle"
        }
    }
}
