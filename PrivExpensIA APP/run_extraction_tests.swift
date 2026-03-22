#!/usr/bin/env swift

import Foundation

// MARK: - Standalone Extraction Test Runner
// Run with: swift run_extraction_tests.swift

// MARK: - Test Structures

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

// MARK: - Extraction Functions (same logic as app)

func extractMerchant(from text: String) -> String {
    let lines = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    let knownMerchants: [(pattern: String, name: String)] = [
        ("migros", "Migros"), ("migrolino", "Migrolino"),
        ("coop", "Coop"), ("denner", "Denner"),
        ("lidl", "Lidl"), ("aldi", "Aldi"), ("spar", "Spar"), ("volg", "Volg"),
        ("manor", "Manor"), ("globus", "Globus"),
        ("starbucks", "Starbucks"), ("mcdonald", "McDonald's"),
        ("cff", "CFF"), ("sbb", "SBB"), ("tpg", "TPG"),
        ("amavita", "Amavita"), ("sun store", "Sun Store"), ("sunstore", "Sun Store"),
        ("digitec", "Digitec"), ("swisscom", "Swisscom"),
        ("parking", "Parking")
    ]

    for i in 0..<min(5, lines.count) {
        let line = lines[i].lowercased()
        for merchant in knownMerchants {
            if line.contains(merchant.pattern) {
                return merchant.name
            }
        }
    }

    // Return first reasonable line as merchant
    for line in lines.prefix(3) {
        if line.count >= 3 && line.count <= 40 && !isNonMerchantLine(line) {
            return cleanMerchantName(line)
        }
    }

    return lines.first ?? "Unknown"
}

func isNonMerchantLine(_ line: String) -> Bool {
    let lowercased = line.lowercased()
    if line.contains("@") || lowercased.contains("www.") { return true }
    if lowercased.contains("tel:") || lowercased.contains("tél:") { return true }
    if lowercased.contains("rue ") || lowercased.contains("avenue ") { return true }
    if line.allSatisfy({ $0.isNumber || $0 == "." || $0 == " " || $0 == "-" }) { return true }
    return false
}

func cleanMerchantName(_ name: String) -> String {
    var cleaned = name
    for pattern in ["Inc.", "LLC", "SA", "AG", "GmbH", "®", "™", "---", "***"] {
        cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
    }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned == cleaned.uppercased() && cleaned.count > 3 {
        cleaned = cleaned.capitalized
    }
    return cleaned.isEmpty ? "Unknown" : cleaned
}

func extractAmount(from text: String) -> Double {
    let totalPatterns = [
        #"(?:TOTAL|TOTALE|GESAMT|SUMME|SOMME)\s*(?:CHF|EUR|Fr\.?|[\$€])?\s*:?\s*(\d+[.,]\d{2})"#,
        #"(?:TOTAL|TOTALE)\s*:?\s*(?:CHF|EUR|Fr\.?)?\s*(\d+[.,]\d{2})"#,
        #"(?:A PAYER|À PAYER|ZU ZAHLEN|NET|MONTANT|BETRAG|Prix)\s*:?\s*(?:CHF|EUR|Fr\.?)?\s*(\d+[.,]\d{2})"#,
        #"(?:CHF|EUR|Fr\.?)\s*:?\s*(\d+[.,]\d{2})"#
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

    // Currency suffix pattern
    let suffixPattern = #"(\d+[.,]\d{2})\s*(?:CHF|EUR|Fr\.?)"#
    if let regex = try? NSRegularExpression(pattern: suffixPattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
       let range = Range(match.range(at: 1), in: text) {
        let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
        if let amount = Double(amountStr) { return amount }
    }

    // Fallback: largest amount
    let allPattern = #"(\d+[.,]\d{2})"#
    if let regex = try? NSRegularExpression(pattern: allPattern),
       case let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)),
       !matches.isEmpty {
        var amounts: [Double] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let str = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let val = Double(str) { amounts.append(val) }
            }
        }
        return amounts.max() ?? 0
    }
    return 0
}

func detectCategory(from text: String) -> String {
    let lowercased = text.lowercased()

    let categories: [(String, [String])] = [
        ("food", ["migros", "coop", "denner", "aldi", "lidl", "spar", "volg", "migrolino", "supermarché", "boulangerie"]),
        ("restaurant", ["restaurant", "café", "cafe", "bistro", "mcdonald", "starbucks", "burger", "pizzeria"]),
        ("hotel", ["hotel", "hôtel", "hostel", "airbnb", "hébergement"]),
        ("transport", ["sbb", "cff", "tpg", "uber", "taxi", "bus", "train", "parking", "billet"]),
        ("health", ["pharmacy", "pharmacie", "apotheke", "amavita", "sunstore", "sun store", "doctor", "médecin"]),
        ("shopping", ["manor", "globus", "digitec", "galaxus", "h&m", "zara", "ikea"]),
        ("telecom", ["swisscom", "sunrise", "salt", "mobile"]),
        ("entertainment", ["cinema", "theater", "concert", "museum", "sport", "fitness"])
    ]

    for (category, keywords) in categories {
        if keywords.contains(where: { lowercased.contains($0) }) {
            return category
        }
    }
    return "other"
}

func detectCurrency(from text: String) -> String {
    let lowercased = text.lowercased()

    let swissIndicators = ["chf", "fr.", "sfr", "migros", "coop", "denner", "sbb", "cff", "tpg",
                          "swisscom", "manor", "amavita", "mwst", "+41", "suisse", "schweiz",
                          "genève", "zürich", "bern", "lausanne"]

    if swissIndicators.contains(where: { lowercased.contains($0) }) {
        return "CHF"
    }
    if text.contains("€") || lowercased.contains(" eur ") { return "EUR" }
    if text.contains("$") { return "USD" }

    return "CHF"  // Default for Swiss app
}

func extractDate(from text: String) -> String {
    // Numeric DD.MM.YYYY
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

        if day >= 1 && day <= 31 && month >= 1 && month <= 12 {
            return String(format: "%04d-%02d-%02d", year, month, day)
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
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    return "unknown"
}

// MARK: - Test Runner

func runTests() {
    let scriptPath = CommandLine.arguments[0]
    let scriptDir = (scriptPath as NSString).deletingLastPathComponent
    let datasetPath = scriptDir + "/PrivExpensIA/TestData/SwissReceiptTestDataset.json"

    guard let data = FileManager.default.contents(atPath: datasetPath),
          let dataset = try? JSONDecoder().decode(TestDataset.self, from: data) else {
        print("❌ Failed to load test dataset from: \(datasetPath)")
        return
    }

    print("\n" + String(repeating: "=", count: 70))
    print("🧪 SWISS RECEIPT EXTRACTION TEST SUITE")
    print(String(repeating: "=", count: 70))
    print("Dataset: \(dataset.testCases.count) test cases\n")

    var passed = 0
    var failed = 0
    var categoryStats: [String: (passed: Int, total: Int)] = [:]

    for testCase in dataset.testCases {
        let category = testCase.id.components(separatedBy: "_").first ?? "other"
        var stats = categoryStats[category] ?? (0, 0)
        stats.total += 1

        let merchant = extractMerchant(from: testCase.text)
        let amount = extractAmount(from: testCase.text)
        let cat = detectCategory(from: testCase.text)
        let currency = detectCurrency(from: testCase.text)
        let date = extractDate(from: testCase.text)

        let merchantOK = merchant.lowercased().contains(testCase.expected.merchant.lowercased()) ||
                        testCase.expected.merchant.lowercased().contains(merchant.lowercased())
        let amountOK = abs(amount - testCase.expected.amount) < 0.01
        let categoryOK = cat.lowercased() == testCase.expected.category.lowercased()
        let currencyOK = currency == testCase.expected.currency
        let dateOK = date == testCase.expected.date

        let allOK = merchantOK && amountOK && categoryOK && currencyOK

        if allOK {
            passed += 1
            stats.passed += 1
            print("✅ [\(testCase.id)] PASS")
        } else {
            failed += 1
            print("❌ [\(testCase.id)] FAIL - \(testCase.description)")
            if !merchantOK { print("   merchant: expected '\(testCase.expected.merchant)' got '\(merchant)'") }
            if !amountOK { print("   amount: expected \(testCase.expected.amount) got \(amount)") }
            if !categoryOK { print("   category: expected '\(testCase.expected.category)' got '\(cat)'") }
            if !currencyOK { print("   currency: expected '\(testCase.expected.currency)' got '\(currency)'") }
            if !dateOK { print("   date: expected '\(testCase.expected.date)' got '\(date)'") }
        }

        categoryStats[category] = stats
    }

    print("\n" + String(repeating: "-", count: 70))
    print("📊 RESULTS BY CATEGORY:")
    for (cat, stats) in categoryStats.sorted(by: { $0.key < $1.key }) {
        let icon = stats.passed == stats.total ? "✅" : "⚠️"
        print("   \(icon) \(cat): \(stats.passed)/\(stats.total)")
    }

    print("\n" + String(repeating: "=", count: 70))
    let passRate = Double(passed) / Double(passed + failed) * 100
    print("📈 TOTAL: \(passed) passed, \(failed) failed (\(String(format: "%.1f", passRate))%)")
    print(String(repeating: "=", count: 70) + "\n")
}

// Run tests
runTests()
