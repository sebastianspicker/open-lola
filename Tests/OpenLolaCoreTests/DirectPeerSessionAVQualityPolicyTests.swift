import Testing

@testable import OpenLolaCore

@Test
func directPeerAVStructuralQualityReportMarksUsefulMediaNotRequired() throws {
    let report = try directPeerAVQualityPolicyReport(qualityPolicy: .structural)

    #expect(report.verdict == .partial)
    #expect(report.avRuntime?.qualityPolicy == .structural)
    #expect(report.avRuntime?.usefulMediaProof == .notRequired)
    try report.validate()
}

@Test
func directPeerAVRequiredQualityReportMarksMissingUsefulMediaProof() throws {
    let report = try directPeerAVQualityPolicyReport(qualityPolicy: .requireUsefulMedia)

    #expect(report.verdict == .partial)
    #expect(report.avRuntime?.qualityPolicy == .requireUsefulMedia)
    #expect(report.avRuntime?.usefulMediaProof == .requiredButNotProven)
    try report.validate()
}

private func directPeerAVQualityPolicyReport(
    qualityPolicy: DirectPeerSessionAVRunQualityPolicy
) throws -> DirectPeerSessionReport {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        try? pair.first.shutdown(reason: "quality policy report test complete")
        try? pair.second.shutdown(reason: "quality policy report test complete")
    }
    try pair.negotiate()
    try pair.startMedia()

    var configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    configuration.qualityPolicy = qualityPolicy
    let control = try DirectPeerSessionControlSocket.bindLoopback()
    defer { control.close() }

    return try buildAVReport(
        configuration: configuration,
        runner: pair.second,
        control: control,
        runtime: DirectPeerSessionAVRuntimeResult(
            metrics: .empty,
            videoFormat: nil,
            receiveProof: nil
        )
    )
}
