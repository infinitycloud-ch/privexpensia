import Foundation
import XCTest

// Edge case tests for optimized Qwen model
class QwenEdgeCaseTests: XCTestCase {
    
    let qwenManager = QwenModelManager.shared
    
    override func setUp() {
        super.setUp()
        // Reset performance metrics before each test
        qwenManager.resetPerformance()
    }
    
    // Test 1: Blurry/low quality receipt
    func testBlurryReceipt() {
        let blurryText = """
        CA  FO R   MAR T
        12 9 20 5
        P in   1. 0
        L it     .5
        TO AL  10. 0
        """
        
        let expectation = XCTestExpectation(description: "Blurry receipt processing")
        
        qwenManager.runInference(prompt: blurryText) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.inferenceTime < 0.3, "Should process quickly even with poor quality")
                XCTAssertNotNil(response.extractedData)
                // Should fallback gracefully
            case .failure(let error):
                // Fallback should prevent failure
                XCTFail("Should not fail with fallback: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 2: Multiple languages mixed
    func testMultilingualReceipt() {
        let mixedText = """
        KONBINI ストア
        Date: 12/09/2025
        おにぎり Rice Ball    ¥150
        Sandwich サンドイッチ  ¥280
        Café au lait        ¥180
        合計 Total          ¥610
        Merci ありがとう
        """
        
        let expectation = XCTestExpectation(description: "Multilingual receipt")
        
        qwenManager.runInference(prompt: mixedText) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.inferenceTime < 0.3)
                if let data = response.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    XCTAssertEqual(json["currency"] as? String, "JPY", "Should detect JPY currency")
                }
            case .failure:
                // OK to fallback on complex multilingual
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 3: Ambiguous amounts
    func testAmbiguousAmounts() {
        let ambiguousText = """
        SHOP
        Item 1    25.00
        Item 2    25.00
        Item 3    25.00
        Discount  -25.00
        Subtotal  50.00
        Tax       25.00
        Total     75.00
        Points    25.00
        """
        
        let expectation = XCTestExpectation(description: "Ambiguous amounts")
        
        qwenManager.runInference(prompt: ambiguousText) { result in
            switch result {
            case .success(let response):
                if let data = response.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let total = json["total_amount"] as? Double ?? 0
                    XCTAssertEqual(total, 75.0, accuracy: 1.0, "Should identify correct total")
                }
            case .failure:
                XCTFail("Should handle ambiguous amounts")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 4: Multiple dates
    func testMultipleDates() {
        let multipleDatesText = """
        INVOICE #2025-001
        Issue Date: 01/09/2025
        Due Date: 30/09/2025
        Service Date: 15/09/2025
        
        Service Fee: $100.00
        
        Payment Date: 12/09/2025
        Total: $100.00
        """
        
        let expectation = XCTestExpectation(description: "Multiple dates")
        
        qwenManager.runInference(prompt: multipleDatesText) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.inferenceTime < 0.3)
                // Should pick most relevant date
            case .failure:
                XCTFail("Should handle multiple dates")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 5: Empty/minimal text
    func testEmptyReceipt() {
        let emptyText = ""
        
        let expectation = XCTestExpectation(description: "Empty receipt")
        
        qwenManager.runInference(prompt: emptyText) { result in
            switch result {
            case .success(let response):
                // Should return fallback
                XCTAssertTrue(response.modelVersion == "fallback" || response.extractedData.contains("Unknown"))
            case .failure:
                // OK to fail on empty
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Test 6: Very long receipt (performance test)
    func testLongReceipt() {
        var longText = "MEGA STORE\n"
        for i in 1...100 {
            longText += "Item \(i)    \(Double.random(in: 1...50))\n"
        }
        longText += "Total: 2500.00"
        
        let expectation = XCTestExpectation(description: "Long receipt")
        
        qwenManager.runInference(prompt: longText) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.inferenceTime < 0.5, "Should handle long receipts efficiently")
            case .failure(let error):
                if case QwenError.timeout = error {
                    // Timeout is acceptable for very long text
                    break
                }
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 7: Malformed JSON characters
    func testMalformedCharacters() {
        let malformedText = """
        "SHOP" & 'STORE'
        Item: "Test's & Special"    $10.00
        <Total>: $10.00 </Total>
        {Payment}: Credit Card
        """
        
        let expectation = XCTestExpectation(description: "Malformed characters")
        
        qwenManager.runInference(prompt: malformedText) { result in
            switch result {
            case .success(let response):
                // Should escape properly
                XCTAssertTrue(response.extractedData.contains("{"))
                XCTAssertTrue(response.extractedData.contains("}"))
            case .failure:
                XCTFail("Should handle special characters")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Test 8: Cache hit performance
    func testCachePerformance() {
        let testText = "SHOP\nTotal: 50.00"
        let iterations = 10
        var times: [TimeInterval] = []
        
        let expectation = XCTestExpectation(description: "Cache performance")
        expectation.expectedFulfillmentCount = iterations
        
        for _ in 0..<iterations {
            qwenManager.runInference(prompt: testText) { result in
                if case .success(let response) = result {
                    times.append(response.inferenceTime)
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // First should be slower, rest should be cache hits
        if times.count >= 2 {
            XCTAssertTrue(times[1] < times[0] * 0.1, "Cache should be much faster")
        }
        
        let stats = qwenManager.getCacheStatistics()
        XCTAssertTrue(stats.hits > 0, "Should have cache hits")
    }
    
    // Test 9: Memory limit test
    func testMemoryLimit() {
        // This test verifies memory monitoring works
        let metrics = qwenManager.getPerformanceMetrics()
        XCTAssertTrue(metrics.peakMemoryUsage < 150 * 1024 * 1024, "Should stay under 150MB")
        
        let memUsage = qwenManager.getCurrentMemoryUsage()
        XCTAssertTrue(memUsage.contains("MB"), "Should report memory in MB")
    }
    
    // Test 10: Timeout handling
    func testTimeoutHandling() {
        // Create a text that would take long to process
        let complexText = String(repeating: "Complex pattern 123.45 ", count: 10000)
        
        let expectation = XCTestExpectation(description: "Timeout handling")
        
        qwenManager.runInference(prompt: complexText) { result in
            // Should either timeout or use fallback
            switch result {
            case .success(let response):
                // Fallback is OK
                XCTAssertTrue(response.inferenceTime < 1.1, "Should respect timeout")
            case .failure(let error):
                if case QwenError.timeout = error {
                    // Timeout is expected
                    break
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // Performance summary test
    func testPerformanceSummary() {
        // Run a few inferences
        let texts = [
            "SHOP\nTotal: 10.00",
            "RESTAURANT\nBill: 25.50",
            "TAXI\nFare: 15.00"
        ]
        
        let expectation = XCTestExpectation(description: "Performance summary")
        expectation.expectedFulfillmentCount = texts.count
        
        for text in texts {
            qwenManager.runInference(prompt: text) { _ in
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Check overall performance
        XCTAssertTrue(qwenManager.isSystemPerformant(), "System should be performant")
        
        let metrics = qwenManager.getPerformanceMetrics()
        XCTAssertTrue(metrics.averageInferenceTime < 0.3, "Average should be < 300ms")
        XCTAssertTrue(metrics.successRate > 0.8, "Success rate should be > 80%")
    }
}