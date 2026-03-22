import Foundation
import UIKit

// MARK: - Pipeline Logger
// Sprint 3: Complete tracing and correlation system for OCR/AI pipeline
// Tracks every step from OCR → AI → final extraction with timestamps

class PipelineLogger {
    static let shared = PipelineLogger()

    private let logQueue = DispatchQueue(label: "pipeline.logger", qos: .utility)
    private var logEntries: [LogEntry] = []
    private var performanceMetrics = PerformanceMetrics()

    private init() {
        setupLogFile()
    }

    // MARK: - Log Levels
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case swiss = "SWISS"     // Special level for Swiss fallback
        case pipeline = "PIPELINE" // Pipeline flow tracking

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .swiss: return "🇨🇭"
            case .pipeline: return "🔄"
            }
        }
    }

    // MARK: - Log Entry Structure
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String
        let correlationId: String?
        let pipelineStage: String?
        let extractedData: [String: Any]?

        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timeString = formatter.string(from: timestamp)

            var result = "\(timeString) [\(level.emoji) \(level.rawValue)]"

            if let correlationId = correlationId {
                result += " [ID: \(correlationId.prefix(8))]"
            }

            if let stage = pipelineStage {
                result += " [\(stage)]"
            }

            result += " \(message)"
            return result
        }
    }

    // MARK: - Performance Metrics
    struct PerformanceMetrics {
        var totalExtractions: Int = 0
        var pipelineUsage: [String: Int] = [:]
        var averageProcessingTimes: [String: TimeInterval] = [:]
        var confidenceDistribution: [Double] = []
        var swissFallbackUsage: Int = 0

        mutating func recordExtraction(pipeline: String, time: TimeInterval, confidence: Double, usedSwissFallback: Bool) {
            totalExtractions += 1
            pipelineUsage[pipeline, default: 0] += 1

            // Update average processing time
            let currentAvg = averageProcessingTimes[pipeline] ?? 0
            let currentCount = pipelineUsage[pipeline] ?? 1
            averageProcessingTimes[pipeline] = ((currentAvg * Double(currentCount - 1)) + time) / Double(currentCount)

            confidenceDistribution.append(confidence)

            if usedSwissFallback {
                swissFallbackUsage += 1
            }
        }
    }

    // MARK: - Logging Methods
    func log(_ message: String, level: LogLevel = .info, correlationId: String? = nil, pipelineStage: String? = nil, extractedData: [String: Any]? = nil) {

        logQueue.async { [weak self] in
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                message: message,
                correlationId: correlationId,
                pipelineStage: pipelineStage,
                extractedData: extractedData
            )

            self?.logEntries.append(entry)

            // Console output for immediate debugging
            print(entry.formattedMessage)

            // Write to file
            self?.writeToFile(entry)
        }
    }

    // MARK: - Specialized Logging Methods
    func logPipelineStart(correlationId: String, mode: String, ocrText: String) {
        log("🎯 Pipeline started - Mode: \(mode) - OCR: \(ocrText.count) chars",
            level: .pipeline,
            correlationId: correlationId,
            pipelineStage: "START")
    }

    func logOCRCompletion(correlationId: String, confidence: Float, charactersExtracted: Int) {
        log("📖 OCR completed - \(charactersExtracted) chars extracted (confidence: \(String(format: "%.2f", confidence)))",
            level: .info,
            correlationId: correlationId,
            pipelineStage: "OCR")
    }

    func logPipelineSelection(correlationId: String, selectedPipeline: String, reason: String) {
        log("⚙️ Pipeline selected: \(selectedPipeline) - Reason: \(reason)",
            level: .pipeline,
            correlationId: correlationId,
            pipelineStage: "SELECTION")
    }

    func logSwissFallback(correlationId: String, amountFound: Double?, pattern: String?) {
        let message: String
        if let amount = amountFound, let pattern = pattern {
            message = "🇨🇭 Swiss fallback SUCCESS - CHF \(String(format: "%.2f", amount)) via pattern: \(pattern)"
        } else {
            message = "🇨🇭 Swiss fallback FAILED - No reliable amount found"
        }

        log(message,
            level: .swiss,
            correlationId: correlationId,
            pipelineStage: "SWISS_FALLBACK")
    }

    func logExtractionCompletion(correlationId: String, pipeline: String, confidence: Double, merchant: String, amount: Double, processingTime: TimeInterval, usedSwissFallback: Bool) {

        let extractedData: [String: Any] = [
            "merchant": merchant,
            "amount": amount,
            "confidence": confidence,
            "processing_time": processingTime,
            "used_swiss_fallback": usedSwissFallback
        ]

        log("🎉 Extraction completed - \(merchant): \(String(format: "%.2f", amount)) (confidence: \(String(format: "%.2f", confidence)), time: \(String(format: "%.2f", processingTime))s)",
            level: .info,
            correlationId: correlationId,
            pipelineStage: "COMPLETION",
            extractedData: extractedData)

        // Update metrics
        logQueue.async { [weak self] in
            self?.performanceMetrics.recordExtraction(
                pipeline: pipeline,
                time: processingTime,
                confidence: confidence,
                usedSwissFallback: usedSwissFallback
            )
        }
    }

    func logError(correlationId: String, stage: String, error: Error) {
        log("❌ Error in \(stage): \(error.localizedDescription)",
            level: .error,
            correlationId: correlationId,
            pipelineStage: stage)
    }

    // MARK: - File Management
    private var logFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsPath.appendingPathComponent("Reports/Sprint3_Audit")
        try? FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true, attributes: nil)
        return reportsDir.appendingPathComponent("pipeline.log")
    }

    private func setupLogFile() {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
                FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil, attributes: nil)
            }

            // Write session header
            let header = "\n=== PIPELINE LOG SESSION STARTED ===\n"
            let headerData = header.data(using: .utf8)!
            if let fileHandle = FileHandle(forWritingAtPath: self.logFileURL.path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(headerData)
                fileHandle.closeFile()
            }
        }
    }

    private func writeToFile(_ entry: LogEntry) {
        guard let data = (entry.formattedMessage + "\n").data(using: .utf8) else { return }

        if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }

    // MARK: - Report Generation
    func generateHTMLReport() -> String {
        let recentEntries = Array(logEntries.suffix(200)) // Last 200 entries

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>PrivExpensIA - Pipeline Audit Report</title>
            <meta charset="UTF-8">
            <style>
                body { font-family: -apple-system, sans-serif; margin: 20px; background: #f5f5f7; }
                .header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
                .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
                .metric-card { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .metric-value { font-size: 24px; font-weight: bold; color: #1e3c72; }
                .metric-label { color: #666; font-size: 14px; }
                .log-container { background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .log-entry { padding: 8px; border-left: 3px solid #e0e0e0; margin: 5px 0; font-family: Monaco, monospace; font-size: 12px; }
                .log-entry.info { border-left-color: #007AFF; }
                .log-entry.warning { border-left-color: #FF9500; }
                .log-entry.error { border-left-color: #FF3B30; }
                .log-entry.swiss { border-left-color: #FF2D92; background: #fff5f8; }
                .log-entry.pipeline { border-left-color: #30D158; }
                .timestamp { color: #666; }
                .correlation-id { color: #007AFF; font-weight: bold; }
                .stage { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-size: 10px; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🎯 PrivExpensIA - Pipeline Audit Report</h1>
                <p>Sprint 3: Unified Pipeline with Swiss Fallback</p>
                <p>Generated: \(DateFormatter.reportDateFormatter.string(from: Date()))</p>
            </div>

            <div class="metrics">
                <div class="metric-card">
                    <div class="metric-value">\(performanceMetrics.totalExtractions)</div>
                    <div class="metric-label">Total Extractions</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">\(performanceMetrics.swissFallbackUsage)</div>
                    <div class="metric-label">Swiss Fallbacks Used</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">\(String(format: "%.1f%%", Double(performanceMetrics.swissFallbackUsage) / Double(max(performanceMetrics.totalExtractions, 1)) * 100))</div>
                    <div class="metric-label">Swiss Success Rate</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">\(String(format: "%.2f", performanceMetrics.confidenceDistribution.isEmpty ? 0 : performanceMetrics.confidenceDistribution.reduce(0, +) / Double(performanceMetrics.confidenceDistribution.count)))</div>
                    <div class="metric-label">Average Confidence</div>
                </div>
            </div>

            \(generatePipelineDistributionHTML())

            <div class="log-container">
                <h2>📝 Recent Pipeline Logs</h2>
                \(recentEntries.map { generateLogEntryHTML($0) }.joined())
            </div>

            \(generateCorrelationLinksHTML())

        </body>
        </html>
        """

        return html
    }

    private func generatePipelineDistributionHTML() -> String {
        let total = performanceMetrics.totalExtractions
        guard total > 0 else { return "" }

        let distributionHTML = performanceMetrics.pipelineUsage.map { pipeline, count in
            let percentage = Double(count) / Double(total) * 100
            return """
            <div class="metric-card">
                <div class="metric-value">\(count)</div>
                <div class="metric-label">\(pipeline) (\(String(format: "%.1f", percentage))%)</div>
            </div>
            """
        }.joined()

        return """
        <div class="metrics">
            <h3 style="grid-column: 1/-1; margin: 0;">Pipeline Usage Distribution</h3>
            \(distributionHTML)
        </div>
        """
    }

    private func generateLogEntryHTML(_ entry: LogEntry) -> String {
        let levelClass = entry.level.rawValue.lowercased()

        return """
        <div class="log-entry \(levelClass)">
            <span class="timestamp">\(DateFormatter.logTimeFormatter.string(from: entry.timestamp))</span>
            \(entry.correlationId.map { "<span class=\"correlation-id\">[\($0.prefix(8))]</span>" } ?? "")
            \(entry.pipelineStage.map { "<span class=\"stage\">[\($0)]</span>" } ?? "")
            \(entry.message)
        </div>
        """
    }

    private func generateCorrelationLinksHTML() -> String {
        let reportsDir = "~/moulinsart/PrivExpensIA/Reports/Sprint3_Audit"

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: reportsDir) else {
            return ""
        }

        let screenshots = files.filter { $0.hasPrefix("screenshot_") }
        let extractions = files.filter { $0.hasPrefix("extraction_") }

        let correlationHTML = zip(screenshots, extractions).map { screenshot, extraction in
            let correlationId = String(screenshot.dropFirst("screenshot_".count).dropLast(".png".count))
            return """
            <div style="margin: 10px 0; padding: 10px; background: #f0f0f0; border-radius: 5px;">
                <strong>Correlation ID: \(correlationId.prefix(8))</strong><br>
                📷 <a href="file://\(reportsDir)/\(screenshot)">Screenshot</a> |
                📊 <a href="file://\(reportsDir)/\(extraction)">JSON Data</a>
            </div>
            """
        }.joined()

        return """
        <div class="log-container">
            <h2>🔗 Screenshot ↔ Data Correlations</h2>
            \(correlationHTML.isEmpty ? "<p>No correlations available yet.</p>" : correlationHTML)
        </div>
        """
    }

    // MARK: - Public Metrics API
    func getTotalExtractions() -> Int {
        return performanceMetrics.totalExtractions
    }

    func getAverageProcessingTime() -> TimeInterval {
        let times = performanceMetrics.averageProcessingTimes.values
        return times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
    }

    func getPipelineDistribution() -> [String: Int] {
        return performanceMetrics.pipelineUsage
    }

    func getAverageConfidence() -> Double {
        let confidences = performanceMetrics.confidenceDistribution
        return confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
    }

    func getSwissFallbackSuccessRate() -> Double {
        guard performanceMetrics.totalExtractions > 0 else { return 0 }
        return Double(performanceMetrics.swissFallbackUsage) / Double(performanceMetrics.totalExtractions)
    }

    // MARK: - Export Logs
    func exportLogsToFile() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let exportURL = logFileURL.deletingLastPathComponent().appendingPathComponent("pipeline_export_\(timestamp).log")

        let allLogs = logEntries.map { $0.formattedMessage }.joined(separator: "\n")
        try? allLogs.write(to: exportURL, atomically: true, encoding: .utf8)

        return exportURL
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}