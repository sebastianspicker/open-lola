// Validates UdpPcmLoopbackReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension UdpPcmLoopbackReport {
    public static func decode(from data: Data) throws -> UdpPcmLoopbackReport {
        try JSONDecoder().decode(UdpPcmLoopbackReport.self, from: data)
    }

    public func validate() throws {
        try validatePrimitiveFields()
        try validateSessionConsistency()
        try validateTimingAndAccounting()
        try validatePassVerdict()
    }

    private func validatePrimitiveFields() throws {
        try requireLoopbackNonEmpty(id, "id")
        try requireLoopbackNonEmpty(capturedAt, "capturedAt")
        try requireLoopbackNonEmpty(route.label, "route.label")
        try requireLoopbackNonEmpty(route.topology, "route.topology")
        try requireLoopbackNonEmpty(session.sessionID, "session.sessionID")
        try requireLoopbackNonEmpty(session.localEndpoint, "session.localEndpoint")
        try requireLoopbackNonEmpty(session.peerEndpoint, "session.peerEndpoint")
        try requireLoopbackPositive(Int(session.port), "session.port")
        try requireLoopbackPositive(session.durationSeconds, "session.durationSeconds")
        try requireLoopbackNonEmpty(peer, "peer")
        try requireLoopbackNonEmpty(notes, "notes")
        try requireLoopbackPositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try requireLoopbackPositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try requireLoopbackPositive(packetMode.channelCount, "packetMode.channelCount")
        try requireLoopbackNonNegative(metrics.packetsSent, "metrics.packetsSent")
        try requireLoopbackNonNegative(metrics.packetsEchoed, "metrics.packetsEchoed")
        try requireLoopbackNonNegative(metrics.lostPackets, "metrics.lostPackets")
        try requireLoopbackNonNegative(metrics.rtt.p50Microseconds, "metrics.rtt.p50Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.p95Microseconds, "metrics.rtt.p95Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.p99Microseconds, "metrics.rtt.p99Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.maxMicroseconds, "metrics.rtt.maxMicroseconds")
        try requireLoopbackNonNegative(
            metrics.oneWayEstimateMicroseconds,
            "metrics.oneWayEstimateMicroseconds"
        )
        try requireLoopbackNonNegative(metrics.jitterP99Microseconds, "metrics.jitterP99Microseconds")
        try requireLoopbackNonNegative(metrics.duplicatePackets, "metrics.duplicatePackets")
        try requireLoopbackNonNegative(metrics.outOfOrderPackets, "metrics.outOfOrderPackets")
        try requireLoopbackNonNegative(metrics.malformedEchoPackets, "metrics.malformedEchoPackets")
        try requireLoopbackNonNegative(metrics.wrongSizeEchoPackets, "metrics.wrongSizeEchoPackets")
        try requireLoopbackNonNegative(metrics.fatalReceiveErrors, "metrics.fatalReceiveErrors")
    }

    private func validateSessionConsistency() throws {
        if session.localRole != role || session.peerRole != role.reciprocal {
            throw UdpPcmLoopbackValidationError.sessionRoleMismatch
        }
        if session.peerEndpoint != peer {
            throw UdpPcmLoopbackValidationError.sessionEndpointMismatch
        }
        if session.packetMode != packetMode {
            throw UdpPcmLoopbackValidationError.sessionPacketModeMismatch
        }
    }

    private func validateTimingAndAccounting() throws {
        guard metrics.rtt.p50Microseconds <= metrics.rtt.p95Microseconds,
              metrics.rtt.p95Microseconds <= metrics.rtt.p99Microseconds,
              metrics.rtt.p99Microseconds <= metrics.rtt.maxMicroseconds else {
            throw UdpPcmLoopbackValidationError.unorderedTiming
        }
        let expectedLost = max(0, metrics.packetsSent - metrics.packetsEchoed)
        if metrics.lostPackets != expectedLost {
            throw UdpPcmLoopbackValidationError.packetAccountingMismatch(
                expectedLost: expectedLost,
                actualLost: metrics.lostPackets
            )
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        if !metrics.byteExactEcho {
            throw UdpPcmLoopbackValidationError.passWithoutByteExactEcho
        }
        if metrics.lostPackets > 0 {
            throw UdpPcmLoopbackValidationError.passWithLoss
        }
        try validatePassPacketIntegrity()
    }

    private func validatePassPacketIntegrity() throws {
        if metrics.duplicatePackets > 0 || metrics.outOfOrderPackets > 0 {
            throw UdpPcmLoopbackValidationError.passWithDuplicateOrOutOfOrderPackets
        }
        if metrics.malformedEchoPackets > 0
            || metrics.wrongSizeEchoPackets > 0
            || metrics.fatalReceiveErrors > 0 {
            throw UdpPcmLoopbackValidationError.passWithMalformedOrFatalEcho
        }
    }

    public func validateSessionPair(with other: UdpPcmLoopbackReport) throws {
        try validate()
        try other.validate()
        guard role != other.role else {
            throw UdpPcmLoopbackValidationError.sessionRolePairMismatch
        }
        guard session.sessionID == other.session.sessionID else {
            throw UdpPcmLoopbackValidationError.sessionIDMismatch
        }
        guard session.packetMode == other.session.packetMode else {
            throw UdpPcmLoopbackValidationError.sessionPacketModeMismatch
        }
        guard session.port == other.session.port else {
            throw UdpPcmLoopbackValidationError.sessionPortMismatch
        }
        guard session.durationSeconds == other.session.durationSeconds else {
            throw UdpPcmLoopbackValidationError.sessionDurationMismatch
        }
        guard session.peerEndpoint == other.session.localEndpoint,
              other.session.peerEndpoint == session.localEndpoint else {
            throw UdpPcmLoopbackValidationError.sessionEndpointMismatch
        }
    }
}
