// Verifies that UltraGrid receive analysis reports RTP quality counters.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridReceiveAnalysisReportsRtpQualityCounters() throws {
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 1, timestamp: 128, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 256, ssrc: 2),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 384, ssrc: 2),
        try ultraGridAudioDatagram(sequence: 3, timestamp: 640, ssrc: 2),
        try ultraGridAudioDatagram(sequence: 1, timestamp: 64, ssrc: 2)
    ]
    let report = try ultraGridReceiveAnalysisReport(received: received)

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.rtpPacketsLost == 0)
    #expect(report.rtpDuplicatePacketCount == 1)
    #expect(report.rtpOutOfOrderPacketCount == 1)
    #expect(report.rtpSsrcChangeCount == 1)
    #expect(report.rtpTimestampRegressionCount == 1)
    #expect(report.rtpJitterLikeArrivalDeltaCount == 1)
}

@Test
func ultraGridReceiveAnalysisExtendsSequenceNumbersPerSSRCAcrossWrap() throws {
    let analysis = UltraGridCompatibilityRunner.analyzeSequence([
        try ultraGridAudioDatagram(sequence: 65_534, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 65_535, timestamp: 128, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 0, timestamp: 256, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 1, timestamp: 384, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 0, timestamp: 256, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 2)
    ])

    #expect(analysis.lost == 0)
    #expect(analysis.duplicates == 1)
    #expect(analysis.outOfOrder == 1)
    #expect(analysis.ssrcChanges == 1)
}

@Test
func ultraGridReceiveAnalysisDoesNotTreatTimestampWrapAsRegression() throws {
    let analysis = UltraGridCompatibilityRunner.analyzeSequence([
        try ultraGridAudioDatagram(sequence: 10, timestamp: UInt32.max - 127, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 11, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 12, timestamp: 128, ssrc: 1)
    ])

    #expect(analysis.timestampRegressions == 0)
    #expect(analysis.jitterLikeArrivalDeltaChanges == 0)
}

@Test
func ultraGridReceiveAnalysisReportsLossAndVideoReassemblyFailures() throws {
    let videoPackets = try receiveAnalysisVideoPackets()
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 128, ssrc: 1),
        UltraGridCompatibilityDatagram(
            stream: .video,
            sourceHost: "203.0.113.10",
            destinationPort: 50_004,
            rtp: try #require(videoPackets.first)
        )
    ]
    let report = try ultraGridReceiveAnalysisReport(received: received, includesVideo: true)

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "UltraGrid video frame reassembly failed for 1 frame(s)")
    #expect(report.rtpPacketsLost == 1)
    #expect(report.videoFrameReassemblyFailureCount == 1)
    #expect(report.sink.audioPacketCount == 2)
    #expect(report.sink.videoFrameCount == 0)
    #expect(report.sink.rejectedMediaCount == 1)
}

private func receiveAnalysisVideoPackets() throws -> [RTPPacket] {
    let frame = Data((0..<2_048).map { UInt8($0 & 0xff) })
    return try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: frame,
            id: 9,
            width: 32,
            height: 32,
            frameRate: 30,
            bitsPerPixel: 24
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 10,
            timestamp: 3_000,
            ssrc: 3,
            maxPayloadBytes: 600
        )
    ))
}

@Test
func ultraGridReceiveAnalysisFailsWhenVideoFragmentRecoveryThrows() throws {
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        UltraGridCompatibilityDatagram(
            stream: .video,
            sourceHost: "203.0.113.10",
            destinationPort: 50_004,
            rtp: RTPPacket(
                header: RTPPacketHeader(
                    payloadType: UltraGridCompatibility.videoPayloadType,
                    sequenceNumber: 1,
                    timestamp: 128,
                    ssrc: 2
                ),
                payload: Data([0x01, 0x02])
            )
        )
    ]
    let report = try ultraGridReceiveAnalysisReport(received: received, includesVideo: true)

    try report.validate()
    #expect(report.verdict == MeasurementVerdict.fail)
    #expect(report.videoFrameReassemblyFailureCount == 1)
    #expect(report.runtimeError == "UltraGrid video fragment recovery failed before frame reassembly")
    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.videoFrameCount == 0)
    #expect(report.sink.rejectedMediaCount == 1)
}

private func ultraGridReceiveAnalysisReport(
    received: [UltraGridCompatibilityDatagram],
    includesVideo: Bool = false
) throws -> UltraGridCompatibilityMediaReport {
    try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .rx,
  peer: "203.0.113.10",
  outputPath: "/tmp/ug-rx.json"
) { input in
  input.dryRun = false
  input.mediaMode = .audio
  input.audioPort = 50_006
  if includesVideo {
    input.videoPort = 50_004
  }
  input.mediaPacketCount = received.count
}),
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: received)
    )
}
