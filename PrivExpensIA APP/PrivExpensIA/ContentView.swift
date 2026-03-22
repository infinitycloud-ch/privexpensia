import SwiftUI
import Foundation
import CoreData

// MARK: - AI Assistant Types (inline - AIAssistantUnified.swift not in Xcode project)
enum AppView: CaseIterable {
    case home, expenses, statistics, settings, scanner, unknown
    var description: String {
        switch self {
        case .home: return "Home"
        case .expenses: return "Expenses"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        case .scanner: return "Scanner"
        case .unknown: return "Unknown"
        }
    }
}

struct AIContext {
    var currentView: AppView = .unknown
    var totalExpenses: Double?
    var monthlyBudget: Double?
    var remainingBudget: Double?
    var expenseCount: Int?
}

// MARK: - Quick AI Manager (Rule-based responses for simple queries)
class QuickAIManager: ObservableObject {
    static let shared = QuickAIManager()
    @Published var isProcessing = false

    private init() {}

    func askQuestion(_ question: String, completion: @escaping (String) -> Void) {
        askQuestion(question, withContext: nil, completion: completion)
    }

    func askQuestion(_ question: String, withContext viewContext: NSManagedObjectContext?, completion: @escaping (String) -> Void) {
        isProcessing = true

        // Simulate LLM processing delay for realistic UX
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.8...1.5)) { [weak self] in
            self?.isProcessing = false

            // Generate conversational response with real data access
            let response = self?.generateConversationalResponse(for: question, withContext: viewContext) ??
                          "Je ne peux pas répondre à cette question pour le moment."
            completion(response)
        }
    }

    private func cleanLLMResponse(_ rawResponse: String) -> String {
        var cleanResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common LLM prefixes and artifacts
        let prefixesToRemove = [
            "Réponse:", "Assistant:", "IA:", "AI:", "Response:",
            "Voici ma réponse:", "Je réponds:", "Bien sûr:",
            "D'accord,", "Alors,", "En fait,"
        ]

        for prefix in prefixesToRemove {
            if cleanResponse.hasPrefix(prefix) {
                cleanResponse = String(cleanResponse.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Remove JSON artifacts if present (from receipt parsing contamination)
        if cleanResponse.contains("{") || cleanResponse.contains("\"currency\"") {
            // This looks like receipt parsing data, fallback to smart response
            return "Je peux vous aider avec vos finances ! Que souhaitez-vous savoir sur votre budget ou vos dépenses ?"
        }

        // Ensure reasonable length for mobile chat
        if cleanResponse.count > 200 {
            let truncated = String(cleanResponse.prefix(180))
            // Guard: ensure lastSpace is a valid index within bounds
            if let lastSpace = truncated.lastIndex(of: " "),
               lastSpace > truncated.startIndex,
               lastSpace < truncated.endIndex {
                cleanResponse = String(truncated[..<lastSpace]) + "..."
            } else {
                cleanResponse = truncated + "..."
            }
        }

        // Ensure the response is not empty
        if cleanResponse.isEmpty || cleanResponse.count < 5 {
            return "Je suis là pour vous aider avec vos finances ! Que puis-je faire pour vous ?"
        }

        return cleanResponse
    }

    private func generateConversationalResponse(for question: String, withContext viewContext: NSManagedObjectContext? = nil) -> String {
        let lowercased = question.lowercased()

        // Advanced conversational patterns with variety

        // Greeting detection with context awareness
        if lowercased.contains("bonjour") || lowercased.contains("salut") || lowercased.contains("hello") || lowercased.contains("hii") || lowercased.contains("hi") {
            let greetings = [
                "Bonjour ! Je suis ravi de vous aider avec vos finances. Que puis-je faire pour vous aujourd'hui ?",
                "Salut ! Votre assistant financier est là. Comment puis-je vous accompagner ?",
                "Hello ! Prêt à optimiser vos finances ensemble ? Que souhaitez-vous savoir ?"
            ]
            return greetings.randomElement() ?? greetings[0]
        }

        // Financial question analysis with natural responses
        if lowercased.contains("quel") || lowercased.contains("quelle") {
            if lowercased.contains("montant") || lowercased.contains("facture") || lowercased.contains("dépense") {
                let responses = [
                    "Pour consulter le montant de vos dépenses, je vous recommande l'onglet Dépenses où tout est organisé chronologiquement. C'est très pratique !",
                    "Vous trouverez tous vos montants dans l'onglet Dépenses. Les dernières transactions apparaissent en haut de la liste !",
                    "L'onglet Dépenses est parfait pour ça ! Toutes vos transactions y sont listées avec les détails complets."
                ]
                return responses.randomElement() ?? responses[0]
            } else if lowercased.contains("budget") {
                return "Votre budget actuel s'affiche sur la page d'accueil en temps réel. Pour le modifier, direction Paramètres > Budget !"
            }
        }

        if lowercased.contains("combien") {
            if lowercased.contains("dépensé") || lowercased.contains("coûté") {
                let responses = [
                    "Pour connaître vos totaux de dépenses, l'onglet Statistiques vous donnera une vue d'ensemble magnifique avec des graphiques !",
                    "Excellente question ! L'onglet Statistiques vous montrera exactement combien vous avez dépensé, avec des analyses détaillées.",
                    "L'onglet Dépenses pour les détails, Statistiques pour la vue globale - vous avez le choix selon vos besoins !"
                ]
                return responses.randomElement() ?? responses[0]
            }
        }

        // Budget-related conversations
        if lowercased.contains("budget") {
            if lowercased.contains("définir") || lowercased.contains("créer") {
                return "C'est une excellente habitude ! Allez dans Paramètres > Budget pour définir vos limites mensuelles. C'est le premier pas vers une gestion financière efficace."
            } else if lowercased.contains("restant") || lowercased.contains("reste") {
                return "Votre budget restant s'affiche en temps réel sur la page d'accueil. Très pratique pour garder le contrôle de vos dépenses !"
            }
        }

        // Expense management with real data
        if lowercased.contains("dépense") || lowercased.contains("transaction") || lowercased.contains("argent") {
            if lowercased.contains("dernière") || lowercased.contains("récent") || lowercased.contains("dernier") {
                if let context = viewContext {
                    return getRecentExpensesInfo(from: context)
                }
                return "Vos dernières transactions apparaissent en haut de l'onglet Dépenses. Vous pouvez voir tous les détails : montant, date, catégorie et lieu !"
            } else if lowercased.contains("total") || lowercased.contains("mois") || lowercased.contains("combien") {
                if let context = viewContext {
                    return getTotalExpensesInfo(from: context)
                }
                return "L'onglet Statistiques vous donne une vue complète de vos dépenses mensuelles avec de superbes graphiques pour analyser vos habitudes !"
            }
        }

        // Scanner help
        if lowercased.contains("scanner") || lowercased.contains("reçu") || lowercased.contains("photo") {
            if lowercased.contains("comment") {
                return "C'est simple ! Appuyez sur l'onglet Scanner, pointez votre appareil photo sur le reçu et l'IA extraira automatiquement toutes les informations. Magique !"
            } else if lowercased.contains("problème") || lowercased.contains("marche pas") {
                return "Pour un scan optimal, assurez-vous que le reçu est bien éclairé et lisible. L'IA fonctionne mieux avec des images nettes et contrastées."
            }
        }

        // App navigation
        if lowercased.contains("aide") || lowercased.contains("help") || lowercased.contains("comment utiliser") {
            return "Je suis là pour vous guider ! PrivExpensIA vous aide à scanner vos reçus, suivre votre budget et analyser vos dépenses. Que voulez-vous explorer en premier ?"
        }

        // Contextual understanding for personal pronouns
        if lowercased.contains("ma") || lowercased.contains("mes") || lowercased.contains("mon") {
            if lowercased.contains("dernière") || lowercased.contains("dernier") {
                return "Pour vos dernières transactions, consultez l'onglet Dépenses - elles sont triées par date. Que cherchez-vous exactement ?"
            } else {
                return "Je peux vous aider avec vos finances personnelles ! Précisez votre question : budget, dépenses, scanner de reçus ?"
            }
        }

        // Default conversational responses with personality
        let defaultResponses = [
            "Interessant ! Pour mieux vous aider, pouvez-vous me préciser si c'est lié au budget, aux dépenses, ou au scanner de reçus ?",
            "Je suis là pour vous accompagner dans la gestion de vos finances. Que souhaitez-vous savoir exactement ?",
            "Bonne question ! Essayez par exemple : 'Comment scanner un reçu ?' ou 'Quel est mon budget restant ?'",
            "Votre assistant financier personnel est à votre écoute ! Posez-moi une question sur le budget, les dépenses ou l'utilisation de l'app."
        ]

        return defaultResponses.randomElement() ?? defaultResponses[0]
    }

    // MARK: - Real Data Access Methods
    private func getRecentExpensesInfo(from context: NSManagedObjectContext) -> String {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        request.fetchLimit = 3

        do {
            let expenses = try context.fetch(request)
            if expenses.isEmpty {
                return "Vous n'avez encore aucune dépense enregistrée. Commencez par scanner un reçu avec l'onglet Scanner !"
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .short

            var response = "Vos dernières dépenses :\n"
            for expense in expenses {
                let amount = CurrencyManager.shared.formatAmount(expense.totalAmount)
                let date = formatter.string(from: expense.date ?? Date())
                let merchant = expense.merchant ?? "Marchand inconnu"
                response += "• \(amount) chez \(merchant) le \(date)\n"
            }

            return response.trimmingCharacters(in: .newlines)
        } catch {
            return "Je ne peux pas accéder à vos dépenses pour le moment. Essayez de consulter l'onglet Dépenses directement."
        }
    }

    private func getTotalExpensesInfo(from context: NSManagedObjectContext) -> String {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()

        // Current month filter
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now

        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfMonth as NSDate, endOfMonth as NSDate)

        do {
            let expenses = try context.fetch(request)
            if expenses.isEmpty {
                return "Vous n'avez aucune dépense ce mois-ci. C'est le moment de scanner vos premiers reçus !"
            }

            let total = expenses.reduce(0) { $0 + $1.totalAmount }
            let totalFormatted = CurrencyManager.shared.formatAmount(total)
            let count = expenses.count

            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let monthName = formatter.string(from: now)

            return "En \(monthName), vous avez dépensé \(totalFormatted) répartis sur \(count) transaction\(count > 1 ? "s" : ""). 📊"
        } catch {
            return "Je ne peux pas calculer vos dépenses pour le moment. Consultez l'onglet Statistiques pour plus de détails."
        }
    }

    // MARK: - Qwen2.5 RAG Integration
    private func askQwenWithExpenseData(question: String, context: NSManagedObjectContext) -> String {

        // 1. Récupérer les données de dépenses pour le RAG
        let expenseData = buildExpenseContext(from: context)

        // 2. Créer le prompt RAG avec les vraies données
        let ragPrompt = createRAGPrompt(question: question, expenseData: expenseData)

        // 3. Appeler Qwen2.5
        let qwenManager = QwenModelManager.shared
        var response = ""

        let semaphore = DispatchSemaphore(value: 0)

        qwenManager.runInference(prompt: ragPrompt) { result in
            switch result {
            case .success(let qwenResponse):
                // Qwen2.5 retourne une réponse conversationnelle
                response = self.cleanQwenResponse(qwenResponse.extractedData)
            case .failure(let error):
                response = self.fallbackWithRealData(question: question, context: context)
            }
            semaphore.signal()
        }

        semaphore.wait()
        return response
    }

    private func askQwenDirectly(question: String) -> String {

        let conversationalPrompt = createDirectConversationalPrompt(question: question)
        let qwenManager = QwenModelManager.shared
        var response = ""

        let semaphore = DispatchSemaphore(value: 0)

        qwenManager.runInference(prompt: conversationalPrompt) { result in
            switch result {
            case .success(let qwenResponse):
                response = self.cleanQwenResponse(qwenResponse.extractedData)
            case .failure(let error):
                response = "Je ne peux pas répondre pour le moment. Essayez de reformuler votre question."
            }
            semaphore.signal()
        }

        semaphore.wait()
        return response
    }

    private func buildExpenseContext(from context: NSManagedObjectContext) -> String {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        request.fetchLimit = 10

        do {
            let expenses = try context.fetch(request)
            var contextData = "Données financières de l'utilisateur:\n"

            for expense in expenses {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                let date = dateFormatter.string(from: expense.date ?? Date())
                let amount = CurrencyManager.shared.formatAmount(expense.totalAmount)
                let merchant = expense.merchant ?? "Inconnu"
                let category = expense.category ?? "Autre"
                contextData += "- \(date): \(amount) chez \(merchant) (catégorie: \(category))\n"
            }

            let total = expenses.reduce(0) { $0 + $1.totalAmount }
            contextData += "\nTotal des dépenses récentes: \(CurrencyManager.shared.formatAmount(total))"
            contextData += "\nNombre de transactions: \(expenses.count)"

            return contextData
        } catch {
            return "Aucune donnée financière disponible."
        }
    }

    private func createRAGPrompt(question: String, expenseData: String) -> String {
        return """
        Tu es un assistant financier intelligent qui aide l'utilisateur avec ses finances personnelles.

        Données de l'utilisateur:
        \(expenseData)

        Question de l'utilisateur: \(question)

        Instructions:
        - Réponds en français de façon conversationnelle et naturelle
        - Utilise les vraies données financières ci-dessus dans ta réponse
        - Sois précis avec les montants et dates réels
        - Garde un ton amical et informatif
        - Limite ta réponse à 2-3 phrases maximum

        Réponse:
        """
    }

    private func createDirectConversationalPrompt(question: String) -> String {
        return """
        Tu es un assistant financier pour l'application PrivExpensIA.

        Question: \(question)

        Instructions:
        - Réponds en français de façon conversationnelle
        - Aide avec les questions sur la gestion financière, budgets, dépenses
        - Sois concis (2-3 phrases maximum)
        - Ton amical et professionnel

        Réponse:
        """
    }

    private func parseQwenConversationalResponse(_ aiData: AIExtractedData) -> String {
        // Le modèle Qwen est configuré pour répondre, pas extraire des données
        // On utilise le merchant comme réponse conversationnelle (hack temporaire)
        let response = aiData.merchant

        if response.isEmpty || response == "Unknown" {
            return "Je ne peux pas répondre à cette question pour le moment."
        }

        // Nettoyer la réponse de Qwen
        return cleanQwenResponse(response)
    }

    private func cleanQwenResponse(_ response: String) -> String {
        var clean = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Supprimer les préfixes typiques de LLM
        let prefixes = ["Réponse:", "Assistant:", "IA:", "Je réponds:", "Voici:"]
        for prefix in prefixes {
            if clean.hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Limiter la longueur pour mobile
        if clean.count > 200 {
            clean = String(clean.prefix(180)) + "..."
        }

        return clean.isEmpty ? "Je ne peux pas répondre à cette question." : clean
    }

    private func fallbackWithRealData(question: String, context: NSManagedObjectContext) -> String {
        let lowercased = question.lowercased()

        if (lowercased.contains("dernière") || lowercased.contains("récent")) &&
           (lowercased.contains("dépense") || lowercased.contains("transaction")) {
            return getRecentExpensesInfo(from: context)
        }

        if (lowercased.contains("total") || lowercased.contains("combien")) &&
           (lowercased.contains("dépense") || lowercased.contains("mois")) {
            return getTotalExpensesInfo(from: context)
        }

        return "Je ne peux pas répondre pour le moment. Reformulez votre question sur vos dépenses ou votre budget."
    }

    private func generateIntelligentResponse(for question: String) -> String {
        let lowercased = question.lowercased()

        // Budget related questions
        if lowercased.contains("budget") || lowercased.contains("limite") {
            if lowercased.contains("définir") || lowercased.contains("créer") || lowercased.contains("établir") {
                return "Allez dans Paramètres > Budget pour définir vos limites mensuelles. C'est l'outil parfait pour contrôler vos dépenses ! 💰"
            } else if lowercased.contains("restant") || lowercased.contains("reste") {
                return "Votre budget restant s'affiche en temps réel sur la page d'accueil. Consultez aussi l'onglet Statistiques pour plus de détails."
            } else {
                return "Je peux vous aider avec votre budget ! Vous pouvez le définir dans les Paramètres et suivre vos dépenses en temps réel."
            }
        }

        // Expense related questions
        else if lowercased.contains("dépense") || lowercased.contains("coût") || lowercased.contains("total") || lowercased.contains("argent") || lowercased.contains("facture") || lowercased.contains("montant") || lowercased.contains("payé") || lowercased.contains("acheté") {
            if lowercased.contains("mois") || lowercased.contains("mensuel") {
                return "L'onglet Statistiques vous montre vos dépenses mensuelles avec des graphiques détaillés. Très pratique pour analyser vos habitudes ! 📊"
            } else if lowercased.contains("dernière") || lowercased.contains("récent") || lowercased.contains("dernier") {
                return "Votre dernière transaction apparaît dans l'onglet Dépenses en haut de la liste. Vous pouvez voir tous les détails : montant, date, catégorie et lieu ! 💳"
            } else if lowercased.contains("facture") && (lowercased.contains("dernière") || lowercased.contains("dernier")) {
                return "Pour voir le montant de votre dernière facture, consultez l'onglet Dépenses - elle sera listée en premier. Vous pouvez aussi scanner de nouvelles factures ! 📄"
            } else if lowercased.contains("combien") {
                return "Pour connaître vos montants de dépenses, allez dans l'onglet Dépenses pour le détail ou Statistiques pour un aperçu global avec graphiques ! 💰"
            } else {
                return "Toutes vos dépenses sont organisées dans l'onglet Dépenses. Vous pouvez les trier par date, montant ou catégorie et voir vos totaux !"
            }
        }

        // Scanner related questions
        else if lowercased.contains("scanner") || lowercased.contains("reçu") || lowercased.contains("photo") || lowercased.contains("camera") {
            if lowercased.contains("comment") || lowercased.contains("utiliser") {
                return "Appuyez sur l'onglet Scanner, pointez votre appareil photo sur le reçu et l'IA extraira automatiquement toutes les infos ! 📸✨"
            } else if lowercased.contains("problème") || lowercased.contains("marche pas") || lowercased.contains("lit pas") {
                return "Assurez-vous que le reçu est bien éclairé et lisible. L'IA fonctionne mieux avec des images nettes et contrastées."
            } else {
                return "Le scanner IA peut lire la plupart des reçus automatiquement. Une vraie magie pour gagner du temps ! ⚡"
            }
        }

        // Navigation and app usage
        else if lowercased.contains("utiliser") || lowercased.contains("app") || lowercased.contains("application") || lowercased.contains("comment") {
            return "PrivExpensIA vous aide à gérer vos finances : scannez vos reçus, suivez votre budget, et analysez vos dépenses. Commencez par définir un budget !"
        }

        // Statistics and reports
        else if lowercased.contains("statistique") || lowercased.contains("graphique") || lowercased.contains("rapport") || lowercased.contains("analyse") {
            return "L'onglet Statistiques offre des graphiques détaillés de vos dépenses par période et catégorie. Parfait pour identifier les tendances ! 📈"
        }

        // Categories
        else if lowercased.contains("catégorie") || lowercased.contains("classification") {
            return "L'IA classe automatiquement vos dépenses (restaurant, transport, etc.). Vous pouvez modifier les catégories dans l'onglet Dépenses."
        }

        // Export and backup
        else if lowercased.contains("export") || lowercased.contains("sauvegarde") || lowercased.contains("pdf") || lowercased.contains("csv") {
            return "Vous pouvez exporter vos données en PDF ou CSV depuis l'onglet Statistiques. Très utile pour votre comptabilité !"
        }

        // General help
        else if lowercased.contains("aide") || lowercased.contains("help") || lowercased.contains("aidez") {
            return "Je suis là pour vous guider ! Demandez-moi comment scanner un reçu, définir un budget, ou analyser vos dépenses. 😊"
        }

        // Questions with "quel/quelle"
        else if lowercased.contains("quel") || lowercased.contains("quelle") {
            if lowercased.contains("montant") || lowercased.contains("facture") || lowercased.contains("dépense") {
                return "Pour connaître le montant de vos dépenses, consultez l'onglet Dépenses qui liste toutes vos transactions par ordre chronologique ! 💵"
            } else if lowercased.contains("budget") {
                return "Votre budget actuel s'affiche sur la page d'accueil. Pour le modifier, allez dans Paramètres > Budget ! 💰"
            } else {
                return "Je peux vous renseigner sur vos finances ! Précisez votre question sur le budget, les dépenses, ou le scanner de reçus."
            }
        }

        // Questions with "combien"
        else if lowercased.contains("combien") {
            if lowercased.contains("dépensé") || lowercased.contains("coûté") || lowercased.contains("payé") {
                return "Vos totaux de dépenses sont disponibles dans l'onglet Statistiques avec des graphiques détaillés, ou dans Dépenses pour le détail ! 📊"
            } else if lowercased.contains("budget") || lowercased.contains("reste") {
                return "Votre budget restant s'affiche en temps réel sur la page d'accueil. Très pratique pour suivre vos finances ! 💳"
            } else {
                return "Je peux vous aider avec vos montants ! Demandez-moi par exemple 'Combien j'ai dépensé ce mois ?' 💰"
            }
        }

        // Greeting responses
        else if lowercased.contains("bonjour") || lowercased.contains("salut") || lowercased.contains("hello") || lowercased.contains("hii") || lowercased.contains("hi") {
            return "Bonjour ! Je suis votre assistant financier. Comment puis-je vous aider à mieux gérer vos dépenses aujourd'hui ? 👋"
        }

        // Default response
        else {
            // Try to give contextual help based on partial matches
            if lowercased.contains("dernière") || lowercased.contains("dernier") {
                return "Pour vos dernières transactions, consultez l'onglet Dépenses - elles sont triées par date ! Que cherchez-vous exactement ? 🔍"
            } else if lowercased.contains("ma") || lowercased.contains("mes") || lowercased.contains("mon") {
                return "Je peux vous aider avec VOS finances ! Demandez-moi par exemple 'Quel est mon budget ?' ou 'Mes dernières dépenses' ! 💼"
            } else {
                let responses = [
                    "Posez-moi une question sur vos finances ! Je peux vous aider avec le budget, les dépenses, ou le scanner de reçus.",
                    "Je suis là pour vous accompagner dans la gestion de vos finances. Que souhaitez-vous savoir ?",
                    "Essayez : 'Comment scanner un reçu ?' ou 'Quel est mon budget ?' Je suis là pour vous aider ! 🤖"
                ]
                return responses.randomElement() ?? responses[0]
            }
        }
    }
}

// Simple Floating AI Assistant
struct FloatingAIAssistant: View {
    @StateObject private var aiManager = QuickAIManager.shared
    @State private var isAnimating = false
    @State private var showingChat = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button(action: {
                    LiquidGlassTheme.Haptics.medium()
                    showingChat = true
                }) {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(LiquidGlassTheme.Colors.accent.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)
                            .overlay {
                                Circle()
                                    .stroke(LiquidGlassTheme.Colors.accent.opacity(0.4), lineWidth: 2)
                            }

                        // AI Head icon
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)

                        // Processing indicator
                        if aiManager.isProcessing {
                            Circle()
                                .stroke(LiquidGlassTheme.Colors.accent, lineWidth: 2)
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }

                // Padding from right edge (above Settings tab)
                .padding(.trailing, 20)
                .padding(.bottom, 90) // Above tab bar
            }
        }
        .sheet(isPresented: $showingChat) {
            // Sprint 5: Utiliser le nouveau ChatAssistantView avec RAG
            ChatAssistantView()
        }
    }
}

// Simple AI Chat View
struct SimpleAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var aiManager = QuickAIManager.shared
    @State private var messageText = ""
    @State private var messages: [SimpleChatMessage] = []

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 40))
                                        .foregroundColor(LiquidGlassTheme.Colors.accent)

                                    Text(LocalizationManager.shared.localized("ai.welcome"))
                                        .font(LiquidGlassTheme.Typography.body)
                                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding()
                            }

                            ForEach(messages) { message in
                                SimpleChatMessageView(message: message)
                            }

                            if aiManager.isProcessing {
                                HStack {
                                    Text(LocalizationManager.shared.localized("ai.thinking"))
                                        .font(LiquidGlassTheme.Typography.caption1)
                                        .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                                        .italic()
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }

                    HStack(spacing: 12) {
                        TextField(LocalizationManager.shared.localized("ai.ask_question"), text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(messageText.isEmpty ? LiquidGlassTheme.Colors.textTertiary : LiquidGlassTheme.Colors.accent)
                        }
                        .disabled(messageText.isEmpty || aiManager.isProcessing)
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("ai.assistant_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("button.done")) { dismiss() }
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = SimpleChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)
        let question = messageText
        messageText = ""

        aiManager.askQuestion(question, withContext: viewContext) { response in
            DispatchQueue.main.async {
                let aiMessage = SimpleChatMessage(content: response, isUser: false)
                messages.append(aiMessage)
            }
        }
    }
}

struct SimpleChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

struct SimpleChatMessageView: View {
    let message: SimpleChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.content)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.isUser ? LiquidGlassTheme.Colors.accent.opacity(0.1) : LiquidGlassTheme.Colors.glassBase)
                )

            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Main Content View with Glass Tab Bar
struct ContentView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedTab = UITestConfig.initialSelectedTab()
    @State private var showingSplash = false  // Splash disabled - direct to main view
    @State private var viewRefreshID = UUID()
    // 4 tabs: Home, Expenses, Stats, Settings (Scan removed)
    @State private var notificationBadges = [
        0: 0,  // Home
        1: 3,  // Expenses (3 new)
        2: 1,  // Statistics (1 update)
        3: 0   // Settings
    ]
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(AnimationManager.Glass.fadeIn) {
                                showingSplash = false
                            }
                        }
                    }
            } else {
                let currentLocale = Locale(identifier: localizationManager.currentLanguage)

                MainTabView(selectedTab: $selectedTab, notificationBadges: $notificationBadges)
                    .environment(\.locale, currentLocale)
                    .id(viewRefreshID)
                    .onAppear {
                        // One-time cleanup of test data from previous versions
                        CoreDataManager.shared.cleanupTestDataIfNeeded()
                        // Remove duplicate documents from failed sync imports
                        CoreDataManager.shared.removeDuplicateDocuments()
                        // Router UI Tests: forcer l'onglet après apparition si demandé
                        if let forcedTab = UITestConfig.forcedTabIndex() {
                            selectedTab = forcedTab
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                        // Forcer la reconstruction de toute la hiérarchie des vues
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewRefreshID = UUID()
                        }
                    }

                // AI Assistant (Global overlay)
                if !showingSplash {
                    FloatingAIAssistant()
                }
            }
        }
    }
}

// MARK: - UI Test Router via Launch Arguments
enum UITestConfig {
    // Arguments supportés:
    // -UITEST_SKIP_SPLASH
    // -UITEST_SELECTED_TAB <index|settings|home|expenses|scan|statistics>
    static func shouldSkipSplash() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITEST_SKIP_SPLASH")
    }

    static func forcedTabIndex() -> Int? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-UITEST_SELECTED_TAB"), i + 1 < args.count {
            let value = args[i + 1].lowercased()
            if let idx = Int(value) { return clampTabIndex(idx) }
            // 4 tabs: Home(0), Expenses(1), Stats(2), Settings(3) - Scan removed
            switch value {
            case "home": return 0
            case "expenses": return 1
            case "statistics", "stats": return 2
            case "settings": return 3
            default: break
            }
        }
        return nil
    }

    static func initialSelectedTab() -> Int {
        forcedTabIndex() ?? 0
    }

    private static func clampTabIndex(_ idx: Int) -> Int {
        max(0, min(3, idx))  // 4 tabs (0-3)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: Int
    @Binding var notificationBadges: [Int: Int]

    var body: some View {
        ZStack {
            // Background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            // Tab Content - 5 tabs (Documents added Sprint 13)
            Group {
                switch selectedTab {
                case 0:
                    HomeGlassView(selectedTab: $selectedTab)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    ExpenseListGlassView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 2:
                    StatisticsGlassView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 3:
                    DocumentBrowserView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 4:
                    SettingsGlassView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }
            }
            .animation(AnimationManager.Glass.tabSwitch, value: selectedTab)
            
            // Glass Tab Bar at bottom
            VStack {
                Spacer()
                GlassTabBarMain(
                    selectedTab: $selectedTab,
                    notificationBadges: notificationBadges
                )
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                .padding(.bottom, LiquidGlassTheme.Layout.spacing8)
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear badge when tab is selected
            if notificationBadges[newValue] ?? 0 > 0 {
                withAnimation(LiquidGlassTheme.Animations.liquidFlow.delay(0.5)) {
                    notificationBadges[newValue] = 0
                }
            }

            // Track tab change - 5 tabs (Documents added Sprint 13)
            let tabNames = ["home", "expenses", "statistics", "documents", "settings"]
            if newValue < tabNames.count {
                AnalyticsManager.shared.trackEvent(.screenView(tabNames[newValue]))
            }
        }
    }
}

// MARK: - Glass Tab Bar Main
struct GlassTabBarMain: View {
    @Binding var selectedTab: Int
    let notificationBadges: [Int: Int]
    
    @Namespace private var tabAnimation
    
    // 5 tabs - Documents tab added (Sprint 13)
    private let tabs: [(icon: String, selectedIcon: String, title: String)] = [
        ("house", "house.fill", "Home"),
        ("doc.text", "doc.text.fill", "Expenses"),
        ("chart.line.uptrend.xyaxis", "chart.line.uptrend.xyaxis", "Stats"),
        ("archivebox", "archivebox.fill", "Documents"),
        ("gearshape", "gearshape.fill", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                GlassTabItemMain(
                    icon: selectedTab == index ? tabs[index].selectedIcon : tabs[index].icon,
                    title: tabs[index].title,
                    isSelected: selectedTab == index,
                    badgeCount: notificationBadges[index] ?? 0,
                    namespace: tabAnimation,
                    action: {
                        if index != selectedTab {
                            withAnimation(AnimationManager.Springs.horizontalSmooth) {
                                selectedTab = index
                                LiquidGlassTheme.Haptics.selection()
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, LiquidGlassTheme.Layout.spacing12)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
        .background(
            // Layered glass effect for visible blur
            ZStack {
                // Base blur material
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                    .fill(.ultraThinMaterial)

                // White tint overlay for liquid glass look
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                    .fill(Color.white.opacity(0.15))

                // Subtle gradient for depth
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 24,
            x: 0,
            y: 12
        )
    }
}

// MARK: - Glass Tab Item Main
struct GlassTabItemMain: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) { // Spacing réduit car plus de texte
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(
                            isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                    
                    // Notification badge
                    if badgeCount > 0 {
                        NotificationBadge(count: badgeCount)
                            .offset(x: 12, y: -8)
                    }
                }
                .frame(height: 28)
                
                // Text supprimé - Icônes seules selon demande NESTOR
                // Text(title)
                //     .font(LiquidGlassTheme.Typography.caption2)
                //     .fontWeight(isSelected ? .medium : .regular)
                //     .foregroundColor(
                //         isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textTertiary
                //     )
            }
            .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LiquidGlassTheme.Colors.glassBase)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(AnimationManager.Gestures.tapFeedback) {
                                isPressed = pressing
                            }
                          },
                          perform: {})
    }
}

// MARK: - Notification Badge
struct NotificationBadge: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LiquidGlassTheme.Colors.error)
                .frame(width: 18, height: 18)
            
            Text("\(min(count, 99))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Splash Screen
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: LiquidGlassTheme.Layout.spacing24) {
                Image(systemName: "doc.text.image.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                LiquidGlassTheme.Colors.accent,
                                LiquidGlassTheme.Colors.primary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text(LocalizationManager.shared.localized("app_name"))
                    .font(LiquidGlassTheme.Typography.displayLarge)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .opacity(logoOpacity)
                
                Text(LocalizationManager.shared.localized("app_tagline"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .opacity(logoOpacity * 0.8)
            }
        }
        .onAppear {
            withAnimation(AnimationManager.Springs.scale.delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

// MARK: - Notifications extension removed - defined in LocalizationManager

#Preview {
    ContentView()
}
