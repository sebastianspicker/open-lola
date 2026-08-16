// Exercises LCOV-identified pure branches with synthetic payloads and configuration only.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRemoteVideoMapperReanchorsWhenHostTimeAdditionOverflows() throws {
    let mapper = DirectPeerRemoteVideoHostTimeMapper()
    let first = mapper.map(
        deterministicWave7Frame(sequence: 1, timestamp: 10),
        observedLocalHostTimeNanoseconds: UInt64.max - 2
    )
    let overflowed = mapper.map(
        deterministicWave7Frame(sequence: 2, timestamp: 20),
        observedLocalHostTimeNanoseconds: 77
    )
    let continued = mapper.map(
        deterministicWave7Frame(sequence: 3, timestamp: 22),
        observedLocalHostTimeNanoseconds: 999
    )

    #expect(first.metadata.timestampNanoseconds == UInt64.max - 2)
    #expect(overflowed.metadata.timestampNanoseconds == 77)
    #expect(continued.metadata.timestampNanoseconds == 79)
}

@Test
func lolaQuickConnectFieldsUseZeroVideoContractForAudioOnlySessions() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-wave7-fields.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.sessionID = "42"
        input.mediaMode = .audio
    })

    let fields = try lolaExpectedQuickConnectFields(
        configuration: configuration,
        sourceIP: "192.0.2.10"
    )

    #expect(fields["SRCIP"] == "192.0.2.20")
    #expect(fields["DSTIP"] == "192.0.2.10")
    #expect(fields["SID"] == "42")
    #expect(fields["FPS"] == "0")
    #expect(fields["BPP"] == "0")
    #expect(fields["X"] == "0")
    #expect(fields["Y"] == "0")
    #expect(fields["COMP"] == "0")
    #expect(fields["BAYER"] == "0")
}

@Test
func realtimeAudioCaptureRingStoresSilenceAndClearsEachReusableSlot() throws {
    let shape = try RealtimeAudioPayloadShape(
        frameCount: 1,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    var ring = RealtimeAudioPayloadCaptureRing(
        capacity: 1,
        shape: shape,
        inputChannelMap: [0, 1]
    )

    let first = ring.pushSilence(startFrame: 1, hostTimeNanoseconds: 2)
    guard let firstPayload = ring.pop() else {
        Issue.record("expected first silent payload")
        return
    }
    let second = ring.pushSilence(startFrame: 3, hostTimeNanoseconds: 4)
    guard let secondPayload = ring.pop() else {
        Issue.record("expected second silent payload")
        return
    }

    #expect(first.result == .stored)
    #expect(second.result == .stored)
    #expect(firstPayload.payload == Data(repeating: 0, count: 4))
    #expect(secondPayload.payload == Data(repeating: 0, count: 4))
    #expect(secondPayload.block.startFrame == 3)
}

private func deterministicWave7Frame(sequence: UInt64, timestamp: UInt64) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequence,
            timestampNanoseconds: timestamp,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 1,
            height: 1,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "wave7-\(sequence)"
        ),
        payload: Data([0, 0, 0, 0])
    )
}
