import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

struct DirectPeerAudioRXLoopConfiguration {
    var transport: DirectPeerSessionAudioTransport
    var opusDecoder: OpusCELTLowDelayDecoder?
    var opusScratch: DirectPeerOpusSessionScratch? = nil
    var maxPackets: Int
    /// A direct RX profile treats packets observed in one bounded drain as a
    /// scheduling burst. Only its newest complete playout unit is useful.
    var preferNewestPayload = false
}

struct DirectPeerAudioRXLoopState {
    var rtpValidator: AES67ST2110L24RTPReceiveValidator
    var aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper
    var rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState
    var playoutFrameAnchor = DirectPeerRemotePlayoutFrameAnchor()
    /// Fixed session buffer for L24-to-float conversion.
    var aes67DecodeScratch = Data()
}

/// Maps the sender's frame timeline onto local output frames. `queuePlayoutPayload` adds the
/// playout target afterwards, so a payload is only late when even the target cannot absorb it.
/// A sustained excess above target plus slack re-anchors too, so latency can shrink again.
struct DirectPeerRemotePlayoutFrameAnchor {
    static let excessLatencyPayloadLimit = 64
    static let excessLatencySlackBuffers: UInt64 = 4

    private(set) var remoteBaseFrame: UInt64?
    private(set) var localBaseFrame: UInt64?
    private(set) var excessLatencyStreak = 0
    private var pendingReanchors = 0

    mutating func localFrame(
        remoteFrame: UInt64,
        nextLocalOutputFrame: UInt64,
        targetFrames: Int,
        framesPerBuffer: Int
    ) -> UInt64 {
        guard let mappedFrame = mappedLocalFrame(remoteFrame: remoteFrame) else {
            return reanchor(remoteFrame: remoteFrame, nextLocalOutputFrame: nextLocalOutputFrame)
        }
        switch directPeerPlayoutFramePlacement(
            mappedFrame: mappedFrame,
            nextLocalOutputFrame: nextLocalOutputFrame,
            targetFrames: targetFrames,
            framesPerBuffer: framesPerBuffer
        ) {
        case .late:
            return reanchor(remoteFrame: remoteFrame, nextLocalOutputFrame: nextLocalOutputFrame)
        case .excessLatency:
            excessLatencyStreak += 1
            guard excessLatencyStreak < Self.excessLatencyPayloadLimit else {
                return reanchor(remoteFrame: remoteFrame, nextLocalOutputFrame: nextLocalOutputFrame)
            }
            return mappedFrame
        case .onTime:
            excessLatencyStreak = 0
            return mappedFrame
        }
    }

    /// Returns and clears the number of re-anchors after the initial anchor.
    mutating func consumeReanchorCount() -> Int {
        let count = pendingReanchors
        pendingReanchors = 0
        return count
    }

    private func mappedLocalFrame(remoteFrame: UInt64) -> UInt64? {
        guard let remoteBaseFrame, let localBaseFrame else {
            return nil
        }
        if remoteFrame >= remoteBaseFrame {
            let mapped = localBaseFrame.addingReportingOverflow(remoteFrame - remoteBaseFrame)
            return mapped.overflow ? nil : mapped.partialValue
        }
        let backwardFrames = remoteBaseFrame - remoteFrame
        guard backwardFrames <= localBaseFrame else {
            return nil
        }
        return localBaseFrame - backwardFrames
    }

    private mutating func reanchor(remoteFrame: UInt64, nextLocalOutputFrame: UInt64) -> UInt64 {
        if remoteBaseFrame != nil {
            pendingReanchors += 1
        }
        remoteBaseFrame = remoteFrame
        localBaseFrame = nextLocalOutputFrame
        excessLatencyStreak = 0
        return nextLocalOutputFrame
    }
}

enum DirectPeerPlayoutFramePlacement: Equatable {
    case late
    case onTime
    case excessLatency
}

/// Pure placement rule: late when `mapped + target < next`, excess when
/// `mapped > next + target + slackBuffers * framesPerBuffer`, otherwise on time.
func directPeerPlayoutFramePlacement(
    mappedFrame: UInt64,
    nextLocalOutputFrame: UInt64,
    targetFrames: Int,
    framesPerBuffer: Int
) -> DirectPeerPlayoutFramePlacement {
    let target = UInt64(max(0, targetFrames))
    let latestPlayable = mappedFrame.addingReportingOverflow(target)
    if !latestPlayable.overflow, latestPlayable.partialValue < nextLocalOutputFrame {
        return .late
    }
    let slack = UInt64(max(0, framesPerBuffer)).multipliedReportingOverflow(
        by: DirectPeerRemotePlayoutFrameAnchor.excessLatencySlackBuffers
    )
    guard !slack.overflow else {
        return .onTime
    }
    let tolerance = target.addingReportingOverflow(slack.partialValue)
    guard !tolerance.overflow else {
        return .onTime
    }
    let excessBound = nextLocalOutputFrame.addingReportingOverflow(tolerance.partialValue)
    if !excessBound.overflow, mappedFrame > excessBound.partialValue {
        return .excessLatency
    }
    return .onTime
}

private struct DirectPeerAudioRXLoopContext {
    var state: DirectPeerAudioRXLoopState
    var result = DirectPeerAudioRXDrainResult()
    var received = 0
}

struct DirectPeerAudioPlayoutPayload {
    var payload: Data
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
}

/// Bounded-drain freshness policy for the direct profile. This is deliberately
/// independent of socket IO so burst behavior remains deterministic.
struct DirectPeerAudioRXFreshnessAccumulator {
    private(set) var newestPayload: DirectPeerAudioPlayoutPayload?
    private(set) var droppedStalePayloadCount = 0

    mutating func record(_ payload: DirectPeerAudioPlayoutPayload) {
        guard let newestPayload else {
            self.newestPayload = payload
            return
        }
        guard directPeerFrameIndexIsNewer(
            payload.senderFrameIndex,
            than: newestPayload.senderFrameIndex
        ) else {
            droppedStalePayloadCount += 1
            return
        }
        self.newestPayload = payload
        droppedStalePayloadCount += 1
    }
}

/// Sender frame indexes are a modulo-2^64 timeline. A gap smaller than half
/// that range is forward progress; equal and backward values are stale.
private func directPeerFrameIndexIsNewer(_ candidate: UInt64, than current: UInt64) -> Bool {
    let distance = candidate &- current
    return distance != 0 && distance < (UInt64.max / 2) + 1
}

private enum DirectPeerAudioRXReceiveOutcome {
    case payload(DirectPeerAudioPlayoutPayload)
    case dropped
    case noPacket
}

func runAudioRXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    state: inout DirectPeerAudioRXLoopState,
    configuration: DirectPeerAudioRXLoopConfiguration
) throws -> DirectPeerAudioRXDrainResult {
    var context = DirectPeerAudioRXLoopContext(
        state: state
    )
    var freshness = DirectPeerAudioRXFreshnessAccumulator()
    receiveLoop: while context.received < configuration.maxPackets {
        switch try receiveDirectPeerAudioPayload(
            runner: &runner,
            configuration: configuration,
            context: &context
        ) {
        case .payload(let payload):
            if configuration.preferNewestPayload {
                freshness.record(payload)
            } else {
                queueDirectPeerAudioPayload(
                    payload,
                    audioGraph: audioGraph,
                    state: &context.state,
                    result: &context.result
                )
            }
        case .dropped:
            continue
        case .noPacket:
            break receiveLoop
        }
    }
    if let newestPayload = freshness.newestPayload {
        context.result.droppedBeforePlayout += freshness.droppedStalePayloadCount
        queueDirectPeerAudioPayload(
            newestPayload,
            audioGraph: audioGraph,
            state: &context.state,
            result: &context.result
        )
    }
    state = context.state
    return context.result
}

private func receiveDirectPeerAudioPayload(
    runner: inout PeerSessionRunner,
    configuration: DirectPeerAudioRXLoopConfiguration,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    switch configuration.transport {
    case .openLolaRaw:
        return try receiveDirectPeerRawAudioPayload(runner: &runner, context: &context)
    case .openLolaOpusCeltLowDelay:
        return try receiveDirectPeerOpusAudioPayload(
            runner: &runner,
            configuration: configuration,
            context: &context
        )
    case .aes67ST2110L24:
        return try receiveDirectPeerAES67AudioPayload(runner: &runner, context: &context)
    }
}

private func receiveDirectPeerRawAudioPayload(
    runner: inout PeerSessionRunner,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    let receivedPacket: PeerSessionReceivedAudioMediaPacket
    do {
        guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
            return .noPacket
        }
        receivedPacket = packet
    } catch {
        guard isRecoverableOpenLolaRawAudioReceiveError(error) else {
            throw error
        }
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    context.received += 1
    guard receivedPacket.packet.header.payloadType == DirectPeerSessionAudioTransport.openLolaRaw.payloadType else {
        context.result.unexpectedPayloadTypes += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let decoded = receivedPacket.decodedPcmV2 else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    let reassembled: DirectPeerOpenLolaRawAudioBlock?
    do {
        reassembled = try context.state.rawAudioReassembly.receive(decoded)
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedIncompleteDeadlines()
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedDuplicateFragments()
    } catch {
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.flushIncomplete()
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedDuplicateFragments()
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let reassembled else {
        return .dropped
    }
    return .payload(DirectPeerAudioPlayoutPayload(
        payload: reassembled.payload,
        senderFrameIndex: reassembled.senderFrameIndex,
        senderHostTimeNanoseconds: reassembled.senderHostTimeNanoseconds
    ))
}

private func receiveDirectPeerOpusAudioPayload(
    runner: inout PeerSessionRunner,
    configuration: DirectPeerAudioRXLoopConfiguration,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    let receivedPacket: PeerSessionReceivedAudioMediaPacket
    do {
        guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
            return .noPacket
        }
        receivedPacket = packet
    } catch is UdpMediaMalformedDatagramError {
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    context.received += 1
    guard receivedPacket.packet.header.payloadType == configuration.transport.payloadType else {
        context.result.unexpectedPayloadTypes += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let opusDecoder = configuration.opusDecoder else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus decoder")
    }
    guard let opusScratch = configuration.opusScratch else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus decoder scratch")
    }
    guard let decoded = receivedPacket.decodedOpusCeltLowDelay else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    do {
        let decodedByteCount = try decoded.payload.withUnsafeBytes { input in
            try opusScratch.decoded.withUnsafeMutableBytes { output in
                try opusDecoder.decode(input, into: output)
            }
        }
        return .payload(DirectPeerAudioPlayoutPayload(
            payload: Data(opusScratch.decoded.prefix(decodedByteCount)),
            senderFrameIndex: decoded.header.senderFrameIndex,
            senderHostTimeNanoseconds: decoded.header.senderHostTimeNanoseconds
        ))
    } catch {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
}

private func receiveDirectPeerAES67AudioPayload(
    runner: inout PeerSessionRunner,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    switch try receiveDirectPeerAES67Packet(runner: &runner, context: &context) {
    case .noPacket:
        return .noPacket
    case .dropped:
        return .dropped
    case let .packet(packet):
        return try decodeDirectPeerAES67AudioPayload(packet: packet, context: &context)
    }
}

private enum DirectPeerAES67ReceiveAttempt {
    case noPacket
    case dropped
    case packet(RTPPacket)
}

private func receiveDirectPeerAES67Packet(
    runner: inout PeerSessionRunner,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAES67ReceiveAttempt {
    do {
        guard let receivedPacket = try runner.receiveAES67ST2110L24RTPPacketIfAvailable() else {
            return .noPacket
        }
        context.received += 1
        return .packet(receivedPacket)
    } catch {
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
}

private func decodeDirectPeerAES67AudioPayload(
    packet: RTPPacket,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    guard let decodedPayload = try decodeDirectPeerAES67Payload(packet, context: &context) else {
        return .dropped
    }
    guard let mappedHostTimeNanoseconds = context.state.aes67ClockMapper.hostTimeNanoseconds(
        rtpTimestamp: packet.header.timestamp,
        observedHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
    ) else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    return .payload(DirectPeerAudioPlayoutPayload(
        payload: decodedPayload,
        senderFrameIndex: UInt64(packet.header.timestamp),
        senderHostTimeNanoseconds: mappedHostTimeNanoseconds
    ))
}

private func decodeDirectPeerAES67Payload(
    _ packet: RTPPacket,
    context: inout DirectPeerAudioRXLoopContext
) throws -> Data? {
    do {
        let lostBefore = context.state.rtpValidator.lostPackets
        try context.state.rtpValidator.validate(packet)
        let lostDelta = max(0, context.state.rtpValidator.lostPackets - lostBefore)
        context.result.rtpPacketsLost += lostDelta
        context.result.droppedBeforePlayout += lostDelta
        let decodedByteCount = context.state.rtpValidator.packetTime.framesPerPacket
            * AES67ST2110L24Profile.channelCount
            * MemoryLayout<Float>.size
        if context.state.aes67DecodeScratch.count != decodedByteCount {
            context.state.aes67DecodeScratch = Data(count: decodedByteCount)
        }
        try packet.payload.withUnsafeBytes { input in
            try context.state.aes67DecodeScratch.withUnsafeMutableBytes { output in
                try L24PCMCodec.decodeFloat32InterleavedStereo(
                    input,
                    into: output,
                    framesPerPacket: context.state.rtpValidator.packetTime.framesPerPacket
                )
            }
        }
        return Data(context.state.aes67DecodeScratch)
    } catch {
        context.result.droppedBeforePlayout += 1
        return nil
    }
}

private func queueDirectPeerAudioPayload(
    _ payload: DirectPeerAudioPlayoutPayload,
    audioGraph: DirectPeerRealtimeAudioGraph,
    state: inout DirectPeerAudioRXLoopState,
    result: inout DirectPeerAudioRXDrainResult
) {
        let localStartFrame = state.playoutFrameAnchor.localFrame(
            remoteFrame: payload.senderFrameIndex,
            nextLocalOutputFrame: audioGraph.nextOutputFrameSnapshot(),
            targetFrames: audioGraph.playoutTargetFramesSnapshot(),
            framesPerBuffer: audioGraph.configuration.framesPerBuffer
        )
        result.playoutReanchors += state.playoutFrameAnchor.consumeReanchorCount()
        let queueResult = audioGraph.queuePlayoutPayload(
            payload.payload,
            startFrame: localStartFrame,
            hostTimeNanoseconds: payload.senderHostTimeNanoseconds
        )
        if queueResult == .stored {
            result.queuedForPlayout += 1
            result.latestHostTimeNanoseconds = payload.senderHostTimeNanoseconds
        } else {
            result.droppedByPlayoutQueue += 1
        }
}

private func isRecoverableOpenLolaRawAudioReceiveError(_ error: Error) -> Bool {
    if error is UdpMediaMalformedDatagramError {
        return true
    }
    if error is MadiReceiveError {
        return true
    }
    if let runnerError = error as? PeerSessionRunnerError {
        switch runnerError {
        case .unsupportedControlMessage:
            return true
        default:
            return false
        }
    }
    return false
}
