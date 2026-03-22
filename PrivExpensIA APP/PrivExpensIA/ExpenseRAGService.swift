import Foundation
import CoreData

// MARK: - Sprint 5: Expense RAG Service
// Retrieval Augmented Generation pour questionner les dépenses en langage naturel

// MARK: - Chat Provider Enum
enum ChatProvider: String, CaseIterable, Identifiable {
    case qwenLocal = "qwen"
    case groq = "groq"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwenLocal: return "Qwen (Local)"
        case .groq: return "Groq Cloud"
        case .openai: return "OpenAI"
        }
    }

    var icon: String {
        switch self {
        case .qwenLocal: return "cpu"
        case .groq: return "bolt.fill"
        case .openai: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .qwenLocal: return "On-device, private"
        case .groq: return "Llama 4 Scout"
        case .openai: return "GPT-5.2"
        }
    }
}

class ExpenseRAGService {
    static let shared = ExpenseRAGService()

    private let qwenManager = QwenModelManager.shared
    private let coreDataManager = CoreDataManager.shared
    private let cloudVisionService = CloudVisionService.shared

    // MARK: - Provider Selection
    private let providerKey = "chat.selectedProvider"

    var selectedProvider: ChatProvider {
        get {
            if let raw = UserDefaults.standard.string(forKey: providerKey),
               let provider = ChatProvider(rawValue: raw) {
                return provider
            }
            return .qwenLocal  // Default to local Qwen
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    func isProviderAvailable(_ provider: ChatProvider) -> Bool {
        switch provider {
        case .qwenLocal:
            return true // Always available
        case .groq:
            return !cloudVisionService.groqAPIKey.isEmpty
        case .openai:
            return !cloudVisionService.openaiAPIKey.isEmpty
        }
    }

    private init() {}

    // MARK: - Chat Message Model

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let content: String
        let timestamp: Date

        enum Role {
            case user
            case assistant
        }
    }

    // MARK: - RAG Query

    func askQuestion(_ question: String, completion: @escaping (Result<String, Error>) -> Void) {

        // 1. Analyser la question pour déterminer le type de requête
        let queryType = analyzeQuestion(question)

        // 2. Récupérer les dépenses pertinentes
        let relevantExpenses = fetchRelevantExpenses(for: queryType)

        // 3. Construire le contexte RAG
        let context = buildRAGContext(expenses: relevantExpenses, queryType: queryType)

        // 4. Construire le prompt
        let prompt = buildRAGPrompt(question: question, context: context)


        // 5. Route to selected provider
        switch selectedProvider {
        case .qwenLocal:
            askQwen(prompt: prompt, queryType: queryType, expenses: relevantExpenses, completion: completion)
        case .groq:
            askGroq(prompt: prompt, queryType: queryType, expenses: relevantExpenses, completion: completion)
        case .openai:
            askOpenAI(prompt: prompt, queryType: queryType, expenses: relevantExpenses, completion: completion)
        }
    }

    // MARK: - Direct LLM Query (No RAG Context)
    /// Use this for document classification/summarization - NO expense data mixed in
    func askLLMDirect(_ prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        switch selectedProvider {
        case .qwenLocal:
            askQwenDirect(prompt: prompt, completion: completion)
        case .groq:
            askGroqDirect(prompt: prompt, completion: completion)
        case .openai:
            askOpenAIDirect(prompt: prompt, completion: completion)
        }
    }

    private func askQwenDirect(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        qwenManager.runInference(prompt: prompt) { result in
            switch result {
            case .success(let response):
                let cleaned = self.cleanResponse(response.extractedData)
                completion(.success(cleaned))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func askGroqDirect(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !cloudVisionService.groqAPIKey.isEmpty else {
            // Fallback to Qwen if no API key
            askQwenDirect(prompt: prompt, completion: completion)
            return
        }

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cloudVisionService.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [
                ["role": "system", "content": "Tu es un assistant d'archivage documentaire. Analyse le document et réponds de façon précise et concise en français. Ne mentionne JAMAIS de dépenses ou données financières externes."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 500
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(NSError(domain: "Groq", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }.resume()
    }

    private func askOpenAIDirect(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !cloudVisionService.openaiAPIKey.isEmpty else {
            // Fallback to Qwen if no API key
            askQwenDirect(prompt: prompt, completion: completion)
            return
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cloudVisionService.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "Tu es un assistant d'archivage documentaire. Analyse le document et réponds de façon précise et concise en français. Ne mentionne JAMAIS de dépenses ou données financières externes."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 500
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }

                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }.resume()
    }

    // MARK: - Provider-Specific Methods

    private func askQwen(prompt: String, queryType: QueryType, expenses: [Expense], completion: @escaping (Result<String, Error>) -> Void) {
        qwenManager.runInference(prompt: prompt) { result in
            switch result {
            case .success(let response):
                let cleaned = self.cleanResponse(response.extractedData)

                // Détecter si Qwen a renvoyé du JSON OCR au lieu d'une réponse conversationnelle
                if self.isOCRJsonResponse(cleaned) {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                } else {
                    completion(.success(cleaned))
                }

            case .failure(let error):
                let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                completion(.success(fallbackAnswer))
            }
        }
    }

    private func askGroq(prompt: String, queryType: QueryType, expenses: [Expense], completion: @escaping (Result<String, Error>) -> Void) {
        guard !cloudVisionService.groqAPIKey.isEmpty else {
            let fallbackAnswer = generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
            completion(.success(fallbackAnswer))
            return
        }

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cloudVisionService.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "meta-llama/llama-4-scout-17b-16e-instruct",
            "messages": [
                ["role": "system", "content": "Tu es un assistant financier. Réponds de façon concise et utile en français."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 500
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                    return
                }

                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }.resume()
    }

    private func askOpenAI(prompt: String, queryType: QueryType, expenses: [Expense], completion: @escaping (Result<String, Error>) -> Void) {
        guard !cloudVisionService.openaiAPIKey.isEmpty else {
            let fallbackAnswer = generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
            completion(.success(fallbackAnswer))
            return
        }

        // GPT-5.2 uses the Responses API
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cloudVisionService.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = "Tu es un assistant financier. Réponds de façon concise et utile en français."
        let fullInput = "\(systemPrompt)\n\n\(prompt)"

        let body: [String: Any] = [
            "model": "gpt-5.2",
            "input": fullInput,
            "reasoning": ["effort": "none"],
            "text": ["verbosity": "low"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                    return
                }

                // GPT-5.2 Responses API returns output_text or output array
                var content: String?
                if let outputText = json["output_text"] as? String {
                    content = outputText
                } else if let output = json["output"] as? [[String: Any]] {
                    // Extract text from output array
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
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    let fallbackAnswer = self.generateFallbackAnswer(queryType: queryType, expenses: expenses, question: "")
                    completion(.success(fallbackAnswer))
                }
            }
        }.resume()
    }

    // MARK: - OCR JSON Detection
    /// Détecte si la réponse de Qwen est du JSON OCR au lieu d'une réponse conversationnelle
    private func isOCRJsonResponse(_ response: String) -> Bool {
        let ocrKeywords = [
            "confidence",
            "total_amount",
            "extraction_method",
            "parser_fallback",
            "tax_amount",
            "\"merchant\":",
            "\"currency\":"
        ]

        let lowercased = response.lowercased()

        // Si la réponse contient plusieurs mots-clés OCR, c'est probablement du JSON OCR
        let matchCount = ocrKeywords.filter { lowercased.contains($0.lowercased()) }.count
        return matchCount >= 3
    }

    // MARK: - Query Analysis

    enum QueryType {
        case totalSpending(period: Period)
        case categorySpending(category: String?, period: Period)
        case merchantHistory(merchant: String?)
        case recentExpenses(count: Int)
        case comparison(categories: [String])
        case general

        enum Period {
            case today
            case week
            case month
            case year
            case all
        }
    }

    private func analyzeQuestion(_ question: String) -> QueryType {
        let lowercased = question.lowercased()

        // Détecter la période
        let period: QueryType.Period
        if lowercased.contains("aujourd'hui") || lowercased.contains("today") {
            period = .today
        } else if lowercased.contains("semaine") || lowercased.contains("week") {
            period = .week
        } else if lowercased.contains("mois") || lowercased.contains("month") {
            period = .month
        } else if lowercased.contains("année") || lowercased.contains("year") {
            period = .year
        } else {
            period = .month  // Default: 1 mois
        }

        // Détecter le type de question
        if lowercased.contains("combien") || lowercased.contains("total") || lowercased.contains("dépensé") {
            // Vérifier si c'est pour une catégorie
            if let category = detectCategory(in: lowercased) {
                return .categorySpending(category: category, period: period)
            }
            // Vérifier si c'est pour un marchand
            if let merchant = detectMerchant(in: lowercased) {
                return .merchantHistory(merchant: merchant)
            }
            return .totalSpending(period: period)
        }

        if lowercased.contains("dernière") || lowercased.contains("récent") || lowercased.contains("last") {
            return .recentExpenses(count: 5)
        }

        if lowercased.contains("compare") || lowercased.contains("vs") || lowercased.contains("versus") {
            return .comparison(categories: detectCategories(in: lowercased))
        }

        if lowercased.contains("migros") || lowercased.contains("coop") || lowercased.contains("chez") {
            if let merchant = detectMerchant(in: lowercased) {
                return .merchantHistory(merchant: merchant)
            }
        }

        return .general
    }

    private func detectCategory(in text: String) -> String? {
        let categories = [
            ("restaurant", "Restaurant"),
            ("resto", "Restaurant"),
            ("café", "Coffee"),
            ("coffee", "Coffee"),
            ("courses", "Groceries"),
            ("alimentation", "Groceries"),
            ("essence", "Gas"),
            ("transport", "Transport"),
            ("santé", "Health"),
            ("shopping", "Shopping"),
            ("loisir", "Entertainment")
        ]

        for (keyword, category) in categories {
            if text.contains(keyword) {
                return category
            }
        }
        return nil
    }

    private func detectMerchant(in text: String) -> String? {
        let merchants = ["migros", "coop", "denner", "aldi", "lidl", "starbucks", "mcdonald"]

        for merchant in merchants {
            if text.contains(merchant) {
                return merchant.capitalized
            }
        }

        // Chercher après "chez" - with bounds checking
        if let range = text.range(of: "chez "),
           range.upperBound <= text.endIndex {
            let afterChez = String(text[range.upperBound...])
            let words = afterChez.components(separatedBy: .whitespaces)
            if let firstWord = words.first, !firstWord.isEmpty {
                return firstWord.capitalized
            }
        }

        return nil
    }

    private func detectCategories(in text: String) -> [String] {
        var found: [String] = []
        let allCategories = Constants.Categories.all

        for category in allCategories {
            if text.lowercased().contains(category.lowercased()) {
                found.append(category)
            }
        }

        return found
    }

    // MARK: - Fetch Expenses

    private func fetchRelevantExpenses(for queryType: QueryType) -> [Expense] {
        let context = coreDataManager.persistentContainer.viewContext
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        // Déterminer la période
        let (startDate, endDate) = getDateRange(for: queryType)

        if let start = startDate {
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, endDate as NSDate)
        }

        // Limiter le nombre pour le contexte Qwen (max ~50 pour rester dans la limite de tokens)
        request.fetchLimit = 50

        do {
            var expenses = try context.fetch(request)

            // Filtrer selon le type de requête
            switch queryType {
            case .categorySpending(let category, _):
                if let cat = category {
                    expenses = expenses.filter { $0.category?.lowercased() == cat.lowercased() }
                }

            case .merchantHistory(let merchant):
                if let merch = merchant {
                    expenses = expenses.filter { ($0.merchant ?? "").lowercased().contains(merch.lowercased()) }
                }

            default:
                break
            }

            return expenses

        } catch {
            return []
        }
    }

    private func getDateRange(for queryType: QueryType) -> (Date?, Date) {
        let now = Date()
        let calendar = Calendar.current

        let period: QueryType.Period
        switch queryType {
        case .totalSpending(let p), .categorySpending(_, let p):
            period = p
        default:
            period = .month
        }

        switch period {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return (monthAgo, now)
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return (yearAgo, now)
        case .all:
            return (nil, now)
        }
    }

    // MARK: - Build RAG Context

    private func buildRAGContext(expenses: [Expense], queryType: QueryType) -> String {
        guard !expenses.isEmpty else {
            return "Aucune dépense trouvée pour cette période."
        }

        var context = ""

        // Statistiques globales
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let avgAmount = total / Double(expenses.count)

        context += "📊 Statistiques:\n"
        context += "- Total: CHF \(String(format: "%.2f", total))\n"
        context += "- Nombre de dépenses: \(expenses.count)\n"
        context += "- Moyenne: CHF \(String(format: "%.2f", avgAmount))\n\n"

        // Par catégorie
        var byCategory: [String: Double] = [:]
        for expense in expenses {
            let cat = expense.category ?? "Other"
            byCategory[cat, default: 0] += expense.amount
        }

        context += "📁 Par catégorie:\n"
        for (category, amount) in byCategory.sorted(by: { $0.value > $1.value }) {
            context += "- \(category): CHF \(String(format: "%.2f", amount))\n"
        }
        context += "\n"

        // Par marchand (top 5)
        var byMerchant: [String: Double] = [:]
        for expense in expenses {
            let merch = expense.merchant ?? "Unknown"
            byMerchant[merch, default: 0] += expense.amount
        }

        context += "🏪 Top marchands:\n"
        for (merchant, amount) in byMerchant.sorted(by: { $0.value > $1.value }).prefix(5) {
            context += "- \(merchant): CHF \(String(format: "%.2f", amount))\n"
        }
        context += "\n"

        // Dernières dépenses (max 10)
        context += "📝 Dernières dépenses:\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        for expense in expenses.prefix(10) {
            let date = formatter.string(from: expense.date ?? Date())
            let merchant = expense.merchant ?? "?"
            let amount = String(format: "%.2f", expense.amount)
            context += "- \(date) \(merchant): CHF \(amount)\n"
        }

        return context
    }

    // MARK: - Build RAG Prompt

    private func buildRAGPrompt(question: String, context: String) -> String {
        return """
        Tu es un assistant pour gérer les dépenses personnelles.
        Réponds de façon concise et utile en français.

        DONNÉES DISPONIBLES:
        \(context)

        QUESTION: \(question)

        RÉPONSE:
        """
    }

    // MARK: - Response Processing

    private func cleanResponse(_ response: String) -> String {
        var cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "RÉPONSE:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Si la réponse est du JSON, extraire le texte
        if cleaned.hasPrefix("{") || cleaned.hasPrefix("[") {
            // C'est du JSON, on le garde tel quel ou on extrait le message
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                cleaned = message
            }
        }

        return cleaned.isEmpty ? "Je n'ai pas pu analyser vos dépenses." : cleaned
    }

    // MARK: - Fallback Answer

    private func generateFallbackAnswer(queryType: QueryType, expenses: [Expense], question: String) -> String {
        guard !expenses.isEmpty else {
            return "Je n'ai trouvé aucune dépense pour cette période."
        }

        let total = expenses.reduce(0.0) { $0 + $1.amount }

        switch queryType {
        case .totalSpending(let period):
            let periodStr: String
            switch period {
            case .today: periodStr = "aujourd'hui"
            case .week: periodStr = "cette semaine"
            case .month: periodStr = "ce mois"
            case .year: periodStr = "cette année"
            case .all: periodStr = "au total"
            }
            return "Vous avez dépensé CHF \(String(format: "%.2f", total)) \(periodStr) (\(expenses.count) transactions)."

        case .categorySpending(let category, let period):
            let cat = category ?? "toutes catégories"
            let periodStr: String
            switch period {
            case .today: periodStr = "aujourd'hui"
            case .week: periodStr = "cette semaine"
            case .month: periodStr = "ce mois"
            case .year: periodStr = "cette année"
            case .all: periodStr = "au total"
            }
            return "Pour \(cat) \(periodStr): CHF \(String(format: "%.2f", total)) (\(expenses.count) dépenses)."

        case .merchantHistory(let merchant):
            let merch = merchant ?? "ce marchand"
            return "Chez \(merch): CHF \(String(format: "%.2f", total)) total (\(expenses.count) visites)."

        case .recentExpenses(let count):
            var response = "Vos \(min(count, expenses.count)) dernières dépenses:\n"
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM"
            for expense in expenses.prefix(count) {
                let date = formatter.string(from: expense.date ?? Date())
                response += "• \(date) - \(expense.merchant ?? "?"): CHF \(String(format: "%.2f", expense.amount))\n"
            }
            return response

        case .comparison(let categories):
            if categories.count >= 2 {
                var response = "Comparaison:\n"
                for category in categories {
                    let catExpenses = expenses.filter { $0.category == category }
                    let catTotal = catExpenses.reduce(0.0) { $0 + $1.amount }
                    response += "• \(category): CHF \(String(format: "%.2f", catTotal))\n"
                }
                return response
            }
            return "Je n'ai pas pu faire cette comparaison."

        case .general:
            return "Vous avez \(expenses.count) dépenses pour un total de CHF \(String(format: "%.2f", total))."
        }
    }

    // MARK: - Predefined Questions

    static let suggestedQuestions = [
        "Combien j'ai dépensé ce mois?",
        "Ma dernière dépense restaurant?",
        "Total des courses cette semaine?",
        "Combien chez Migros?",
        "Compare Restaurant vs Coffee"
    ]
}
