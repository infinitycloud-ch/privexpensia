import Foundation

// Performance tests for Qwen2.5 model
class QwenPerformanceTests {
    
    static func runAllTests(completion: @escaping (TestReport) -> Void) {
        var report = TestReport()
        let testSamples = getTestSamples()
        
        let group = DispatchGroup()
        
        // Test 1: Model loading time
        group.enter()
        testModelLoading { result in
            report.modelLoadingTime = result
            group.leave()
        }
        
        // Test 2: Inference performance
        group.enter()
        testInferencePerformance(samples: testSamples) { results in
            report.inferenceResults = results
            group.leave()
        }
        
        // Test 3: Memory usage
        group.enter()
        testMemoryUsage { usage in
            report.memoryUsage = usage
            group.leave()
        }
        
        // Test 4: Accuracy
        group.enter()
        testExtractionAccuracy(samples: testSamples) { accuracy in
            report.accuracy = accuracy
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(report)
        }
    }
    
    private static func testModelLoading(completion: @escaping (TimeInterval) -> Void) {
        let startTime = Date()
        
        QwenModelManager.shared.downloadModel(progress: { _ in }) { result in
            let loadTime = Date().timeIntervalSince(startTime)
            completion(loadTime)
        }
    }
    
    private static func testInferencePerformance(samples: [TestSample], 
                                                 completion: @escaping ([InferenceResult]) -> Void) {
        var results: [InferenceResult] = []
        let qwenManager = QwenModelManager.shared
        
        for sample in samples {
            let startTime = Date()
            
            qwenManager.runInference(prompt: sample.text) { result in
                let inferenceTime = Date().timeIntervalSince(startTime)
                
                let inferenceResult = InferenceResult(
                    sampleName: sample.name,
                    inferenceTime: inferenceTime,
                    success: result.isSuccess,
                    underTarget: inferenceTime < 0.5
                )
                
                results.append(inferenceResult)
                
                if results.count == samples.count {
                    completion(results)
                }
            }
        }
    }
    
    private static func testMemoryUsage(completion: @escaping (MemoryUsage) -> Void) {
        let beforeMemory = getCurrentMemoryUsage()
        
        // Run inference to measure memory impact
        let qwenManager = QwenModelManager.shared
        qwenManager.runInference(prompt: "Test receipt") { _ in
            let afterMemory = getCurrentMemoryUsage()
            
            let usage = MemoryUsage(
                beforeInference: beforeMemory,
                afterInference: afterMemory,
                delta: afterMemory - beforeMemory,
                underTarget: (afterMemory - beforeMemory) < 200 // < 200MB target
            )
            
            completion(usage)
        }
    }
    
    private static func testExtractionAccuracy(samples: [TestSample], 
                                              completion: @escaping (AccuracyReport) -> Void) {
        var correctExtractions = 0
        var totalFields = 0
        let qwenManager = QwenModelManager.shared
        
        for sample in samples {
            qwenManager.runInference(prompt: sample.text) { result in
                if case .success(let response) = result {
                    // Parse JSON response
                    if let data = response.extractedData.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Check merchant
                        if let merchant = json["merchant"] as? String,
                           !merchant.isEmpty && merchant != "Unknown Merchant" {
                            correctExtractions += 1
                        }
                        totalFields += 1
                        
                        // Check amount
                        if let amount = json["total_amount"] as? Double,
                           amount > 0 {
                            correctExtractions += 1
                        }
                        totalFields += 1
                        
                        // Check category
                        if let category = json["category"] as? String,
                           category != "Other" {
                            correctExtractions += 1
                        }
                        totalFields += 1
                    }
                }
            }
        }
        
        let accuracy = totalFields > 0 ? Double(correctExtractions) / Double(totalFields) : 0
        
        completion(AccuracyReport(
            correctExtractions: correctExtractions,
            totalFields: totalFields,
            accuracy: accuracy,
            meetsTarget: accuracy > 0.8
        ))
    }
    
    private static func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0
    }
    
    private static func getTestSamples() -> [TestSample] {
        return [
            TestSample(
                name: "French Restaurant",
                text: """
                LE BISTROT PARISIEN
                123 Rue de la République
                75001 Paris
                
                Date: 12/09/2025 19:30
                
                Entrée du jour      12.50€
                Plat principal      18.90€
                Dessert             8.50€
                Vin rouge           6.00€
                
                Sous-total:        45.90€
                TVA 20%:            9.18€
                TOTAL:             55.08€
                
                Paiement: CB Visa ****1234
                Merci de votre visite!
                """
            ),
            TestSample(
                name: "Supermarket",
                text: """
                CARREFOUR MARKET
                Centre Commercial
                Date: 10/09/2025
                
                Pain                1.20
                Lait 1L            1.50
                Pommes 1kg         2.80
                Fromage            4.50
                
                TOTAL             10.00
                TVA 5.5%           0.55
                
                Espèces:          20.00
                Rendu:            10.00
                """
            ),
            TestSample(
                name: "Uber Ride",
                text: """
                UBER
                
                Trip Date: Sep 11, 2025
                Pick up: 123 Main St
                Drop off: Airport
                
                Base Fare:         $35.00
                Time:              $5.50
                Distance:          $12.30
                
                Subtotal:          $52.80
                Service Fee:       $2.50
                
                Total:             $55.30
                
                Payment: Apple Pay
                """
            ),
            TestSample(
                name: "Pharmacy",
                text: """
                PHARMACIE CENTRALE
                
                12/09/2025 14:23
                
                Paracetamol 500mg   4.50€
                Vitamines C         8.90€
                Pansements         3.20€
                
                Total HT:          16.60€
                TVA 5.5%:           0.91€
                TOTAL TTC:         17.51€
                
                CB Mastercard
                """
            ),
            TestSample(
                name: "Coffee Shop",
                text: """
                STARBUCKS COFFEE
                
                09/12/2025 08:15 AM
                
                Cappuccino Grande   4.95
                Croissant          2.50
                
                Subtotal:          7.45
                Tax:               0.65
                Total:             8.10
                
                Visa Debit ****5678
                Thank you!
                """
            ),
            TestSample(
                name: "Gas Station",
                text: """
                SHELL STATION
                
                Date: 2025-09-10
                
                Unleaded 95
                Litres: 45.23
                Price/L: 1.85€
                
                Amount:           83.68€
                
                Payment: Credit Card
                """
            ),
            TestSample(
                name: "Cinema",
                text: """
                AMC THEATERS
                
                Sep 11, 2025 7:30PM
                
                Adult Ticket x2    $28.00
                Popcorn Large      $8.50
                Soda x2            $10.00
                
                Subtotal:          $46.50
                Tax:               $3.72
                Total:             $50.22
                
                Mastercard ****9012
                """
            ),
            TestSample(
                name: "Electric Bill",
                text: """
                EDF ÉLECTRICITÉ
                
                Facture du 01/09/2025
                
                Consommation:      125 kWh
                Prix/kWh:          0.18€
                
                Montant HT:        22.50€
                TVA 20%:            4.50€
                TOTAL TTC:         27.00€
                
                Prélèvement automatique
                """
            ),
            TestSample(
                name: "Clothing Store",
                text: """
                ZARA
                
                12/09/2025
                
                T-Shirt            19.99
                Jeans              49.99
                Jacket             89.99
                
                Subtotal:         159.97
                VAT 20%:           31.99
                Total:            191.96
                
                Card Payment
                """
            ),
            TestSample(
                name: "Train Ticket",
                text: """
                SNCF
                
                Billet TGV
                Paris → Lyon
                12/09/2025 14:30
                
                Tarif Normal:      75.00€
                
                Paiement CB
                """
            )
        ]
    }
}

// Test data structures
struct TestSample {
    let name: String
    let text: String
}

struct TestReport {
    var modelLoadingTime: TimeInterval = 0
    var inferenceResults: [InferenceResult] = []
    var memoryUsage: MemoryUsage = MemoryUsage()
    var accuracy: AccuracyReport = AccuracyReport()
    
    var summary: String {
        let avgInferenceTime = inferenceResults.isEmpty ? 0 : 
            inferenceResults.reduce(0) { $0 + $1.inferenceTime } / Double(inferenceResults.count)
        
        let passedTests = inferenceResults.filter { $0.underTarget }.count
        
        return """
        📊 QWEN2.5 PERFORMANCE REPORT
        ================================
        
        🚀 Model Loading: \(String(format: "%.2f", modelLoadingTime))s
        
        ⚡ Inference Performance:
        - Average: \(String(format: "%.3f", avgInferenceTime))s
        - Under 500ms: \(passedTests)/\(inferenceResults.count) tests
        - Success Rate: \(inferenceResults.filter { $0.success }.count)/\(inferenceResults.count)
        
        💾 Memory Usage:
        - Before: \(String(format: "%.1f", memoryUsage.beforeInference))MB
        - After: \(String(format: "%.1f", memoryUsage.afterInference))MB
        - Delta: \(String(format: "%.1f", memoryUsage.delta))MB
        - Under 200MB: \(memoryUsage.underTarget ? "✅" : "❌")
        
        🎯 Accuracy:
        - Correct: \(accuracy.correctExtractions)/\(accuracy.totalFields)
        - Rate: \(String(format: "%.1f", accuracy.accuracy * 100))%
        - Target Met (>80%): \(accuracy.meetsTarget ? "✅" : "❌")
        
        ✅ Overall: \(isTestPassed ? "PASSED" : "FAILED")
        """
    }
    
    var isTestPassed: Bool {
        let avgInferenceTime = inferenceResults.isEmpty ? 1.0 :
            inferenceResults.reduce(0) { $0 + $1.inferenceTime } / Double(inferenceResults.count)
        
        return avgInferenceTime < 0.5 && 
               memoryUsage.underTarget && 
               accuracy.meetsTarget
    }
}

struct InferenceResult {
    let sampleName: String
    let inferenceTime: TimeInterval
    let success: Bool
    let underTarget: Bool
}

struct MemoryUsage {
    var beforeInference: Double = 0
    var afterInference: Double = 0
    var delta: Double = 0
    var underTarget: Bool = true
}

struct AccuracyReport {
    var correctExtractions: Int = 0
    var totalFields: Int = 0
    var accuracy: Double = 0
    var meetsTarget: Bool = false
}

extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}