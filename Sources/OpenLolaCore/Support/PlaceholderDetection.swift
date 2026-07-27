// Recognizes placeholder text in report fields so validation rejects template values through one normalized predicate.
import Foundation

enum PlaceholderDetection {
    static let manualEvidenceToken = "todo" + "(human)"

    private static let physicalEvidenceFragments = [
        manualEvidenceToken,
        "placeholder",
        "not supplied",
        "not-supplied",
        "required",
        "synthetic",
        "fixme",
        "xxx",
        "unimplemented"
    ]
    private static let physicalEvidenceExactValues = ["unknown", "tbd"]

    static func matchesPhysicalEvidencePlaceholder(_ value: String) -> Bool {
        matches(
            value,
            containing: physicalEvidenceFragments,
            exactly: physicalEvidenceExactValues
        )
    }

    static func matches(
        _ value: String,
        containing fragments: [String],
        exactly exactValues: [String] = [],
        trimWhitespace: Bool = true,
        emptyIsPlaceholder: Bool = true
    ) -> Bool {
        let normalized = normalize(value, trimWhitespace: trimWhitespace)
        if emptyIsPlaceholder, normalized.isEmpty {
            return true
        }
        let pattern = PlaceholderPattern(
            fragments: fragments,
            exactValues: exactValues,
            trimWhitespace: trimWhitespace
        )
        return pattern.matches(normalized)
    }

    static func matchesOptional(
        _ value: String?,
        containing fragments: [String],
        exactly exactValues: [String] = [],
        trimWhitespace: Bool = true,
        nilIsPlaceholder: Bool = true,
        emptyIsPlaceholder: Bool = true
    ) -> Bool {
        guard let value else {
            return nilIsPlaceholder
        }
        return matches(
            value,
            containing: fragments,
            exactly: exactValues,
            trimWhitespace: trimWhitespace,
            emptyIsPlaceholder: emptyIsPlaceholder
        )
    }

    static func normalize(_ value: String, trimWhitespace: Bool = true) -> String {
        let trimmed = trimWhitespace
            ? value.trimmingCharacters(in: .whitespacesAndNewlines)
            : value
        return trimmed.lowercased()
    }

    private struct PlaceholderPattern {
        let fragments: [String]
        let exactValues: Set<String>

        init(fragments: [String], exactValues: [String], trimWhitespace: Bool) {
            self.fragments = fragments
                .map { normalize($0, trimWhitespace: trimWhitespace) }
                .filter { !$0.isEmpty }
            self.exactValues = Set(exactValues.map { normalize($0, trimWhitespace: trimWhitespace) })
        }

        func matches(_ normalizedValue: String) -> Bool {
            exactValues.contains(normalizedValue)
                || fragments.contains { containsDelimitedFragment($0, in: normalizedValue) }
        }
    }

    private static func containsDelimitedFragment(_ normalizedFragment: String, in value: String) -> Bool {
        var searchRange = value.startIndex..<value.endIndex
        while let range = value.range(of: normalizedFragment, range: searchRange) {
            if isFragmentBoundary(range.lowerBound, in: value, direction: .before)
                && isFragmentBoundary(range.upperBound, in: value, direction: .after)
                && !isInsideNonPlaceholderToken(range, in: value) {
                return true
            }
            searchRange = range.upperBound..<value.endIndex
        }
        return false
    }

    private enum FragmentBoundaryDirection {
        case before
        case after
    }

    private static func isFragmentBoundary(
        _ index: String.Index,
        in value: String,
        direction: FragmentBoundaryDirection
    ) -> Bool {
        switch direction {
        case .before:
            guard index > value.startIndex else {
                return true
            }
            return !isAlphanumeric(value[value.index(before: index)])
        case .after:
            guard index < value.endIndex else {
                return true
            }
            return !isAlphanumeric(value[index])
        }
    }

    private static func isAlphanumeric(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func isInsideNonPlaceholderToken(_ range: Range<String.Index>, in value: String) -> Bool {
        let token = tokenContaining(range, in: value)
        return token.contains("://")
            || token.contains("@")
            || token.contains("::")
    }

    private static func tokenContaining(_ range: Range<String.Index>, in value: String) -> String {
        var start = range.lowerBound
        while start > value.startIndex {
            let previous = value.index(before: start)
            guard !value[previous].isWhitespace else {
                break
            }
            start = previous
        }

        var end = range.upperBound
        while end < value.endIndex, !value[end].isWhitespace {
            end = value.index(after: end)
        }
        return String(value[start..<end])
    }
}
