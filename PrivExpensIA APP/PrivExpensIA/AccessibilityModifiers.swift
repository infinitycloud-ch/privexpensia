import SwiftUI

// MARK: - Accessibility Modifiers
extension View {
    
    // MARK: - VoiceOver Support
    func accessibilityElement(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    // MARK: - Dynamic Type Support
    func dynamicTypeSize() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    // MARK: - Reduce Motion Support
    func reduceMotionAnimation<V>(_ animation: Animation?, value: V) -> some View where V: Equatable {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.1) : animation,
            value: value
        )
    }
    
    // MARK: - High Contrast Support
    func highContrastAware() -> some View {
        self
    }
}

// MARK: - Accessibility Manager
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverRunning: Bool
    @Published var isDynamicTypeEnabled: Bool
    @Published var isReduceMotionEnabled: Bool
    @Published var isHighContrastEnabled: Bool
    @Published var preferredContentSize: ContentSizeCategory
    
    private init() {
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory != .large
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        if let category = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory) {
            self.preferredContentSize = category
        } else {
            self.preferredContentSize = .large
        }
        
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeChanged),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func voiceOverStatusChanged() {
        DispatchQueue.main.async {
            self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
    }
    
    @objc private func contentSizeChanged() {
        DispatchQueue.main.async {
            if let category = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory) {
            self.preferredContentSize = category
        } else {
            self.preferredContentSize = .large
        }
            self.isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory != .large
        }
    }
    
    @objc private func reduceMotionChanged() {
        DispatchQueue.main.async {
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
    }
    
    // MARK: - Accessibility Announcements
    static func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    static func announceScreenChange(_ message: String) {
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }
    
    static func announceLayoutChange(_ message: String) {
        UIAccessibility.post(notification: .layoutChanged, argument: message)
    }
}

// MARK: - Accessible Glass Card
struct AccessibleGlassCard<Content: View>: View {
    let content: Content
    let label: String
    let hint: String?
    var isButton: Bool = false
    
    init(label: String, hint: String? = nil, isButton: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.isButton = isButton
        self.content = content()
    }
    
    var body: some View {
        GlassCard {
            content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .if(isButton) { view in
            view.accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Accessible Button
struct AccessibleGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let accessibilityLabel: String?
    let accessibilityHint: String?
    
    init(
        _ title: String,
        icon: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
    
    var body: some View {
        GlassButton(title, icon: icon, action: action)
            .accessibilityLabel(accessibilityLabel ?? title)
            .accessibilityHint(accessibilityHint ?? "Double tap to activate")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Color Contrast Checker
struct ColorContrastChecker {
    
    // WCAG 2.1 contrast ratio requirements
    // Normal text: 4.5:1
    // Large text: 3:1
    // Enhanced normal text: 7:1
    // Enhanced large text: 4.5:1
    
    static func checkContrast(foreground: Color, background: Color) -> Bool {
        let ratio = contrastRatio(between: foreground, and: background)
        return ratio >= 4.5 // WCAG AA standard for normal text
    }
    
    static func contrastRatio(between color1: Color, and color2: Color) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private static func relativeLuminance(of color: Color) -> Double {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = linearize(red)
        let g = linearize(green)
        let b = linearize(blue)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    private static func linearize(_ value: CGFloat) -> Double {
        let v = Double(value)
        if v <= 0.03928 {
            return v / 12.92
        } else {
            return pow((v + 0.055) / 1.055, 2.4)
        }
    }
}

// MARK: - Helper Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Accessibility Labels
struct AccessibilityLabels {
    static let scanReceipt = "Scan receipt"
    static let scanReceiptHint = "Opens camera to scan a paper receipt"
    
    static let viewExpenses = "View expenses"
    static let viewExpensesHint = "Shows list of all your expenses"
    
    static let viewStatistics = "View statistics"
    static let viewStatisticsHint = "Shows spending charts and analytics"
    
    static let settings = "Settings"
    static let settingsHint = "Opens app settings and preferences"
    
    static let deleteExpense = "Delete expense"
    static let deleteExpenseHint = "Removes this expense permanently"
    
    static let editExpense = "Edit expense"
    static let editExpenseHint = "Modify expense details"
    
    static let exportData = "Export data"
    static let exportDataHint = "Export expenses to PDF or CSV file"
    
    static let submitFeedback = "Submit feedback"
    static let submitFeedbackHint = "Send your feedback to improve the app"
}