import Foundation
import os.log

// MARK: - Analytics Manager
// Privacy-first analytics - all data stays on device
final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let logger = Logger(subsystem: "com.minhtam.ExpenseAI", category: "Analytics")
    private let userDefaults = UserDefaults.standard
    
    private init() {
        setupAnalytics()
    }
    
    // MARK: - Setup
    private func setupAnalytics() {
        // Initialize on-device analytics
        logger.info("Analytics initialized - Privacy mode enabled")
        
        // Track app launch
        incrementCounter(for: "app_launches")
        
        // Track version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            userDefaults.set(version, forKey: "last_app_version")
        }
    }
    
    // MARK: - Event Tracking (Local Only)
    func trackEvent(_ event: AnalyticsEvent) {
        logger.info("Event: \(event.name) - \(event.parameters.debugDescription)")
        
        // Store locally for statistics
        incrementCounter(for: event.name)
        
        // Store event details for local reporting
        var events = userDefaults.array(forKey: "local_events") as? [[String: Any]] ?? []
        events.append([
            "name": event.name,
            "timestamp": Date().timeIntervalSince1970,
            "parameters": event.parameters
        ])
        
        // Keep only last 100 events
        if events.count > 100 {
            events = Array(events.suffix(100))
        }
        
        userDefaults.set(events, forKey: "local_events")
    }
    
    // MARK: - Performance Tracking
    func trackPerformance(operation: String, duration: TimeInterval) {
        logger.info("Performance: \(operation) took \(String(format: "%.3f", duration))s")
        
        // Store performance metrics locally
        var metrics = userDefaults.dictionary(forKey: "performance_metrics") ?? [:]
        var operationMetrics = metrics[operation] as? [String: Any] ?? [:]
        
        let count = (operationMetrics["count"] as? Int ?? 0) + 1
        let total = (operationMetrics["total"] as? Double ?? 0) + duration
        let average = total / Double(count)
        
        operationMetrics["count"] = count
        operationMetrics["total"] = total
        operationMetrics["average"] = average
        operationMetrics["last"] = duration
        
        metrics[operation] = operationMetrics
        userDefaults.set(metrics, forKey: "performance_metrics")
    }
    
    // MARK: - Crash Reporting (Local)
    func logError(_ error: Error, context: String? = nil) {
        logger.error("Error in \(context ?? "Unknown"): \(error.localizedDescription)")
        
        // Store error locally
        var errors = userDefaults.array(forKey: "local_errors") as? [[String: Any]] ?? []
        errors.append([
            "error": error.localizedDescription,
            "context": context ?? "Unknown",
            "timestamp": Date().timeIntervalSince1970,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ])
        
        // Keep only last 50 errors
        if errors.count > 50 {
            errors = Array(errors.suffix(50))
        }
        
        userDefaults.set(errors, forKey: "local_errors")
        incrementCounter(for: "error_count")
    }
    
    // MARK: - User Properties (Local)
    func setUserProperty(_ value: Any, for key: String) {
        var properties = userDefaults.dictionary(forKey: "user_properties") ?? [:]
        properties[key] = value
        userDefaults.set(properties, forKey: "user_properties")
    }
    
    // MARK: - Statistics
    func getStatistics() -> AnalyticsStatistics {
        let launches = userDefaults.integer(forKey: "counter_app_launches")
        let scans = userDefaults.integer(forKey: "counter_receipt_scanned")
        let errors = userDefaults.integer(forKey: "counter_error_count")
        let performance = userDefaults.dictionary(forKey: "performance_metrics") ?? [:]
        
        return AnalyticsStatistics(
            appLaunches: launches,
            receiptsScanned: scans,
            totalErrors: errors,
            performanceMetrics: performance
        )
    }
    
    // MARK: - Beta Feedback
    func submitFeedback(_ feedback: BetaFeedback) {
        logger.info("Beta feedback received: \(feedback.message)")
        
        var feedbacks = userDefaults.array(forKey: "beta_feedbacks") as? [[String: Any]] ?? []
        feedbacks.append([
            "message": feedback.message,
            "rating": feedback.rating,
            "category": feedback.category,
            "timestamp": Date().timeIntervalSince1970,
            "deviceModel": feedback.deviceModel,
            "osVersion": feedback.osVersion
        ])
        
        userDefaults.set(feedbacks, forKey: "beta_feedbacks")
        
        // Track feedback event
        trackEvent(AnalyticsEvent(
            name: "beta_feedback_submitted",
            parameters: ["rating": feedback.rating, "category": feedback.category]
        ))
    }
    
    // MARK: - Export for Beta Report
    func exportBetaReport() -> String {
        let stats = getStatistics()
        let errors = userDefaults.array(forKey: "local_errors") as? [[String: Any]] ?? []
        let feedbacks = userDefaults.array(forKey: "beta_feedbacks") as? [[String: Any]] ?? []
        
        var report = """
        === PrivExpensIA Beta Report ===
        Generated: \(Date())
        Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        
        === Statistics ===
        App Launches: \(stats.appLaunches)
        Receipts Scanned: \(stats.receiptsScanned)
        Total Errors: \(stats.totalErrors)
        
        === Performance ===
        """
        
        for (operation, metrics) in stats.performanceMetrics {
            if let metricsDict = metrics as? [String: Any],
               let average = metricsDict["average"] as? Double {
                report += "\n\(operation): \(String(format: "%.3f", average))s avg"
            }
        }
        
        report += "\n\n=== Recent Errors ===\n"
        for error in errors.suffix(10) {
            if let timestamp = error["timestamp"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                report += "\n[\(date)] \(error["context"] ?? ""): \(error["error"] ?? "")"
            }
        }
        
        report += "\n\n=== Beta Feedback ===\n"
        for feedback in feedbacks {
            if let message = feedback["message"] as? String,
               let rating = feedback["rating"] as? Int {
                report += "\nRating: \(rating)/5 - \(message)"
            }
        }
        
        return report
    }
    
    // MARK: - Privacy Clear
    func clearAllData() {
        logger.info("Clearing all analytics data")
        
        let keys = [
            "local_events",
            "local_errors",
            "performance_metrics",
            "user_properties",
            "beta_feedbacks"
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        
        // Reset counters
        resetAllCounters()
    }
    
    // MARK: - Helpers
    private func incrementCounter(for key: String) {
        let counterKey = "counter_\(key)"
        let current = userDefaults.integer(forKey: counterKey)
        userDefaults.set(current + 1, forKey: counterKey)
    }
    
    private func resetAllCounters() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("counter_") {
            userDefaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Analytics Event
struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    
    // Predefined events
    static func screenView(_ screen: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "screen_view", parameters: ["screen": screen])
    }
    
    static func receiptScanned(success: Bool, duration: TimeInterval) -> AnalyticsEvent {
        AnalyticsEvent(name: "receipt_scanned", parameters: [
            "success": success,
            "duration": duration
        ])
    }
    
    static func expenseSaved(category: String, amount: Double) -> AnalyticsEvent {
        AnalyticsEvent(name: "expense_saved", parameters: [
            "category": category,
            "amount": amount
        ])
    }
    
    static func featureUsed(_ feature: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "feature_used", parameters: ["feature": feature])
    }
}

// MARK: - Analytics Statistics
struct AnalyticsStatistics {
    let appLaunches: Int
    let receiptsScanned: Int
    let totalErrors: Int
    let performanceMetrics: [String: Any]
}

// MARK: - Beta Feedback
struct BetaFeedback {
    let message: String
    let rating: Int // 1-5
    let category: String
    let deviceModel: String
    let osVersion: String
    
    init(message: String, rating: Int, category: String) {
        self.message = message
        self.rating = rating
        self.category = category
        
        // Get device info
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        self.deviceModel = modelCode ?? "Unknown"
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }
}