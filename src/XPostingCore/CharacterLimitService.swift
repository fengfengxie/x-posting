import Foundation

public struct CharacterLimitAnalysis: Sendable {
    public let weightedCharacters: Int
    public let isWithinLimit: Bool
    public let remaining: Int
    public let estimatedPosts: Int

    public init(weightedCharacters: Int, isWithinLimit: Bool, remaining: Int, estimatedPosts: Int) {
        self.weightedCharacters = weightedCharacters
        self.isWithinLimit = isWithinLimit
        self.remaining = remaining
        self.estimatedPosts = estimatedPosts
    }
}

public struct CharacterLimitService: Sendable {
    public let postLimit: Int
    public let weightedURLLength: Int

    private let urlRegex: NSRegularExpression
    private let tokenRegex: NSRegularExpression

    public init(postLimit: Int = 280, weightedURLLength: Int = 23) {
        self.postLimit = postLimit
        self.weightedURLLength = weightedURLLength
        self.urlRegex = try! NSRegularExpression(pattern: "https?://[^\\s]+")
        self.tokenRegex = try! NSRegularExpression(pattern: "\\S+\\s*")
    }

    public func analyze(_ text: String) -> CharacterLimitAnalysis {
        let weighted = weightedCount(for: text)
        let within = weighted <= postLimit
        let estimatedPosts = max(1, Int(ceil(Double(weighted) / Double(postLimit))))
        return CharacterLimitAnalysis(
            weightedCharacters: weighted,
            isWithinLimit: within,
            remaining: postLimit - weighted,
            estimatedPosts: estimatedPosts
        )
    }

    public func split(_ text: String) -> [PostSegment] {
        let weighted = weightedCount(for: text)
        if weighted <= postLimit {
            return [PostSegment(index: 1, text: text, weightedCharacterCount: weighted)]
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = tokenRegex.matches(in: text, range: nsRange)
        let rawTokens: [String]

        if matches.isEmpty {
            rawTokens = [text]
        } else {
            rawTokens = matches.compactMap { match in
                guard let range = Range(match.range, in: text) else { return nil }
                return String(text[range])
            }
        }

        var segments: [String] = []
        var current = ""

        for token in rawTokens {
            let candidate = current + token
            if weightedCount(for: candidate) <= postLimit {
                current = candidate
                continue
            }

            if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }

            if weightedCount(for: token) <= postLimit {
                current = token
            } else {
                let broken = splitLongToken(token)
                if !broken.isEmpty {
                    segments.append(contentsOf: broken.dropLast())
                    current = broken.last ?? ""
                }
            }
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            segments.append(trailing)
        }

        return segments.enumerated().map { idx, segment in
            PostSegment(index: idx + 1, text: segment, weightedCharacterCount: weightedCount(for: segment))
        }
    }

    private func splitLongToken(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""

        for char in text {
            let candidate = current + String(char)
            if weightedCount(for: candidate) <= postLimit {
                current = candidate
            } else {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                current = String(char)
            }
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            parts.append(trailing)
        }

        return parts
    }

    public func weightedCount(for text: String) -> Int {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = urlRegex.matches(in: text, range: nsRange)

        var result = 0
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }

            if cursor < range.lowerBound {
                result += weightedCountForPlainText(String(text[cursor..<range.lowerBound]))
            }

            result += weightedURLLength
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            result += weightedCountForPlainText(String(text[cursor..<text.endIndex]))
        }

        return result
    }

    private func weightedCountForPlainText(_ text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            if scalar.properties.isWhitespace {
                partialResult += 1
                return
            }

            // Approximation used for EN/ZH mixed content where CJK generally consumes more budget.
            if isWideCJKScalar(scalar) {
                partialResult += 2
            } else {
                partialResult += 1
            }
        }
    }

    private func isWideCJKScalar(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return
            (0x4E00...0x9FFF).contains(value) ||
            (0x3400...0x4DBF).contains(value) ||
            (0xF900...0xFAFF).contains(value)
    }
}
