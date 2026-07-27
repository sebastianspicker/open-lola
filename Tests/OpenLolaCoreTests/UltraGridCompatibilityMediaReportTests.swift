// Verifies that UltraGrid public runner selects fixture providers for packet bytes.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridPublicRunnerSelectsFixtureProvidersForPacketBytes() throws {
    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/ug-public-fixture.json"
) { input in
  input.dryRun = true
  input.mediaMode = .audioVideo
  input.framesPerPacket = 2
  input.videoWidth = 2
  input.videoHeight = 2
  input.videoFrameRate = 30
  input.videoBitsPerPixel = 8
  input.audioCapture = "fixture:0102030405060708"
  input.videoCapture = "fixture:11121314"
  input.mediaPacketCount = 1
})
    )

    try report.validate()
    let audio = try #require(report.datagrams.first { $0.stream == LoLaCompatibilityMediaStream.audio })
    let audioPayload = try UltraGridAudioPayload.decode(audio.rtp.payload)
    let videoFragments = try report.datagrams
        .filter { $0.stream == LoLaCompatibilityMediaStream.video }
        .map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }

    #expect(report.provider.audioSource == "fixture")
    #expect(report.provider.videoSource == "fixture")
    #expect(report.observedEvidenceClasses == [ExternalConnectorEvidenceClass.synthetic])
    #expect(audioPayload.pcmPayload == Data([1, 2, 3, 4, 5, 6, 7, 8]))
    #expect(try UltraGridCompatibility.reassembleVideoFrame(videoFragments) == Data([0x11, 0x12, 0x13, 0x14]))
}

@Test
func ultraGridLiveProviderSelectionReportsLiveDeviceEvidenceBeforeHardwareStart() throws {
    let provider = try UltraGridSessionMediaProvider(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/ug-live-provider.json"
) { input in
  input.mediaMode = .audioVideo
  input.videoWidth = 2
  input.videoHeight = 2
  input.videoFrameRate = 30
  input.videoBitsPerPixel = 8
  input.audioCapture = "coreaudio:input-device-uid"
  input.audioPlayback = "coreaudio:output-device-uid"
  input.videoCapture = "avfoundation:camera-uid"
})
    )

    assertLiveDeviceProviderEvidence(
        provider.providerReport, audioSource: "coreaudio-live", videoSource: "avfoundation-raw8-live"
    )
}

@Test
func ultraGridMediaReportRequiresExplicitRuntimeEvidenceBoundary() throws {
    var report = syntheticUltraGridBoundaryReport()

    try report.validate()
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)

    report.observedEvidenceClasses = []
    #expect(throws: ExternalConnectorSessionError.emptyList("ultraGridMedia.observedEvidenceClasses")) {
        try report.validate()
    }

    report = syntheticUltraGridBoundaryReport(missingEvidenceClassesForPass: [])
    #expect(throws: ExternalConnectorSessionError.emptyList("ultraGridMedia.missingEvidenceClassesForPass")) {
        try report.validate()
    }

    let requiredEvidence = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.missingEvidenceClassesForPass = requiredEvidence
    report.verdict = MeasurementVerdict.pass
    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }

    report.realLinkTransmitted = true
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.missingEvidenceClassesForPass"
    )) {
        try report.validate()
    }

    report.missingEvidenceClassesForPass = []
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.observedEvidenceClasses"
    )) {
        try report.validate()
    }

    report.observedEvidenceClasses = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.runtimeError = "late media failure"
    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeError")) {
        try report.validate()
    }
}

@Test
func ultraGridMediaReportAllowsPassOnlyWithCompleteRuntimeEvidence() throws {
    var report = try completeUltraGridRuntimePassReport()

    try report.validate()

    report.sink.rejectedMediaCount = 1
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.sink.rejectedMediaCount"
    )) {
        try report.validate()
    }

    report.sink.rejectedMediaCount = 0
    report.videoFrameReassemblyFailureCount = 1
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.videoFrameReassemblyFailureCount"
    )) {
        try report.validate()
    }
}

@Test
func ultraGridInvalidSyntheticPassFixtureIsRejected() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/UltraGridCompatibilityMediaReports/invalid/ultragrid-synthetic-pass.json")
    let report = try UltraGridCompatibilityMediaReport.decode(from: Data(contentsOf: url))

    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}

@Test
func ultraGridDatagramBuilderUsesInjectedMediaProviderBytes() throws {
    let videoFrame = Data((0..<128).map { UInt8($0) })
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/ug-provider.json"
) { input in
  input.mediaMode = .audioVideo
  input.channels = 2
  input.framesPerPacket = 2
  input.videoWidth = 8
  input.videoHeight = 8
  input.videoFrameRate = 30
  input.videoBitsPerPixel = 24
  input.mediaPacketCount = 1
}),
        mediaProvider: UltraGridFixedMediaProvider(
            audio: Data([0x01, 0x02, 0x03, 0x04]),
            video: videoFrame
        )
    )

    let audio = try #require(datagrams.first { $0.stream == .audio })
    let audioPayload = try UltraGridAudioPayload.decode(audio.rtp.payload)
    #expect(audioPayload.pcmPayload == Data([0x01, 0x02, 0x03, 0x04]))

    let videoFragments = try datagrams
        .filter { $0.stream == .video }
        .map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }
    #expect(try UltraGridCompatibility.reassembleVideoFrame(videoFragments) == videoFrame)
}

@Test
func ultraGridGeneratedRawVideoUsesFullConfiguredFrameAndCounters() throws {
    let width = 640
    let height = 360
    let bitsPerPixel = 24
    let frameByteCount = width * height * (bitsPerPixel / 8)
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/ug-generated-frame.json"
) { input in
  input.mediaMode = .video
  input.videoWidth = width
  input.videoHeight = height
  input.videoFrameRate = 30
  input.videoBitsPerPixel = bitsPerPixel
  input.mediaPacketCount = 1
})
    )

    let fragments = try datagrams.map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }
    let reassembled = try UltraGridCompatibility.reassembleVideoFrame(fragments)
    let expectedFragmentCount = (frameByteCount + 1_200 - UltraGridVideoPayloadHeader.byteCount - 1)
        / (1_200 - UltraGridVideoPayloadHeader.byteCount)
    let report = UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ug-generated-frame",
            capturedAt: "2026-05-18T00:00:00Z",
            role: .tx,
            mediaMode: .video
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: datagrams,
            transmittedDatagramCount: datagrams.count,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            realLinkTransmitted: false,
            verdict: .partial,
            notes: "Generated raw-video sizing test."
        )
    ))

    try report.validate()
    #expect(datagrams.count == expectedFragmentCount)
    #expect(reassembled.count == frameByteCount)
    #expect(report.videoDatagramCount == expectedFragmentCount)
    #expect(report.videoFramePayloadByteCount == frameByteCount)
    #expect(report.rtpPayloadByteCount >= frameByteCount)
}

private func syntheticUltraGridBoundaryReport(
    missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass] =
        ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
) -> UltraGridCompatibilityMediaReport {
    UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ug-evidence-boundary",
            capturedAt: "2026-05-18T00:00:00Z",
            role: .tx,
            mediaMode: .audio
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 0,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            missingEvidenceClassesForPass: missingEvidenceClassesForPass,
            realLinkTransmitted: false,
            verdict: .partial,
            notes: "Synthetic boundary test."
        )
    ))
}

private func completeUltraGridRuntimePassReport() throws -> UltraGridCompatibilityMediaReport {
    UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ug-runtime-pass",
            capturedAt: "2026-05-18T00:00:00Z",
            role: .txRx,
            mediaMode: .audioVideo
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1)],
            transmittedDatagramCount: 1,
            receivedDatagramCount: 1
        ),
        reports: completeUltraGridNestedReports(),
        evidence: UltraGridCompatibilityEvidenceState(
            observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
            missingEvidenceClassesForPass: [],
            realLinkTransmitted: true,
            verdict: .pass,
            notes: "Complete measured evidence test."
        )
    ))
}

private func completeUltraGridNestedReports() -> UltraGridCompatibilityNestedReports {
    UltraGridCompatibilityNestedReports(
        topology: UltraGridTopologyReport(
            mode: .directPeer,
            role: .direct,
            state: .directPeerReady,
            peerRequired: true,
            peerConfigured: true,
            localHost: "198.51.100.10",
            peer: "198.51.100.20",
            notes: "Measured direct-peer route evidence attached."
        ),
        provider: ExternalConnectorMediaProviderReport(
            audioSource: "coreaudio-live",
            videoSource: "avfoundation-raw8-live",
            observedEvidenceClasses: [.liveDevice],
            notes: "Measured live-device provider evidence."
        ),
        sink: ExternalConnectorMediaSinkReport(
            audioPacketCount: 1,
            audioPayloadByteCount: 8,
            videoFrameCount: 0,
            videoPayloadByteCount: 0,
            rejectedMediaCount: 0,
            notes: "Measured sink evidence."
        )
    )
}

private struct UltraGridFixedMediaProvider: UltraGridMediaProviding {
    var audio: Data
    var video: Data

    func audioPCM(sequenceNumber _: Int, channels _: Int, framesPerPacket _: Int) throws -> Data {
        audio
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        video
    }
}
