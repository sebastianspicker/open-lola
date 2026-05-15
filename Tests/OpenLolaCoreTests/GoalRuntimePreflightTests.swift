import Foundation
import Testing

@testable import OpenLolaCore

@Test
func goalRuntimePreflightMapsEveryRuntimeDeliverable() throws {
    let report = blockedPreflightReport()

    try report.validate()

    let deliverableIDs = Set(report.deliverables.map(\.id))
    let requiredIDs = Set(GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue))

    #expect(report.goalDocument == "GOAL.md")
    #expect(report.sourceOfTruth == "docs/mac-port/README.md")
    #expect(report.verdict == .partial)
    #expect(report.realWorldVerdict == .partial)
    #expect(deliverableIDs == requiredIDs)
    #expect(report.summary.deliverableCount == requiredIDs.count)
    #expect(report.summary.partialDeliverableCount == requiredIDs.count)
    #expect(report.summary.blockedDeliverableCount == requiredIDs.count)
}

@Test
func goalRuntimePreflightRecordsCurrentHostBlockers() throws {
    let report = blockedPreflightReport()

    let blockers = report.deliverables.flatMap(\.blockers).joined(separator: "\n")

    #expect(report.summary.audioDeviceCount == 0)
    #expect(report.summary.rmeMadiCandidateCount == 0)
    #expect(report.summary.videoDeviceCount == 0)
    #expect(report.summary.blackmagicAtemCandidateCount == 0)
    #expect(report.summary.codeSigningIdentityCount == 1)
    #expect(report.summary.developerIDApplicationIdentityCount == 0)
    #expect(blockers.contains("RME MADI device is not visible"))
    #expect(blockers.contains("Blackmagic/ATEM/DeckLink/UltraStudio device is not visible"))
    #expect(blockers.contains("Developer ID Application identity is not visible"))
}

@Test
func goalRuntimePreflightParsesDeveloperIDSigningIdentities() {
    let output = """
      1) 1234567890ABCDEF "Apple Configurator: Hochschule Example"
      2) ABCDEF1234567890 "Developer ID Application: Open LoLa Test Team (TEAMID1234)"
         2 valid identities found
    """

    let probe = GoalRuntimePreflightSigningProbe.parse(
        command: "/usr/bin/security find-identity -v -p codesigning",
        exitCode: 0,
        output: output,
        error: nil
    )

    #expect(probe.identities.count == 2)
    #expect(probe.developerIDApplicationIdentityCount == 1)
}

@Test
func goalRuntimePreflightSigningProbeDrainsVerboseOutputWithoutPipeDeadlock() {
    let script = """
    import sys
    print('  1) ABCDEF1234567890 "Developer ID Application: Open LoLa Test Team (TEAMID1234)"')
    sys.stdout.write('x' * 1048576)
    sys.stdout.flush()
    """

    let probe = GoalRuntimePreflightSigningProbe.capture(
        executable: "/usr/bin/python3",
        arguments: ["-c", script]
    )

    #expect(probe.exitCode == 0)
    #expect(probe.developerIDApplicationIdentityCount == 1)
    #expect(probe.error == nil)
}

@Test
func goalRuntimePreflightRejectsFalsePass() throws {
    var report = blockedPreflightReport()
    report.deliverables[0].verdict = .pass
    report.summary = GoalRuntimePreflightSummary(
        deliverables: report.deliverables,
        audio: report.audio,
        video: report.video,
        signing: report.signing
    )

    #expect(throws: GoalRuntimePreflightValidationError.deliverablePassWithoutPhysicalEvidence(
        GoalRuntimeEvidenceDeliverableID.twoMacRmeMadiBidirectional.rawValue
    )) {
        try report.validate()
    }
}

@Test
func goalRuntimePreflightJSONSurfaceRoundTrips() throws {
    let report = blockedPreflightReport()
    let data = try report.prettyJSONData()
    let decoded = try JSONDecoder().decode(GoalRuntimePreflightReport.self, from: data)

    #expect(decoded == report)
    #expect(decoded.realWorldVerdict == .partial)
}

@Test
func goalRuntimePreflightValidatorPrintsBothVerdicts() throws {
    let data = try blockedPreflightReport().prettyJSONData()
    let output = try ReportValidatorSurface.validate(
        data,
        as: GoalRuntimePreflightReport.self,
        label: "GOAL.md runtime preflight report",
        extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
    )

    #expect(output.lines == [
        "GOAL.md runtime preflight report valid: goal-runtime-preflight-2026-05-05",
        "real-world-verdict: partial",
        "VERDICT: PARTIAL",
    ])
}

private func blockedPreflightReport() -> GoalRuntimePreflightReport {
    GoalRuntimePreflightReport.make(
        capturedAt: "2026-05-05T00:00:00Z",
        audio: GoalRuntimePreflightAudioProbe(
            captured: false,
            deviceCount: 0,
            rmeMadiCandidateCount: 0,
            error: "noDevices"
        ),
        video: GoalRuntimePreflightVideoProbe(
            captured: true,
            deviceCount: 0,
            blackmagicAtemCandidateCount: 0,
            permissionStatus: .denied,
            blackmagicSdkStatus: .notLinkedOptionalBoundary
        ),
        signing: GoalRuntimePreflightSigningProbe(
            command: "/usr/bin/security find-identity -v -p codesigning",
            exitCode: 0,
            identities: [
                GoalRuntimePreflightSigningIdentity(
                    label: "Apple Configurator: Hochschule fuer Musik und Tanz Koeln",
                    developerIDApplication: false
                ),
            ],
            error: nil
        )
    )
}
