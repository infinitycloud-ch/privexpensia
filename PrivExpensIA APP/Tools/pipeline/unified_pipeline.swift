import Foundation
import UIKit
import Combine

// MARK: - Unified Pipeline Manager
// Sprint 3: Single entry point for all OCR/AI extraction
// Eliminates inconsistencies between MLX, Qwen, and Parser modes

class UnifiedPipelineManager {
    static let shared = UnifiedPipelineManager()

    private let logger = PipelineLogger.shared
    private let ocrService = OCRService.shared
    private let qwenManager = QwenModelManager.shared
    private let mlxService = MLXService.shared
    private let expenseParser = ExpenseParser.shared

    private init() {
        logger.log("🔧 UnifiedPipelineManager initialized", level: .info)
    }

    // MARK: - Pipeline Modes
    enum PipelineMode: String, CaseIterable {
        case qwen = "qwen"           // QwenModelManager - Fast AI
        case mlx = "mlx"             // MLXService - Full AI
        case parser = "parser"       // ExpenseParser - Regex/Heuristics
        case auto = "auto"           // Automatic selection based on confidence

        var description: String {
            switch self {
            case .qwen: return "Qwen2.5 Fast AI"
            case .mlx: return "MLX Full AI Model"
            case .parser: return "Regex/Heuristics Parser"
            case .auto: return "Automatic Mode Selection"
            }
        }
    }

    // MARK: - Unified Extraction Result
    struct UnifiedResult {
        let extractedData: UnifiedExpenseData
        let pipelineUsed: PipelineMode
        let confidence: Double
        let processingTime: TimeInterval
        let logs: [String]
        let screenshot: UIImage?
        let correlationId: String

        var isHighConfidence: Bool { confidence >= 0.7 }
        var shouldUseFallback: Bool { confidence < 0.5 }
    }

    // MARK: - Main Unified Extraction Entry Point
    func extractExpense(from image: UIImage,
                       preferredMode: PipelineMode = .auto,
                       completion: @escaping (Result<UnifiedResult, Error>) -> Void) {

        let correlationId = UUID().uuidString
        let startTime = Date()
        var extractionLogs: [String] = []

        logger.log("🎯 Starting unified extraction - Mode: \(preferredMode.description) - ID: \(correlationId)", level: .info)
        extractionLogs.append("🎯 Pipeline started: \(preferredMode.description)")

        // Step 1: OCR Processing (always first)
        logger.log("📖 Step 1: OCR Processing", level: .debug)
        extractionLogs.append("📖 OCR Processing started")

        ocrService.processImage(image) { [weak self] ocrResult in
            guard let self = self else { return }

            switch ocrResult {
            case .success(let ocrData):
                extractionLogs.append("✅ OCR completed: \(ocrData.text.count) chars, confidence: \(ocrData.confidence)")
                self.logger.log("✅ OCR Success: \(ocrData.text.count) characters extracted", level: .info)

                // Step 2: Determine actual pipeline mode
                let actualMode = self.determinePipelineMode(preferredMode: preferredMode,
                                                          ocrData: ocrData,
                                                          logs: &extractionLogs)

                // Step 3: Execute chosen pipeline
                self.executePipeline(mode: actualMode,
                                   ocrData: ocrData,
                                   image: image,
                                   correlationId: correlationId,
                                   logs: &extractionLogs) { result in

                    let totalTime = Date().timeIntervalSince(startTime)

                    switch result {
                    case .success(let expenseData):
                        extractionLogs.append("🎉 Extraction completed in \(String(format: "%.2f", totalTime))s")

                        let unifiedResult = UnifiedResult(
                            extractedData: expenseData,
                            pipelineUsed: actualMode,
                            confidence: expenseData.confidence,
                            processingTime: totalTime,
                            logs: extractionLogs,
                            screenshot: image,
                            correlationId: correlationId
                        )

                        // Save correlation data
                        self.saveCorrelationData(unifiedResult)

                        completion(.success(unifiedResult))

                    case .failure(let error):
                        extractionLogs.append("❌ Pipeline failed: \(error.localizedDescription)")
                        self.logger.log("❌ Pipeline failed: \(error)", level: .error)
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                extractionLogs.append("❌ OCR failed: \(error.localizedDescription)")
                self.logger.log("❌ OCR failed: \(error)", level: .error)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Pipeline Mode Selection Logic
    private func determinePipelineMode(preferredMode: PipelineMode,
                                     ocrData: ExtractedData,
                                     logs: inout [String]) -> PipelineMode {

        switch preferredMode {
        case .auto:
            // Auto-selection logic based on text characteristics
            let text = ocrData.text.lowercased()

            // Swiss receipts detection - force parser for reliability
            if text.contains("chf") || text.contains("fr.") ||
               text.contains("migros") || text.contains("coop") {
                logs.append("🇨🇭 Swiss receipt detected -> Parser mode")
                logger.log("🇨🇭 Swiss receipt detected, using parser mode", level: .info)
                return .parser
            }

            // High OCR confidence - use AI
            if ocrData.confidence > 0.8 {
                logs.append("🧠 High OCR confidence -> Qwen AI mode")
                return .qwen
            }

            // Low OCR confidence - use parser
            logs.append("📝 Low OCR confidence -> Parser fallback")
            return .parser

        default:
            logs.append("⚙️ Using preferred mode: \(preferredMode.description)")
            return preferredMode
        }
    }

    // MARK: - Pipeline Execution
    private func executePipeline(mode: PipelineMode,
                               ocrData: ExtractedData,
                               image: UIImage,
                               correlationId: String,
                               logs: inout [String],
                               completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logger.log("🔄 Executing pipeline: \(mode.description)", level: .info)
        logs.append("🔄 Executing: \(mode.description)")

        switch mode {
        case .qwen:
            executeQwenPipeline(ocrData: ocrData, logs: &logs, completion: completion)

        case .mlx:
            executeMLXPipeline(ocrData: ocrData, logs: &logs, completion: completion)

        case .parser:
            executeParserPipeline(ocrData: ocrData, logs: &logs, completion: completion)

        case .auto:
            // This should not happen as auto is resolved in determinePipelineMode
            logs.append("⚠️ Auto mode not resolved, falling back to parser")
            executeParserPipeline(ocrData: ocrData, logs: &logs, completion: completion)
        }
    }

    // MARK: - Qwen Pipeline
    private func executeQwenPipeline(ocrData: ExtractedData,
                                   logs: inout [String],
                                   completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logs.append("🤖 Qwen AI processing...")

        qwenManager.runInference(prompt: ocrData.text) { [weak self] result in
            switch result {
            case .success(let qwenResponse):
                logs.append("✅ Qwen completed: confidence varies")

                // Parse Qwen JSON response
                if let data = qwenResponse.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    let expenseData = self?.parseQwenResponse(json: json, ocrData: ocrData) ?? UnifiedExpenseData()
                    logs.append("📊 Parsed Qwen data: \(expenseData.merchant) - \(expenseData.totalAmount)")

                    completion(.success(expenseData))
                } else {
                    logs.append("❌ Qwen JSON parsing failed, falling back to parser")
                    self?.executeParserPipeline(ocrData: ocrData, logs: &logs, completion: completion)
                }

            case .failure(let error):
                logs.append("❌ Qwen failed: \(error.localizedDescription), falling back to parser")
                self?.executeParserPipeline(ocrData: ocrData, logs: &logs, completion: completion)
            }
        }
    }

    // MARK: - MLX Pipeline
    private func executeMLXPipeline(ocrData: ExtractedData,
                                  logs: inout [String],
                                  completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logs.append("🧠 MLX AI processing...")

        mlxService.runInference(prompt: ocrData.text) { [weak self] result in
            switch result {
            case .success(let mlxData):
                logs.append("✅ MLX completed: confidence \(mlxData.confidence)")

                let expenseData = self?.parseMLXResponse(mlxData: mlxData, ocrData: ocrData) ?? UnifiedExpenseData()
                logs.append("📊 Parsed MLX data: \(expenseData.merchant) - \(expenseData.totalAmount)")

                completion(.success(expenseData))

            case .failure(let error):
                logs.append("❌ MLX failed: \(error.localizedDescription), falling back to parser")
                self?.executeParserPipeline(ocrData: ocrData, logs: &logs, completion: completion)
            }
        }
    }

    // MARK: - Parser Pipeline (Enhanced Swiss Fallback)
    private func executeParserPipeline(ocrData: ExtractedData,
                                     logs: inout [String],
                                     completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logs.append("📝 Enhanced parser processing...")

        // Use enhanced parser with Swiss fallback
        let parsedExpense = expenseParser.parseFromOCRResult(ocrData)
        logs.append("✅ Parser completed: \(parsedExpense.merchant) - \(parsedExpense.formattedTotal)")

        let expenseData = parseParserResponse(parsedExpense: parsedExpense, ocrData: ocrData)
        logs.append("📊 Unified parser data: confidence \(expenseData.confidence)")

        completion(.success(expenseData))
    }

    // MARK: - Response Parsers
    private func parseQwenResponse(json: [String: Any], ocrData: ExtractedData) -> UnifiedExpenseData {
        var data = UnifiedExpenseData()

        data.merchant = json["merchant"] as? String ?? "Unknown"
        data.totalAmount = json["total_amount"] as? Double ?? 0
        data.taxAmount = json["tax_amount"] as? Double ?? 0
        data.currency = json["currency"] as? String ?? "EUR"
        data.category = json["category"] as? String ?? "Other"
        data.confidence = json["confidence"] as? Double ?? 0.5
        data.extractionMethod = "Qwen2.5-AI"
        data.rawText = ocrData.text

        return data
    }

    private func parseMLXResponse(mlxData: AIExtractedData, ocrData: ExtractedData) -> UnifiedExpenseData {
        var data = UnifiedExpenseData()

        data.merchant = mlxData.merchant
        data.totalAmount = mlxData.totalAmount
        data.taxAmount = mlxData.taxAmount
        data.date = mlxData.date
        data.category = mlxData.category
        data.confidence = mlxData.confidence
        data.extractionMethod = "MLX-AI"
        data.rawText = ocrData.text

        return data
    }

    private func parseParserResponse(parsedExpense: ParsedExpense, ocrData: ExtractedData) -> UnifiedExpenseData {
        var data = UnifiedExpenseData()

        data.merchant = parsedExpense.merchant
        data.totalAmount = parsedExpense.totalAmount
        data.taxAmount = parsedExpense.vatAmount
        data.currency = parsedExpense.currency
        data.date = parsedExpense.date
        data.category = parsedExpense.category
        data.confidence = calculateParserConfidence(parsedExpense)
        data.extractionMethod = "Enhanced-Parser"
        data.rawText = ocrData.text

        return data
    }

    private func calculateParserConfidence(_ parsed: ParsedExpense) -> Double {
        var confidence = 0.5 // Base confidence

        if !parsed.merchant.isEmpty && parsed.merchant != "Unknown" { confidence += 0.15 }
        if parsed.totalAmount > 0 { confidence += 0.2 }
        if parsed.vatAmount > 0 { confidence += 0.1 }
        if parsed.category != "Other" { confidence += 0.05 }

        return min(confidence, 0.95)
    }

    // MARK: - Correlation Data Management
    private func saveCorrelationData(_ result: UnifiedResult) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let reportDir = "~/moulinsart/PrivExpensIA/Reports/Sprint3_Audit"
        try? FileManager.default.createDirectory(atPath: reportDir, withIntermediateDirectories: true, attributes: nil)

        // Save screenshot with correlation ID
        if let screenshot = result.screenshot,
           let imageData = screenshot.pngData() {
            let imagePath = "\(reportDir)/screenshot_\(result.correlationId).png"
            try? imageData.write(to: URL(fileURLWithPath: imagePath))
        }

        // Save extraction JSON
        let jsonData: [String: Any] = [
            "correlation_id": result.correlationId,
            "timestamp": timestamp,
            "pipeline_used": result.pipelineUsed.rawValue,
            "processing_time": result.processingTime,
            "confidence": result.confidence,
            "extracted_data": [
                "merchant": result.extractedData.merchant,
                "total_amount": result.extractedData.totalAmount,
                "tax_amount": result.extractedData.taxAmount,
                "currency": result.extractedData.currency,
                "category": result.extractedData.category,
                "extraction_method": result.extractedData.extractionMethod
            ],
            "logs": result.logs
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let jsonPath = "\(reportDir)/extraction_\(result.correlationId).json"
            try? jsonString.write(to: URL(fileURLWithPath: jsonPath), atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Performance Metrics
    func getPerformanceMetrics() -> PipelineMetrics {
        return PipelineMetrics(
            totalExtractions: logger.getTotalExtractions(),
            averageProcessingTime: logger.getAverageProcessingTime(),
            pipelineDistribution: logger.getPipelineDistribution(),
            averageConfidence: logger.getAverageConfidence()
        )
    }
}

// MARK: - Unified Expense Data Structure
struct UnifiedExpenseData {
    var merchant: String = ""
    var totalAmount: Double = 0
    var taxAmount: Double = 0
    var currency: String = "EUR"
    var date: Date = Date()
    var category: String = "Other"
    var confidence: Double = 0.5
    var extractionMethod: String = ""
    var rawText: String = ""

    var formattedAmount: String {
        return "\(currency) \(String(format: "%.2f", totalAmount))"
    }
}

// MARK: - Performance Metrics
struct PipelineMetrics {
    let totalExtractions: Int
    let averageProcessingTime: TimeInterval
    let pipelineDistribution: [String: Int]
    let averageConfidence: Double
}