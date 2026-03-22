import Foundation
import SwiftUI

// MARK: - Fixed Localization Manager using native Bundle API
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    private var currentBundle: Bundle = .main

    @Published var currentLanguage: String = "en" {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguageCode")

            // Charger le bon bundle de langue
            let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "Base", ofType: "lproj")!
            self.currentBundle = Bundle(path: path)!

            // Notifier l'UI de changer
            objectWillChange.send()
            // Force environment update
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }
    
    private let supportedLanguages = [
        "en": "English",
        "fr": "Français",
        "de": "Deutsch", 
        "it": "Italiano",
        "es": "Español",
        "ja": "日本語",
        "ko": "한국어",
        "sk": "Slovenčina"
    ]
    
    private init() {
        // Initialize with default, will be configured later
        configure()

        // Initialiser le bundle après configuration
        let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj") ?? Bundle.main.path(forResource: "Base", ofType: "lproj")!
        self.currentBundle = Bundle(path: path)!
    }

    /// Configure the localization manager - call this from app startup
    func configure() {
        // Check for launch arguments first (for testing)
        let arguments = ProcessInfo.processInfo.arguments

        // Check for -AppleLanguages argument
        if let index = arguments.firstIndex(of: "-AppleLanguages"),
           index + 1 < arguments.count {
            let langArg = arguments[index + 1]
            // Extract language from format like "(fr-CH)" or "(fr)"
            let cleanedLang = langArg
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .components(separatedBy: "-").first ?? "en"

            self.currentLanguage = cleanedLang
            return
        }

        // Check UserDefaults for saved preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguageCode") {
            self.currentLanguage = savedLanguage
            return
        }

        // Use system language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))

        // Validate language is supported
        if supportedLanguages.keys.contains(languageCode) {
            self.currentLanguage = languageCode
        } else {
            self.currentLanguage = "en"
        }
    }
    
    func localized(_ key: String) -> String {
        // Utiliser le bundle qu'on a explicitement chargé
        return currentBundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    
    func getAvailableLanguages() -> [(code: String, name: String)] {
        return supportedLanguages.map { ($0.key, $0.value) }
    }
    
    func setLanguage(_ code: String) {
        currentLanguage = code
        NotificationCenter.default.post(name: .languageChanged, object: code)
    }
    
    func getLanguageName(for code: String) -> String {
        return supportedLanguages[code] ?? "English"
    }
    
    func forceSetLanguage(_ code: String) {
        setLanguage(code)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension
extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
}

// MARK: - Text Extension
extension Text {
    init(localized key: String) {
        self.init(LocalizationManager.shared.localized(key))
    }
}