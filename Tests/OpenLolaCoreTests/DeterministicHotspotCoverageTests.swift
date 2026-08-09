// Exercises bounded media transport seams without devices, external peers, or persisted artifacts.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimeAudioCaptureRingPreservesPayloadAndRejectsFullOrMalformedInput() throws {
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
    let payload = Data([1, 2, 3, 4])
    let stored = payload.withUnsafeBytes {
        ring.pushInterleaved(
            startFrame: 7,
            hostTimeNanoseconds: 9,
            sourceChannelCount: 2,
            sourceBytes: $0
        )
    }
    let full = payload.withUnsafeBytes {
        ring.pushInterleaved(
            startFrame: 8,
            hostTimeNanoseconds: 10,
            sourceChannelCount: 2,
            sourceBytes: $0
        )
    }

    #expect(stored.result == .stored)
    #expect(full.result == .droppedFull)
    #expect(ring.droppedBlocks == 1)
    guard let captured = ring.pop() else {
        Issue.record("expected stored capture payload")
        return
    }
    #expect(captured.block.startFrame == 7)
    #expect(captured.block.hostTimeNanoseconds == 9)
    #expect(captured.payload == payload)

    let malformed = Data([0, 1]).withUnsafeBytes {
        ring.pushInterleaved(
            startFrame: 9,
            hostTimeNanoseconds: 11,
            sourceChannelCount: 2,
            sourceBytes: $0
        )
    }
    #expect(malformed.result == .droppedInvalid)
}

@Test
func udpLoopbackDiagnosticsClassifiesComparableAndDivergentSyntheticPingMeasurements() {
    let ping = NetworkPingResult(
        transmitted: 3,
        received: 3,
        packetLossPercent: 0,
        minRttMilliseconds: 1,
        averageRttMilliseconds: 1,
        maxRttMilliseconds: 1,
        standardDeviationMilliseconds: 0
    )

    #expect(UdpPcmLoopbackDiagnosticsComparison.compare(
        udpAverageRttMicroseconds: 1_050,
        ping: ping
    ).classification == .similar)
    #expect(UdpPcmLoopbackDiagnosticsComparison.compare(
        udpAverageRttMicroseconds: 1_200,
        ping: ping
    ).classification == .udpHigher)
    #expect(UdpPcmLoopbackDiagnosticsComparison.compare(
        udpAverageRttMicroseconds: 700,
        ping: ping
    ).classification == .udpLower)
}

@Test
func madiCorrectionEventRejectsCallbackMutationAndInvalidCorrectionEvidence() {
    let callbackMutation = MadiFullDuplexCorrectionEvent(
        sequenceNumber: 1,
        action: .insertFrame,
        driftSlopePartsPerMillion: 10,
        correctionFrames: 1,
        changedInsideAudioCallback: true,
        reason: "synthetic test"
    )
    let invalidEvidence = MadiFullDuplexCorrectionEvent(
        sequenceNumber: 2,
        action: .dropFrame,
        driftSlopePartsPerMillion: .nan,
        correctionFrames: 0,
        changedInsideAudioCallback: false,
        reason: ""
    )

    #expect(throws: MadiFullDuplexError.correctionChangedInsideCallback) {
        try callbackMutation.validate()
    }
    #expect(throws: MadiFullDuplexError.nonFiniteField("correction.driftSlopePartsPerMillion")) {
        try invalidEvidence.validate()
    }
}
