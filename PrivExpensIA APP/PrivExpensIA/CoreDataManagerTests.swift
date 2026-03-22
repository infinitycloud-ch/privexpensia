import XCTest
import CoreData
@testable import PrivExpensIA

class CoreDataManagerTests: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    
    override func setUp() {
        super.setUp()
        coreDataManager = CoreDataManager.shared
    }
    
    override func tearDown() {
        coreDataManager = nil
        super.tearDown()
    }
    
    func testSaveOCRResult() {
        let expectation = self.expectation(description: "Save OCR result")
        
        let testData = ExtractedData(
            text: "CARREFOUR MARKET\nTotal: 45.50€\nTVA: 3.50€",
            language: "fr",
            processingTime: 1.5,
            confidence: 0.95
        )
        
        let testImage = createTestImage()
        
        coreDataManager.saveOCRResult(extractedData: testData, image: testImage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let expenses = self.coreDataManager.fetchRecentExpenses(limit: 1)
            XCTAssertFalse(expenses.isEmpty, "Should have saved at least one expense")
            
            if let expense = expenses.first {
                XCTAssertNotNil(expense.value(forKey: "id"))
                XCTAssertNotNil(expense.value(forKey: "date"))
                XCTAssertEqual(expense.value(forKey: "merchant") as? String, "CARREFOUR MARKET")
                XCTAssertEqual(expense.value(forKey: "amount") as? Double, 45.50, accuracy: 0.01)
                XCTAssertEqual(expense.value(forKey: "tax") as? Double, 3.50, accuracy: 0.01)
                XCTAssertNotNil(expense.value(forKey: "category"))
                XCTAssertNotNil(expense.value(forKey: "receiptImage"))
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testExtractMerchantFromText() {
        let texts = [
            "WALMART SUPERCENTER\n123 Main St": "WALMART SUPERCENTER",
            "   \nCARREFOUR\nParis": "CARREFOUR",
            "": "Unknown Merchant"
        ]
        
        for (text, expectedMerchant) in texts {
            let testData = ExtractedData(text: text, language: "en", processingTime: 1.0, confidence: 0.9)
            coreDataManager.saveOCRResult(extractedData: testData, image: nil)
            
            let expenses = coreDataManager.fetchRecentExpenses(limit: 1)
            if let expense = expenses.first {
                let merchant = expense.value(forKey: "merchant") as? String
                XCTAssertEqual(merchant, expectedMerchant, "Expected merchant: \(expectedMerchant)")
            }
        }
    }
    
    func testExtractAmountFromText() {
        let texts = [
            "TOTAL: $45.99": 45.99,
            "Total: €123.45": 123.45,
            "TOTAL:£67.89": 67.89,
            "No amount here": 0.0
        ]
        
        for (text, expectedAmount) in texts {
            let testData = ExtractedData(text: text, language: "en", processingTime: 1.0, confidence: 0.9)
            coreDataManager.saveOCRResult(extractedData: testData, image: nil)
            
            let expenses = coreDataManager.fetchRecentExpenses(limit: 1)
            if let expense = expenses.first {
                let amount = expense.value(forKey: "amount") as? Double ?? 0
                XCTAssertEqual(amount, expectedAmount, accuracy: 0.01, "Expected amount: \(expectedAmount)")
            }
        }
    }
    
    func testCategoryDetection() {
        let texts = [
            "RESTAURANT Le Bistrot": "Food",
            "UBER Technologies": "Transport",
            "WALMART STORE": "Shopping",
            "PHARMACY CVS": "Health",
            "CINEMA AMC": "Entertainment",
            "ELECTRIC COMPANY": "Bills",
            "Random Store": "Other"
        ]
        
        for (text, expectedCategory) in texts {
            let testData = ExtractedData(text: text, language: "en", processingTime: 1.0, confidence: 0.9)
            coreDataManager.saveOCRResult(extractedData: testData, image: nil)
            
            let expenses = coreDataManager.fetchRecentExpenses(limit: 1)
            if let expense = expenses.first {
                let category = expense.value(forKey: "category") as? String
                XCTAssertEqual(category, expectedCategory, "Expected category: \(expectedCategory) for text: \(text)")
            }
        }
    }
    
    func testFetchRecentExpenses() {
        // Save multiple expenses
        for i in 1...5 {
            let testData = ExtractedData(
                text: "Test Store \(i)\nTotal: $\(i * 10).00",
                language: "en",
                processingTime: 1.0,
                confidence: 0.9
            )
            coreDataManager.saveOCRResult(extractedData: testData, image: nil)
        }
        
        // Test fetching with limit
        let recentExpenses = coreDataManager.fetchRecentExpenses(limit: 3)
        XCTAssertLessThanOrEqual(recentExpenses.count, 3, "Should respect fetch limit")
        
        // Test fetching all
        let allExpenses = coreDataManager.fetchRecentExpenses(limit: 100)
        XCTAssertGreaterThanOrEqual(allExpenses.count, 5, "Should fetch all saved expenses")
    }
    
    func testPerformance() {
        measure {
            let testData = ExtractedData(
                text: "Performance Test Store\nTotal: $100.00\nTax: $8.00",
                language: "en",
                processingTime: 0.5,
                confidence: 0.95
            )
            
            for _ in 1...10 {
                coreDataManager.saveOCRResult(extractedData: testData, image: nil)
            }
            
            _ = coreDataManager.fetchRecentExpenses(limit: 10)
        }
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}