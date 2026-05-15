import Foundation
import Testing

@testable import OpenLolaCore

private enum ExampleVerdictValidationError: Error, Equatable {
    case missingRequiredEvidence
    case forbiddenBlocker
}

@Test
func verdictValidationPolicyRunsRulesOnlyForPassVerdicts() throws {
    var evaluated = false

    VerdictValidationPolicy.validatePass(.partial) {
        evaluated = true
    }
    #expect(!evaluated)

    VerdictValidationPolicy.validatePass(.pass) {
        evaluated = true
    }
    #expect(evaluated)
}

@Test
func verdictValidationPolicyNamesRequireAndForbidInvalidPassRules() {
    #expect(throws: ExampleVerdictValidationError.missingRequiredEvidence) {
        try VerdictValidationPolicy.passRequires(false, ExampleVerdictValidationError.missingRequiredEvidence)
    }
    #expect(throws: ExampleVerdictValidationError.forbiddenBlocker) {
        try VerdictValidationPolicy.passForbids(true, ExampleVerdictValidationError.forbiddenBlocker)
    }
}

@Test
func verdictValidationPolicyCentralizesPassDurationThresholds() {
    #expect(VerdictValidationPolicy.hardwareValidationMinimumPassDurationSeconds == 1_800)
    #expect(VerdictValidationPolicy.fasterThanLoLaMinimumPassDurationSeconds == 3_600)
    #expect(HardwareValidationReport.minimumPassDurationSeconds
        == VerdictValidationPolicy.hardwareValidationMinimumPassDurationSeconds)
}

@Test
func verdictValidationPolicyExplainsPassDurationThresholds() throws {
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("hardwareValidationMinimumPassDurationMinutes = 30"))
    #expect(source.contains("fasterThanLoLaMinimumPassDurationMinutes = 60"))
    #expect(source.contains("short smoke fixtures cannot"))
    #expect(source.contains("sustained drift, jitter, and packet-loss behavior"))
}

@Test
func verdictValidationPolicyCentralizesUniversalPassForbidPrefixes() {
    #expect(VerdictValidationPolicy.universalPassForbids.map(\.casePrefix) == [
        "passWith",
        "passAllows",
        "passUses",
        "passIncreases",
        "passChanges",
        "passBlocks",
    ])
    #expect(VerdictValidationPolicy.universalPassForbids.allSatisfy { !$0.notes.isEmpty })
    #expect(VerdictValidationPolicy.universalPassForbids.first?.matches(caseName: "passWithBlockers") == true)
    #expect(VerdictValidationPolicy.universalPassForbidCasePrefixes == [
        "passWith",
        "passAllows",
        "passUses",
        "passIncreases",
        "passChanges",
        "passBlocks",
    ])
}

@Test
func invalidPassCaseNamesMapToRequiresOrForbidsRules() {
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passWithoutMeasuredRun")?.rule == .requires)
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passMissingVerificationGate")?.rule == .requires)
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passRunTooShort")?.rule == .requires)
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passWithGeneratedArtifacts")?.rule == .forbids)
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passAllowsRealtimeFileIO")?.rule == .forbids)
    #expect(VerdictValidationPolicy.describeInvalidPassCase("passChangesAudioPlayoutTarget")?.rule == .forbids)
}

@Test
func releaseAndEvidenceInvalidPassCasesHaveStructuredRuleDescriptors() throws {
    let cases = try discoverInvalidPassCases()
    let unclassified = cases.filter { item in
        VerdictValidationPolicy.describeInvalidPassCase(item.caseName) == nil
    }

    #expect(!cases.isEmpty)
    #expect(unclassified.isEmpty, "unclassified invalid-pass cases: \(unclassified.map(\.label).joined(separator: ", "))")
}

private struct InvalidPassCase {
    let label: String
    let caseName: String
}

private func discoverInvalidPassCases() throws -> [InvalidPassCase] {
    let sourceRoots = [
        repositoryRoot.appendingPathComponent("Sources/OpenLolaCore/Evidence"),
        repositoryRoot.appendingPathComponent("Sources/OpenLolaCore/Release"),
    ]
    let regex = try NSRegularExpression(pattern: #"case\s+(pass[A-Za-z0-9_]+)"#)
    var cases: [InvalidPassCase] = []

    for root in sourceRoots {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in regex.matches(in: source, range: range) {
                guard let caseRange = Range(match.range(at: 1), in: source) else {
                    continue
                }
                let caseName = String(source[caseRange])
                cases.append(InvalidPassCase(
                    label: "\(relativePath(url)):\(caseName)",
                    caseName: caseName
                ))
            }
        }
    }
    return cases.sorted { $0.label < $1.label }
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func relativePath(_ url: URL) -> String {
    let rootPath = repositoryRoot.standardizedFileURL.path + "/"
    let filePath = url.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath) else {
        return filePath
    }
    return String(filePath.dropFirst(rootPath.count))
}
