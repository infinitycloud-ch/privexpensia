import SwiftUI

// MARK: - Sprint 5: Chat Assistant View
// Interface conversationnelle pour questionner les dépenses avec Qwen RAG

struct ChatAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ExpenseRAGService.ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var showSuggestions = true
    @State private var showProviderPicker = false
    @State private var selectedProvider: ChatProvider = ExpenseRAGService.shared.selectedProvider
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Background
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                            // Welcome message if empty
                            if messages.isEmpty {
                                welcomeView
                            }

                            // Suggested questions
                            if showSuggestions && messages.isEmpty {
                                suggestionsView
                            }

                            // Messages
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Loading indicator
                            if isLoading {
                                loadingView
                            }
                        }
                        .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                        .padding(.vertical, LiquidGlassTheme.Layout.spacing12)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input area
                inputView
            }
        }
        .onAppear {
            addWelcomeMessage()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Close button - allows going back
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Assistant IA")
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                // Provider indicator button
                Button(action: { showProviderPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: selectedProvider.icon)
                            .font(.system(size: 10))
                        Text(selectedProvider.displayName)
                            .font(LiquidGlassTheme.Typography.caption2)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }

            Spacer()

            // Clear chat button
            if !messages.isEmpty {
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing12)
        .background(
            LiquidGlassBackground(
                cornerRadius: 0,
                material: LiquidGlassTheme.LiquidGlass.ultraThin,
                intensity: 0.5
            )
        )
        .sheet(isPresented: $showProviderPicker) {
            ProviderPickerSheet(selectedProvider: $selectedProvider)
                .presentationDetents([.height(300)])
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(LiquidGlassTheme.Colors.accent.opacity(0.7))

            Text(LocalizationManager.shared.localized("chat.greeting"))
                .font(LiquidGlassTheme.Typography.title2)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            Text(LocalizationManager.shared.localized("chat.help_prompt"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, LiquidGlassTheme.Layout.spacing40)
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
            Text("Suggestions")
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                .padding(.leading, 4)

            FlowLayout(spacing: 8) {
                ForEach(ExpenseRAGService.suggestedQuestions, id: \.self) { question in
                    SuggestionChip(text: question) {
                        askQuestion(question)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: LiquidGlassTheme.Colors.accent))
                .scaleEffect(0.8)

            Text("Analyse en cours...")
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
        .padding(LiquidGlassTheme.Layout.spacing12)
        .background(
            LiquidGlassBackground(
                cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                material: LiquidGlassTheme.LiquidGlass.thin,
                intensity: 0.5
            )
        )
    }

    // MARK: - Input View

    private var inputView: some View {
        HStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            // Text field
            TextField("Posez votre question...", text: $inputText)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                .padding(LiquidGlassTheme.Layout.spacing12)
                .background(
                    LiquidGlassBackground(
                        cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                        material: LiquidGlassTheme.LiquidGlass.thin,
                        intensity: 0.6
                    )
                )
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            // Send button
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(inputText.isEmpty ? LiquidGlassTheme.Colors.textSecondary : LiquidGlassTheme.Colors.accent)
            }
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing12)
        .background(
            LiquidGlassBackground(
                cornerRadius: 0,
                material: LiquidGlassTheme.LiquidGlass.regular,
                intensity: 0.7
            )
        )
    }

    // MARK: - Actions

    private func addWelcomeMessage() {
        // Already shown in welcomeView
    }

    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        askQuestion(question)
        inputText = ""
    }

    private func askQuestion(_ question: String) {
        // Add user message
        let userMessage = ExpenseRAGService.ChatMessage(
            role: .user,
            content: question,
            timestamp: Date()
        )
        messages.append(userMessage)
        showSuggestions = false

        // Show loading
        isLoading = true
        LiquidGlassTheme.Haptics.light()

        // Ask RAG service
        ExpenseRAGService.shared.askQuestion(question) { result in
            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let answer):
                    let assistantMessage = ExpenseRAGService.ChatMessage(
                        role: .assistant,
                        content: answer,
                        timestamp: Date()
                    )
                    self.messages.append(assistantMessage)
                    LiquidGlassTheme.Haptics.success()

                case .failure(let error):
                    let errorMessage = ExpenseRAGService.ChatMessage(
                        role: .assistant,
                        content: "Désolé, je n'ai pas pu traiter votre demande: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    LiquidGlassTheme.Haptics.error()
                }
            }
        }
    }

    private func clearChat() {
        withAnimation {
            messages.removeAll()
            showSuggestions = true
        }
        LiquidGlassTheme.Haptics.light()
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ExpenseRAGService.ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(message.role == .user ? .white : LiquidGlassTheme.Colors.textPrimary)
                    .padding(LiquidGlassTheme.Layout.spacing12)
                    .background(
                        Group {
                            if message.role == .user {
                                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                                    .fill(LiquidGlassTheme.Colors.accent)
                            } else {
                                LiquidGlassBackground(
                                    cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                                    material: LiquidGlassTheme.LiquidGlass.thin,
                                    intensity: 0.7
                                )
                            }
                        }
                    )

                Text(formatTime(message.timestamp))
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing12)
                .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
                .background(
                    LiquidGlassBackground(
                        cornerRadius: LiquidGlassTheme.Layout.cornerRadiusSmall,
                        material: LiquidGlassTheme.LiquidGlass.ultraThin,
                        intensity: 0.5
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusSmall)
                        .stroke(LiquidGlassTheme.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Flow Layout for Suggestions

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Provider Picker Sheet

struct ProviderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedProvider: ChatProvider

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Choisir le modèle IA")
                        .font(LiquidGlassTheme.Typography.title2)
                        .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        .padding(.top, 8)

                    ForEach(ChatProvider.allCases) { provider in
                        ProviderOptionRow(
                            provider: provider,
                            isSelected: selectedProvider == provider,
                            isAvailable: ExpenseRAGService.shared.isProviderAvailable(provider)
                        ) {
                            if ExpenseRAGService.shared.isProviderAvailable(provider) {
                                selectedProvider = provider
                                ExpenseRAGService.shared.selectedProvider = provider
                                LiquidGlassTheme.Haptics.light()
                                dismiss()
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct ProviderOptionRow: View {
    let provider: ChatProvider
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: provider.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isAvailable ? (isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textPrimary) : LiquidGlassTheme.Colors.textTertiary)
                    .frame(width: 40)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(LiquidGlassTheme.Typography.headline)
                        .foregroundColor(isAvailable ? LiquidGlassTheme.Colors.textPrimary : LiquidGlassTheme.Colors.textTertiary)

                    Text(isAvailable ? provider.description : "API key required")
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(isAvailable ? LiquidGlassTheme.Colors.textSecondary : LiquidGlassTheme.Colors.textTertiary)
                }

                Spacer()

                // Checkmark
                if isSelected && isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
            .padding(16)
            .background(
                LiquidGlassBackground(
                    cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                    material: isSelected ? LiquidGlassTheme.LiquidGlass.regular : LiquidGlassTheme.LiquidGlass.ultraThin,
                    intensity: isSelected ? 0.8 : 0.5
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                    .stroke(isSelected ? LiquidGlassTheme.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.6)
    }
}

// MARK: - Preview

struct ChatAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        ChatAssistantView()
    }
}
