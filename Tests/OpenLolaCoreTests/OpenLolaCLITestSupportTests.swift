// Shared open-lola CLI helpers keep command-line test scenarios deterministic.
import Foundation
import Testing

@Test
func openLolaCLIExecutableCandidatesPreferExplicitCLIPath() {
    let candidates = openLolaCLIExecutableCandidates(
        repositoryRoot: URL(fileURLWithPath: "/tmp/open-lola-repository"),
        environment: [
            "OPEN_LOLA_TEST_OPEN_LOLA_CLI": " /tmp/explicit-open-lola ",
            "OPEN_LOLA_SWIFT_BUILD_PATH": "/tmp/swift-build"
        ]
    )

    #expect(candidates.map(\.path) == ["/tmp/explicit-open-lola"])
}

@Test
func openLolaCLIExecutableCandidatesUseConfiguredSwiftBuildPath() {
    let candidates = openLolaCLIExecutableCandidates(
        repositoryRoot: URL(fileURLWithPath: "/tmp/open-lola-repository"),
        environment: ["OPEN_LOLA_SWIFT_BUILD_PATH": " /tmp/swift-build "]
    )

    #expect(candidates.map(\.path) == ["/tmp/swift-build/debug/open-lola"])
}

@Test
func openLolaCLIExecutableCandidatesFallBackToRepositoryBuildDirectory() {
    let candidates = openLolaCLIExecutableCandidates(
        repositoryRoot: URL(fileURLWithPath: "/tmp/open-lola-repository"),
        environment: [:]
    )

    #expect(candidates.map(\.path) == ["/tmp/open-lola-repository/.build/debug/open-lola"])
}
