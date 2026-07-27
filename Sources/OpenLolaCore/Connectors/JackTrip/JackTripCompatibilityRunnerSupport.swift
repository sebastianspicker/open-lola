// Holds private JackTrip runner helpers that keep packet generation and runtime policy independently testable.
import Foundation

typealias JackTripProviderLifecycleLease = ExternalConnectorLifecycleLease

protocol JackTripMonotonicClock {
    func nowNanoseconds() -> UInt64
    func sleep(untilNanoseconds: UInt64) throws
}

struct JackTripSystemMonotonicClock: JackTripMonotonicClock {
    func nowNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    func sleep(untilNanoseconds: UInt64) throws {
        _ = DispatchSemaphore(value: 0).wait(
            timeout: DispatchTime(uptimeNanoseconds: untilNanoseconds)
        )
    }
}

enum JackTripNativeSocketModeValidator {
    static func validate(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard !configuration.dryRun else { return }
        try validateTransport(configuration)
        try validateAudioBackend(configuration)
        try validatePluginMode(configuration)
        try validateTopology(configuration)
        try validateReceivePayload(configuration)
    }

    private static func validateTransport(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard configuration.jackTrip.transportMode == .udp else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-native-transport-\(configuration.jackTrip.transportMode.rawValue)"
            )
        }
    }

    private static func validateAudioBackend(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard configuration.jackTrip.audioBackend != .jackGraph else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-native-audio-backend-jack-graph"
            )
        }
    }

    private static func validatePluginMode(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard configuration.jackTrip.pluginMode == .disabled else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-native-plugin-\(configuration.jackTrip.pluginMode.rawValue)"
            )
        }
    }

    private static func validateTopology(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard configuration.jackTrip.topologyMode == .directPeer else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-native-hub-topology-unwired")
        }
        guard configuration.jackTrip.topologyRole == .direct else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-native-hub-topology-unwired")
        }
        guard configuration.jackTrip.hubTCPHandshakeMode == .none else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-native-hub-topology-unwired")
        }
    }

    private static func validateReceivePayload(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard !configuration.role.receives || configuration.jackTrip.payloadEncoding != .opusCELTLowDelay else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-native-opus-rx-playout-unwired"
            )
        }
    }
}

private struct JackTripDatagramGenerationContext {
    let configuration: ExternalConnectorSessionConfiguration
    let sampleRate: JackTripSampleRate
    let bitResolution: JackTripBitResolution
    let channels: UInt8
    let frames: UInt16
    let redundancy: Int
    let opusEncoder: OpusCELTLowDelayEncoder?
    let packetPeriodNanoseconds: UInt64

    init(
        configuration: ExternalConnectorSessionConfiguration,
        opusEncoderFactory: (Int) throws -> OpusCELTLowDelayEncoder
    ) throws {
        if configuration.jackTrip.packetHeaderMode == .empty,
           configuration.jackTrip.redundancy != 1 {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-empty-header-redundancy")
        }
        _ = try ExternalConnectorMediaProfile.build(configuration: configuration)
        self.configuration = configuration
        sampleRate = try JackTripSampleRate(hertz: configuration.sampleRateHertz)
        bitResolution = try Self.bitResolution(for: configuration)
        channels = try uint8(configuration.channels, "channels")
        frames = try uint16(configuration.framesPerPacket, "framesPerPacket")
        redundancy = max(1, configuration.jackTrip.redundancy)
        opusEncoder = try Self.opusEncoder(for: configuration, factory: opusEncoderFactory)
        packetPeriodNanoseconds = Self.packetPeriodNanoseconds(for: configuration)
    }

    func packet(
        at packetIndex: Int,
        audioProvider: any JackTripAudioFrameProviding,
        deadlineNanoseconds: UInt64?
    ) throws -> JackTripAudioPacket {
        try ensureDeadlineHasNotExpired(deadlineNanoseconds, before: "audio capture")
        let planar = try jackTripPayload(
            configuration: configuration,
            audioProvider: audioProvider,
            packetIndex: packetIndex,
            bitResolution: bitResolution,
            deadlineNanoseconds: deadlineNanoseconds,
            opusEncoder: opusEncoder
        )
        return try JackTripAudioPacket(
            header: JackTripDefaultHeader(
                timestampMicroseconds: UInt64(1_700_000_000_000_000 + packetIndex * configuration.framesPerPacket),
                sequenceNumber: UInt16(packetIndex & 0xffff),
                bufferSizeSamples: frames,
                sampleRate: sampleRate,
                bitResolution: bitResolution,
                incomingChannelsFromNetwork: channels,
                outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
            ),
            planarAudioPayload: planar
        )
    }

    func datagram(containing packets: [JackTripAudioPacket]) -> JackTripCompatibilityDatagram {
        JackTripCompatibilityDatagram(
            destinationPort: configuration.peerAudioPort ?? configuration.audioPort,
            headerMode: configuration.jackTrip.packetHeaderMode,
            packets: packets
        )
    }

    private static func bitResolution(
        for configuration: ExternalConnectorSessionConfiguration
    ) throws -> JackTripBitResolution {
        if configuration.jackTrip.payloadEncoding == .opusCELTLowDelay {
            return .bit32
        }
        return try JackTripBitResolution(bits: configuration.jackTrip.bitResolutionBits)
    }

    private static func opusEncoder(
        for configuration: ExternalConnectorSessionConfiguration,
        factory: (Int) throws -> OpusCELTLowDelayEncoder
    ) throws -> OpusCELTLowDelayEncoder? {
        guard configuration.jackTrip.payloadEncoding == .opusCELTLowDelay else {
            return nil
        }
        return try factory(configuration.channels)
    }

    private static func packetPeriodNanoseconds(
        for configuration: ExternalConnectorSessionConfiguration
    ) -> UInt64 {
        let frames = UInt64(max(1, configuration.framesPerPacket))
        let product = frames.multipliedReportingOverflow(by: 1_000_000_000)
        let numerator = product.overflow ? UInt64.max : product.partialValue
        return max(1, numerator / UInt64(max(1, configuration.sampleRateHertz)))
    }
}

struct JackTripDatagramGenerationRequest {
    let configuration: ExternalConnectorSessionConfiguration
    let audioProvider: any JackTripAudioFrameProviding
    let deadlineNanoseconds: UInt64?
    let opusEncoderFactory: (Int) throws -> OpusCELTLowDelayEncoder
    let clock: (any JackTripMonotonicClock)?
}

private struct JackTripPacingRequest {
    let packetIndex: Int
    let packetCount: Int
    let periodNanoseconds: UInt64
    let startNanoseconds: UInt64?
    let lastEmissionNanoseconds: UInt64?
    let deadlineNanoseconds: UInt64?
    let clock: (any JackTripMonotonicClock)?
}

enum JackTripDatagramGenerator {
    static func forEachDatagram(
        _ request: JackTripDatagramGenerationRequest,
        emit: (JackTripCompatibilityDatagram) throws -> Void
    ) throws {
        let context = try JackTripDatagramGenerationContext(
            configuration: request.configuration,
            opusEncoderFactory: request.opusEncoderFactory
        )
        var packets: [JackTripAudioPacket] = []
        let pacingStartNanoseconds = request.clock?.nowNanoseconds()
        var packetIndex = 0
        var lastEmissionNanoseconds: UInt64?
        while packetIndex < request.configuration.mediaPacketCount {
            guard let slot = try pacingSlot(JackTripPacingRequest(
                packetIndex: packetIndex,
                packetCount: request.configuration.mediaPacketCount,
                periodNanoseconds: context.packetPeriodNanoseconds,
                startNanoseconds: pacingStartNanoseconds,
                lastEmissionNanoseconds: lastEmissionNanoseconds,
                deadlineNanoseconds: request.deadlineNanoseconds,
                clock: request.clock
            )) else { break }
            packetIndex = slot.index
            let packet = try context.packet(
                at: packetIndex,
                audioProvider: request.audioProvider,
                deadlineNanoseconds: request.deadlineNanoseconds
            )
            guard !isPacingOverrun(slot: slot, periodNanoseconds: context.packetPeriodNanoseconds, clock: request.clock) else {
                packetIndex += 1
                continue
            }
            packets.append(packet)
            try ensureDeadlineHasNotExpired(request.deadlineNanoseconds, before: "UDP emit")
            let redundantPackets = Array(packets[max(0, packets.count - context.redundancy)..<packets.count].reversed())
            lastEmissionNanoseconds = request.clock?.nowNanoseconds()
            try emit(context.datagram(containing: redundantPackets))
            packetIndex += 1
        }
    }

    private static func isPacingOverrun(
        slot: (index: Int, targetNanoseconds: UInt64),
        periodNanoseconds: UInt64,
        clock: (any JackTripMonotonicClock)?
    ) -> Bool {
        guard let clock else { return false }
        return clock.nowNanoseconds() >= saturatedAdd(slot.targetNanoseconds, periodNanoseconds)
    }

    private static func pacingSlot(
        _ request: JackTripPacingRequest
    ) throws -> (index: Int, targetNanoseconds: UInt64)? {
        guard let clock = request.clock, let startNanoseconds = request.startNanoseconds else {
            return (request.packetIndex, 0)
        }
        let now = clock.nowNanoseconds()
        let index = nextSlotIndex(
            packetIndex: request.packetIndex,
            now: now,
            startNanoseconds: startNanoseconds,
            periodNanoseconds: request.periodNanoseconds,
            lastEmissionNanoseconds: request.lastEmissionNanoseconds
        )
        guard index < request.packetCount else { return nil }
        let target = slotTarget(
            index: index,
            startNanoseconds: startNanoseconds,
            periodNanoseconds: request.periodNanoseconds
        )
        try waitForPacingSlot(
            now: now,
            targetNanoseconds: target,
            deadlineNanoseconds: request.deadlineNanoseconds,
            clock: clock
        )
        return (index, target)
    }

    private static func nextSlotIndex(
        packetIndex: Int,
        now: UInt64,
        startNanoseconds: UInt64,
        periodNanoseconds: UInt64,
        lastEmissionNanoseconds: UInt64?
    ) -> Int {
        var index = max(packetIndex, slotIndex(
            atNanoseconds: now,
            startNanoseconds: startNanoseconds,
            periodNanoseconds: periodNanoseconds
        ))
        if let lastEmissionNanoseconds {
            index = max(index, firstSlotIndex(
                atOrAfterNanoseconds: saturatedAdd(lastEmissionNanoseconds, periodNanoseconds),
                startNanoseconds: startNanoseconds,
                periodNanoseconds: periodNanoseconds
            ))
        }
        return index
    }

    private static func waitForPacingSlot(
        now: UInt64,
        targetNanoseconds: UInt64,
        deadlineNanoseconds: UInt64?,
        clock: any JackTripMonotonicClock
    ) throws {
        guard now < targetNanoseconds else { return }
        if let deadlineNanoseconds, targetNanoseconds >= deadlineNanoseconds {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip exchange deadline expired before pacing slot"
            )
        }
        try clock.sleep(untilNanoseconds: targetNanoseconds)
    }

    private static func slotIndex(
        atNanoseconds value: UInt64,
        startNanoseconds: UInt64,
        periodNanoseconds: UInt64
    ) -> Int {
        guard value > startNanoseconds else { return 0 }
        return Int(clamping: (value - startNanoseconds) / periodNanoseconds)
    }

    private static func firstSlotIndex(
        atOrAfterNanoseconds value: UInt64,
        startNanoseconds: UInt64,
        periodNanoseconds: UInt64
    ) -> Int {
        guard value > startNanoseconds else { return 0 }
        let elapsed = value - startNanoseconds
        let quotient = elapsed / periodNanoseconds
        let rounded = elapsed % periodNanoseconds == 0 ? quotient : saturatedAdd(quotient, 1)
        return Int(clamping: rounded)
    }

    private static func slotTarget(
        index: Int,
        startNanoseconds: UInt64,
        periodNanoseconds: UInt64
    ) -> UInt64 {
        let product = UInt64(index).multipliedReportingOverflow(by: periodNanoseconds)
        return saturatedAdd(startNanoseconds, product.overflow ? UInt64.max : product.partialValue)
    }

    private static func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

private func ensureDeadlineHasNotExpired(_ deadlineNanoseconds: UInt64?, before operation: String) throws {
    guard let deadlineNanoseconds, DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds else {
        return
    }
    throw ExternalConnectorSessionError.socketFailed("JackTrip exchange deadline expired before \(operation)")
}
