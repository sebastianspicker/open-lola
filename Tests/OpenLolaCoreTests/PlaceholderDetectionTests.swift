import Foundation
import Testing

@testable import OpenLolaCore

@Test
func placeholderDetectionMatchesExactValuesAfterNormalizingCaseAndWhitespace() {
    #expect(PlaceholderDetection.matches(
        " Not-Supplied ",
        containing: [],
        exactly: ["not-supplied"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "not supplied",
        containing: [],
        exactly: ["not-supplied"],
        emptyIsPlaceholder: false
    ))
}

@Test
func placeholderDetectionMatchesFragmentsCaseInsensitively() {
    #expect(PlaceholderDetection.matches(
        "TODO(HUMAN): record driver version",
        containing: ["todo(human)"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "production driver version recorded",
        containing: ["todo(human)", "placeholder", "synthetic"],
        emptyIsPlaceholder: false
    ))
}

@Test
func placeholderDetectionRequiresDelimitedFragments() {
    #expect(PlaceholderDetection.matches(
        "m13-driver-required",
        containing: ["required"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "m13-driver-prerequired",
        containing: ["required"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "m13-driver-requiredness",
        containing: ["required"],
        emptyIsPlaceholder: false
    ))
}

@Test
func placeholderDetectionStillMatchesPunctuationDelimitedFragments() {
    #expect(PlaceholderDetection.matches(
        "TODO(human): record driver version",
        containing: ["todo(human)"],
        emptyIsPlaceholder: false
    ))
    #expect(PlaceholderDetection.matches(
        "measured synthetic evidence",
        containing: ["synthetic"],
        emptyIsPlaceholder: false
    ))
}

@Test
func placeholderDetectionIgnoresFragmentsInsideUriEmailAndIPv6Tokens() {
    #expect(!PlaceholderDetection.matches(
        "https://lab.example/placeholder/device",
        containing: ["placeholder"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "todo(human)@example.org",
        containing: ["todo(human)"],
        emptyIsPlaceholder: false
    ))
    #expect(!PlaceholderDetection.matches(
        "2001:db8::synthetic",
        containing: ["synthetic"],
        emptyIsPlaceholder: false
    ))
    #expect(PlaceholderDetection.matches(
        "status: placeholder",
        containing: ["placeholder"],
        emptyIsPlaceholder: false
    ))
}

@Test
func placeholderDetectionUsesSharedPhysicalEvidenceProfile() {
    for value in [
        "TODO(human): record hardware",
        "not supplied",
        "required",
        "synthetic",
        "FIXME",
        "XXX",
        "unimplemented",
        "unknown",
        "tbd",
    ] {
        #expect(PlaceholderDetection.matchesPhysicalEvidencePlaceholder(value))
    }

    #expect(!PlaceholderDetection.matchesPhysicalEvidencePlaceholder("RME MADIface Pro measured on mac-a"))
}

@Test
func placeholderDetectionCompilesPatternInputsOncePerMatch() throws {
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Support/PlaceholderDetection.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("private struct PlaceholderPattern"))
    #expect(source.contains("let exactValues: Set<String>"))
    #expect(source.contains("let pattern = PlaceholderPattern("))
    #expect(source.contains("func matches(_ normalizedValue: String) -> Bool"))
    #expect(source.contains("private static func containsDelimitedFragment(_ normalizedFragment: String"))
    #expect(!source.contains("let normalizedFragment = normalize(fragment)"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
