import SwiftUI
import Foundation
import CoreData

// MARK: - Unified AI Assistant Implementation
// All AI assistant functionality in one file to avoid scope issues

// MARK: - AI Context Types
enum AppView: CaseIterable {
    case home
    case expenses
    case statistics
    case settings
    case scanner
    case unknown

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
    var recentExpenses: [ExpenseSummary]?
}

struct ExpenseSummary {
    let merchant: String
    let amount: Double
    let category: String
    let date: Date
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - AI Context Manager
class AIContextManager: ObservableObject {
    static let shared = AIContextManager()

    @Published var currentContext = AIContext()

    private init() {}

    func setCurrentView(_ view: AppView) {
        currentContext.currentView = view
        updateContext()
    }

    func updateContext() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let context = self?.buildCurrentContext() ?? AIContext()

            DispatchQueue.main.async {
                self?.currentContext = context
            }
        }
    }

    private func buildCurrentContext() -> AIContext {
        var context = currentContext

        let coreDataManager = CoreDataManager.shared
        let viewContext = coreDataManager.persistentContainer.viewContext

        do {
            let expenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            expenseRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
            expenseRequest.fetchLimit = 10

            let expenses = try viewContext.fetch(expenseRequest)

            context.recentExpenses = expenses.map { expense in
                ExpenseSummary(
                    merchant: expense.merchant ?? "Unknown",
                    amount: expense.totalAmount,
                    category: expense.category ?? "Other",
                    date: expense.date ?? Date()
                )
            }

            context.expenseCount = expenses.count
            context.totalExpenses = expenses.reduce(0) { $0 + $1.totalAmount }

            let budgetManager = SimpleBudgetManager.shared
            context.monthlyBudget = budgetManager.monthlyBudget
            context.remainingBudget = budgetManager.remainingBudget

        } catch {
        }

        return context
    }

    var currentContextDescription: String {
        switch currentContext.currentView {
        case .home:
            return LocalizationManager.shared.localized("ai.context.home")
        case .expenses:
            return LocalizationManager.shared.localized("ai.context.expenses")
        case .statistics:
            return LocalizationManager.shared.localized("ai.context.statistics")
        case .settings:
            return LocalizationManager.shared.localized("ai.context.settings")
        case .scanner:
            return LocalizationManager.shared.localized("ai.context.scanner")
        case .unknown:
            return LocalizationManager.shared.localized("menu.home")
        }
    }
}

// MARK: - AI Assistant Manager
class AIAssistantManager: ObservableObject {
    static let shared = AIAssistantManager()

    @Published var isProcessing = false
    @Published var lastResponse = ""

    private let qwenManager = QwenModelManager.shared

    private init() {}

    func askQuestion(_ question: String, context: AIContext, completion: @escaping (String) -> Void) {
        guard !isProcessing else { return }

        DispatchQueue.main.async {
            self.isProcessing = true
        }

        // Create conversational prompt
        let conversationalPrompt = createConversationalPrompt(question: question, context: context)

        qwenManager.runInference(prompt: conversationalPrompt) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false

                switch result {
                case .success(let qwenResponse):
                    let answer = self?.parseConversationalResponse(qwenResponse.extractedData) ??
                                "Je n'ai pas pu traiter votre question. Pouvez-vous la reformuler ?"
                    self?.lastResponse = answer
                    completion(answer)

                case .failure:
                    let fallbackAnswer = self?.generateFallbackAnswer(for: question, context: context) ??
                                        "Désolé, je rencontre un problème technique. Essayez plus tard."
                    completion(fallbackAnswer)
                }
            }
        }
    }

    private func createConversationalPrompt(question: String, context: AIContext) -> String {
        let systemPrompt = """
        Tu es un assistant IA spécialisé dans la gestion financière personnelle. Tu aides les utilisateurs avec l'application PrivExpensIA.

        Instructions importantes:
        - Réponds TOUJOURS en français
        - Sois concis mais informatif (2-3 phrases max)
        - Utilise les données du contexte quand c'est pertinent
        - Si tu ne sais pas, propose une alternative utile
        - Sois amical et encourageant
        """

        let contextInfo = formatContextForPrompt(context)

        return """
        \(systemPrompt)

        CONTEXTE ACTUEL:
        \(contextInfo)

        QUESTION UTILISATEUR: \(question)

        Réponds de manière conversationnelle en français:
        """
    }

    private func formatContextForPrompt(_ context: AIContext) -> String {
        var contextLines: [String] = []

        contextLines.append("- Vue actuelle: \(context.currentView.description)")

        if let totalExpenses = context.totalExpenses {
            contextLines.append("- Total des dépenses: \(String(format: "%.2f", totalExpenses))€")
        }

        if let monthlyBudget = context.monthlyBudget {
            contextLines.append("- Budget mensuel: \(String(format: "%.2f", monthlyBudget))€")
        }

        if let remainingBudget = context.remainingBudget {
            let status = remainingBudget > 0 ? "reste" : "dépassé de"
            contextLines.append("- Budget \(status): \(String(format: "%.2f", abs(remainingBudget)))€")
        }

        if let recentExpenses = context.recentExpenses, !recentExpenses.isEmpty {
            let recent = recentExpenses.prefix(3).map { "\($0.merchant): \(String(format: "%.2f", $0.amount))€" }
            contextLines.append("- Dépenses récentes: \(recent.joined(separator: ", "))")
        }

        return contextLines.isEmpty ? "Aucune donnée disponible" : contextLines.joined(separator: "\n")
    }

    private func parseConversationalResponse(_ rawResponse: String) -> String {
        var cleanResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleanResponse.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = json["response"] as? String ?? json["answer"] as? String {
            cleanResponse = response
        }

        let prefixesToRemove = ["Réponse:", "Assistant:", "IA:", "AI:", "Response:"]

        for prefix in prefixesToRemove {
            if cleanResponse.hasPrefix(prefix) {
                cleanResponse = String(cleanResponse.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if cleanResponse.isEmpty || cleanResponse.count < 10 {
            return "Je n'ai pas pu générer une réponse appropriée. Pouvez-vous reformuler votre question ?"
        }

        if cleanResponse.count > 300 {
            let truncated = String(cleanResponse.prefix(280))
            if let lastSpace = truncated.lastIndex(of: " ") {
                cleanResponse = String(truncated[..<lastSpace]) + "..."
            } else {
                cleanResponse = truncated + "..."
            }
        }

        return cleanResponse
    }

    private func generateFallbackAnswer(for question: String, context: AIContext) -> String {
        let lowercased = question.lowercased()

        if lowercased.contains("budget") {
            if let budget = context.monthlyBudget, let remaining = context.remainingBudget {
                if remaining > 0 {
                    return "Votre budget mensuel est de \(String(format: "%.0f", budget))€. Il vous reste \(String(format: "%.0f", remaining))€ ce mois-ci. 👍"
                } else {
                    return "Votre budget mensuel est de \(String(format: "%.0f", budget))€. Vous avez dépassé de \(String(format: "%.0f", abs(remaining)))€. Essayez de réduire vos dépenses."
                }
            } else {
                return "Vous n'avez pas encore défini de budget. Allez dans Paramètres pour configurer votre budget mensuel."
            }
        }

        if lowercased.contains("dépense") && (lowercased.contains("combien") || lowercased.contains("total")) {
            if let total = context.totalExpenses {
                return "Vous avez dépensé \(String(format: "%.2f", total))€ au total. Consultez les Statistiques pour plus de détails."
            } else {
                return "Vous n'avez pas encore de dépenses enregistrées. Utilisez le scanner pour ajouter vos premiers reçus !"
            }
        }

        if lowercased.contains("scanner") || lowercased.contains("reçu") || lowercased.contains("comment ajouter") {
            return "Pour ajouter une dépense, utilisez l'onglet Scanner et photographiez votre reçu. L'IA extraira automatiquement les informations ! 📸"
        }

        switch context.currentView {
        case .home:
            return "Sur l'accueil, vous voyez vos dépenses du jour et votre budget. Utilisez les onglets pour naviguer dans l'app."
        case .expenses:
            return "Ici vous pouvez voir toutes vos dépenses, les organiser par catégorie et générer des rapports."
        case .statistics:
            return "Les statistiques vous montrent vos tendances de dépenses avec des graphiques détaillés."
        case .settings:
            return "Dans les paramètres, configurez votre budget, devise et préférences de l'application."
        case .scanner:
            return "Le scanner vous permet de capturer vos reçus. L'IA extrait automatiquement les informations importantes."
        case .unknown:
            return "Je peux vous aider avec vos questions sur l'app. Essayez de me demander quelque chose de spécifique !"
        }
    }
}

// MARK: - Floating AI Assistant
struct FloatingAIAssistant: View {
    @StateObject private var aiManager = AIAssistantManager.shared
    @State private var dragOffset = CGSize.zero
    @State private var isAnimating = false
    @State private var showingChat = false

    @AppStorage("ai_assistant_position_x") private var savedX: Double = 300
    @AppStorage("ai_assistant_position_y") private var savedY: Double = 100

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                aiButton
                    .position(
                        x: savedX + dragOffset.width,
                        y: savedY + dragOffset.height
                    )
                    .gesture(dragGesture)
                    .onAppear {
                        startBreathingAnimation()
                    }
            }
        }
        .sheet(isPresented: $showingChat) {
            AIAssistantChatView()
        }
    }

    private var aiButton: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.medium()
            showingChat = true
        }) {
            ZStack {
                Circle()
                    .fill(
                        LiquidGlassBackground(
                            cornerRadius: 30,
                            material: LiquidGlassTheme.LiquidGlass.thick,
                            intensity: 1.0
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 0.8 : 1.0)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)

                if aiManager.isProcessing {
                    Circle()
                        .stroke(LiquidGlassTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(
            color: LiquidGlassTheme.Colors.accent.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
        )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                savedX += value.translation.width
                savedY += value.translation.height

                savedX = max(50, min(UIScreen.main.bounds.width - 50, savedX))
                savedY = max(100, min(UIScreen.main.bounds.height - 150, savedY))

                withAnimation(.spring()) {
                    dragOffset = .zero
                }

                LiquidGlassTheme.Haptics.light()
            }
    }

    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            isAnimating = true
        }
    }
}

// MARK: - AI Assistant Chat View
struct AIAssistantChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiManager = AIAssistantManager.shared
    @StateObject private var contextManager = AIContextManager.shared
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    contextBanner
                    chatMessagesView
                    chatInputView
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("ai.assistant_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("button_done")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadChatHistory()
            contextManager.updateContext()
        }
    }

    private var contextBanner: some View {
        HStack {
            Image(systemName: "location.circle.fill")
                .foregroundColor(LiquidGlassTheme.Colors.accent)

            Text(contextManager.currentContextDescription)
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

            Spacer()
        }
        .padding()
        .background(
            LiquidGlassBackground(
                cornerRadius: 0,
                material: LiquidGlassTheme.LiquidGlass.ultraThin,
                intensity: 0.5
            )
        )
    }

    private var chatMessagesView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if messages.isEmpty {
                    welcomeMessageView
                }

                ForEach(messages) { message in
                    ChatMessageView(message: message)
                }

                if aiManager.isProcessing {
                    typingIndicatorView
                }
            }
            .padding()
        }
    }

    private var welcomeMessageView: some View {
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
        .background(
            LiquidGlassBackground(
                cornerRadius: 16,
                material: LiquidGlassTheme.LiquidGlass.ultraThin,
                intensity: 0.5
            )
        )
    }

    private var chatInputView: some View {
        HStack(spacing: 12) {
            TextField(LocalizationManager.shared.localized("ai.ask_question"), text: $messageText)
                .textFieldStyle(LiquidGlassTextFieldStyle())

            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(messageText.isEmpty ? LiquidGlassTheme.Colors.textTertiary : LiquidGlassTheme.Colors.accent)
            }
            .disabled(messageText.isEmpty || aiManager.isProcessing)
        }
        .padding()
        .background(
            LiquidGlassBackground(
                cornerRadius: 0,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.8
            )
        )
    }

    private var typingIndicatorView: some View {
        HStack {
            Text(LocalizationManager.shared.localized("ai.thinking"))
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                .italic()

            Spacer()
        }
        .padding()
        .background(
            LiquidGlassBackground(
                cornerRadius: 16,
                material: LiquidGlassTheme.LiquidGlass.ultraThin,
                intensity: 0.5
            )
        )
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = ChatMessage(
            id: UUID(),
            content: messageText,
            isUser: true,
            timestamp: Date()
        )

        messages.append(userMessage)
        let question = messageText
        messageText = ""

        aiManager.askQuestion(question, context: contextManager.currentContext) { response in
            DispatchQueue.main.async {
                let aiMessage = ChatMessage(
                    id: UUID(),
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(aiMessage)
                saveChatHistory()
            }
        }
    }

    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "chat_history"),
           let savedMessages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = savedMessages
        }
    }

    private func saveChatHistory() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "chat_history")
        }
    }
}

// MARK: - Chat Message View
struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .padding()
                    .background(
                        LiquidGlassBackground(
                            cornerRadius: 16,
                            material: message.isUser ? LiquidGlassTheme.LiquidGlass.regular : LiquidGlassTheme.LiquidGlass.thick,
                            intensity: message.isUser ? 0.8 : 1.0
                        )
                    )

                Text(formatTime(message.timestamp))
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }

            if !message.isUser {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Text Field Style
struct LiquidGlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                LiquidGlassBackground(
                    cornerRadius: 20,
                    material: LiquidGlassTheme.LiquidGlass.regular,
                    intensity: 0.8
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LiquidGlassTheme.Colors.accent.opacity(0.3), lineWidth: 1)
            )
    }
}