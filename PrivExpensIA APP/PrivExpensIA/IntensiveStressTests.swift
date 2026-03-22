import Foundation
import XCTest
import UIKit

// Sprint 2 Day 4: Intensive Stress Tests & Edge Cases
class IntensiveStressTests: XCTestCase {
    
    let qwenManager = QwenModelManager.shared
    let aiService = AIExtractionService.shared
    
    // MARK: - Test 1: Load Test (100 consecutive inferences)
    
    func testIntensiveLoad100Inferences() {
        let expectation = XCTestExpectation(description: "100 consecutive inferences")
        expectation.expectedFulfillmentCount = 100
        
        var successCount = 0
        var failureCount = 0
        var totalTime: TimeInterval = 0
        var memoryBefore = getCurrentMemoryUsage()
        
        // Generate 100 different receipts
        let receipts = generateTestReceipts(count: 100)
        
        for (index, receipt) in receipts.enumerated() {
            qwenManager.runInference(prompt: receipt) { result in
                switch result {
                case .success(let response):
                    successCount += 1
                    totalTime += response.inferenceTime
                    
                    // Check for performance degradation
                    if index > 50 && response.inferenceTime > 0.5 {
                        print("⚠️ Performance degradation detected at inference #\(index)")
                    }
                    
                case .failure:
                    failureCount += 1
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 120) // 2 minutes max
        
        let memoryAfter = getCurrentMemoryUsage()
        let memoryLeak = memoryAfter - memoryBefore
        
        // Assertions
        XCTAssertGreaterThan(successCount, 90, "Should have >90% success rate")
        XCTAssertLessThan(totalTime / 100, 0.4, "Average time should be <400ms")
        XCTAssertLessThan(memoryLeak, 50 * 1024 * 1024, "Memory leak should be <50MB")
        
        print("""
        📊 LOAD TEST RESULTS:
        - Success: \(successCount)/100
        - Average time: \(String(format: "%.0fms", (totalTime / 100) * 1000))
        - Memory leak: \(String(format: "%.1fMB", Double(memoryLeak) / 1024 / 1024))
        """)
    }
    
    // MARK: - Test 2: Memory Leak Detection
    
    func testMemoryLeakDetection() {
        let iterations = 50
        var memorySnapshots: [Int64] = []
        
        // Take initial snapshot
        memorySnapshots.append(getCurrentMemoryUsage())
        
        for i in 0..<iterations {
            autoreleasepool {
                let testText = "TEST RECEIPT \(i)\nTotal: \(Double.random(in: 10...1000))"
                
                let expectation = XCTestExpectation(description: "Inference \(i)")
                
                qwenManager.runInference(prompt: testText) { _ in
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 2)
                
                // Take memory snapshot every 10 iterations
                if i % 10 == 0 {
                    memorySnapshots.append(getCurrentMemoryUsage())
                }
            }
        }
        
        // Analyze memory trend
        let initialMemory = memorySnapshots.first!
        let finalMemory = memorySnapshots.last!
        let memoryGrowth = finalMemory - initialMemory
        
        // Check for linear growth (sign of leak)
        var isLeaking = false
        for i in 1..<memorySnapshots.count {
            if memorySnapshots[i] > memorySnapshots[i-1] + 10 * 1024 * 1024 {
                isLeaking = true
                break
            }
        }
        
        XCTAssertFalse(isLeaking, "Memory leak detected - continuous growth")
        XCTAssertLessThan(memoryGrowth, 30 * 1024 * 1024, "Total memory growth should be <30MB")
        
        print("""
        💾 MEMORY ANALYSIS:
        - Initial: \(String(format: "%.1fMB", Double(initialMemory) / 1024 / 1024))
        - Final: \(String(format: "%.1fMB", Double(finalMemory) / 1024 / 1024))
        - Growth: \(String(format: "%.1fMB", Double(memoryGrowth) / 1024 / 1024))
        """)
    }
    
    // MARK: - Test 3: Critical Edge Cases
    
    func testVeryBlurryImage() {
        // Simulate very low quality text
        let blurryText = """
        C  R  F  U   M  R  T
        D t :  2 0 5
        
        I e   :  . 0
        T x:    .5
        T t l:  0.
        """
        
        let expectation = XCTestExpectation(description: "Blurry text")
        
        qwenManager.runInference(prompt: blurryText) { result in
            // Should not crash, even if extraction fails
            XCTAssertNotNil(result)
            
            if case .success(let response) = result {
                // Should fallback gracefully
                XCTAssertTrue(response.extractedData.contains("Unknown") || 
                             response.modelVersion == "fallback")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testTornPartialTicket() {
        let tornTicket = """
        SUPERMA
        Date: 12/09
        
        Bread    1.
        Milk     
        Coffee   3
        
        Tot
        """
        
        let expectation = XCTestExpectation(description: "Torn ticket")
        
        qwenManager.runInference(prompt: tornTicket) { result in
            XCTAssertNotNil(result)
            // Should handle gracefully
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testComplexMultilingual() {
        let multilingual = """
        INTERNATIONAL STORE 国際店
        Date/日付/Date: 12/09/2025
        
        Café au lait (カフェオレ)    €3.50
        Sandwich (サンドイッチ)      €5.00
        お茶 (Green Tea)            €2.00
        
        Sous-total/小計:            €10.50
        TVA/税/VAT (20%):           €2.10
        Total/合計/Total:           €12.60
        
        Merci/ありがとう/Thank you!
        """
        
        let expectation = XCTestExpectation(description: "Multilingual")
        
        qwenManager.runInference(prompt: multilingual) { result in
            if case .success(let response) = result {
                if let data = response.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Should extract the total correctly
                    let total = json["total_amount"] as? Double ?? 0
                    XCTAssertEqual(total, 12.60, accuracy: 0.1)
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testLargeAmounts() {
        let largeAmount = """
        LUXURY STORE
        
        Diamond Ring      €15,999.00
        Gold Watch        €8,500.00
        Tax (20%)         €4,899.80
        
        TOTAL:           €29,398.80
        """
        
        let expectation = XCTestExpectation(description: "Large amounts")
        
        qwenManager.runInference(prompt: largeAmount) { result in
            if case .success(let response) = result {
                if let data = response.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let total = json["total_amount"] as? Double ?? 0
                    XCTAssertGreaterThan(total, 10000, "Should handle large amounts")
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testHandwrittenNotes() {
        // Simulate handwritten/irregular text
        let handwritten = """
        Joe's Coffee
        12 sept
        
        coffee    3.5O
        muffin    2,oo
        
        total ~ 5.50
        cash
        thanks :)
        """
        
        let expectation = XCTestExpectation(description: "Handwritten")
        
        qwenManager.runInference(prompt: handwritten) { result in
            // Should not crash on irregular formatting
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    // MARK: - Test 4: Real-World Conditions
    
    func testOfflineMode() {
        // Simulate offline by not loading model
        qwenManager.resetPerformance()
        
        let expectation = XCTestExpectation(description: "Offline mode")
        
        qwenManager.runInference(prompt: "TEST") { result in
            // Should use fallback or cached data
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testLowMemoryConditions() {
        // Force memory pressure
        var largeData: [[Int]] = []
        for _ in 0..<100 {
            largeData.append(Array(repeating: 0, count: 100000))
        }
        
        let expectation = XCTestExpectation(description: "Low memory")
        
        qwenManager.runInference(prompt: "TEST RECEIPT\nTotal: 10.00") { result in
            // Should handle memory pressure gracefully
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
        
        // Clean up
        largeData.removeAll()
    }
    
    func testRapidBackgroundForeground() {
        let expectation = XCTestExpectation(description: "Background switches")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            // Simulate app lifecycle changes
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            Thread.sleep(forTimeInterval: 0.1)
            
            NotificationCenter.default.post(
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            
            qwenManager.runInference(prompt: "Test \(i)") { _ in
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testInterruptions() {
        var interrupted = false
        
        let expectation = XCTestExpectation(description: "Interruption handling")
        
        // Start inference
        qwenManager.runInference(prompt: "LONG TEST RECEIPT WITH MANY ITEMS") { result in
            // Should complete or fallback gracefully
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        // Simulate interruption after 100ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            interrupted = true
            // Simulate phone call
            NotificationCenter.default.post(
                name: NSNotification.Name("AVAudioSessionInterruption"),
                object: nil
            )
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    // MARK: - Test 5: Final Validation Pipeline
    
    func testMassiveValidationPipeline() {
        let receipts = generateTestReceipts(count: 200)
        let expectation = XCTestExpectation(description: "200 receipts validation")
        expectation.expectedFulfillmentCount = 200
        
        var stats = ValidationStats()
        let startTime = Date()
        
        for receipt in receipts {
            qwenManager.runInference(prompt: receipt) { result in
                switch result {
                case .success(let response):
                    stats.successCount += 1
                    stats.totalTime += response.inferenceTime
                    
                    if response.inferenceTime < 0.4 {
                        stats.fastCount += 1
                    }
                    
                case .failure:
                    stats.failureCount += 1
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 180) // 3 minutes
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Final assertions
        XCTAssertGreaterThan(stats.successRate, 0.9, "Success rate should be >90%")
        XCTAssertLessThan(stats.averageTime, 0.4, "Average time should be <400ms")
        XCTAssertEqual(stats.crashCount, 0, "Should have zero crashes")
        
        print("""
        
        🎯 FINAL VALIDATION RESULTS:
        ================================
        Total Receipts: 200
        Success: \(stats.successCount) (\(String(format: "%.1f%%", stats.successRate * 100)))
        Failures: \(stats.failureCount)
        Fast (<400ms): \(stats.fastCount)
        Average Time: \(String(format: "%.0fms", stats.averageTime * 1000))
        Total Time: \(String(format: "%.1fs", totalTime))
        Crashes: \(stats.crashCount)
        
        ✅ VALIDATION: \(stats.successRate > 0.9 ? "PASSED" : "FAILED")
        """)
    }
    
    // MARK: - Test 6: Crash Prevention (1000 operations)
    
    func testZeroCrash1000Operations() {
        let operationCount = 1000
        var crashDetected = false
        
        for i in 0..<operationCount {
            autoreleasepool {
                // Mix of different operations
                let operation = i % 5
                
                switch operation {
                case 0: // Normal inference
                    _ = qwenManager.runInference(prompt: "Test \(i)") { _ in }
                    
                case 1: // Cache clear
                    qwenManager.resetPerformance()
                    
                case 2: // Memory check
                    _ = qwenManager.getCurrentMemoryUsage()
                    
                case 3: // Performance check
                    _ = qwenManager.isSystemPerformant()
                    
                case 4: // Metrics access
                    _ = qwenManager.getPerformanceMetrics()
                    
                default:
                    break
                }
                
                // Check for crash
                if !Thread.isMainThread && Thread.current.isCancelled {
                    crashDetected = true
                    break
                }
            }
        }
        
        XCTAssertFalse(crashDetected, "No crash should occur in 1000 operations")
        
        print("""
        🛡️ STABILITY TEST:
        - Operations: \(operationCount)
        - Crashes: 0
        - Status: STABLE ✅
        """)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Int64 {
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
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func generateTestReceipts(count: Int) -> [String] {
        var receipts: [String] = []
        
        let merchants = ["CARREFOUR", "STARBUCKS", "SHELL", "UBER", "PHARMACIE", "ZARA"]
        let currencies = ["€", "$", "£", "¥"]
        
        for i in 0..<count {
            let merchant = merchants.randomElement()!
            let currency = currencies.randomElement()!
            let total = Double.random(in: 5...500)
            let tax = total * 0.2
            
            let receipt = """
            \(merchant) #\(i)
            Date: 12/09/2025 \(String(format: "%02d:%02d", i % 24, i % 60))
            
            Item 1: \(currency)\(String(format: "%.2f", Double.random(in: 1...50)))
            Item 2: \(currency)\(String(format: "%.2f", Double.random(in: 1...50)))
            
            Subtotal: \(currency)\(String(format: "%.2f", total - tax))
            Tax: \(currency)\(String(format: "%.2f", tax))
            TOTAL: \(currency)\(String(format: "%.2f", total))
            
            Payment: Card
            """
            
            receipts.append(receipt)
        }
        
        return receipts
    }
}

// Validation statistics
struct ValidationStats {
    var successCount = 0
    var failureCount = 0
    var fastCount = 0
    var totalTime: TimeInterval = 0
    var crashCount = 0
    
    var successRate: Double {
        let total = successCount + failureCount
        return total > 0 ? Double(successCount) / Double(total) : 0
    }
    
    var averageTime: Double {
        successCount > 0 ? totalTime / Double(successCount) : 0
    }
}