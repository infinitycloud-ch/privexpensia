import SwiftUI
import Combine

// MARK: - Settings View with Glass Toggles
struct SettingsGlassView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var sectionAppear = false
    
    var body: some View {
        ZStack {
            // Background already in MainTabView
            
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Layout.spacing20) {
                    // Header
                    headerSection
                    
                    // Profile Section
                    profileSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 0), value: sectionAppear)
                    
                    // Preferences Section
                    preferencesSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 1), value: sectionAppear)

                    // Cloud Vision Section
                    cloudVisionSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 2), value: sectionAppear)

                    // Chat Assistant Section
                    chatAssistantSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 2), value: sectionAppear)

                    // Privacy Section
                    privacySection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 2), value: sectionAppear)

                    // Document Sync Section
                    documentSyncSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 3), value: sectionAppear)

                    // About Section
                    aboutSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 3), value: sectionAppear)
                    
                    // Footer
                    footerSection
                        .glassAppear(isVisible: sectionAppear)
                        .animation(AnimationManager.chainedAnimation(step: 4), value: sectionAppear)
                }
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            withAnimation(AnimationManager.Glass.cardAppear.delay(0.2)) {
                sectionAppear = true
            }
        }
        .sheet(isPresented: $viewModel.showCurrencyPicker) {
            CurrencyPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLanguagePicker) {
            LanguagePickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showProfileEditor) {
            ProfileEditorView(isPresented: $viewModel.showProfileEditor)
        }
        .sheet(isPresented: $viewModel.showFolderPicker) {
            FolderPickerView(onFolderSelected: { url in
                _ = viewModel.syncService.setSyncFolder(url: url)
                viewModel.showFolderPicker = false
            }, onCancel: {
                viewModel.showFolderPicker = false
            })
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
            Text(LocalizationManager.shared.localized("settings_title"))
                .font(LiquidGlassTheme.Typography.displaySmall)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Text(LocalizationManager.shared.localized("settings_subtitle"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing20)
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                HStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LiquidGlassTheme.Colors.accent,
                                        LiquidGlassTheme.Colors.primary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Text(viewModel.userInitials)
                            .font(LiquidGlassTheme.Typography.title1)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing4) {
                        Text(viewModel.userName)
                            .font(LiquidGlassTheme.Typography.headline)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        
                        Text(viewModel.userEmail)
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                        
                        Text(LocalizationManager.shared.localized("settings.premium_member"))
                            .font(LiquidGlassTheme.Typography.caption2)
                            .foregroundColor(LiquidGlassTheme.Colors.accent)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.editProfile()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    }
                }
                
                Divider()
                    .background(LiquidGlassTheme.Colors.glassBase)
                
                // Stats
                HStack(spacing: LiquidGlassTheme.Layout.spacing32) {
                    StatItem(value: viewModel.totalScans, label: LocalizationManager.shared.localized("settings.scans"))
                    StatItem(value: viewModel.totalAmount, label: LocalizationManager.shared.localized("settings.total"))
                    StatItem(value: viewModel.daysSinceStart, label: viewModel.daysLabel)
                }
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.preferences"), icon: "slider.horizontal.3")
                
                GlassToggleRow(
                    icon: "bell.fill",
                    title: LocalizationManager.shared.localized("settings.notifications"),
                    subtitle: LocalizationManager.shared.localized("notifications_subtitle"),
                    isOn: $viewModel.notificationsEnabled
                )
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                GlassToggleRow(
                    icon: "moon.fill",
                    title: LocalizationManager.shared.localized("settings.dark_mode"),
                    subtitle: LocalizationManager.shared.localized("dark_mode_subtitle"),
                    isOn: $viewModel.darkModeEnabled
                )
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                GlassToggleRow(
                    icon: "faceid",
                    title: LocalizationManager.shared.localized("settings.faceid"),
                    subtitle: LocalizationManager.shared.localized("settings.faceid_subtitle"),
                    isOn: $viewModel.faceIDEnabled
                )

                Divider().background(LiquidGlassTheme.Colors.glassBase)

                SettingsRow(
                    icon: "dollarsign.circle.fill",
                    title: LocalizationManager.shared.localized("settings.currency"),
                    value: viewModel.currency
                ) {
                    viewModel.changeCurrency()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "globe",
                    title: LocalizationManager.shared.localized("settings.language"),
                    value: viewModel.language
                ) {
                    viewModel.changeLanguage()
                }
            }
        }
    }
    
    // MARK: - Cloud Vision Section
    private var cloudVisionSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.cloud_vision.title"), icon: "eye.circle.fill")

                GlassToggleRow(
                    icon: "cloud.fill",
                    title: LocalizationManager.shared.localized("settings.cloud_vision.enable"),
                    subtitle: LocalizationManager.shared.localized("settings.cloud_vision.subtitle"),
                    isOn: $viewModel.cloudVisionEnabled
                )

                if viewModel.cloudVisionEnabled {
                    Divider().background(LiquidGlassTheme.Colors.glassBase)

                    // Provider Selector
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                        Text(LocalizationManager.shared.localized("settings.provider"))
                            .font(LiquidGlassTheme.Typography.caption1)
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                            ForEach(CloudVisionService.VisionProvider.allCases, id: \.self) { provider in
                                ProviderButton(
                                    provider: provider,
                                    isSelected: viewModel.selectedProvider == provider,
                                    action: {
                                        viewModel.selectedProvider = provider
                                        LiquidGlassTheme.Haptics.selection()
                                    }
                                )
                            }
                        }
                    }

                    Divider().background(LiquidGlassTheme.Colors.glassBase)

                    // API Key Input
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                            Text(viewModel.selectedProvider == .openai ? LocalizationManager.shared.localized("settings.api_key_openai") : LocalizationManager.shared.localized("settings.api_key_groq"))
                                .font(LiquidGlassTheme.Typography.body)
                                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                        }

                        SecureField(LocalizationManager.shared.localized("settings.api_key_placeholder"), text: viewModel.selectedProvider == .openai ? $viewModel.openaiAPIKey : $viewModel.groqAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(LiquidGlassTheme.Typography.caption1)

                        if viewModel.isCloudVisionConfigured {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(LiquidGlassTheme.Colors.success)
                                Text(LocalizationManager.shared.localized("settings.api_key_configured"))
                                    .font(LiquidGlassTheme.Typography.caption2)
                                    .foregroundColor(LiquidGlassTheme.Colors.success)
                            }
                        }
                    }

                    Divider().background(LiquidGlassTheme.Colors.glassBase)

                    // Test Button
                    SettingsRow(
                        icon: "play.circle.fill",
                        title: LocalizationManager.shared.localized("settings.cloud_vision.test"),
                        value: viewModel.selectedProvider.displayName
                    ) {
                        viewModel.testCloudVision()
                    }
                }
            }
        }
    }

    // MARK: - Chat Assistant Section
    private var chatAssistantSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.chat_assistant.title"), icon: "bubble.left.and.bubble.right.fill")

                // Provider Selector
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                    Text(LocalizationManager.shared.localized("settings.chat_assistant.provider"))
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                    HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                        // Local Qwen
                        ChatProviderButton(
                            provider: .qwenLocal,
                            isSelected: viewModel.chatProvider == .qwenLocal,
                            action: {
                                viewModel.chatProvider = .qwenLocal
                                LiquidGlassTheme.Haptics.selection()
                            }
                        )

                        // Groq (if API key configured)
                        ChatProviderButton(
                            provider: .groq,
                            isSelected: viewModel.chatProvider == .groq,
                            isAvailable: !viewModel.groqAPIKey.isEmpty,
                            action: {
                                viewModel.chatProvider = .groq
                                LiquidGlassTheme.Haptics.selection()
                            }
                        )
                    }

                    if viewModel.chatProvider == .groq && viewModel.groqAPIKey.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(LiquidGlassTheme.Colors.warning)
                            Text(LocalizationManager.shared.localized("settings.chat_assistant.groq_required"))
                                .font(LiquidGlassTheme.Typography.caption2)
                                .foregroundColor(LiquidGlassTheme.Colors.warning)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Privacy Section
    private var privacySection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.privacy_security"), icon: "lock.fill")
                
                GlassToggleRow(
                    icon: "eye.slash.fill",
                    title: LocalizationManager.shared.localized("settings.private_mode"),
                    subtitle: LocalizationManager.shared.localized("settings.private_mode_subtitle"),
                    isOn: $viewModel.privateModeEnabled
                )
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                GlassToggleRow(
                    icon: "icloud.fill",
                    title: LocalizationManager.shared.localized("settings.icloud_sync"),
                    subtitle: LocalizationManager.shared.localized("settings.icloud_sync_subtitle"),
                    isOn: $viewModel.iCloudSyncEnabled
                )
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "arrow.down.doc.fill",
                    title: LocalizationManager.shared.localized("settings.export_data"),
                    value: ""
                ) {
                    viewModel.exportData()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "trash.fill",
                    title: LocalizationManager.shared.localized("settings.clear_cache"),
                    value: viewModel.cacheSize
                ) {
                    viewModel.clearCache()
                }
            }
        }
    }

    // MARK: - Document Sync Section
    private var documentSyncSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.document_sync"), icon: "folder.fill")

                // Sync folder selection
                SettingsRow(
                    icon: "folder.badge.plus",
                    title: LocalizationManager.shared.localized("settings.sync_folder"),
                    value: viewModel.syncFolderName.isEmpty
                        ? LocalizationManager.shared.localized("settings.sync_folder_none")
                        : viewModel.syncFolderName
                ) {
                    viewModel.showFolderPicker = true
                }

                if viewModel.syncService.hasSyncFolder {
                    Divider().background(LiquidGlassTheme.Colors.glassBase)

                    GlassToggleRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: LocalizationManager.shared.localized("settings.auto_sync"),
                        subtitle: LocalizationManager.shared.localized("settings.auto_sync_subtitle"),
                        isOn: Binding(
                            get: { viewModel.syncService.syncEnabled },
                            set: { viewModel.syncService.toggleSync(enabled: $0) }
                        )
                    )

                    Divider().background(LiquidGlassTheme.Colors.glassBase)

                    GlassToggleRow(
                        icon: "wifi",
                        title: LocalizationManager.shared.localized("settings.wifi_only"),
                        subtitle: LocalizationManager.shared.localized("settings.wifi_only_subtitle"),
                        isOn: Binding(
                            get: { viewModel.syncService.wifiOnlyEnabled },
                            set: { viewModel.syncService.toggleWiFiOnly(enabled: $0) }
                        )
                    )

                    // Pending sync count
                    if viewModel.syncService.pendingCount > 0 {
                        Divider().background(LiquidGlassTheme.Colors.glassBase)

                        HStack {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .foregroundColor(.orange)
                            Text(LocalizationManager.shared.localized("settings.pending_sync"))
                                .font(LiquidGlassTheme.Typography.body)
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(viewModel.syncService.pendingCount)")
                                .font(LiquidGlassTheme.Typography.headline)
                                .foregroundColor(.orange)
                        }
                    }

                    if let lastSync = viewModel.syncService.lastSyncDate {
                        Divider().background(LiquidGlassTheme.Colors.glassBase)

                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                            Text(LocalizationManager.shared.localized("settings.last_sync"))
                                .font(LiquidGlassTheme.Typography.body)
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                            Spacer()
                            Text(formatSyncDate(lastSync))
                                .font(LiquidGlassTheme.Typography.caption1)
                                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                        }
                    }

                    if let error = viewModel.syncService.syncError {
                        Divider().background(LiquidGlassTheme.Colors.glassBase)

                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(LiquidGlassTheme.Typography.caption1)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }

    private func formatSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - About Section
    private var aboutSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                SectionHeader(title: LocalizationManager.shared.localized("settings.about"), icon: "info.circle.fill")
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: LocalizationManager.shared.localized("settings.help_support"),
                    value: ""
                ) {
                    viewModel.showHelp()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "doc.text.fill",
                    title: LocalizationManager.shared.localized("settings.terms_of_service"),
                    value: ""
                ) {
                    viewModel.showTerms()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "hand.raised.fill",
                    title: LocalizationManager.shared.localized("settings.privacy_policy"),
                    value: ""
                ) {
                    viewModel.showPrivacy()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "star.fill",
                    title: LocalizationManager.shared.localized("settings.rate_app"),
                    value: ""
                ) {
                    viewModel.rateApp()
                }
                
                Divider().background(LiquidGlassTheme.Colors.glassBase)
                
                SettingsRow(
                    icon: "info.circle.fill",
                    title: LocalizationManager.shared.localized("settings.credits"),
                    value: ""
                ) {
                    viewModel.showCredits()
                }

            }
        }
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
            Text("PrivExpenses")
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Text("\(LocalizationManager.shared.localized("settings.version")) \(viewModel.appVersion)")
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            
            Text(LocalizationManager.shared.localized("settings.made_with"))
                .font(LiquidGlassTheme.Typography.caption2)
                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            
            Button(action: {
                viewModel.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(LocalizationManager.shared.localized("settings.sign_out"))
                }
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.error)
                .padding(LiquidGlassTheme.Layout.spacing12)
                .frame(maxWidth: .infinity)
                .background(
                    LiquidGlassBackground(
                        cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium,
                        material: LiquidGlassTheme.LiquidGlass.thin,
                        intensity: 0.7
                    )
                )
            }
        }
        .padding(.vertical, LiquidGlassTheme.Layout.spacing32)
    }
}

// MARK: - Currency Picker View
struct CurrencyPickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                List(viewModel.availableCurrencies, id: \.self) { currency in
                    HStack {
                        Text(currency)
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                        Spacer()

                        if currency == viewModel.currency {
                            Image(systemName: "checkmark")
                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                        }
                    }
                    .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
                    .background(Color.white.opacity(0.1)) // Ajout pour visibilité
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectCurrency(currency)
                        dismiss()
                    }
                    .listRowBackground(Color.clear) // Background transparent pour les rows
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(LocalizationManager.shared.localized("settings.select_currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("common.done")) {
                        dismiss()
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                List(viewModel.availableLanguages, id: \.self) { language in
                    HStack {
                        Text(language)
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

                        Spacer()

                        if language == viewModel.language {
                            Image(systemName: "checkmark")
                                .foregroundColor(LiquidGlassTheme.Colors.accent)
                        }
                    }
                    .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
                    .background(Color.white.opacity(0.1)) // Ajout pour visibilité
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectLanguage(language)
                        dismiss()
                    }
                    .listRowBackground(Color.clear) // Background transparent pour les rows
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(LocalizationManager.shared.localized("settings.select_language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationManager.shared.localized("common.done")) {
                        dismiss()
                    }
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(LiquidGlassTheme.Colors.accent)
            
            Text(title)
                .font(LiquidGlassTheme.Typography.headline)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Glass Toggle Row
struct GlassToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            GlassToggle(isOn: $isOn)
        }
    }
}

// MARK: - Glass Toggle
struct GlassToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? LiquidGlassTheme.Colors.accent.opacity(0.3) : LiquidGlassTheme.Colors.glassBase)
                .frame(width: 50, height: 30)
            
            HStack {
                if isOn {
                    Spacer()
                }
                
                Circle()
                    .fill(isOn ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary)
                    .frame(width: 26, height: 26)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                
                if !isOn {
                    Spacer()
                }
            }
            .padding(.horizontal, 2)
            .frame(width: 50)
        }
        .onTapGesture {
            withAnimation(AnimationManager.Springs.horizontalQuick) {
                isOn.toggle()
                LiquidGlassTheme.Haptics.selection()
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.light()
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                    .frame(width: 28)
                
                Text(title)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Spacer()
                
                if !value.isEmpty {
                    Text(value)
                        .font(LiquidGlassTheme.Typography.caption1)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing4) {
            Text(value)
                .font(LiquidGlassTheme.Typography.title2)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)

            Text(label)
                .font(LiquidGlassTheme.Typography.caption2)
                .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Provider Button
struct ProviderButton: View {
    let provider: CloudVisionService.VisionProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: provider == .openai ? "brain.head.profile" : "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary)

                Text(provider.rawValue)
                    .font(LiquidGlassTheme.Typography.caption1)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary)

                Text(provider == .openai ? "Best accuracy" : "Ultra fast")
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }
            .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                    .fill(isSelected ? LiquidGlassTheme.Colors.accent.opacity(0.15) : LiquidGlassTheme.Colors.glassBase.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                    .stroke(isSelected ? LiquidGlassTheme.Colors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Chat Provider Button
struct ChatProviderButton: View {
    let provider: ChatProvider
    let isSelected: Bool
    var isAvailable: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: provider.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? LiquidGlassTheme.Colors.accent : (isAvailable ? LiquidGlassTheme.Colors.textSecondary : LiquidGlassTheme.Colors.textTertiary))

                Text(provider.displayName)
                    .font(LiquidGlassTheme.Typography.caption1)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? LiquidGlassTheme.Colors.accent : (isAvailable ? LiquidGlassTheme.Colors.textSecondary : LiquidGlassTheme.Colors.textTertiary))

                Text(provider.description)
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
            }
            .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                    .fill(isSelected ? LiquidGlassTheme.Colors.accent.opacity(0.15) : LiquidGlassTheme.Colors.glassBase.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                    .stroke(isSelected ? LiquidGlassTheme.Colors.accent : Color.clear, lineWidth: 2)
            )
            .opacity(isAvailable ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAvailable)
    }
}

// MARK: - View Model
class SettingsViewModel: ObservableObject {
    // User profile from UserProfileManager
    var userName: String {
        UserProfileManager.shared.firstName.isEmpty ? "User" : UserProfileManager.shared.firstName
    }

    var userEmail: String {
        // Show preferred currency instead of email
        "\(LocalizationManager.shared.localized("settings.preferred_currency")): \(UserProfileManager.shared.preferredCurrency)"
    }

    var userInitials: String {
        let name = UserProfileManager.shared.firstName
        guard !name.isEmpty else { return "U" }
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? String(name.prefix(1)).uppercased() : initials
    }

    @Published var showProfileEditor = false
    
    @Published var notificationsEnabled: Bool
    @Published var darkModeEnabled: Bool
    @Published var faceIDEnabled: Bool
    @Published var privateModeEnabled: Bool
    @Published var iCloudSyncEnabled: Bool
    
    @Published var currency: String
    @Published var language: String
    @Published var cacheSize = "24 MB"
    @Published var appVersion = "1.0.2"

    @Published var showCurrencyPicker = false
    @Published var showLanguagePicker = false
    @Published var showFolderPicker = false

    // Document Sync
    let syncService = DocumentSyncService.shared

    var syncFolderName: String {
        syncService.syncFolderName
    }

    // Cloud Vision Settings
    @Published var cloudVisionEnabled: Bool {
        didSet {
            CloudVisionService.shared.isEnabled = cloudVisionEnabled
        }
    }
    @Published var openaiAPIKey: String {
        didSet {
            CloudVisionService.shared.openaiAPIKey = openaiAPIKey
        }
    }
    @Published var groqAPIKey: String {
        didSet {
            CloudVisionService.shared.groqAPIKey = groqAPIKey
        }
    }
    @Published var selectedProvider: CloudVisionService.VisionProvider {
        didSet {
            CloudVisionService.shared.selectedProvider = selectedProvider
        }
    }

    // Chat provider for RAG assistant
    @Published var chatProvider: ChatProvider {
        didSet {
            ExpenseRAGService.shared.selectedProvider = chatProvider
        }
    }

    var isCloudVisionConfigured: Bool {
        CloudVisionService.shared.isConfigured
    }
    
    // Real stats from CoreDataManager
    @Published var totalScans = "0"
    @Published var totalAmount = "€0"
    @Published var daysSinceStart = "0"
    
    var daysLabel: String {
        let days = Int(daysSinceStart) ?? 0
        return days == 1 ? "Day" : "Days"
    }
    
    let availableCurrencies = ["EUR", "USD", "GBP", "CHF", "JPY", "CNY", "CAD", "AUD"]
    let availableLanguages = ["English", "Français", "Deutsch", "Italiano", "Español", "日本語", "한국어", "Slovenčina"]
    
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load from UserDefaults with defaults
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.darkModeEnabled = defaults.object(forKey: "darkModeEnabled") as? Bool ?? false
        self.faceIDEnabled = defaults.object(forKey: "faceIDEnabled") as? Bool ?? true
        self.privateModeEnabled = defaults.object(forKey: "privateModeEnabled") as? Bool ?? false
        self.iCloudSyncEnabled = defaults.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

        self.currency = defaults.string(forKey: "selectedCurrency") ?? "CHF"
        self.language = defaults.string(forKey: "selectedLanguage") ?? "English"

        // Cloud Vision settings
        self.cloudVisionEnabled = CloudVisionService.shared.isEnabled
        self.openaiAPIKey = CloudVisionService.shared.openaiAPIKey
        self.groqAPIKey = CloudVisionService.shared.groqAPIKey
        self.selectedProvider = CloudVisionService.shared.selectedProvider

        // Chat provider settings
        self.chatProvider = ExpenseRAGService.shared.selectedProvider

        // Setup observers to save changes
        setupObservers()

        // Load real stats
        updateStats()
    }
    
    private func setupObservers() {
        $notificationsEnabled.sink { [weak self] value in
            self?.defaults.set(value, forKey: "notificationsEnabled")
        }.store(in: &cancellables)
        
        $darkModeEnabled.sink { [weak self] value in
            self?.defaults.set(value, forKey: "darkModeEnabled")
            // Haptic feedback for theme change
            LiquidGlassTheme.Haptics.medium()
            // Notify ThemeManager about the change
            NotificationCenter.default.post(name: .themeChanged, object: value)
            // Force UI refresh with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.forEach { window in
                        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                            window.overrideUserInterfaceStyle = value ? .dark : .light
                        }
                    }
                }
            }
        }.store(in: &cancellables)
        
        $faceIDEnabled.sink { [weak self] value in
            self?.defaults.set(value, forKey: "faceIDEnabled")
        }.store(in: &cancellables)

        $privateModeEnabled.sink { [weak self] value in
            self?.defaults.set(value, forKey: "privateModeEnabled")
        }.store(in: &cancellables)
        
        $iCloudSyncEnabled.sink { [weak self] value in
            self?.defaults.set(value, forKey: "iCloudSyncEnabled")
        }.store(in: &cancellables)
        
        $currency.dropFirst().sink { [weak self] value in
            self?.defaults.set(value, forKey: "selectedCurrency")
            NotificationCenter.default.post(name: .currencyChanged, object: value)
        }.store(in: &cancellables)
        
        $language.dropFirst().sink { [weak self] value in
            self?.defaults.set(value, forKey: "selectedLanguage")
            self?.updateAppLanguage(value)
        }.store(in: &cancellables)
    }
    
    private func updateStats() {
        let expenses = CoreDataManager.shared.fetchExpenses()
        totalScans = "\(expenses.count)"
        
        let total = expenses.reduce(0) { $0 + $1.amount }
        let currencySymbol = getCurrencySymbol(currency)
        totalAmount = "\(currencySymbol)\(String(format: "%.0f", total))"
        
        if let firstExpense = expenses.first {
            let days = Calendar.current.dateComponents([.day], from: firstExpense.date ?? Date(), to: Date()).day ?? 0
            daysSinceStart = "\(max(1, days))"
        }
    }
    
    private func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "CHF "  // Added space
        case "JPY": return "¥"
        case "CNY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        default: return currency + " "
        }
    }
    
    func editProfile() {
        LiquidGlassTheme.Haptics.light()
        showProfileEditor = true
    }
    
    func changeCurrency() {
        LiquidGlassTheme.Haptics.light()
        showCurrencyPicker = true
    }
    
    func changeLanguage() {
        LiquidGlassTheme.Haptics.light()
        showLanguagePicker = true
    }
    
    func selectCurrency(_ newCurrency: String) {
        currency = newCurrency
        showCurrencyPicker = false
        // Mettre à jour le CurrencyManager centralisé
        CurrencyManager.shared.updateCurrency(newCurrency)
        updateStats() // Refresh with new currency
        LiquidGlassTheme.Haptics.success()
    }
    
    func selectLanguage(_ newLanguage: String) {
        language = newLanguage
        showLanguagePicker = false

        // Map language names to codes and update LocalizationManager
        let languageMap = [
            "English": "en",
            "Français": "fr",
            "Deutsch": "de",
            "Italiano": "it",
            "Español": "es",
            "日本語": "ja",
            "한국어": "ko",
            "Slovenčina": "sk"
        ]

        if let code = languageMap[newLanguage] {
            LocalizationManager.shared.currentLanguage = code
            // Post notification pour que l'UI se mette à jour instantanément
            NotificationCenter.default.post(name: .languageDidChange, object: code)
        }

        LiquidGlassTheme.Haptics.success()
    }
    
    private func updateAppLanguage(_ language: String) {
        // Map language names to locale codes
        let languageMap = [
            "English": "en",
            "Français": "fr",
            "Deutsch": "de",
            "Italiano": "it",
            "Español": "es",
            "日本語": "ja",
            "한국어": "ko",
            "Slovenčina": "sk"
        ]
        
        if let localeCode = languageMap[language] {
            UserDefaults.standard.set([localeCode], forKey: "AppleLanguages")
            // Note: App restart required for language change to take effect
        }
    }
    
    func exportData() {
        LiquidGlassTheme.Haptics.success()
    }
    
    func clearCache() {
        LiquidGlassTheme.Haptics.medium()
        cacheSize = "0 MB"
        // Clear image cache
        URLCache.shared.removeAllCachedResponses()
        // Clear any other caches
    }
    
    func showHelp() {
        LiquidGlassTheme.Haptics.light()
    }
    
    func showTerms() {
        LiquidGlassTheme.Haptics.light()
    }
    
    func showPrivacy() {
        LiquidGlassTheme.Haptics.light()
    }
    
    func rateApp() {
        LiquidGlassTheme.Haptics.success()
    }
    
    func showCredits() {
        LiquidGlassTheme.Haptics.light()
    }

    func testCloudVision() {
        LiquidGlassTheme.Haptics.medium()

        // Create a simple test image (white square with text)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200))
        let testImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))

            let text = "TEST RECEIPT\nTOTAL: 42.50 CHF"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            text.draw(at: CGPoint(x: 20, y: 50), withAttributes: attributes)
        }

        CloudVisionService.shared.analyzeReceipt(image: testImage) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let extraction):
                    LiquidGlassTheme.Haptics.success()

                case .failure(let error):
                    LiquidGlassTheme.Haptics.error()
                }
            }
        }
    }

    func signOut() {
        LiquidGlassTheme.Haptics.medium()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let currencyChanged = Notification.Name("currencyChanged")
}

// MARK: - Profile Editor View
struct ProfileEditorView: View {
    @Binding var isPresented: Bool
    @ObservedObject var profileManager = UserProfileManager.shared

    @State private var firstName: String = ""
    @State private var selectedCurrency: String = "CHF"

    private let currencies = ["CHF", "EUR", "USD", "GBP", "JPY", "CAD", "AUD"]

    var body: some View {
        NavigationView {
            ZStack {
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized("profile.first_name"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        TextField("", text: $firstName)
                            .font(.system(size: 20, weight: .medium))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3))
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }

                    // Currency picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizationManager.shared.localized("profile.preferred_currency"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(currencies, id: \.self) { currency in
                                    Button(action: {
                                        selectedCurrency = currency
                                        LiquidGlassTheme.Haptics.light()
                                    }) {
                                        Text(currency)
                                            .font(.system(size: 16, weight: selectedCurrency == currency ? .bold : .medium))
                                            .foregroundColor(selectedCurrency == currency ? .white : LiquidGlassTheme.Colors.textPrimary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedCurrency == currency
                                                          ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                                          : LinearGradient(colors: [LiquidGlassTheme.Colors.glassBase.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle(LocalizationManager.shared.localized("profile.edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationManager.shared.localized("button.cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationManager.shared.localized("button.save")) {
                        saveProfile()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            firstName = profileManager.firstName
            selectedCurrency = profileManager.preferredCurrency
        }
    }

    private func saveProfile() {
        let trimmedName = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        profileManager.updateProfile(firstName: trimmedName, preferredCurrency: selectedCurrency)
        LiquidGlassTheme.Haptics.success()
        isPresented = false
    }
}

// MARK: - Folder Picker View
struct FolderPickerView: UIViewControllerRepresentable {
    let onFolderSelected: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFolderSelected: onFolderSelected, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFolderSelected: (URL) -> Void
        let onCancel: () -> Void

        init(onFolderSelected: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onFolderSelected = onFolderSelected
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onFolderSelected(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
