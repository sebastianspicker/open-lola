// Verifies NAT keepalive RTT accounting uses local monotonic time only.
import Testing

@testable import OpenLolaCore

@Test
func natKeepaliveRttUsesLocalSendTimeWhenPeerTimestampIsUnrepresentable() {
    var state = NatKeepaliveExchangeState(sequence: 7, timeoutNanoseconds: 1_000)
    state.recordKeepaliveSent(at: 10_000)

    state.recordAcknowledgedKeepalive(
        NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: "session",
            peerID: "peer",
            sequence: 3,
            sentAtNanoseconds: .max,
            ackSequence: 7
        ),
        receivedAt: 12_500
    )

    #expect(state.rttMicroseconds == 2.5)
}

@Test
func natKeepaliveIgnoresStaleAndMismatchedAcknowledgements() {
    var state = NatKeepaliveExchangeState(sequence: 7, timeoutNanoseconds: 1_000)
    state.recordKeepaliveSent(at: 10_000)

    state.recordAcknowledgedKeepalive(
        NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: "session",
            peerID: "peer",
            sequence: 3,
            sentAtNanoseconds: 1,
            ackSequence: 6
        ),
        receivedAt: 12_500
    )

    #expect(state.rttMicroseconds == nil)
    #expect(state.outstandingSentAtNanoseconds == 10_000)

    let matchingAcknowledgement = NatTraversalKeepaliveMessage(
        magic: NatProtocolMagic.keepalive,
        sessionID: "session",
        peerID: "peer",
        sequence: 4,
        sentAtNanoseconds: 2,
        ackSequence: 7
    )
    state.recordAcknowledgedKeepalive(matchingAcknowledgement, receivedAt: 13_000)
    state.recordAcknowledgedKeepalive(matchingAcknowledgement, receivedAt: 20_000)

    #expect(state.rttMicroseconds == 3)
    #expect(state.outstandingSentAtNanoseconds == nil)
}

@Test
func natKeepaliveRttRequiresNonDecreasingLocalClock() {
    var state = NatKeepaliveExchangeState(sequence: 7, timeoutNanoseconds: 1_000)
    state.recordKeepaliveSent(at: 10_000)

    state.recordAcknowledgedKeepalive(
        NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: "session",
            peerID: "peer",
            sequence: 3,
            sentAtNanoseconds: .max,
            ackSequence: 7
        ),
        receivedAt: 9_999
    )

    #expect(state.rttMicroseconds == nil)
    #expect(state.outstandingSentAtNanoseconds == 10_000)
}

@Test
func natKeepaliveRetriesRetainOriginalOutstandingSendTime() {
    var state = NatKeepaliveExchangeState(sequence: 7, timeoutNanoseconds: 1_000)
    state.recordKeepaliveSent(at: 10_000)
    state.recordKeepaliveSent(at: 15_000)

    state.recordAcknowledgedKeepalive(
        NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: "session",
            peerID: "peer",
            sequence: 3,
            sentAtNanoseconds: .max,
            ackSequence: 7
        ),
        receivedAt: 20_000
    )

    #expect(state.attempts == 2)
    #expect(state.lastSend == 15_000)
    #expect(state.rttMicroseconds == 10)
    #expect(state.outstandingSentAtNanoseconds == nil)
}
