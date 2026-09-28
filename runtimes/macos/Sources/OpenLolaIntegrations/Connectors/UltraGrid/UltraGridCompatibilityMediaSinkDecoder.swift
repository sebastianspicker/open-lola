import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Handles UltraGridCompatibilityMediaSinkDecoder receive-side processing, isolating input handling from compatibility and report policy.
import Foundation

enum UltraGridCompatibilityMediaSinkDecoder {
    private struct RuntimeMediaSinkState {
        var audioPacketCount = 0
        var audioPayloadByteCount = 0
        var rejectedMediaCount = 0
        var videoFrameCount = 0
        var videoPayloadByteCount = 0
        var videoPackets: [RTPPacket] = []
    }

    static func consumeReceivedMedia(
        _ datagrams: [UltraGridCompatibilityDatagram],
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        previewAdapter: UltraGridRawVideoPreviewAdapter? = nil,
        audioPlayout: (any UltraGridReceiveAudioPlayout)? = nil
    ) throws -> ExternalConnectorMediaSinkReport {
        var state = RuntimeMediaSinkState()
        for datagram in datagrams {
            consumeReceivedDatagram(
                datagram,
                encryptionConfiguration: encryptionConfiguration,
                audioPlayout: audioPlayout,
                state: &state
            )
        }
        consumeVideoFrames(state: &state, previewAdapter: previewAdapter)
        return mediaSinkReport(state)
    }

    private static func consumeReceivedDatagram(
        _ datagram: UltraGridCompatibilityDatagram,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        audioPlayout: (any UltraGridReceiveAudioPlayout)?,
        state: inout RuntimeMediaSinkState
    ) {
        switch datagram.stream {
        case .audio:
            consumeAudioDatagram(
                datagram,
                encryptionConfiguration: encryptionConfiguration,
                audioPlayout: audioPlayout,
                state: &state
            )
        case .video:
            consumeVideoDatagram(datagram, encryptionConfiguration: encryptionConfiguration, state: &state)
        }
    }

    private static func consumeAudioDatagram(
        _ datagram: UltraGridCompatibilityDatagram,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        audioPlayout: (any UltraGridReceiveAudioPlayout)?,
        state: inout RuntimeMediaSinkState
    ) {
        do {
            let audioRTP = try decodedRTP(
                datagram.rtp,
                encryptedPayloadType: UltraGridCompatibility.encryptedAudioPayloadType,
                encryptionConfiguration: encryptionConfiguration
            )
            let audio = try UltraGridAudioPayload.decode(audioRTP.payload)
            let block = try decodedPCM(audio)
            if let audioPlayout {
                let outcome = try audioPlayout.enqueue(
                    block,
                    hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
                )
                state.rejectedMediaCount += outcome.droppedBlocks
                guard !outcome.wasEntirelyDropped else {
                    return
                }
            }
            state.audioPacketCount += 1
            state.audioPayloadByteCount += audio.pcmPayload.count
        } catch {
            state.rejectedMediaCount += 1
        }
    }

    private static func consumeVideoDatagram(
        _ datagram: UltraGridCompatibilityDatagram,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        state: inout RuntimeMediaSinkState
    ) {
        do {
            state.videoPackets.append(try decodedRTP(
                datagram.rtp,
                encryptedPayloadType: UltraGridCompatibility.encryptedVideoPayloadType,
                encryptionConfiguration: encryptionConfiguration
            ))
        } catch {
            state.rejectedMediaCount += 1
        }
    }

    static func decodedRTP(
        _ packet: RTPPacket,
        encryptedPayloadType: UInt8,
        encryptionConfiguration: UltraGridEncryptionConfiguration?
    ) throws -> RTPPacket {
        guard packet.header.payloadType == encryptedPayloadType else {
            return packet
        }
        return try UltraGridRTPPacketCodec.decode(
            packet,
            encryptionConfiguration: encryptionConfiguration
        ).rtp
    }

    static func decodedPCM(_ audio: UltraGridAudioPayload) throws -> DecodedInterleavedPCM {
        let header = audio.header
        guard header.audioTag == UltraGridPCMAudioTag.littleEndianPCM else {
            throw UltraGridCompatibilityError.unsupportedMode("audio-tag-\(header.audioTag)")
        }
        guard header.quantizationBits == 16 else {
            throw UltraGridCompatibilityError.unsupportedMode("audio-quantization-\(header.quantizationBits)")
        }
        guard header.payloadOffset == 0 else {
            throw UltraGridCompatibilityError.unsupportedMode("audio-payload-offset-\(header.payloadOffset)")
        }
        let channels = Int(header.substreamID)
        try validateUltraGridPositive(channels, "audio.channels")
        let sampleRateHertz = Int(header.sampleRateHertz)
        try validateUltraGridPositive(sampleRateHertz, "audio.sampleRateHertz")
        let payloadByteCount = Int(header.payloadByteCount)
        guard audio.pcmPayload.count == payloadByteCount else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: payloadByteCount,
                actual: audio.pcmPayload.count
            )
        }
        let bytesPerFrame = channels * MemoryLayout<Int16>.size
        guard audio.pcmPayload.count.isMultiple(of: bytesPerFrame) else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: (audio.pcmPayload.count / bytesPerFrame) * bytesPerFrame,
                actual: audio.pcmPayload.count
            )
        }
        return DecodedInterleavedPCM(
            payload: audio.pcmPayload,
            sampleRateHertz: sampleRateHertz,
            channels: channels,
            representation: .int16LittleEndian
        )
    }

    private static func consumeVideoFrames(
        state: inout RuntimeMediaSinkState,
        previewAdapter: UltraGridRawVideoPreviewAdapter?
    ) {
        do {
            let frames = try Dictionary(grouping: state.videoPackets) { packet in
                if packet.header.payloadType == UltraGridCompatibility.fecPayloadType {
                    return try UltraGridFECPayload.decode(packet.payload).header.bufferNumber
                }
                return try UltraGridVideoRawFragmentPayload.decode(packet.payload).frameID
            }
            for packets in frames.values {
                try consumeVideoFrame(packets, state: &state, previewAdapter: previewAdapter)
            }
        } catch {
            state.rejectedMediaCount += state.videoPackets.isEmpty ? 0 : 1
        }
    }

    private static func consumeVideoFrame(
        _ packets: [RTPPacket],
        state: inout RuntimeMediaSinkState,
        previewAdapter: UltraGridRawVideoPreviewAdapter?
    ) throws {
        let frame = try UltraGridCompatibility.reassembleReceivedVideoFrame(from: packets)
        if let previewAdapter, !previewAdapter.submit(frame) {
            throw UltraGridCompatibilityError.unsupportedMode("raw-video-preview-rejected")
        }
        state.videoFrameCount += 1
        state.videoPayloadByteCount += frame.payload.count
    }

    private static func mediaSinkReport(_ state: RuntimeMediaSinkState) -> ExternalConnectorMediaSinkReport {
        ExternalConnectorMediaSinkReport(
            audioPacketCount: state.audioPacketCount,
            audioPayloadByteCount: state.audioPayloadByteCount,
            videoFrameCount: state.videoFrameCount,
            videoPayloadByteCount: state.videoPayloadByteCount,
            rejectedMediaCount: state.rejectedMediaCount,
            notes: "Decoded UltraGrid PT21 PCM, optional PT22 single-parity FEC, "
                + "and reassembled PT20 raw-video frames into bounded artifact sink counters."
        )
    }
}

struct UltraGridIncrementalReceiveSummary: Sendable {
    var analysis: UltraGridCompatibilityRunner.RuntimeMediaAnalysis
    var sink: ExternalConnectorMediaSinkReport
}

/// Streaming receive analysis used by the socket path. Report evidence may be
/// capped, but every accepted datagram passes through this observer. It retains
/// only sequence-number sets and the currently assembling raw-video frame.
final class UltraGridIncrementalReceiveObserver: @unchecked Sendable {
    private struct SequenceState {
        var seen: Set<UInt16> = []
        var ssrcs: Set<UInt32> = []
        var duplicateCount = 0
        var outOfOrderCount = 0
        var timestampRegressionCount = 0
        var jitterLikeDeltaChangeCount = 0
        var previousSequence: UInt16?
        var previousTimestamp: UInt32?
        var expectedTimestampDelta: UInt32?

        mutating func record(_ header: RTPPacketHeader) {
            if !seen.insert(header.sequenceNumber).inserted {
                duplicateCount += 1
            }
            ssrcs.insert(header.ssrc)
            if let previousSequence, header.sequenceNumber < previousSequence {
                outOfOrderCount += 1
            }
            if let previousTimestamp {
                if header.timestamp < previousTimestamp {
                    timestampRegressionCount += 1
                } else {
                    let delta = header.timestamp - previousTimestamp
                    if delta > 0 {
                        if let expectedTimestampDelta, delta != expectedTimestampDelta {
                            jitterLikeDeltaChangeCount += 1
                        } else if expectedTimestampDelta == nil {
                            self.expectedTimestampDelta = delta
                        }
                    }
                }
            }
            previousSequence = header.sequenceNumber
            previousTimestamp = header.timestamp
        }

        var lostCount: Int {
            guard let minimum = seen.min(), let maximum = seen.max() else { return 0 }
            return max(0, Int(maximum) - Int(minimum) + 1 - seen.count)
        }
    }

    private static let maximumCurrentVideoBytes = UltraGridCompatibility.maximumRawVideoFrameBytes
    private static let maximumCurrentVideoPackets = Int(UInt16.max) + 1

    private let encryptionConfiguration: UltraGridEncryptionConfiguration?
    private let previewAdapter: UltraGridRawVideoPreviewAdapter?
    private let audioPlayout: (any UltraGridReceiveAudioPlayout)?
    private var audioSequence = SequenceState()
    private var videoSequence = SequenceState()
    private var audioPacketCount = 0
    private var audioPayloadByteCount = 0
    private var rejectedMediaCount = 0
    private var videoFrameCount = 0
    private var videoPayloadByteCount = 0
    private var videoFrameReassemblyFailures = 0
    private var videoFrameRecoveryFailed = false
    private var currentVideoFrameID: UInt32?
    private var currentVideoPackets: [RTPPacket] = []
    private var currentVideoBytes = 0

    init(
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        previewAdapter: UltraGridRawVideoPreviewAdapter? = nil,
        audioPlayout: (any UltraGridReceiveAudioPlayout)? = nil
    ) {
        self.encryptionConfiguration = encryptionConfiguration
        self.previewAdapter = previewAdapter
        self.audioPlayout = audioPlayout
    }

    func record(_ datagram: UltraGridCompatibilityDatagram) {
        switch datagram.stream {
        case .audio:
            audioSequence.record(datagram.rtp.header)
            consumeAudio(datagram.rtp)
        case .video:
            videoSequence.record(datagram.rtp.header)
            consumeVideo(datagram.rtp)
        }
    }

    func finish() -> UltraGridIncrementalReceiveSummary {
        finishCurrentVideoFrame()
        let analysis = UltraGridCompatibilityRunner.RuntimeMediaAnalysis(
            lost: audioSequence.lostCount + videoSequence.lostCount,
            duplicates: audioSequence.duplicateCount + videoSequence.duplicateCount,
            outOfOrder: audioSequence.outOfOrderCount + videoSequence.outOfOrderCount,
            ssrcChanges: max(0, audioSequence.ssrcs.count - 1) + max(0, videoSequence.ssrcs.count - 1),
            timestampRegressions: audioSequence.timestampRegressionCount + videoSequence.timestampRegressionCount,
            jitterLikeArrivalDeltaChanges: audioSequence.jitterLikeDeltaChangeCount
                + videoSequence.jitterLikeDeltaChangeCount,
            videoFrameReassemblyFailures: videoFrameReassemblyFailures,
            videoFrameRecoveryFailed: videoFrameRecoveryFailed
        )
        let sink = ExternalConnectorMediaSinkReport(
            audioPacketCount: audioPacketCount,
            audioPayloadByteCount: audioPayloadByteCount,
            videoFrameCount: videoFrameCount,
            videoPayloadByteCount: videoPayloadByteCount,
            rejectedMediaCount: rejectedMediaCount,
            notes: "Incrementally decoded every accepted UltraGrid PT21 PCM datagram and retained only "
                + "the current bounded PT20/FEC frame while report packet evidence remained capped."
        )
        return UltraGridIncrementalReceiveSummary(analysis: analysis, sink: sink)
    }

    private func consumeAudio(_ packet: RTPPacket) {
        do {
            let decoded = try UltraGridCompatibilityMediaSinkDecoder.decodedRTP(
                packet,
                encryptedPayloadType: UltraGridCompatibility.encryptedAudioPayloadType,
                encryptionConfiguration: encryptionConfiguration
            )
            let audio = try UltraGridAudioPayload.decode(decoded.payload)
            let block = try UltraGridCompatibilityMediaSinkDecoder.decodedPCM(audio)
            if let audioPlayout {
                let outcome = try audioPlayout.enqueue(
                    block,
                    hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
                )
                rejectedMediaCount += outcome.droppedBlocks
                guard !outcome.wasEntirelyDropped else {
                    return
                }
            }
            audioPacketCount += 1
            audioPayloadByteCount += audio.pcmPayload.count
        } catch {
            rejectedMediaCount += 1
        }
    }

    private func consumeVideo(_ packet: RTPPacket) {
        do {
            let decoded = try UltraGridCompatibilityMediaSinkDecoder.decodedRTP(
                packet,
                encryptedPayloadType: UltraGridCompatibility.encryptedVideoPayloadType,
                encryptionConfiguration: encryptionConfiguration
            )
            let frameID: UInt32
            if decoded.header.payloadType == UltraGridCompatibility.fecPayloadType {
                frameID = try UltraGridFECPayload.decode(decoded.payload).header.bufferNumber
            } else {
                frameID = try UltraGridVideoRawFragmentPayload.decode(decoded.payload).frameID
            }
            if let currentVideoFrameID, currentVideoFrameID != frameID {
                finishCurrentVideoFrame()
            }
            currentVideoFrameID = frameID
            currentVideoPackets.append(decoded)
            currentVideoBytes += decoded.payload.count
            if currentVideoPackets.count > Self.maximumCurrentVideoPackets
                || currentVideoBytes > Self.maximumCurrentVideoBytes {
                rejectedMediaCount += 1
                videoFrameReassemblyFailures += 1
                currentVideoPackets.removeAll(keepingCapacity: true)
                currentVideoBytes = 0
                currentVideoFrameID = nil
            }
        } catch {
            rejectedMediaCount += 1
            videoFrameReassemblyFailures += 1
        }
    }

    private func finishCurrentVideoFrame() {
        guard !currentVideoPackets.isEmpty else {
            currentVideoFrameID = nil
            currentVideoBytes = 0
            return
        }
        defer {
            currentVideoPackets.removeAll(keepingCapacity: true)
            currentVideoFrameID = nil
            currentVideoBytes = 0
        }
        do {
            let fragments = try UltraGridCompatibility.recoverVideoFragments(from: currentVideoPackets)
            let frame = try UltraGridCompatibility.reassembleVideoFrame(fragments)
            if let previewAdapter,
               !previewAdapter.submit(try UltraGridCompatibility.reassembleReceivedVideoFrame(from: currentVideoPackets)) {
                throw UltraGridCompatibilityError.unsupportedMode("raw-video-preview-rejected")
            }
            videoFrameCount += 1
            videoPayloadByteCount += frame.count
        } catch {
            rejectedMediaCount += 1
            videoFrameReassemblyFailures += 1
            videoFrameRecoveryFailed = true
        }
    }
}
