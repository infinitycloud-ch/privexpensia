import Foundation
import SwiftUI

// MARK: - Currency Manager
// Singleton ObservableObject pour la gestion centralisée de la devise
// Source de vérité unique pour toute l'application

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()

    @Published var currentCurrency: String {
        didSet {
            UserDefaults.standard.set(currentCurrency, forKey: "selectedCurrency")
            // Post notification pour que les autres vues se mettent à jour
            NotificationCenter.default.post(name: Notification.Name("currencyChanged"), object: currentCurrency)
        }
    }

    // Currencies supportées avec leurs symboles
    let supportedCurrencies = [
        "EUR": "€",
        "USD": "$",
        "GBP": "£",
        "CHF": "CHF ",
        "JPY": "¥",
        "CNY": "¥",
        "CAD": "C$",
        "AUD": "A$"
    ]

    private init() {
        // Initialiser depuis UserDefaults avec CHF comme défaut (app suisse)
        self.currentCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "CHF"
    }

    // MARK: - Currency Symbol
    var symbol: String {
        getCurrencySymbol()
    }

    // SF Symbol icon name for current currency
    // Note: CHF uses "banknote" because "francsign" (₣) is outdated - Swiss use "CHF" text
    var sfSymbolName: String {
        switch currentCurrency {
        case "EUR": return "eurosign"
        case "USD", "CAD", "AUD": return "dollarsign"
        case "GBP": return "sterlingsign"
        case "JPY", "CNY": return "yensign"
        case "CHF": return "banknote"  // ₣ is outdated, Swiss use "CHF" text
        default: return "banknote"
        }
    }

    func getCurrencySymbol(_ currency: String? = nil) -> String {
        let targetCurrency = currency ?? currentCurrency
        return supportedCurrencies[targetCurrency] ?? targetCurrency + " "
    }

    // MARK: - Currency Formatting
    func formatAmount(_ amount: Double, showSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        if showSymbol {
            let symbol = getCurrencySymbol()
            if currentCurrency == "CHF" {
                // CHF goes before the amount: "CHF 25.50"
                return "\(symbol)\(formatter.string(from: NSNumber(value: amount)) ?? "0.00")"
            } else {
                // Other currencies: "€25.50", "$25.50"
                return "\(symbol)\(formatter.string(from: NSNumber(value: amount)) ?? "0.00")"
            }
        } else {
            return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
        }
    }

    // MARK: - Currency Update
    func updateCurrency(_ newCurrency: String) {
        guard supportedCurrencies.keys.contains(newCurrency) else { return }
        currentCurrency = newCurrency
    }

    // MARK: - Available Currencies List
    func getAvailableCurrencies() -> [String] {
        return Array(supportedCurrencies.keys).sorted()
    }
}

