import SwiftUI

@main
struct PrivExpensIAApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    let persistenceController = CoreDataManager.shared

    init() {
        // Debug: Check bundle languages
        
        // Initialize localization first
        let _ = LocalizationManager.shared

        // Reconfigure after app is ready (to catch launch arguments)
        DispatchQueue.main.async {
            LocalizationManager.shared.configure()
        }

        // Initialize theme manager
        let _ = ThemeManager.shared
        
        // Initialize core managers safely
        DispatchQueue.main.async {
            // Start performance monitoring after launch
            PerformanceOptimizer.shared.startMonitoring()

            // Clear AI cache at startup to avoid stale results
            QwenModelManager.shared.resetPerformance()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if profileManager.hasProfile {
                    ContentView()
                } else {
                    OnboardingProfileView {
                        // Profile created - will automatically show ContentView
                        // because hasProfile becomes true
                    }
                }
            }
            .environmentObject(LocalizationManager.shared)
            .environmentObject(themeManager)
            .environmentObject(currencyManager)
            .environmentObject(profileManager)
            .environment(\.managedObjectContext, persistenceController.persistentContainer.viewContext)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .onAppear {
                // Track app launch safely
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AnalyticsManager.shared.trackEvent(
                        AnalyticsEvent(name: "app_launched", parameters: [
                            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                        ])
                    )
                }
            }
        }
    }
}