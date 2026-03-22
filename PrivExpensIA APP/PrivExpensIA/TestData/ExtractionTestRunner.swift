import Foundation

// MARK: - Extraction Test Runner
// Validates extraction functions against SwissReceiptTestDataset.json

final class ExtractionTestRunner {
    static let shared = ExtractionTestRunner()

    private init() {}

    // MARK: - Test Case Structures

    struct TestCase: Codable {
        let id: String
        let description: String
        let text: String
        let expected: ExpectedResult
    }

    struct ExpectedResult: Codable {
        let merchant: String
        let amount: Double
        let taxAmount: Double?
        let category: String
        let currency: String
        let date: String
    }

    struct TestDataset: Codable {
        let version: String
        let description: String
        let created: String
        let testCases: [TestCase]
    }

    struct TestResult {
        let testId: String
        let description: String
        let passed: Bool
        let details: [FieldResult]

        struct FieldResult {
            let field: String
            let expected: String
            let actual: String
            let passed: Bool
        }
    }

    // MARK: - Run Tests

    func runAllTests() -> TestReport {
        guard let dataset = loadTestDataset() else {
            return TestReport(totalTests: 0, passed: 0, failed: 0, results: [], errorMessage: "Failed to load test dataset")
        }

        var results: [TestResult] = []

        for testCase in dataset.testCases {
            let result = runSingleTest(testCase)
            results.append(result)
        }

        let passed = results.filter { $0.passed }.count
        let failed = results.count - passed

        return TestReport(
            totalTests: results.count,
            passed: passed,
            failed: failed,
            results: results,
            errorMessage: nil
        )
    }

    // MARK: - Single Test Execution

    private func runSingleTest(_ testCase: TestCase) -> TestResult {
        var fieldResults: [TestResult.FieldResult] = []

        // Test Merchant Extraction
        let extractedMerchant = TextExtractionUtils.shared.extractMerchant(from: testCase.text)
        let merchantPassed = normalizeForComparison(extractedMerchant).contains(normalizeForComparison(testCase.expected.merchant)) ||
                            normalizeForComparison(testCase.expected.merchant).contains(normalizeForComparison(extractedMerchant))
        fieldResults.append(TestResult.FieldResult(
            field: "merchant",
            expected: testCase.expected.merchant,
            actual: extractedMerchant,
            passed: merchantPassed
        ))

        // Test Amount Extraction
        let extractedAmount = extractAmount(from: testCase.text)
        let amountPassed = abs(extractedAmount - testCase.expected.amount) < 0.01
        fieldResults.append(TestResult.FieldResult(
            field: "amount",
            expected: String(format: "%.2f", testCase.expected.amount),
            actual: String(format: "%.2f", extractedAmount),
            passed: amountPassed
        ))

        // Test Category Detection
        let extractedCategory = TextExtractionUtils.shared.detectCategory(from: testCase.text)
        let categoryPassed = normalizeForComparison(extractedCategory) == normalizeForComparison(testCase.expected.category)
        fieldResults.append(TestResult.FieldResult(
            field: "category",
            expected: testCase.expected.category,
            actual: extractedCategory,
            passed: categoryPassed
        ))

        // Test Currency Detection
        let extractedCurrency = TextExtractionUtils.shared.detectCurrency(from: testCase.text)
        let currencyPassed = extractedCurrency == testCase.expected.currency
        fieldResults.append(TestResult.FieldResult(
            field: "currency",
            expected: testCase.expected.currency,
            actual: extractedCurrency,
            passed: currencyPassed
        ))

        // Test Date Extraction
        let extractedDate = extractDate(from: testCase.text)
        let datePassed = compareDates(extractedDate, testCase.expected.date)
        fieldResults.append(TestResult.FieldResult(
            field: "date",
            expected: testCase.expected.date,
            actual: formatDate(extractedDate),
            passed: datePassed
        ))

        // Overall pass if all critical fields pass (merchant, amount, category, currency)
        let criticalFieldsPassed = fieldResults.filter { ["merchant", "amount", "category", "currency"].contains($0.field) }.allSatisfy { $0.passed }

        return TestResult(
            testId: testCase.id,
            description: testCase.description,
            passed: criticalFieldsPassed,
            details: fieldResults
        )
    }

    // MARK: - Extraction Helpers (mirrors LlamaInferenceService)

    private func extractAmount(from text: String) -> Double {
        // Priority 1: Explicit total keywords
        let totalPatterns = [
            #"(?:TOTAL|TOTALE|GESAMT|SUMME|SOMME)\s*(?:CHF|EUR|Fr\.?|[\$€])?\s*:?\s*(\d+[.,]\d{2})"#,
            #"(?:A PAYER|À PAYER|ZU ZAHLEN|NET|MONTANT|BETRAG)\s*:?\s*(?:CHF|EUR|Fr\.?)?\s*(\d+[.,]\d{2})"#,
            #"(?:CHF|EUR|Fr\.?)\s*(?:TOTAL)?\s*:?\s*(\d+[.,]\d{2})"#,
            #"(?:Total|Prix)\s*:?\s*(?:CHF|Fr\.?)?\s*(\d+[.,]\d{2})"#
        ]

        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr), amount > 0 {
                    return amount
                }
            }
        }

        // Priority 2: Amount with currency suffix
        let suffixPattern = #"(\d+[.,]\d{2})\s*(?:CHF|EUR|Fr\.?)"#
        if let regex = try? NSRegularExpression(pattern: suffixPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           let range = Range(match.range(at: 1), in: text) {
            let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
            if let amount = Double(amountStr) {
                return amount
            }
        }

        // Priority 3: Largest amount in text
        let allAmountsPattern = #"(\d+[.,]\d{2})"#
        if let regex = try? NSRegularExpression(pattern: allAmountsPattern),
           case let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           !matches.isEmpty {
            var amounts: [Double] = []
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                    if let value = Double(amountStr) {
                        amounts.append(value)
                    }
                }
            }
            return amounts.max() ?? 0
        }

        return 0
    }

    private func extractDate(from text: String) -> Date {
        // Numeric pattern DD.MM.YYYY or DD/MM/YYYY
        let numericPattern = #"(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})"#
        if let regex = try? NSRegularExpression(pattern: numericPattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           let dayRange = Range(match.range(at: 1), in: text),
           let monthRange = Range(match.range(at: 2), in: text),
           let yearRange = Range(match.range(at: 3), in: text) {

            var day = Int(text[dayRange]) ?? 0
            var month = Int(text[monthRange]) ?? 0
            var year = Int(text[yearRange]) ?? 0

            if year < 100 { year = 2000 + year }
            if month > 12 && day <= 12 { swap(&day, &month) }

            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = year

            if let date = Calendar(identifier: .gregorian).date(from: components) {
                return date
            }
        }

        // Text month pattern
        let textPattern = #"(\d{1,2})\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{4})"#
        if let regex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
           let dayRange = Range(match.range(at: 1), in: text),
           let monthRange = Range(match.range(at: 2), in: text),
           let yearRange = Range(match.range(at: 3), in: text) {

            let day = Int(text[dayRange]) ?? 1
            let monthStr = String(text[monthRange]).lowercased()
            let year = Int(text[yearRange]) ?? 2026

            let monthMap: [String: Int] = [
                "janvier": 1, "février": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
                "juillet": 7, "août": 8, "septembre": 9, "octobre": 10, "novembre": 11, "décembre": 12,
                "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
                "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
            ]

            if let month = monthMap[monthStr] {
                var components = DateComponents()
                components.day = day
                components.month = month
                components.year = year
                if let date = Calendar(identifier: .gregorian).date(from: components) {
                    return date
                }
            }
        }

        return Date()
    }

    // MARK: - Helpers

    private func loadTestDataset() -> TestDataset? {
        guard let url = Bundle.main.url(forResource: "SwissReceiptTestDataset", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dataset = try? JSONDecoder().decode(TestDataset.self, from: data) else {

            // Try loading from TestData folder directly
            let fileManager = FileManager.default
            let possiblePaths = [
                Bundle.main.bundlePath + "/TestData/SwissReceiptTestDataset.json",
                Bundle.main.resourcePath ?? "" + "/SwissReceiptTestDataset.json"
            ]

            for path in possiblePaths {
                if fileManager.fileExists(atPath: path),
                   let data = fileManager.contents(atPath: path),
                   let dataset = try? JSONDecoder().decode(TestDataset.self, from: data) {
                    return dataset
                }
            }

            return nil
        }
        return dataset
    }

    private func normalizeForComparison(_ str: String) -> String {
        return str.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func compareDates(_ date: Date, _ expectedStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let expectedDate = formatter.date(from: expectedStr) else { return false }

        let calendar = Calendar(identifier: .gregorian)
        return calendar.isDate(date, inSameDayAs: expectedDate)
    }
}

// MARK: - Test Report

struct TestReport {
    let totalTests: Int
    let passed: Int
    let failed: Int
    let results: [ExtractionTestRunner.TestResult]
    let errorMessage: String?

    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passed) / Double(totalTests) * 100
    }

    func printReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("EXTRACTION TEST REPORT")
        print(String(repeating: "=", count: 60))

        if let error = errorMessage {
            print("ERROR: \(error)")
            return
        }

        print("Total: \(totalTests) | Passed: \(passed) | Failed: \(failed)")
        print(String(format: "Pass Rate: %.1f%%", passRate))
        print(String(repeating: "-", count: 60))

        // Group by category (from test ID prefix)
        var categoryResults: [String: (passed: Int, total: Int)] = [:]

        for result in results {
            let category = result.testId.components(separatedBy: "_").first ?? "other"
            var stats = categoryResults[category] ?? (0, 0)
            stats.total += 1
            if result.passed { stats.passed += 1 }
            categoryResults[category] = stats
        }

        print("\nRESULTS BY CATEGORY:")
        for (category, stats) in categoryResults.sorted(by: { $0.key < $1.key }) {
            let status = stats.passed == stats.total ? "✅" : "⚠️"
            print("  \(status) \(category): \(stats.passed)/\(stats.total)")
        }

        print("\nDETAILED RESULTS:")
        for result in results {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            print("\n[\(result.testId)] \(status)")
            print("  \(result.description)")

            for field in result.details where !field.passed {
                print("  ⚠️ \(field.field): expected '\(field.expected)' got '\(field.actual)'")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
    }

    func toJSON() -> String {
        var json: [String: Any] = [
            "totalTests": totalTests,
            "passed": passed,
            "failed": failed,
            "passRate": String(format: "%.1f%%", passRate)
        ]

        var resultsArray: [[String: Any]] = []
        for result in results {
            var fields: [[String: Any]] = []
            for field in result.details {
                fields.append([
                    "field": field.field,
                    "expected": field.expected,
                    "actual": field.actual,
                    "passed": field.passed
                ])
            }
            resultsArray.append([
                "id": result.testId,
                "passed": result.passed,
                "fields": fields
            ])
        }
        json["results"] = resultsArray

        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
