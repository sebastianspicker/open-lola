import Foundation

@testable import OpenLolaCore

func integratedAvPassCandidateReport() throws -> IntegratedAvReport {
    var report = try sharedIntegratedAvFixture(named: "integrated-av-partial")
    report.id = "m10-p04-integrated-pass"
    report.verdict = .pass
    report.runMode = .measured
    report.durationSeconds = 1_800
    report.runWindow = IntegratedAvRunWindowEvidence(
        startedAt: "2026-05-03T10:00:00Z",
        endedAt: "2026-05-03T10:30:00Z",
        audioVideoOverlapSeconds: 1_800
    )
    report.audio.baselineRouteReportId = "m05-rme-audio-only-pass"
    report.audio.baselineVerdict = .pass
    report.audio.integratedVerdict = .pass
    report.proof = IntegratedProofEvidence(
        identity: IntegratedProofEvidence.Identity(
            closureGate: .p04IntegratedAvProof,
            audioOnlyBaselineFirst: true,
            audioOnlyBaselineReportId: "m05-rme-audio-only-pass",
            integratedRunReportId: "m10-p04-integrated-pass"
        ),
        audioRoute: IntegratedProofEvidence.AudioRoute(
            packetCapturePoint: "receiver-en6-ingress",
            rmeAudioDeviceVisible: true,
            rmeAudioDeviceUid: "rme-madi-core-audio-uid",
            baselineRouteVerdict: .pass,
            integratedRouteVerdict: .pass
        ),
        video: IntegratedProofEvidence.VideoEvidence(
            captureEnabled: true,
            captureReportId: "m08-blackmagic-capture-pass",
            transportEnabled: true,
            transportReportId: "m09-video-transport-pass",
            transportPacketCapturePoint: "receiver-en6-video-ingress",
            previewEnabled: false,
            previewReportId: nil
        ),
        control: IntegratedProofEvidence.ControlEvidence(
            oscPollingEnabled: true,
            oscControlReportId: "m11-osc-loopback-pass",
            atemReadOnlyPollingEnabled: true,
            atemControlReportId: "m11-atem-readonly-pass",
            atemArmedCommandsAllowed: false
        )
    )
    return report
}

private func sharedIntegratedAvFixture(named name: String) throws -> IntegratedAvReport {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let candidates = [
        root.appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/\(name).json"),
        root.appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/invalid/\(name).json"),
    ]
    guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        throw SharedIntegratedAvFixtureError.missingFixture(name)
    }
    return try IntegratedAvReport.decode(from: Data(contentsOf: url))
}

private enum SharedIntegratedAvFixtureError: Error, Equatable {
    case missingFixture(String)
}
