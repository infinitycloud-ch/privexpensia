import Foundation

// MARK: - Date Formatting Extensions for PrivExpensIA
extension Date {

    /// Format date as dd.MM.yyyy (ex: 14.09.2025)
    func formatDDMMYYYY() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: self)
    }

    /// Format date as dd.MM (ex: 14.09)
    func formatDDMM() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: self)
    }

    /// Format date as dd/MM/yyyy HH:mm
    func formatFullDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: self)
    }

    /// Format date for charts with short format
    func formatForChart() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: self)
    }
}

// MARK: - Global Date Formatter
struct GlobalDateFormatter {

    static let shared = GlobalDateFormatter()

    private let standardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    private let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    /// Format any date using standard format dd.MM.yyyy
    func formatStandard(_ date: Date) -> String {
        return standardFormatter.string(from: date)
    }

    /// Format any date using short format dd.MM
    func formatShort(_ date: Date) -> String {
        return shortFormatter.string(from: date)
    }

    /// Format any date with time
    func formatFull(_ date: Date) -> String {
        return fullFormatter.string(from: date)
    }
}