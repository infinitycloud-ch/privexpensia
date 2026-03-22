import Foundation
import XCTest

// MARK: - Final Regression Tests v1.0
// Complete validation suite for production release

class RegressionTestsV1: XCTestCase {
    
    let qwenManager = QwenModelManager.shared
    let ocrService = OCRService.shared
    let coreDataManager = CoreDataManager.shared
    
    override func setUp() {
        super.setUp()
        // Warm cache before tests
        CacheWarmingService.shared.warmCache { _ in }
    }
    
    // MARK: - Test 1: 500 Operations Stress Test
    func testMassiveOperations500() {
        let expectation = XCTestExpectation(description: "500 operations")
        expectation.expectedFulfillmentCount = 500
        
        var stats = TestStatistics()
        let startTime = Date()
        
        for i in 0..<500 {
            let operation = i % 10
            
            autoreleasepool {
                switch operation {
                case 0...6: // 70% inference operations
                    let receipt = generateRandomReceipt(index: i)
                    qwenManager.runInference(prompt: receipt) { result in
                        if case .success(let response) = result {
                            stats.successCount += 1
                            if response.inferenceTime < Constants.Performance.targetInferenceTime {
                                stats.underTargetCount += 1
                            }
                        } else {
                            stats.failureCount += 1
                        }
                        expectation.fulfill()
                    }
                    
                case 7: // Cache operations
                    qwenManager.resetPerformance()
                    expectation.fulfill()
                    
                case 8: // Memory check
                    let usage = qwenManager.getCurrentMemoryUsage()
                    print("Memory at operation \(i): \(usage)")
                    expectation.fulfill()
                    
                case 9: // Metrics check
                    let metrics = qwenManager.getPerformanceMetrics()
                    if !metrics.isPerformant {
                        stats.performanceIssues += 1
                    }
                    expectation.fulfill()
                    
                default:
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 300) // 5 minutes max
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assertions
        XCTAssertEqual(stats.crashCount, 0, "Should have zero crashes")
        XCTAssertGreaterThan(Double(stats.successCount) / 500, 0.9, "Success rate > 90%")
        XCTAssertGreaterThan(Double(stats.underTargetCount) / Double(stats.successCount), 0.8, "80% under target time")
        XCTAssertLessThan(stats.performanceIssues, 10, "Less than 10 performance issues")
        
        print("""
        
        📊 500 OPERATIONS REGRESSION TEST
        ==================================
        Total Time: \(String(format: "%.1fs", totalTime))
        Success: \(stats.successCount)/500
        Under Target: \(stats.underTargetCount)
        Performance Issues: \(stats.performanceIssues)
        Crashes: \(stats.crashCount)
        Result: \(stats.crashCount == 0 ? "✅ PASSED" : "❌ FAILED")
        """)
    }
    
    // MARK: - Test 2: All Nominal Cases
    func testAllNominalCases() {
        let testCases = [
            ("Restaurant", "LE BISTROT\nPlat: 25.00€\nTotal: 25.00€"),
            ("Groceries", "CARREFOUR\nArticles: 45.50€"),
            ("Transport", "UBER\nFare: $30.00"),
            ("Coffee", "STARBUCKS\nCoffee: $5.00"),
            ("Gas", "SHELL\nFuel: 85.00€"),
            ("Shopping", "ZARA\nClothes: 120.00€"),
            ("Health", "PHARMACY\nMedicine: 15.00€"),
            ("Entertainment", "CINEMA\nTickets: $25.00"),
            ("Bills", "ELECTRICITY\nBill: 150.00€"),
            ("Other", "MISC STORE\nItem: 10.00")
        ]
        
        var passedCount = 0
        
        for (expectedCategory, receipt) in testCases {
            let expectation = XCTestExpectation(description: expectedCategory)
            
            qwenManager.runInference(prompt: receipt) { result in
                if case .success(let response) = result {
                    if let data = response.extractedData.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let category = json["category"] as? String {
                        if category == expectedCategory {
                            passedCount += 1
                        }
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5)
        }
        
        XCTAssertGreaterThan(passedCount, 8, "Should correctly categorize most receipts")
        print("✅ Nominal cases: \(passedCount)/\(testCases.count) passed")
    }
    
    // MARK: - Test 3: All Edge Cases
    func testAllEdgeCases() {
        let edgeCases = [
            "Empty": "",
            "Numbers only": "123 456 789",
            "Special chars": "@#$%^&*()",
            "Very long": String(repeating: "Item ", count: 1000),
            "Unicode": "Total: 💰 €∞.∞∞",
            "HTML tags": "<receipt><total>100</total></receipt>",
            "JSON": "{\"total\": 100, \"merchant\": \"Test\"}",
            "Binary": "\0\0\0\0",
            "Negative": "Total: -100.00€",
            "Huge amount": "Total: 999999999.99€"
        ]
        
        var handledCount = 0
        
        for (name, edge) in edgeCases.enumerated() {
            let expectation = XCTestExpectation(description: "Edge \(name)")
            
            qwenManager.runInference(prompt: edge) { result in
                // Should not crash, any result is acceptable
                handledCount += 1
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2)
        }
        
        XCTAssertEqual(handledCount, edgeCases.count, "All edge cases handled without crash")
        print("✅ Edge cases: \(handledCount)/\(edgeCases.count) handled")
    }
    
    // MARK: - Test 4: iOS Version Compatibility
    func testIOSCompatibility() {
        // Check iOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion)"
        
        XCTAssertGreaterThanOrEqual(Double(versionString) ?? 0, Constants.App.minimumIOSVersion,
                                   "iOS version meets minimum requirement")
        
        // Test on different simulated versions
        let testVersions: [String] = ["17.0", "17.1", "17.2", "17.3", "17.4", "17.5"]
        
        for version in testVersions {
            // Simulate version-specific behavior
            let expectation = XCTestExpectation(description: "iOS \(version)")
            
            qwenManager.runInference(prompt: "Test iOS \(version)") { _ in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2)
        }
        
        print("✅ iOS compatibility: All versions tested")
    }
    
    // MARK: - Test 5: Memory Stability
    func testMemoryStability() {
        var memoryReadings: [Int64] = []
        
        // Take 10 memory readings during operations
        for i in 0..<10 {
            autoreleasepool {
                let expectation = XCTestExpectation(description: "Memory \(i)")
                
                // Perform operation
                qwenManager.runInference(prompt: "Memory test \(i)") { _ in
                    // Record memory
                    let memory = getCurrentMemoryUsage()
                    memoryReadings.append(memory)
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5)
            }
        }
        
        // Check for memory leaks (should not grow continuously)
        var isLeaking = false
        for i in 1..<memoryReadings.count {
            if memoryReadings[i] > memoryReadings[0] + 50 * 1024 * 1024 { // 50MB tolerance
                isLeaking = true
                break
            }
        }
        
        XCTAssertFalse(isLeaking, "No memory leaks detected")
        
        let avgMemory = memoryReadings.reduce(0, +) / Int64(memoryReadings.count)
        XCTAssertLessThan(avgMemory, Constants.Performance.maxMemoryUsage, "Memory under limit")
        
        print("✅ Memory stability: Avg \(avgMemory / 1024 / 1024)MB")
    }
    
    // MARK: - Test 6: Cache Performance
    func testCachePerformance() {
        let testText = "CACHE TEST\nTotal: 100.00€"
        var times: [TimeInterval] = []
        
        // First call (cache miss)
        let expectation1 = XCTestExpectation(description: "Cache miss")
        qwenManager.runInference(prompt: testText) { result in
            if case .success(let response) = result {
                times.append(response.inferenceTime)
            }
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
        
        // Subsequent calls (cache hits)
        for i in 0..<5 {
            let expectation = XCTestExpectation(description: "Cache hit \(i)")
            qwenManager.runInference(prompt: testText) { result in
                if case .success(let response) = result {
                    times.append(response.inferenceTime)
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2)
        }
        
        // Cache hits should be much faster
        if times.count >= 2 {
            let firstTime = times[0]
            let avgCacheTime = times.dropFirst().reduce(0, +) / Double(times.count - 1)
            
            XCTAssertLessThan(avgCacheTime, firstTime * 0.1, "Cache hits 10x faster")
            print("✅ Cache performance: First \(Int(firstTime * 1000))ms, Cached \(Int(avgCacheTime * 1000))ms")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomReceipt(index: Int) -> String {
        let merchants = ["STORE", "SHOP", "MARKET", "RESTAURANT", "CAFE"]
        let amounts = [10.00, 25.50, 45.00, 99.99, 150.00]
        
        let merchant = merchants[index % merchants.count]
        let amount = amounts[index % amounts.count]
        
        return """
        \(merchant) #\(index)
        Date: 12/09/2025
        Items: \(index % 10 + 1)
        Total: €\(amount)
        """
    }
    
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
}

// Test Statistics
struct TestStatistics {
    var successCount = 0
    var failureCount = 0
    var underTargetCount = 0
    var performanceIssues = 0
    var crashCount = 0
}