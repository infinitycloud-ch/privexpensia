import XCTest
import Vision
import UIKit
@testable import PrivExpensIA

class OCRTests: XCTestCase {
    
    func testFrenchReceiptExtraction() {
        let expectation = self.expectation(description: "OCR extraction française")
        
        let receiptImage = createMockReceipt(text: """
            CARREFOUR MARKET
            123 Rue de la République
            75001 Paris
            
            Date: 12/09/2025
            ----------------------
            Pain baguette     1.20€
            Lait 1L          1.50€
            Pommes 1kg       2.80€
            ----------------------
            TOTAL:           5.50€
            TVA 5.5%:        0.30€
            
            Merci de votre visite!
            """, language: "fr")
        
        OCRService.shared.processImage(receiptImage) { result in
            switch result {
            case .success(let data):
                XCTAssertFalse(data.text.isEmpty, "Le texte extrait ne doit pas être vide")
                XCTAssertTrue(data.text.contains("CARREFOUR"), "Doit extraire le nom du magasin")
                XCTAssertTrue(data.text.contains("5.50"), "Doit extraire le montant total")
                XCTAssertLessThan(data.processingTime, 2.0, "Performance doit être < 2 secondes")
                print("✅ Test FR réussi - Temps: \(data.processingTime)s")
            case .failure(let error):
                XCTFail("Extraction échouée: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testEnglishReceiptExtraction() {
        let expectation = self.expectation(description: "OCR extraction anglaise")
        
        let receiptImage = createMockReceipt(text: """
            WALMART SUPERCENTER
            456 Main Street
            New York, NY 10001
            
            Date: 09/12/2025
            ----------------------
            Milk 1 Gallon    $4.99
            Bread            $2.49
            Apples 2lb       $3.99
            ----------------------
            SUBTOTAL:       $11.47
            TAX 8.875%:      $1.02
            TOTAL:          $12.49
            
            Thank you for shopping!
            """, language: "en")
        
        OCRService.shared.processImage(receiptImage) { result in
            switch result {
            case .success(let data):
                XCTAssertFalse(data.text.isEmpty, "Le texte extrait ne doit pas être vide")
                XCTAssertTrue(data.text.contains("WALMART"), "Doit extraire le nom du magasin")
                XCTAssertTrue(data.text.contains("12.49"), "Doit extraire le montant total")
                XCTAssertLessThan(data.processingTime, 2.0, "Performance doit être < 2 secondes")
                print("✅ Test EN réussi - Temps: \(data.processingTime)s")
            case .failure(let error):
                XCTFail("Extraction échouée: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testPerformanceBenchmark() {
        let receiptImage = createMockReceipt(text: "Test Receipt\nTotal: $100.00", language: "en")
        
        measure {
            let expectation = self.expectation(description: "Performance test")
            
            OCRService.shared.processImage(receiptImage) { _ in
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 3, handler: nil)
        }
    }
    
    func testMultiLanguageSupport() {
        let languages = ["fr", "de", "it", "en", "ja", "ko", "sk", "es"]
        
        for lang in languages {
            let expectation = self.expectation(description: "Test \(lang)")
            let image = createMockReceipt(text: "Test \(lang)", language: lang)
            
            OCRService.shared.processImage(image) { result in
                if case .success(let data) = result {
                    print("✅ Language \(lang) supported - Time: \(data.processingTime)s")
                }
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 3, handler: nil)
        }
    }
    
    private func createMockReceipt(text: String, language: String) -> UIImage {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            let rect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}