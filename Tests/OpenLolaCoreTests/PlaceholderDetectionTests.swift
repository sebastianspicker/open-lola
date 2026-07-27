// Verifies that placeholder detection matches exact values after normalizing case and whitespace.
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

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
