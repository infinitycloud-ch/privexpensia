import Foundation
import SwiftUI

// MARK: - App Constants v1.0
// Centralized configuration for PrivExpensIA
// All magic numbers and strings externalized here

enum Constants {
    
    // MARK: - App Info
    enum App {
        static let name = "PrivExpenses"
        static let version = "1.0.0"
        static let buildNumber = "1"
        static let minimumIOSVersion = 17.0
        static let copyright = "© 2025 Minh-Tam Dang"
    }
    
    // MARK: - Model Configuration
    enum Model {
        static let name = "Qwen2.5-0.5B-Instruct-4bit"
        static let sizeInBytes = 300 * 1024 * 1024 // 300MB
        static let maxTokens = 256
        static let temperature: Float = 0.2
        static let topP: Float = 0.9
        static let topK = 30
        static let repetitionPenalty: Float = 1.1
        static let batchSize = 1
    }
    
    // MARK: - Performance Limits
    enum Performance {
        static let maxInferenceTime: TimeInterval = 1.0 // 1 second
        static let targetInferenceTime: TimeInterval = 0.3 // 300ms
        static let maxMemoryUsage: Int64 = 150 * 1024 * 1024 // 150MB
        static let cacheTimeout: TimeInterval = 0.2 // 200ms for extraction
        static let ocrTimeout: TimeInterval = 2.0 // 2 seconds
    }
    
    // MARK: - Cache Configuration
    enum Cache {
        static let maxEntries = 100
        static let ttl: TimeInterval = 86400 // 24 hours
        static let purgeThreshold = 10 // entries to remove when full
        static let warmupItemCount = 5 // items to preload
    }
    
    // MARK: - OCR Settings
    enum OCR {
        static let supportedLanguages = ["fr", "de", "it", "en", "ja", "ko", "sk", "es"]
        static let recognitionLevel = "accurate"
        static let usesLanguageCorrection = true
        static let minimumConfidence: Float = 0.5
        static let preprocessingQuality: Float = 0.8
    }
    
    // MARK: - UI Configuration
    enum UI {
        static let animationDuration: TimeInterval = 0.3
        static let hapticFeedbackEnabled = true
        static let cornerRadius: CGFloat = 12.0
        static let shadowOpacity: Float = 0.1
        static let primaryColor = Color(red: 100/255, green: 55/255, blue: 227/255)
        static let successColor = Color(red: 52/255, green: 199/255, blue: 89/255)
        static let errorColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    }

    // MARK: - AI Mode Configuration
    enum AIMode {
        static let userDefaultsKey = "isAIModeEnabled"
        static let defaultValue = true

        static var isEnabled: Bool {
            get {
                UserDefaults.standard.object(forKey: userDefaultsKey) as? Bool ?? defaultValue
            }
            set {
                UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            }
        }
    }
    
    // MARK: - Error Messages (Localized)
    enum ErrorMessages {
        static var genericError: String { LocalizationManager.shared.localized("message.error") }
        static var cameraPermission: String { LocalizationManager.shared.localized("camera_access_description") }
        static var photoLibraryPermission: String { LocalizationManager.shared.localized("error.upload_failed") }
        static var modelNotLoaded: String { LocalizationManager.shared.localized("ai.processing") }
        static var memoryLimitExceeded: String { LocalizationManager.shared.localized("error.server_error") }
        static var ocrFailed: String { LocalizationManager.shared.localized("error.scan_failed") }
        static var networkError: String { LocalizationManager.shared.localized("error.network") }
        static var extractionFailed: String { LocalizationManager.shared.localized("error.invalid_receipt") }
        static var saveError: String { LocalizationManager.shared.localized("error.upload_failed") }
        static var timeoutError: String { LocalizationManager.shared.localized("error.scan_failed") }
    }

    // MARK: - Success Messages (Localized)
    enum SuccessMessages {
        static var scanComplete: String { LocalizationManager.shared.localized("scan.complete") }
        static var expenseSaved: String { LocalizationManager.shared.localized("message.expense_saved") }
        static var exportComplete: String { LocalizationManager.shared.localized("message.success") }
        static var syncComplete: String { LocalizationManager.shared.localized("message.success") }
    }
    
    // MARK: - Onboarding Tips
    enum OnboardingTips {
        static let welcome = "Welcome to PrivExpensIA! 🎉"
        static let scanTip = "Hold your camera steady for best results"
        static let lightingTip = "Good lighting improves accuracy"
        static let multiLanguageTip = "Receipts in 8 languages supported"
        static let offlineTip = "Works 100% offline - your data stays private"
        static let aiTip = "AI extracts amounts, dates, and categories automatically"
    }
    
    // MARK: - File Paths
    enum Paths {
        static let documentsDirectory: URL = {
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                fatalError("Documents directory not found")
            }
            return url
        }()
        static let modelDirectory = documentsDirectory.appendingPathComponent("models/qwen2.5")
        static let cacheDirectory = documentsDirectory.appendingPathComponent("cache")
        static let exportsDirectory = documentsDirectory.appendingPathComponent("exports")
    }
    
    // MARK: - Validation Rules
    enum Validation {
        static let minimumImageWidth = 1024
        static let minimumImageHeight = 768
        static let maximumImageSize = 10 * 1024 * 1024 // 10MB
        static let maximumReceiptAge = 365 // days
        static let minimumAmount: Double = 0.01
        static let maximumAmount: Double = 999999.99
    }
    
    // MARK: - Categories
    enum Categories {
        static let all = [
            "Restaurant",
            "Groceries",
            "Transport",
            "Shopping",
            "Entertainment",
            "Health",
            "Bills",
            "Coffee",
            "Gas",
            "Other"
        ]
        
        static let defaultCategory = "Other"
        
        static let icons: [String: String] = [
            "Restaurant": "fork.knife",
            "Groceries": "cart",
            "Transport": "car",
            "Shopping": "bag",
            "Entertainment": "tv",
            "Health": "heart",
            "Bills": "doc.text",
            "Coffee": "cup.and.saucer",
            "Gas": "fuelpump",
            "Other": "questionmark.circle"
        ]
    }
    
    // MARK: - Currencies
    enum Currencies {
        static let supported = ["CHF", "EUR", "USD", "GBP", "JPY"]
        static let defaultCurrency = "CHF"
        static let symbols: [String: String] = [
            "EUR": "€",
            "USD": "$",
            "GBP": "£",
            "JPY": "¥",
            "CHF": "Fr."
        ]
    }
    
    // MARK: - Analytics Events (for future)
    enum Analytics {
        static let appLaunched = "app_launched"
        static let scanStarted = "scan_started"
        static let scanCompleted = "scan_completed"
        static let expenseSaved = "expense_saved"
        static let exportCreated = "export_created"
        static let errorOccurred = "error_occurred"
    }
    
    // MARK: - Debug Settings
    enum Debug {
        #if DEBUG
        static let enableLogging = true
        static let mockInference = false
        static let showPerformanceOverlay = true
        #else
        static let enableLogging = false
        static let mockInference = false
        static let showPerformanceOverlay = false
        #endif
    }
}