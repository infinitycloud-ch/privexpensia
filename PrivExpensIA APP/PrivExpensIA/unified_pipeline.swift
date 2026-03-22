import Foundation
import UIKit
import Combine

// MARK: - Pipeline Errors
enum PipelineError: Error, LocalizedError {
    case extractionFailed
    case ocrFailed
    case noDataExtracted

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract data from receipt"
        case .ocrFailed:
            return "OCR processing failed"
        case .noDataExtracted:
            return "No valid data could be extracted"
        }
    }
}

// MARK: - 🚀 Sprint 3.2: Extraction Mode Selector
// Controls pipeline behavior for testing and optimization

/// Defines the extraction strategy for the unified pipeline
public enum ExtractionMode {
    case auto           // Default: Smart "Fusée" mode - Parser first, Cloud Vision fallback if configured
    case forceParser    // Force deterministic parser only (no cloud)
    case forceCloud     // Force Cloud Vision only (Groq/OpenAI) - bypass parser

    var description: String {
        switch self {
        case .auto:
            return "auto (Parser → Cloud fallback)"
        case .forceParser:
            return "forceParser (Parser Only)"
        case .forceCloud:
            return "forceCloud (Cloud Vision)"
        }
    }
}

// MARK: - Unified Pipeline Manager
// Sprint 9: Single entry point for all OCR/AI extraction
// Uses Parser (offline) + Cloud Vision (Groq/OpenAI) for fallback

class UnifiedPipelineManager {
    static let shared = UnifiedPipelineManager()

    private let logger = PipelineLogger.shared
    private let ocrService = OCRService.shared
    private let cloudVisionService = CloudVisionService.shared
    private let expenseParser = ExpenseParser.shared

    private init() {
        logger.log("🔧 UnifiedPipelineManager initialized", level: .info)
    }

    // MARK: - Pipeline Modes
    enum PipelineMode: String, CaseIterable {
        case cloud = "cloud"         // CloudVisionService - Groq/OpenAI
        case parser = "parser"       // ExpenseParser - Regex/Heuristics
        case auto = "auto"           // Automatic selection: Parser first, Cloud fallback

        var description: String {
            switch self {
            case .cloud: return "Cloud Vision (Groq/OpenAI)"
            case .parser: return "Regex/Heuristics Parser"
            case .auto: return "Auto (Parser → Cloud)"
            }
        }
    }

    // MARK: - Unified Extraction Result
    public struct UnifiedResult {
        public let extractedData: UnifiedExpenseData
        public let pipelineUsed: String  // 🚀 Sprint 3.2: Changed to String to support ExtractionMode
        public let confidence: Double
        public let processingTime: TimeInterval
        public let logs: [String]
        public let screenshot: UIImage?
        public let correlationId: String

        public var isHighConfidence: Bool { confidence >= 0.7 }
        public var shouldUseFallback: Bool { confidence < 0.5 }

        // 🚀 Sprint 3.2: Public initializer
        public init(extractedData: UnifiedExpenseData, pipelineUsed: String, confidence: Double,
                   processingTime: TimeInterval, logs: [String], screenshot: UIImage?, correlationId: String) {
            self.extractedData = extractedData
            self.pipelineUsed = pipelineUsed
            self.confidence = confidence
            self.processingTime = processingTime
            self.logs = logs
            self.screenshot = screenshot
            self.correlationId = correlationId
        }
    }

    // MARK: - 🚀 Sprint 3.2: Main Unified Extraction Entry Point
    /// Extracts expense data from image using the specified extraction mode
    /// - Parameters:
    ///   - image: The receipt image to process
    ///   - extractionMode: Strategy to use (.auto, .forceParser, .forceCloud)
    ///   - completion: Result callback with extracted data
    func extractExpense(from image: UIImage,
                       extractionMode: ExtractionMode = .auto,
                       completion: @escaping (Result<UnifiedResult, Error>) -> Void) {

        let correlationId = UUID().uuidString
        let startTime = Date()
        // Les logs sont maintenant gérés par le logger

        // 🚀 Sprint 3.2: Log the selected extraction mode
        logger.log("🎯 Starting unified extraction - Mode: \(extractionMode.description) - ID: \(correlationId)", level: .info)
        logger.log("🚀 [UNIFIED_PIPELINE] Using mode: \(extractionMode.description)", level: .info)

        // Step 1: OCR Processing (always first)
        logger.log("📖 Step 1: OCR Processing", level: .debug)
        logger.log("📖 OCR Processing started", level: .info)

        ocrService.processImage(image) { [weak self] ocrResult in
            guard let self = self else { return }

            switch ocrResult {
            case .success(let ocrData):
                self.logger.log("✅ OCR completed: \(ocrData.text.count) chars, confidence: \(ocrData.confidence)", level: .info)

                // 🚀 Sprint 3.2: Execute extraction based on selected mode
                self.executeExtractionMode(extractionMode: extractionMode,
                                         ocrData: ocrData,
                                         image: image,
                                         correlationId: correlationId) { result in

                    let totalTime = Date().timeIntervalSince(startTime)

                    switch result {
                    case .success(let expenseData):
                        self.logger.log("🎉 Extraction completed in \(String(format: "%.2f", totalTime))s", level: .info)

                        let unifiedResult = UnifiedResult(
                            extractedData: expenseData,
                            pipelineUsed: extractionMode.description,
                            confidence: expenseData.confidence,
                            processingTime: totalTime,
                            logs: self.logger.getAllLogs(),
                            screenshot: image,
                            correlationId: correlationId
                        )

                        // Save correlation data
                        self.saveCorrelationData(unifiedResult)

                        completion(.success(unifiedResult))

                    case .failure(let error):
                        self.logger.log("❌ Pipeline failed: \(error.localizedDescription)", level: .error)
                        self.logger.log("❌ Pipeline failed: \(error)", level: .error)
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                logger.log("❌ OCR failed: \(error.localizedDescription)", level: .error)
                self.logger.log("❌ OCR failed: \(error)", level: .error)
                completion(.failure(error))
            }
        }
    }

    // MARK: - 🚀 Sprint 3.2: Extraction Mode Execution Logic
    /// Executes the appropriate extraction strategy based on the selected mode
    private func executeExtractionMode(extractionMode: ExtractionMode,
                                     ocrData: ExtractedData,
                                     image: UIImage,
                                     correlationId: String,
                                     completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logger.log("🚀 [EXTRACTION_MODE] Executing mode: \(extractionMode.description)", level: .info)

        switch extractionMode {
        case .auto:
            // 🚀 SMART MODE: Parser first, Cloud Vision fallback if configured
            logger.log("🚀 [AUTO] Starting smart pipeline - Parser → Cloud fallback", level: .info)
            executeParserPipeline(ocrData: ocrData) { [weak self] result in
                switch result {
                case .success(let parserData):
                    // Accept ANY currency with valid amount
                    if parserData.totalAmount > 0 {
                        if parserData.currency == "CHF" {
                            self?.logger.log("🚀 [AUTO] ✅ Swiss deterministic SUCCESS - Pipeline complete", level: .swiss)
                        } else {
                            self?.logger.log("🚀 [AUTO] ✅ Parser SUCCESS (\(parserData.currency) \(parserData.totalAmount)) - Pipeline complete", level: .info)
                        }
                        completion(.success(parserData))
                        return
                    }

                    // Parser found no amount → Fallback to Cloud Vision if configured
                    if CloudVisionService.shared.isEnabled && CloudVisionService.shared.isConfigured {
                        self?.logger.log("🚀 [AUTO] Parser found no amount, falling back to Cloud Vision", level: .info)
                        self?.executeCloudVisionPipeline(image: image, completion: completion)
                    } else {
                        self?.logger.log("🚀 [AUTO] Parser found no amount, Cloud Vision not configured - returning parser result", level: .warning)
                        completion(.success(parserData))
                    }

                case .failure(_):
                    // Parser failed → Fallback to Cloud Vision if configured
                    if CloudVisionService.shared.isEnabled && CloudVisionService.shared.isConfigured {
                        self?.logger.log("🚀 [AUTO] Parser failed, falling back to Cloud Vision", level: .warning)
                        self?.executeCloudVisionPipeline(image: image, completion: completion)
                    } else {
                        self?.logger.log("🚀 [AUTO] Parser failed, Cloud Vision not configured", level: .error)
                        completion(.failure(PipelineError.extractionFailed))
                    }
                }
            }

        case .forceParser:
            // 🔧 FORCE PARSER MODE: Use deterministic parser only (offline)
            logger.log("🔧 [FORCE_PARSER] Using parser only - No cloud fallback", level: .info)
            executeParserPipeline(ocrData: ocrData, completion: completion)

        case .forceCloud:
            // ☁️ FORCE CLOUD MODE: Skip parser, use Cloud Vision directly
            logger.log("☁️ [FORCE_CLOUD] Using Cloud Vision only - Bypassing parser", level: .info)
            executeCloudVisionPipeline(image: image, completion: completion)
        }
    }

    // MARK: - Pipeline Mode Selection Logic (Legacy - not used)
    private func determinePipelineMode(preferredMode: PipelineMode,
                                     ocrData: ExtractedData) -> PipelineMode {

        switch preferredMode {
        case .auto:
            // Auto-selection: Swiss receipts use parser, others can use cloud
            let text = ocrData.text.lowercased()

            // Swiss receipts detection - force parser for reliability
            if text.contains("chf") || text.contains("fr.") ||
               text.contains("migros") || text.contains("coop") {
                logger.log("🇨🇭 Swiss receipt detected -> Parser mode", level: .swiss)
                return .parser
            }

            // If cloud is configured and high confidence, use cloud
            if CloudVisionService.shared.isConfigured && ocrData.confidence > 0.8 {
                logger.log("☁️ High OCR confidence + Cloud configured -> Cloud mode", level: .info)
                return .cloud
            }

            // Default to parser
            logger.log("📝 Using parser mode", level: .info)
            return .parser

        default:
            logger.log("⚙️ Using preferred mode: \(preferredMode.description)", level: .info)
            return preferredMode
        }
    }

    // MARK: - Pipeline Execution (Legacy - not used directly)
    private func executePipeline(mode: PipelineMode,
                               ocrData: ExtractedData,
                               image: UIImage,
                               correlationId: String,
                               completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logger.log("🚀 Pipeline Execution - Mode: \(mode.description)", level: .info)

        // Start with parser
        executeParserPipeline(ocrData: ocrData) { [weak self] result in
            switch result {
            case .success(let parserData):
                // Accept ANY currency with valid amount
                if parserData.totalAmount > 0 {
                    self?.logger.log("✅ Parser SUCCESS - Pipeline terminé", level: .info)
                    completion(.success(parserData))
                    return
                }

                // Parser found no amount → Fallback based on mode
                switch mode {
                case .cloud, .auto:
                    if CloudVisionService.shared.isConfigured {
                        self?.executeCloudVisionPipeline(image: image, completion: completion)
                    } else {
                        completion(.success(parserData))
                    }

                case .parser:
                    // Mode parser explicite → utiliser le résultat
                    completion(.success(parserData))
                }

            case .failure(_):
                self?.logger.log("❌ Parser failed - Fallback vers Cloud", level: .error)
                if CloudVisionService.shared.isConfigured {
                    self?.executeCloudVisionPipeline(image: image, completion: completion)
                } else {
                    completion(.failure(PipelineError.extractionFailed))
                }
            }
        }
    }

    // MARK: - Cloud Vision Pipeline (Groq/OpenAI)
    private func executeCloudVisionPipeline(image: UIImage,
                                           completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logger.log("☁️ Cloud Vision processing via \(cloudVisionService.selectedProvider.displayName)...", level: .info)

        cloudVisionService.analyzeReceipt(image: image) { [weak self] result in
            switch result {
            case .success(let cloudResult):
                self?.logger.log("✅ Cloud Vision completed: \(cloudResult.merchant) - \(cloudResult.amount) \(cloudResult.currency)", level: .info)

                // Convert CloudVisionService.ExtractionResult to UnifiedExpenseData
                var expenseData = UnifiedExpenseData()
                expenseData.merchant = cloudResult.merchant
                expenseData.totalAmount = cloudResult.amount
                expenseData.taxAmount = cloudResult.taxAmount
                expenseData.currency = cloudResult.currency
                expenseData.category = cloudResult.category
                expenseData.date = cloudResult.date ?? Date()
                expenseData.confidence = cloudResult.confidence
                expenseData.extractionMethod = "CloudVision-\(cloudResult.provider.rawValue)"

                self?.logger.log("📊 Cloud Vision data: \(expenseData.merchant) - \(expenseData.totalAmount)", level: .info)
                completion(.success(expenseData))

            case .failure(let error):
                self?.logger.log("❌ Cloud Vision failed: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            }
        }
    }

    // MARK: - 🚀 FUSÉE ÉTAGE 1: Parser Pipeline (Swiss Deterministic First)
    private func executeParserPipeline(ocrData: ExtractedData,
                                     completion: @escaping (Result<UnifiedExpenseData, Error>) -> Void) {

        logger.log("🚀 [ÉTAGE 1] FUSÉE - Parser déterministe processing...", level: .info)

        // Use enhanced parser with Swiss fallback (ÉTAGE 1 priority)
        let parsedExpense = expenseParser.parseFromOCRResult(ocrData)
        logger.log("✅ Parser completed: \(parsedExpense.merchant) - \(parsedExpense.formattedTotal)", level: .info)

        var expenseData = parseParserResponse(parsedExpense: parsedExpense, ocrData: ocrData)

        // 🚀 LOGIQUE FUSÉE: Si Swiss déterministe a trouvé CHF + montant > 0, ARRÊTER
        if expenseData.currency == "CHF" && expenseData.totalAmount > 0 {
            logger.log("🚀 [ÉTAGE 1] SUCCÈS DÉTERMINISTE - CHF \(expenseData.totalAmount) trouvé, arrêt du pipeline", level: .swiss)
            expenseData.extractionMethod = "FUSÉE-ÉTAGE-1-SWISS"
            expenseData.confidence = 0.95 // Haute confiance pour Swiss déterministe
            completion(.success(expenseData))
            return
        }

        logger.log("🔍 [ÉTAGE 1] Pas de résultat Swiss déterministe, préparation pour ÉTAGE 2 (IA)", level: .info)
        logger.log("📊 Unified parser data: confidence \(expenseData.confidence)", level: .info)

        completion(.success(expenseData))
    }

    // MARK: - Response Parsers

    /// Parse amount from Double or String (e.g., "28.00 CHF" -> 28.0)
    private func parseAmountValue(_ value: Any?) -> Double {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let stringValue = value as? String {
            // Remove currency symbols and text, keep only numbers and decimal
            let cleanedString = stringValue
                .replacingOccurrences(of: ",", with: ".")
                .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .joined()
            if let parsed = Double(cleanedString) {
                return parsed
            }
        }
        return 0.0
    }

    /// Validate that an amount appears in the OCR text with decimals (not just as address)
    private func validateAmountInText(_ amount: Double, ocrText: String) -> Bool {
        guard amount > 0 else { return false }

        // Format as string with 2 decimals
        let amountStr = String(format: "%.2f", amount)
        let amountStrComma = amountStr.replacingOccurrences(of: ".", with: ",")
        let intPart = Int(amount)

        // Check if amount appears with decimals in OCR text
        if ocrText.contains(amountStr) || ocrText.contains(amountStrComma) {
            return true  // Amount found with decimals - valid
        }

        // Check if just the integer part appears (potential address)
        let intPattern = "\\b\(intPart)\\b"
        if let regex = try? NSRegularExpression(pattern: intPattern),
           regex.firstMatch(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText)) != nil {
            // Integer appears but not with decimals - likely an address
            logger.log("⚠️ [VALIDATION] Amount \(amount) appears as integer only - likely address", level: .warning)
            return false
        }

        return true  // Not found at all, let it through (AI might have calculated it)
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
            "pipeline_used": result.pipelineUsed,
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
    var currency: String = "CHF"
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