import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Validates LoLaCompatibilityMediaEnvelopeValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

enum LoLaCompatibilityMediaEnvelopeValidation {
    static func validateReceivedWireEnvelopes(
        _ encodedFrames: [Data],
        configuration: ExternalConnectorSessionConfiguration
    ) throws {
        for encodedFrame in encodedFrames {
            let wireFrame = try LoLaCompatibilityWireFrame.decode(encodedFrame)
            try validateMediaPorts(wireFrame, configuration: configuration)
        }
    }

    /// Validates every datagram's grammar and summarizes frame completeness.
    ///
    /// Grammar faults still throw. Frame-level incompleteness does not: on a
    /// live UDP link a lost fragment, a fragment that arrives before its
    /// prelude, or a frame cut off at the evidence boundary are ordinary
    /// observations, so they are counted and reported instead of failing the
    /// whole session.
    @discardableResult
    static func validateReceivedFrames(
        _ encodedFrames: [Data],
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaReceivedMediaValidationSummary {
        let expectedAudioPayloadByteCount = try LoLaCompatibilityMediaModel.audioPayloadByteCount(
            channels: configuration.channels
        )
        var videoPreludes: [UInt32: LoLaCompatibilityVideoPrelude] = [:]
        var videoFragments: [UInt32: [LoLaCompatibilityNormalFragment]] = [:]
        var summary = LoLaReceivedMediaValidationSummary()

        for encodedFrame in encodedFrames {
            let wireFrame = try LoLaCompatibilityWireFrame.decode(encodedFrame)
            try validateMediaPorts(wireFrame, configuration: configuration)
            let mediaPacket = try LoLaCompatibilityMediaCodec.decode(wireFrame.payload)
            let stream = receivedStream(for: mediaPacket, wireFrame: wireFrame, configuration: configuration)
            try validateStreamPort(stream, wireFrame: wireFrame, configuration: configuration)
            switch stream {
            case .audio:
                guard let fragment = mediaPacket.normalFragment else {
                    throw LoLaCompatibilityMediaCodecError.invalidFragmentMagic
                }
                try validateAudioFragment(fragment, expectedPayloadByteCount: expectedAudioPayloadByteCount)
                summary.audioDatagrams += 1
            case .video:
                try validateVideoPacket(
                    mediaPacket,
                    videoPreludes: &videoPreludes,
                    videoFragments: &videoFragments,
                    summary: &summary
                )
            }
        }

        summary.orphanVideoFragments = videoFragments
            .filter { videoPreludes[$0.key] == nil }
            .reduce(0) { $0 + $1.value.count }
        for prelude in videoPreludes.values {
            do {
                _ = try LoLaCompatibilityMediaCodec.reassemble(
                    prelude: prelude,
                    fragments: videoFragments[prelude.frameID] ?? []
                )
                summary.completeVideoFrames += 1
            } catch LoLaCompatibilityMediaCodecError.missingFragment {
                summary.incompleteVideoFrames += 1
            } catch LoLaCompatibilityMediaCodecError.duplicateFragment {
                summary.incompleteVideoFrames += 1
            }
        }
        return summary
    }

    private static func validateVideoPacket(
        _ mediaPacket: LoLaCompatibilityDecodedMediaPacket,
        videoPreludes: inout [UInt32: LoLaCompatibilityVideoPrelude],
        videoFragments: inout [UInt32: [LoLaCompatibilityNormalFragment]],
        summary: inout LoLaReceivedMediaValidationSummary
    ) throws {
        if let prelude = mediaPacket.videoPrelude {
            if videoPreludes[prelude.frameID] != nil {
                summary.duplicateVideoPreludes += 1
            }
            videoPreludes[prelude.frameID] = prelude
        } else if let fragment = mediaPacket.normalFragment {
            videoFragments[fragment.header.frameID, default: []].append(fragment)
        } else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentMagic
        }
    }

    private static func receivedStream(
        for packet: LoLaCompatibilityDecodedMediaPacket,
        wireFrame: LoLaCompatibilityWireFrame,
        configuration: ExternalConnectorSessionConfiguration
    ) -> LoLaCompatibilityMediaStream {
        let ports = Set([wireFrame.sourcePort, wireFrame.destinationPort])
        return packet.kind == .videoPrelude || ports.contains(configuration.videoPort) ? .video : .audio
    }

    private static func validateMediaPorts(
        _ wireFrame: LoLaCompatibilityWireFrame,
        configuration: ExternalConnectorSessionConfiguration
    ) throws {
        guard wireFrame.destinationPort == configuration.audioPort
            || wireFrame.destinationPort == configuration.videoPort else {
            throw LoLaCompatibilityMediaCodecError.unexpectedMediaPort(wireFrame.destinationPort)
        }
    }

    private static func validateStreamPort(
        _ stream: LoLaCompatibilityMediaStream,
        wireFrame: LoLaCompatibilityWireFrame,
        configuration: ExternalConnectorSessionConfiguration
    ) throws {
        let expectedPort = stream == .audio ? configuration.audioPort : configuration.videoPort
        guard wireFrame.destinationPort == expectedPort else {
            throw LoLaCompatibilityMediaCodecError.mediaStreamPortMismatch(
                stream: stream,
                expected: expectedPort,
                actual: wireFrame.destinationPort
            )
        }
    }

    private static func validateAudioFragment(
        _ fragment: LoLaCompatibilityNormalFragment,
        expectedPayloadByteCount: Int
    ) throws {
        guard fragment.header.fragmentCount == 1 else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentCount(fragment.header.fragmentCount)
        }
        guard fragment.header.fragmentIndex == 0 else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentIndex(fragment.header.fragmentIndex)
        }
        guard fragment.header.originalOffset == 0 else {
            throw LoLaCompatibilityMediaCodecError.fragmentOffsetMismatch(
                expected: 0,
                actual: fragment.header.originalOffset
            )
        }
        guard fragment.header.finalFlag else {
            throw LoLaCompatibilityMediaCodecError.invalidFinalFlag(
                fragmentIndex: 0,
                expected: true,
                actual: false
            )
        }
        let body = try LoLaCompatibilityMediaCodec.decodeSerializedBody(fragment.fragmentBytes)
        let expectedFrameID = body.sequence &+ 1
        guard expectedFrameID == fragment.header.frameID else {
            throw LoLaCompatibilityMediaCodecError.sequenceMismatch(
                expected: expectedFrameID,
                actual: fragment.header.frameID
            )
        }
        try LoLaCompatibilityMediaCodec.validateAudioPayloadByteCount(
            body.payloadLength,
            channels: expectedPayloadByteCount / LoLaCompatibilityMediaModel.defaultAudioPayloadBytesPerChannel
        )
    }
}

/// Frame-level completeness observed across one set of validated datagrams.
struct LoLaReceivedMediaValidationSummary: Equatable, Sendable {
    var audioDatagrams = 0
    var completeVideoFrames = 0
    var incompleteVideoFrames = 0
    var orphanVideoFragments = 0
    var duplicateVideoPreludes = 0

    var note: String {
        "Validated \(audioDatagrams) audio datagram(s); video frames complete \(completeVideoFrames), "
            + "incomplete \(incompleteVideoFrames), fragments without prelude \(orphanVideoFragments), "
            + "duplicate preludes \(duplicateVideoPreludes)."
    }
}
