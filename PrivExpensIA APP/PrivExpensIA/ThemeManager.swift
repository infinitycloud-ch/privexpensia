import SwiftUI
import Combine

// MARK: - Theme Manager for Dark Mode Support
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "darkModeEnabled")
            NotificationCenter.default.post(name: .themeChanged, object: isDarkMode)
        }
    }
    
    @Published var currentColorScheme: ColorScheme
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let isDark = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        self.isDarkMode = isDark
        self.currentColorScheme = isDark ? .dark : .light
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for dark mode changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                let isDark = UserDefaults.standard.bool(forKey: "darkModeEnabled")
                if self?.isDarkMode != isDark {
                    self?.isDarkMode = isDark
                    self?.currentColorScheme = isDark ? .dark : .light
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        currentColorScheme = isDarkMode ? .dark : .light
    }
}

// MARK: - Theme-aware Colors
extension LiquidGlassTheme.Colors {
    // Dynamic colors that adapt to dark/light mode
    static var dynamicBackground: LinearGradient {
        let isDark = ThemeManager.shared.isDarkMode
        
        if isDark {
            // Dark mode gradient - deeper, richer colors
            return LinearGradient(
                colors: [
                    Color(red: 10/255, green: 8/255, blue: 20/255),
                    Color(red: 20/255, green: 15/255, blue: 35/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Light mode gradient - original colors
            return LinearGradient(
                colors: [
                    Color(red: 24/255, green: 20/255, blue: 46/255),
                    Color(red: 40/255, green: 35/255, blue: 68/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    static var dynamicTextPrimary: Color {
        ThemeManager.shared.isDarkMode ? Color.white : Color.white
    }
    
    static var dynamicTextSecondary: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.8) : Color.white.opacity(0.7)
    }
    
    static var dynamicTextTertiary: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.6) : Color.white.opacity(0.5)
    }
    
    static var dynamicGlassWhite: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.1)
    }
    
    static var dynamicGlassLight: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.03) : Color.white.opacity(0.05)
    }
    
    static var dynamicGlassDark: Color {
        ThemeManager.shared.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.2)
    }
    
    static var dynamicCardBackground: Color {
        ThemeManager.shared.isDarkMode ? Color.white.opacity(0.06) : Color.white.opacity(0.1)
    }
    
    static var dynamicAccent: Color {
        ThemeManager.shared.isDarkMode ? 
            Color(red: 255/255, green: 65/255, blue: 105/255) :  // Brighter in dark mode
            Color(red: 255/255, green: 45/255, blue: 85/255)     // Original
    }
    
    static var dynamicPrimary: Color {
        ThemeManager.shared.isDarkMode ?
            Color(red: 108/255, green: 106/255, blue: 234/255) :  // Brighter in dark mode
            Color(red: 88/255, green: 86/255, blue: 214/255)      // Original
    }
    
    // Semantic colors with dark mode support
    static var dynamicSuccess: Color {
        ThemeManager.shared.isDarkMode ?
            Color(red: 72/255, green: 219/255, blue: 109/255) :
            Color(red: 52/255, green: 199/255, blue: 89/255)
    }
    
    static var dynamicWarning: Color {
        ThemeManager.shared.isDarkMode ?
            Color(red: 255/255, green: 169/255, blue: 20/255) :
            Color(red: 255/255, green: 149/255, blue: 0/255)
    }
    
    static var dynamicError: Color {
        ThemeManager.shared.isDarkMode ?
            Color(red: 255/255, green: 79/255, blue: 68/255) :
            Color(red: 255/255, green: 59/255, blue: 48/255)
    }
}

// MARK: - Theme Environment Key
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension for Theme
extension View {
    func withTheme() -> some View {
        self
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(ThemeManager.shared.currentColorScheme)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}