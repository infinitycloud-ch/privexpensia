import Foundation
import UIKit

// MARK: - Cloud Vision Service
// Supports OpenAI Vision (GPT-4o) and Groq Vision for receipt analysis

class CloudVisionService {
    static let shared = CloudVisionService()

    private let defaults = UserDefaults.standard

    // MARK: - Provider Configuration

    enum VisionProvider: String, CaseIterable {
        case openai = "OpenAI"
        case groq = "Groq"

        var displayName: String {
            switch self {
            case .openai: return "OpenAI GPT-4o"
            case .groq: return "Groq Vision"
            }
        }

        var description: String {
            switch self {
            case .openai: return "Most accurate, ~2-3s"
            case .groq: return "Ultra-fast, ~0.5s"
            }
        }
    }

    // MARK: - Settings Keys

    private enum Keys {
        static let openaiAPIKey = "cloudVision.openaiAPIKey"
        static let groqAPIKey = "cloudVision.groqAPIKey"
        static let selectedProvider = "cloudVision.selectedProvider"
        static let isEnabled = "cloudVision.isEnabled"
    }

    // MARK: - Settings Properties

    var openaiAPIKey: String {
        get { defaults.string(forKey: Keys.openaiAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.openaiAPIKey) }
    }

    var groqAPIKey: String {
        get { defaults.string(forKey: Keys.groqAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.groqAPIKey) }
    }

    var selectedProvider: VisionProvider {
        get {
            let rawValue = defaults.string(forKey: Keys.selectedProvider) ?? VisionProvider.groq.rawValue
            return VisionProvider(rawValue: rawValue) ?? .groq
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.selectedProvider) }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    var isConfigured: Bool {
        switch selectedProvider {
        case .openai: return !openaiAPIKey.isEmpty
        case .groq: return !groqAPIKey.isEmpty
        }
    }

    // MARK: - Extraction Result

    struct ExtractionResult {
        var merchant: String
        var amount: Double
        var currency: String
        var date: Date?
        var category: String
        var items: [String]
        var taxAmount: Double
        var confidence: Double
        var processingTime: TimeInterval
        var provider: VisionProvider
    }

    // MARK: - API Calls

    func analyzeReceipt(image: UIImage, completion: @escaping (Result<ExtractionResult, Error>) -> Void) {
        guard isEnabled && isConfigured else {
            completion(.failure(CloudVisionError.notConfigured))
            return
        }

        let startTime = Date()

        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(CloudVisionError.imageConversionFailed))
            return
        }
        let base64Image = imageData.base64EncodedString()

        switch selectedProvider {
        case .openai:
            analyzeWithOpenAI(base64Image: base64Image, startTime: startTime, completion: completion)
        case .groq:
            analyzeWithGroq(base64Image: base64Image, startTime: startTime, completion: completion)
        }
    }

    // MARK: - OpenAI Vision API (GPT-5.2 Responses API)

    private func analyzeWithOpenAI(base64Image: String, startTime: Date, completion: @escaping (Result<ExtractionResult, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            completion(.failure(CloudVisionError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Analyze this receipt image and extract the following information in JSON format:
        {
            "merchant": "store name",
            "amount": 123.45,
            "currency": "CHF",
            "date": "DD.MM.YYYY",
            "category": "Restaurant/Groceries/Transport/etc",
            "items": ["item1", "item2"],
            "tax_amount": 12.34
        }

        IMPORTANT:
        - Extract the TOTAL TTC (total including tax), NOT the Total HT (before tax)
        - For Swiss receipts, look for "TOTAL TTC", "Gesamt", "Total CHF"
        - Return ONLY valid JSON, no other text
        - If currency is not visible, default to CHF for Swiss receipts
        """

        // GPT-5.2 Responses API with vision
        let body: [String: Any] = [
            "model": "gpt-5.2",
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": prompt
                        ],
                        [
                            "type": "input_image",
                            "image_url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ],
            "reasoning": ["effort": "none"],
            "text": ["verbosity": "low"]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }


        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let processingTime = Date().timeIntervalSince(startTime)

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(CloudVisionError.noData))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // GPT-5.2 Responses API format
                    var content: String?

                    // Try output_text first (simple response)
                    if let outputText = json["output_text"] as? String {
                        content = outputText
                    }
                    // Try output array (structured response)
                    else if let output = json["output"] as? [[String: Any]] {
                        for item in output {
                            if let type = item["type"] as? String, type == "message",
                               let messageContent = item["content"] as? [[String: Any]] {
                                for contentItem in messageContent {
                                    if let text = contentItem["text"] as? String {
                                        content = text
                                        break
                                    }
                                }
                            }
                        }
                    }

                    if let content = content {

                        let result = self?.parseVisionResponse(content, provider: .openai, processingTime: processingTime)
                        DispatchQueue.main.async {
                            if let result = result {
                                completion(.success(result))
                            } else {
                                completion(.failure(CloudVisionError.parsingFailed))
                            }
                        }
                    } else if let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(CloudVisionError.apiError(message)))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(CloudVisionError.parsingFailed))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(CloudVisionError.parsingFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Groq Vision API

    private func analyzeWithGroq(base64Image: String, startTime: Date, completion: @escaping (Result<ExtractionResult, Error>) -> Void) {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            completion(.failure(CloudVisionError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Analyze this receipt image and extract the following information in JSON format:
        {
            "merchant": "store name",
            "amount": 123.45,
            "currency": "CHF",
            "date": "DD.MM.YYYY",
            "category": "Restaurant/Groceries/Transport/etc",
            "items": ["item1", "item2"],
            "tax_amount": 12.34
        }

        IMPORTANT:
        - Extract the TOTAL TTC (total including tax), NOT the Total HT (before tax)
        - For Swiss receipts, look for "TOTAL TTC", "Gesamt", "Total CHF"
        - Return ONLY valid JSON, no other text
        """

        // Groq uses Llama 4 Scout for vision tasks (multimodal with image support)
        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.1
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }


        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let processingTime = Date().timeIntervalSince(startTime)

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(CloudVisionError.noData))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {


                    let result = self?.parseVisionResponse(content, provider: .groq, processingTime: processingTime)
                    DispatchQueue.main.async {
                        if let result = result {
                            completion(.success(result))
                        } else {
                            completion(.failure(CloudVisionError.parsingFailed))
                        }
                    }
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(CloudVisionError.apiError(message)))
                    }
                } else {
                    // Debug: print raw response
                    if let rawString = String(data: data, encoding: .utf8) {
                    }
                    DispatchQueue.main.async {
                        completion(.failure(CloudVisionError.parsingFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Response Parsing

    private func parseVisionResponse(_ content: String, provider: VisionProvider, processingTime: TimeInterval) -> ExtractionResult? {
        // Extract JSON from response (may be wrapped in markdown)
        var jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON object
        if let startIndex = jsonString.firstIndex(of: "{"),
           let endIndex = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[startIndex...endIndex])
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Extract fields
        let merchant = json["merchant"] as? String ?? "Unknown"

        var amount: Double = 0
        if let amountValue = json["amount"] as? Double {
            amount = amountValue
        } else if let amountValue = json["amount"] as? Int {
            amount = Double(amountValue)
        } else if let amountString = json["amount"] as? String {
            amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        let currency = json["currency"] as? String ?? "CHF"
        let category = json["category"] as? String ?? "Other"
        let items = json["items"] as? [String] ?? []

        var taxAmount: Double = 0
        if let taxValue = json["tax_amount"] as? Double {
            taxAmount = taxValue
        } else if let taxValue = json["tax_amount"] as? Int {
            taxAmount = Double(taxValue)
        }

        // Parse date
        var date: Date? = nil
        if let dateString = json["date"] as? String {
            let formats = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy"]
            for format in formats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let parsed = formatter.date(from: dateString) {
                    date = parsed
                    break
                }
            }
        }

        return ExtractionResult(
            merchant: merchant,
            amount: amount,
            currency: currency,
            date: date ?? Date(),
            category: normalizeCategory(category),
            items: items,
            taxAmount: taxAmount,
            confidence: 0.95,
            processingTime: processingTime,
            provider: provider
        )
    }

    private func normalizeCategory(_ category: String) -> String {
        let lowercased = category.lowercased()
        let categoryMap: [String: String] = [
            "restaurant": "Restaurant",
            "food": "Restaurant",
            "dining": "Restaurant",
            "cafe": "Coffee",
            "coffee": "Coffee",
            "groceries": "Groceries",
            "supermarket": "Groceries",
            "grocery": "Groceries",
            "transport": "Transport",
            "transportation": "Transport",
            "taxi": "Transport",
            "uber": "Transport",
            "shopping": "Shopping",
            "retail": "Shopping",
            "gas": "Gas",
            "fuel": "Gas",
            "petrol": "Gas",
            "health": "Health",
            "pharmacy": "Health",
            "medical": "Health",
            "entertainment": "Entertainment"
        ]

        for (key, value) in categoryMap {
            if lowercased.contains(key) {
                return value
            }
        }

        return "Other"
    }

    // MARK: - Errors

    enum CloudVisionError: Error, LocalizedError {
        case notConfigured
        case imageConversionFailed
        case invalidURL
        case noData
        case parsingFailed
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Cloud Vision not configured. Add your API key in Settings."
            case .imageConversionFailed:
                return "Failed to process the image"
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No response from server"
            case .parsingFailed:
                return "Failed to parse response"
            case .apiError(let message):
                return "API Error: \(message)"
            }
        }
    }
}
