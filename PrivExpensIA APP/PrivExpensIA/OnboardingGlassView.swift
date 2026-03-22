import SwiftUI

// MARK: - Onboarding Flow with Glass Effects
struct OnboardingGlassView: View {
    @State private var currentPage = 0
    @State private var showMainApp = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "doc.text.image.fill",
                title: LocalizationManager.shared.localized("onboarding.scanning.title"),
                description: LocalizationManager.shared.localized("onboarding.scanning.description"),
                gradientColors: [LiquidGlassTheme.Colors.accent, LiquidGlassTheme.Colors.primary]
            ),
            OnboardingPage(
                icon: "sparkles",
                title: LocalizationManager.shared.localized("onboarding.ai.title"),
                description: LocalizationManager.shared.localized("onboarding.ai.description"),
                gradientColors: [LiquidGlassTheme.Colors.primary, Color.purple]
            ),
            OnboardingPage(
                icon: "chart.pie.fill",
                title: LocalizationManager.shared.localized("onboarding.budget.title"),
                description: LocalizationManager.shared.localized("onboarding.budget.description"),
                gradientColors: [Color.orange, Color.pink]
            ),
            OnboardingPage(
                icon: "square.and.arrow.up.fill",
                title: LocalizationManager.shared.localized("onboarding.export.title"),
                description: LocalizationManager.shared.localized("onboarding.export.description"),
                gradientColors: [Color.blue, Color.cyan]
            ),
            OnboardingPage(
                icon: "lock.shield.fill",
                title: LocalizationManager.shared.localized("onboarding.privacy.title"),
                description: LocalizationManager.shared.localized("onboarding.privacy.description"),
                gradientColors: [Color.green, LiquidGlassTheme.Colors.success]
            )
        ]
    }
    
    var body: some View {
        if showMainApp || hasCompletedOnboarding {
            ContentView()
        } else {
            ZStack {
                // Background
                LiquidGlassTheme.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                // Mesh gradient orbs
                meshGradientBackground
                
                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button(LocalizationManager.shared.localized("button_skip")) {
                            completeOnboarding()
                        }
                        .font(LiquidGlassTheme.Typography.body)
                        .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                        .padding()
                    }
                    
                    // Page Content
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Custom Page Indicator
                    pageIndicator
                        .padding(.bottom, LiquidGlassTheme.Layout.spacing20)
                    
                    // Action Button
                    actionButton
                        .padding(.horizontal, LiquidGlassTheme.Layout.spacing32)
                        .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
                }
            }
        }
    }
    
    // MARK: - Mesh Gradient Background
    private var meshGradientBackground: some View {
        GeometryReader { geometry in
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                pages[currentPage].gradientColors[index % 2].opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: CGFloat.random(in: -100...geometry.size.width),
                        y: CGFloat.random(in: -100...geometry.size.height)
                    )
                    .blur(radius: 80)
                    .animation(
                        Animation.easeInOut(duration: 3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.5),
                        value: currentPage
                    )
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage ?
                        LiquidGlassTheme.Colors.accent :
                        LiquidGlassTheme.Colors.glassBase
                    )
                    .frame(
                        width: index == currentPage ? 28 : 8,
                        height: 8
                    )
                    .animation(AnimationManager.Springs.horizontalSmooth, value: currentPage)
            }
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            if currentPage < pages.count - 1 {
                withAnimation(AnimationManager.Springs.horizontalSmooth) {
                    currentPage += 1
                    LiquidGlassTheme.Haptics.light()
                }
            } else {
                completeOnboarding()
            }
        }) {
            HStack {
                Text(currentPage < pages.count - 1 ? LocalizationManager.shared.localized("button_next") : LocalizationManager.shared.localized("get_started"))
                    .font(LiquidGlassTheme.Typography.headline)
                
                Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(LiquidGlassTheme.Layout.spacing16)
            .background(
                LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusCircle, material: LiquidGlassTheme.LiquidGlass.thin)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: LiquidGlassTheme.Colors.primary.opacity(0.3),
                radius: 16,
                x: 0,
                y: 8
            )
        }
    }
    
    // MARK: - Complete Onboarding
    private func completeOnboarding() {
        withAnimation(AnimationManager.Glass.fadeIn) {
            hasCompletedOnboarding = true
            showMainApp = true
            LiquidGlassTheme.Haptics.success()
        }
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var iconScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing32) {
            Spacer()
            
            // Icon with Glass Effect
            ZStack {
                // Glass background
                Circle()
                    .fill(LiquidGlassTheme.Colors.glassBase)
                    .background(.ultraThinMaterial)
                    .frame(width: 180, height: 180)
                    .blur(radius: 1)
                    .shadow(
                        color: page.gradientColors[0].opacity(0.3),
                        radius: 30,
                        x: 0,
                        y: 15
                    )
                
                // Gradient overlay
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.gradientColors[0].opacity(0.2),
                                page.gradientColors[1].opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                
                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
            }
            .padding(.bottom, LiquidGlassTheme.Layout.spacing20)
            
            // Text Content
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(page.title)
                    .font(LiquidGlassTheme.Typography.displaySmall)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LiquidGlassTheme.Layout.spacing32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentOpacity)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(AnimationManager.Springs.scale.delay(0.1)) {
                iconScale = 1.0
            }
            withAnimation(AnimationManager.Glass.fadeIn.delay(0.3)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
}

// MARK: - Permission Request View
struct PermissionRequestView: View {
    @Binding var isPresented: Bool
    let onAllow: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: LiquidGlassTheme.Layout.spacing24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LiquidGlassTheme.Colors.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                }
                
                // Title
                Text(LocalizationManager.shared.localized("camera_access_title"))
                    .font(LiquidGlassTheme.Typography.title1)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                // Description
                Text(LocalizationManager.shared.localized("camera_access_description"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                // Buttons
                VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
                    GlassButton(LocalizationManager.shared.localized("allow_camera_access"), icon: "checkmark") {
                        onAllow()
                        isPresented = false
                    }
                    
                    Button(LocalizationManager.shared.localized("not_now")) {
                        isPresented = false
                    }
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                }
            }
            .padding(LiquidGlassTheme.Layout.spacing32)
            .background(
                LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge, material: LiquidGlassTheme.LiquidGlass.regular)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.3),
                radius: 30,
                x: 0,
                y: 15
            )
            .padding(LiquidGlassTheme.Layout.spacing32)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0)
            .animation(AnimationManager.Springs.scale, value: isPresented)
        }
    }
}

// MARK: - Success Animation View
struct SuccessAnimationView: View {
    @State private var checkmarkScale: CGFloat = 0
    @State private var circleScale: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Success circle
            Circle()
                .stroke(LiquidGlassTheme.Colors.success, lineWidth: 3)
                .frame(width: 100, height: 100)
                .scaleEffect(circleScale)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(LiquidGlassTheme.Colors.success)
                .scaleEffect(checkmarkScale)
        }
        .onAppear {
            withAnimation(AnimationManager.Springs.scale) {
                circleScale = 1.0
            }
            withAnimation(AnimationManager.Springs.scale.delay(0.2)) {
                checkmarkScale = 1.0
            }
            LiquidGlassTheme.Haptics.success()
        }
    }
}

#Preview {
    OnboardingGlassView()
}