import Foundation

// MARK: - Swiss Date Formatting Extensions
extension DateFormatter {

    /// Formatage de date suisse standard: DD.MM.YYYY
    static let swissDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_CH") // Suisse allemand
        return formatter
    }()

    /// Formatage de date court suisse: DD.MM
    static let swissShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()

    /// Formatage avec heure suisse: DD.MM.YYYY HH:mm
    static let swissDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()

    /// Formatage relatif en français
    static let frenchRelative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.dateTimeStyle = .named
        return formatter
    }()
}

// MARK: - Date Extension pour formats suisses
extension Date {

    /// Format suisse standard: 14.09.2025
    var swissFormat: String {
        return DateFormatter.swissDate.string(from: self)
    }

    /// Format suisse court: 14.09
    var swissShortFormat: String {
        return DateFormatter.swissShort.string(from: self)
    }

    /// Format avec heure: 14.09.2025 15:30
    var swissDateTimeFormat: String {
        return DateFormatter.swissDateTime.string(from: self)
    }

    /// Format relatif français: "il y a 7 heures"
    var frenchRelativeFormat: String {
        return DateFormatter.frenchRelative.localizedString(for: self, relativeTo: Date())
    }
}