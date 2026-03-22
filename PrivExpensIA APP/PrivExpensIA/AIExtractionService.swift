import Foundation
import Combine
import UIKit

// AI-Powered Extraction Service
// Orchestrates OCR → MLX/AI → Structured Data pipeline

class AIExtractionService {
    static let shared = AIExtractionService()

    private let ocrService = OCRService.shared
    private let mlxService = MLXService.shared
    private let coreDataManager = CoreDataManager.shared

    private var cancellables = Set<AnyCancellable>()
    var forceQwenMode: Bool = false  // Toggle pour forcer le mode Qwen

    private init() {
        initializeAI()
    }
    
    // Pipeline stages
    enum PipelineStage {
        case idle
        case ocr
        case preprocessing
        case aiInference
        case postprocessing
        case saving
        case complete
    }
    
    @Published private(set) var currentStage: PipelineStage = .idle
    @Published private(set) var progress: Double = 0.0
    
    // Initialize AI models
    private func initializeAI() {
        mlxService.initializeModel { result in
            switch result {
            case .success:
                break
            case .failure:
                break
            }
        }
    }
    
    // Main extraction pipeline
    func extractExpenseData(from image: UIImage,
                           completion: @escaping (Result<EnhancedExpenseData, Error>) -> Void) {

        let pipelineStart = Date()
        var enhancedData = EnhancedExpenseData()

        // Stage 1: OCR
        currentStage = .ocr
        progress = 0.2
        
        ocrService.processImage(image) { [weak self] ocrResult in
            switch ocrResult {
            case .success(let ocrData):
                enhancedData.rawText = ocrData.text
                enhancedData.ocrTime = ocrData.processingTime
                enhancedData.ocrConfidence = Double(ocrData.confidence)
                

                // Stage 2: Preprocessing
                self?.currentStage = .preprocessing
                self?.progress = 0.4

                let preprocessedText = self?.preprocessText(ocrData.text) ?? ocrData.text

                // Stage 3: AI Inference
                self?.currentStage = .aiInference
                self?.progress = 0.6

                // Choisir le mode selon forceQwenMode
                if self?.forceQwenMode == true {
                    // Mode Qwen - Utiliser le vrai modèle MLX
                    self?.mlxService.runInference(prompt: preprocessedText) { mlxResult in
                    switch mlxResult {
                    case .success(let mlxData):
                        // Stage 4: Postprocessing
                        self?.currentStage = .postprocessing
                        self?.progress = 0.8
                        
                        enhancedData.merchant = mlxData.merchant
                        enhancedData.totalAmount = mlxData.totalAmount
                        enhancedData.taxAmount = mlxData.taxAmount
                        enhancedData.date = mlxData.date
                        enhancedData.category = mlxData.category
                        enhancedData.items = mlxData.items
                        enhancedData.aiConfidence = mlxData.confidence
                        enhancedData.aiTime = mlxData.processingTime
                        
                        // Validate and enhance data
                        enhancedData = self?.validateAndEnhance(enhancedData) ?? enhancedData
                        
                        // Stage 5: Save to Core Data
                        self?.currentStage = .saving
                        self?.progress = 0.9
                        
                        self?.saveToDatabase(enhancedData, image: image)
                        
                        // Complete
                        self?.currentStage = .complete
                        self?.progress = 1.0
                        
                        enhancedData.totalPipelineTime = Date().timeIntervalSince(pipelineStart)
                        
                        completion(.success(enhancedData))
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                } else {
                    // Mode Rapide - Utiliser QwenModelManager avec fallback
                    QwenModelManager.shared.runInference(prompt: preprocessedText) { quickResult in
                        switch quickResult {
                        case .success(let response):

                            // Parser le JSON de la réponse avec gestion d'erreurs
                            if let data = response.extractedData.data(using: .utf8) {
                                do {
                                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                                        enhancedData.merchant = json["merchant"] as? String ?? "Unknown"
                                        enhancedData.totalAmount = json["total_amount"] as? Double ?? 0
                                        enhancedData.taxAmount = json["tax_amount"] as? Double ?? 0
                                        enhancedData.category = json["category"] as? String ?? "Other"
                                        enhancedData.currency = json["currency"] as? String ?? "CHF"

                                        // Confiance réaliste basée sur parsing
                                        if let confidence = json["confidence"] as? Double {
                                            enhancedData.aiConfidence = confidence
                                        } else {
                                            enhancedData.aiConfidence = 0.3 // Confiance faible si pas spécifiée
                                        }

                                        enhancedData.aiTime = response.inferenceTime

                                    } else {
                                        enhancedData.aiConfidence = 0.1
                                    }
                                } catch {
                                    enhancedData.aiConfidence = 0.1
                                }
                            } else {
                                enhancedData.aiConfidence = 0.1
                            }

                            // Validate and enhance data
                            enhancedData = self?.validateAndEnhance(enhancedData) ?? enhancedData

                            // Stage 5: Save to Core Data
                            self?.currentStage = .saving
                            self?.progress = 0.9

                            self?.saveToDatabase(enhancedData, image: image)

                            // Complete
                            self?.currentStage = .complete
                            self?.progress = 1.0

                            enhancedData.totalPipelineTime = Date().timeIntervalSince(pipelineStart)

                            completion(.success(enhancedData))

                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Preprocess text for AI model
    private func preprocessText(_ text: String) -> String {
        var processed = text
        
        // Remove excessive whitespace
        processed = processed.replacingOccurrences(of: #"\s+"#, with: " ", 
                                                  options: .regularExpression)
        
        // Normalize currency symbols
        processed = processed.replacingOccurrences(of: "€", with: "EUR ")
        processed = processed.replacingOccurrences(of: "$", with: "USD ")
        processed = processed.replacingOccurrences(of: "£", with: "GBP ")
        processed = processed.replacingOccurrences(of: "¥", with: "JPY ")
        
        // Standardize decimal separators
        processed = processed.replacingOccurrences(of: ",", with: ".")
        
        // Add structure hints for AI
        if !processed.lowercased().contains("total") && processed.contains(#"\d+\.\d{2}"#) {
            processed += "\n[Hint: Look for total amount in the text]"
        }
        
        return processed
    }
    
    // Validate and enhance extracted data
    private func validateAndEnhance(_ data: EnhancedExpenseData) -> EnhancedExpenseData {
        var enhanced = data
        
        // Validate amounts
        if enhanced.taxAmount > enhanced.totalAmount {
            enhanced.taxAmount = enhanced.totalAmount * 0.1 // Default to 10% tax
        }
        
        // Calculate subtotal if missing
        if enhanced.subtotal == 0 && enhanced.totalAmount > 0 {
            enhanced.subtotal = enhanced.totalAmount - enhanced.taxAmount
        }
        
        // Enhance merchant name
        enhanced.merchant = cleanMerchantName(enhanced.merchant)
        
        // Add metadata
        enhanced.currency = detectCurrency(from: enhanced.rawText)
        enhanced.paymentMethod = detectPaymentMethod(from: enhanced.rawText)
        
        // Calculate overall confidence
        enhanced.overallConfidence = (enhanced.ocrConfidence + enhanced.aiConfidence) / 2
        
        return enhanced
    }
    
    private func cleanMerchantName(_ name: String) -> String {
        var cleaned = name
        
        // Remove common prefixes/suffixes
        let removePatterns = ["Inc.", "LLC", "Ltd.", "Corp.", "®", "™"]
        for pattern in removePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }
        
        // Trim and capitalize
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    // MARK: - Delegated to TextExtractionUtils (unified utilities)
    private func detectCurrency(from text: String) -> String {
        return TextExtractionUtils.shared.detectCurrency(from: text)
    }

    private func detectPaymentMethod(from text: String) -> String {
        return TextExtractionUtils.shared.detectPaymentMethod(from: text)
    }
    
    // Save to Core Data
    private func saveToDatabase(_ data: EnhancedExpenseData, image: UIImage?) {
        // Convert to ExtractedData for compatibility
        let extractedData = ExtractedData(
            text: data.rawText,
            language: "multi",
            processingTime: data.totalPipelineTime,
            confidence: Float(data.overallConfidence)
        )
        
        coreDataManager.saveOCRResult(extractedData: extractedData, image: image)
    }
    
    // Batch processing for multiple receipts
    func processBatch(_ images: [UIImage], 
                     progress: @escaping (Double) -> Void,
                     completion: @escaping ([EnhancedExpenseData]) -> Void) {
        
        var results: [EnhancedExpenseData] = []
        let total = Double(images.count)
        
        let group = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            group.enter()
            
            extractExpenseData(from: image) { result in
                if case .success(let data) = result {
                    results.append(data)
                }
                
                progress(Double(index + 1) / total)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}

// Enhanced data structure with AI insights
struct EnhancedExpenseData {
    // Basic fields
    var merchant: String = ""
    var totalAmount: Double = 0
    var taxAmount: Double = 0
    var subtotal: Double = 0
    var date: Date = Date()
    var category: String = ""
    
    // Items
    var items: [ExpenseItem] = []
    
    // Enhanced fields
    var currency: String = "CHF"
    var paymentMethod: String = "Unknown"
    var rawText: String = ""
    
    // Confidence metrics
    var ocrConfidence: Double = 0
    var aiConfidence: Double = 0
    var overallConfidence: Double = 0
    
    // Performance metrics
    var ocrTime: TimeInterval = 0
    var aiTime: TimeInterval = 0
    var totalPipelineTime: TimeInterval = 0
    
    // Computed properties
    var isHighConfidence: Bool {
        overallConfidence > 0.8
    }
    
    var performanceGrade: String {
        if totalPipelineTime < 2 { return "A" }
        if totalPipelineTime < 3 { return "B" }
        if totalPipelineTime < 5 { return "C" }
        return "D"
    }
}