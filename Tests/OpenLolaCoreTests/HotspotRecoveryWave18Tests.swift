// Exercises deterministic core report and state validation seams without runtime I/O.
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave18LoLaCollectionCapsInMemoryPayloads() throws {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 2, expectedHeight: 1, targetFrameCount: 2
    )
    state.append(Data([1]))
    state.append(Data([2]))
    state.append(Data([3]))

    #expect(state.payloadCount == 2)
    #expect(try state.result() == [Data([1]), Data([2])])
}

@Test
func wave18LoLaCollectionRejectsInsufficientPayloads() {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 1, expectedHeight: 1, targetFrameCount: 2
    )
    state.append(Data([1]))

    #expect(throws: LoLaVideoPayloadError.captureUnavailable) {
        _ = try state.result()
    }
}

@Test
func wave18LoLaCollectionReturnsRecordedFailure() {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 1, expectedHeight: 1, targetFrameCount: 1
    )
    state.record(.captureUnavailable)

    #expect(throws: LoLaVideoPayloadError.captureUnavailable) {
        _ = try state.result()
    }
}

@Test
func wave18LoLaCollectionAcceptsMatchingDimensions() {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 1920, expectedHeight: 1080, targetFrameCount: 1
    )

    #expect(state.dimensionMismatchError(actualWidth: 1920, actualHeight: 1080) == nil)
}

@Test
func wave18LoLaCollectionReportsDimensionMismatch() {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 1920, expectedHeight: 1080, targetFrameCount: 1
    )

    #expect(state.dimensionMismatchError(actualWidth: 1280, actualHeight: 720) == .frameDimensionMismatch(
        expectedWidth: 1920, expectedHeight: 1080, actualWidth: 1280, actualHeight: 720
    ))
}

@Test
func wave18LoLaCollectionWaitsForConditionSignalledProducer() throws {
    let state = LoLaAVFoundationPayloadCollectionState(
        expectedWidth: 1, expectedHeight: 1, targetFrameCount: 1
    )
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
        state.append(Data([0x18]))
    }

    state.waitForPayloads(until: Date().addingTimeInterval(1))

    #expect(state.payloadCount == 1)
    #expect(try state.result() == [Data([0x18])])
}

@Test
func wave18JackTripRejectsNegativeTransmittedCount() {
    var report = wave18JackTripReport()
    report.transmittedDatagramCount = -1

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger(
        "jackTripMedia.transmittedDatagramCount", "-1"
    )) {
        try report.validate()
    }
}

@Test
func wave18JackTripRejectsNegativeReceivedCount() {
    var report = wave18JackTripReport()
    report.receivedDatagramCount = -1

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger(
        "jackTripMedia.receivedDatagramCount", "-1"
    )) {
        try report.validate()
    }
}

@Test
func wave18JackTripRejectsNegativeStopControlCount() {
    var report = wave18JackTripReport()
    report.stopControlDatagramCount = -1

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger(
        "jackTripMedia.stopControlDatagramCount", "-1"
    )) {
        try report.validate()
    }
}

@Test
func wave18JackTripRejectsNegativeRedundancyRecoveryCount() {
    var report = wave18JackTripReport()
    report.redundancyRecoveredPacketCount = -1

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger(
        "jackTripMedia.redundancyRecoveredPacketCount", "-1"
    )) {
        try report.validate()
    }
}

@Test
func wave18GoalCodewiseClosureRejectsBlankIdentity() {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    report.id = ""

    #expect(throws: GoalCodewiseClosureValidationError.emptyField("id")) {
        try report.validate()
    }
}

@Test
func wave18GoalCodewiseClosureRejectsDuplicateRequirement() {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    let duplicate = try! #require(report.requirements.first)
    report.requirements.append(duplicate)
    report.summary = GoalCodewiseClosureSummary(requirements: report.requirements)

    #expect(throws: GoalCodewiseClosureValidationError.duplicateRequirement(duplicate.id)) {
        try report.validate()
    }
}

@Test
func wave18GoalCodewiseClosureRejectsMissingDocumentationArea() {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    let missing = try! #require(report.requiredDocumentationAreas.first)
    report.requiredDocumentationAreas.removeFirst()

    #expect(throws: GoalCodewiseClosureValidationError.missingRequiredDocumentationArea(missing.path)) {
        try report.validate()
    }
}

@Test
func wave18GoalCodewiseClosureRejectsSummaryMutation() {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    report.summary.requirementCount += 1

    #expect(throws: GoalCodewiseClosureValidationError.summaryMismatch) {
        try report.validate()
    }
}

@Test
func wave18IntegratedProfileAggregatesEmptyVerdictsAsPass() {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.profileOptions = []
    report.subordinateEvidence = []
    report.benchmarkMatrix = []

    #expect(report.aggregateSubordinateVerdict == .pass)
}

@Test
func wave18IntegratedProfileAggregatesPartialVerdicts() {
    let report = IntegratedProfileSyntheticSmoke.run()

    #expect(report.aggregateSubordinateVerdict == .partial)
}

@Test
func wave18IntegratedProfileAggregatesFailedVerdicts() {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.profileOptions[0].verdict = .fail

    #expect(report.aggregateSubordinateVerdict == .fail)
}

@Test
func wave18IntegratedProfileRejectsEmptyIdentityField() {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.id = ""

    #expect(throws: IntegratedProfileValidationError.emptyField("id")) {
        try report.validate()
    }
}

@Test
func wave18IntegratedProfilePassRejectsPlaceholderEvidence() throws {
    var report = try wave18PassIntegratedProfile()
    report.profileOptions[0].sourceReportId = "fixture-profile-report"

    #expect(throws: IntegratedProfileValidationError.passWithPlaceholderEvidenceField(
        "profileOptions.sourceReportId"
    )) {
        try report.validate()
    }
}

@Test
func wave18IntegratedProfileRejectsNegativeMetric() throws {
    var report = try wave18PassIntegratedProfile()
    report.benchmarkMatrix[0].metrics.audioJitterP99Microseconds = -1

    #expect(throws: IntegratedProfileValidationError.negativeField(
        "benchmarkMatrix.metrics.audioJitterP99Microseconds"
    )) {
        try report.validate()
    }
}

@Test
func wave18IntegratedProfileRejectsNonFiniteMetric() throws {
    var report = try wave18PassIntegratedProfile()
    report.benchmarkMatrix[0].metrics.residentMemoryMegabytes = .nan

    #expect(throws: IntegratedProfileValidationError.nonFiniteField(
        "benchmarkMatrix.metrics.residentMemoryMegabytes"
    )) {
        try report.validate()
    }
}

@Test
func wave18IntegratedProfileRejectsOutOfRangeCpuPercent() throws {
    var report = try wave18PassIntegratedProfile()
    report.benchmarkMatrix[0].metrics.cpuP99Percent = 101

    #expect(throws: IntegratedProfileValidationError.percentOutOfRange(
        field: "benchmarkMatrix.metrics.cpuP99Percent", value: 101
    )) {
        try report.validate()
    }
}

@Test
func wave18ConnectionPlanValidatesPureDryRunConfiguration() throws {
    let report = try wave18ConnectionPlan()

    try report.validate()
    #expect(report.endpoints.count == 2)
}

@Test
func wave18ConnectionPlanRejectsPassVerdict() throws {
    var report = try wave18ConnectionPlan()
    report.verdict = .pass

    #expect(throws: ExternalConnectorValidationError.realWorldPassNotAllowed) {
        try report.validate()
    }
}

@Test
func wave18ConnectionPlanRejectsWrongEndpointCount() throws {
    var report = try wave18ConnectionPlan()
    report.endpoints.removeLast()

    #expect(throws: ExternalConnectorSessionError.emptyList("endpoints")) {
        try report.validate()
    }
}

@Test
func wave18ConnectionPlanRejectsInconsistentShellCommand() throws {
    var report = try wave18ConnectionPlan()
    report.endpoints[0].shellCommand = "different"

    #expect(throws: ExternalConnectorSessionError.inconsistentShellCommand(
        "endpoints.shellCommand"
    )) {
        try report.validate()
    }
}

@Test
func wave18UltraGridRejectsUnsupportedRawVideoFourCCMode() {
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("raw-video-16bpp")) {
        _ = try UltraGridCompatibility.videoFragments(wave18VideoRequest(bitsPerPixel: 16))
    }
}

@Test
func wave18UltraGridRejectsEmptyRawVideoFrame() {
    #expect(throws: UltraGridCompatibilityError.invalidField("video.framePayload", 0)) {
        var request = wave18VideoRequest()
        request.framePayload = Data()
        _ = try UltraGridCompatibility.videoFragments(request)
    }
}

@Test
func wave18UltraGridRejectsRawVideoPayloadAtHeaderLimit() {
    #expect(throws: UltraGridCompatibilityError.invalidField(
        "video.maxPayloadBytes", UltraGridVideoRawFragmentPayload.headerByteCount
    )) {
        var request = wave18VideoRequest()
        request.maxPayloadBytes = UltraGridVideoRawFragmentPayload.headerByteCount
        _ = try UltraGridCompatibility.videoFragments(request)
    }
}

@Test
func wave18UltraGridRawFragmentRejectsPayloadBeyondFrameLength() throws {
    let header = wave18VideoHeader(payloadOffset: 0, payloadByteCount: 1)
    var encoded = try header.encoded()
    encoded.append(contentsOf: [1, 2])

    #expect(throws: UltraGridCompatibilityError.invalidPayloadLength(expected: 1, actual: 2)) {
        _ = try UltraGridVideoRawFragmentPayload.decode(encoded)
    }
}

@Test
func wave18UltraGridReassemblyRejectsEmptyFragments() {
    #expect(throws: UltraGridCompatibilityError.reassemblyIncomplete(missing: [0])) {
        _ = try UltraGridCompatibility.reassembleVideoFrame([])
    }
}

@Test
func wave18UltraGridReassemblyRejectsGaps() throws {
    let fragment = UltraGridVideoRawFragmentPayload(
        header: wave18VideoHeader(payloadOffset: 1, payloadByteCount: 3), fragmentPayload: Data([2])
    )

    #expect(throws: UltraGridCompatibilityError.reassemblyIncomplete(missing: [0])) {
        _ = try UltraGridCompatibility.reassembleVideoFrame([fragment])
    }
}

@Test
func wave18UltraGridReassemblyRejectsMixedFrames() throws {
    let first = UltraGridVideoRawFragmentPayload(
        header: wave18VideoHeader(payloadOffset: 0, payloadByteCount: 3), fragmentPayload: Data([1])
    )
    let second = UltraGridVideoRawFragmentPayload(
        header: UltraGridVideoPayloadHeader(
            bufferNumber: 2,
            payloadOffset: 1,
            payloadByteCount: 3,
            geometry: .init(width: 1, height: 1, fourCC: try UltraGridFourCC("RGB3")),
            timing: .init(frameRateNumerator: 60)
        ),
        fragmentPayload: Data([2])
    )

    #expect(throws: UltraGridCompatibilityError.unsupportedMode("mixed-video-fragments")) {
        _ = try UltraGridCompatibility.reassembleVideoFrame([first, second])
    }
}

@Test
func wave18GoalRuntimeTemplateRejectsBlankMetadata() {
    var report = GoalRuntimeEvidenceTemplateReport.template()
    report.sourceOfTruth = ""

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.emptyField("sourceOfTruth")) {
        try report.validate()
    }
}

@Test
func wave18GoalRuntimeTemplateRejectsSummaryMutation() {
    var report = GoalRuntimeEvidenceTemplateReport.template()
    report.summary.deliverableCount += 1

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.summaryMismatch) {
        try report.validate()
    }
}

@Test
func wave18GoalRuntimeTemplateRejectsDuplicateDeliverable() throws {
    var report = GoalRuntimeEvidenceTemplateReport.template()
    let duplicate = try #require(report.deliverables.first)
    report.deliverables.append(duplicate)
    report.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: report.deliverables)

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.duplicateDeliverable(duplicate.id)) {
        try report.validate()
    }
}

@Test
func wave18GoalRuntimeTemplateRejectsMissingDeliverable() throws {
    var report = GoalRuntimeEvidenceTemplateReport.template()
    let missing = try #require(report.deliverables.first)
    report.deliverables.removeFirst()
    report.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: report.deliverables)

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.missingDeliverable(missing.id)) {
        try report.validate()
    }
}

private func wave18JackTripReport() -> JackTripCompatibilityMediaReport {
    jackTripCompatibilityMediaReport {
        $0.id = "wave18-jacktrip"
        $0.capturedAt = "2026-08-05T00:00:00Z"
        $0.notes = "Deterministic count-validation fixture."
    }
}

private func wave18PassIntegratedProfile() throws -> IntegratedProfileReport {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.id = "wave18-integrated-profile-pass"
    report.title = "Wave 18 measured profile"
    report.runMode = .measured
    report.verdict = .pass
    report.notes = "Measured validation fixture."

    for index in report.profileOptions.indices {
        let label = report.profileOptions[index].label.rawValue
        report.profileOptions[index].sourceReportId = "measured-\(label)-source"
        report.profileOptions[index].costReportId = "measured-\(label)-cost"
        report.profileOptions[index].verdict = .pass
    }
    for index in report.subordinateEvidence.indices {
        let lane = report.subordinateEvidence[index].lane.rawValue
        report.subordinateEvidence[index].reportId = "measured-\(lane)-report"
        report.subordinateEvidence[index].verdict = .pass
        report.subordinateEvidence[index].measured = true
        report.subordinateEvidence[index].physicalPassEvidence = true
    }
    for index in report.benchmarkMatrix.indices {
        let scenario = report.benchmarkMatrix[index].scenario.rawValue
        report.benchmarkMatrix[index].reportId = "measured-\(scenario)-matrix"
        report.benchmarkMatrix[index].verdict = .pass
        report.benchmarkMatrix[index].measured = true
        report.benchmarkMatrix[index].physicalEvidence = true
    }
    return report
}

private func wave18ConnectionPlan() throws -> ExternalConnectorConnectionPlanReport {
    try ExternalConnectorConnectionPlanRunner.run(
        configuration: ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", "lola",
            "--local-host", "198.51.100.20",
            "--remote-host", "198.51.100.10",
            "--output", "/tmp/wave18-connection-plan.json"
        ])
    )
}

private func wave18VideoRequest(bitsPerPixel: Int = 24) -> UltraGridVideoFragmentRequest {
    UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data([1, 2, 3]),
            id: 1,
            width: 1,
            height: 1,
            frameRate: 60,
            bitsPerPixel: bitsPerPixel
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 1,
            timestamp: 1,
            ssrc: 1,
            payloadType: UltraGridCompatibility.videoPayloadType,
            maxPayloadBytes: 1_200
        )
    )
}

private func wave18VideoHeader(
    payloadOffset: UInt32,
    payloadByteCount: UInt32
) -> UltraGridVideoPayloadHeader {
    UltraGridVideoPayloadHeader(
        bufferNumber: 1,
        payloadOffset: payloadOffset,
        payloadByteCount: payloadByteCount,
        geometry: .init(width: 1, height: 1, fourCC: UltraGridFourCC(rawValue: 0x5247_4233)),
        timing: .init(frameRateNumerator: 60)
    )
}
