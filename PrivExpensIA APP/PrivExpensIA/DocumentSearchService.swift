import Foundation
import CoreData

// MARK: - Search Result Model
struct DocumentSearchResult {
    let document: Document
    let score: Double
    let snippet: String?         // Context snippet from rawText
    let matchedFields: Set<MatchField>

    enum MatchField: String {
        case title
        case summary
        case content  // rawText
    }
}

// MARK: - Document Search Service
final class DocumentSearchService {
    static let shared = DocumentSearchService()
    private init() {}

    // Field weights for relevance scoring
    private let titleWeight: Double = 10.0
    private let summaryWeight: Double = 5.0
    private let contentWeight: Double = 1.0

    // Snippet context: chars before/after match
    private let snippetContextLength = 60

    /// Search documents with relevance scoring across title, summary, and rawText.
    /// Multi-word queries use AND logic (all terms must match in at least one field).
    func search(query: String, in documents: [Document]) -> [DocumentSearchResult] {
        let terms = tokenize(query)
        guard !terms.isEmpty else { return [] }

        var results: [DocumentSearchResult] = []

        for document in documents {
            if let result = scoreDocument(document, terms: terms) {
                results.append(result)
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Private

    private func tokenize(_ query: String) -> [String] {
        query
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func scoreDocument(_ document: Document, terms: [String]) -> DocumentSearchResult? {
        let title = document.title ?? ""
        let summary = document.summary ?? ""
        let rawText = document.rawText ?? ""

        let normalizedTitle = normalize(title)
        let normalizedSummary = normalize(summary)
        let normalizedContent = normalize(rawText)

        var totalScore: Double = 0
        var matchedFields = Set<DocumentSearchResult.MatchField>()
        var allTermsMatch = true

        for term in terms {
            var termFound = false

            // Title matches
            let titleMatches = countOccurrences(of: term, in: normalizedTitle)
            if titleMatches > 0 {
                // Bonus for exact title start or word boundary match
                let exactStartBonus: Double = normalizedTitle.hasPrefix(term) ? 5.0 : 1.0
                totalScore += Double(titleMatches) * titleWeight * exactStartBonus
                matchedFields.insert(.title)
                termFound = true
            }

            // Summary matches
            let summaryMatches = countOccurrences(of: term, in: normalizedSummary)
            if summaryMatches > 0 {
                totalScore += Double(summaryMatches) * summaryWeight
                matchedFields.insert(.summary)
                termFound = true
            }

            // Content matches
            let contentMatches = countOccurrences(of: term, in: normalizedContent)
            if contentMatches > 0 {
                // Logarithmic scaling for content (many matches in long text shouldn't dominate)
                totalScore += log2(Double(contentMatches) + 1) * contentWeight
                matchedFields.insert(.content)
                termFound = true
            }

            if !termFound {
                allTermsMatch = false
                break
            }
        }

        // All terms must match somewhere (AND logic)
        guard allTermsMatch else { return nil }

        // Extract snippet from rawText if content matched
        var snippet: String? = nil
        if matchedFields.contains(.content), !rawText.isEmpty {
            snippet = extractSnippet(from: rawText, terms: terms)
        } else if matchedFields.contains(.summary), !summary.isEmpty, !matchedFields.contains(.title) {
            // If only summary matched, show summary as snippet
            snippet = summary
        }

        return DocumentSearchResult(
            document: document,
            score: totalScore,
            snippet: snippet,
            matchedFields: matchedFields
        )
    }

    private func countOccurrences(of term: String, in text: String) -> Int {
        guard !text.isEmpty, !term.isEmpty else { return 0 }
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: term, options: .literal, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }

    private func extractSnippet(from text: String, terms: [String]) -> String? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }

        // Find the first term occurrence in the original text
        var bestRange: Range<String.Index>? = nil
        for term in terms {
            if let range = normalized.range(of: term, options: .literal) {
                if bestRange == nil || range.lowerBound < bestRange!.lowerBound {
                    bestRange = range
                }
            }
        }

        guard let matchRange = bestRange else { return nil }

        // Calculate snippet bounds in original text (same indices work because folding preserves length for most latin chars)
        let matchStart = normalized.distance(from: normalized.startIndex, to: matchRange.lowerBound)
        let snippetStart = max(0, matchStart - snippetContextLength)
        let snippetEnd = min(text.count, matchStart + snippetContextLength + 20)

        let startIdx = text.index(text.startIndex, offsetBy: snippetStart)
        let endIdx = text.index(text.startIndex, offsetBy: min(snippetEnd, text.count))

        var snippet = String(text[startIdx..<endIdx])
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        if snippetStart > 0 { snippet = "..." + snippet }
        if snippetEnd < text.count { snippet = snippet + "..." }

        return snippet
    }
}
