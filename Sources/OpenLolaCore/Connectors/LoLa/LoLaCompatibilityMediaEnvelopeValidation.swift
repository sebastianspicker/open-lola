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

    static func validateReceivedFrames(
        _ encodedFrames: [Data],
        configuration: ExternalConnectorSessionConfiguration
    ) throws {
        let expectedAudioPayloadByteCount = try LoLaCompatibilityMediaModel.audioPayloadByteCount(
            channels: configuration.channels
        )
        var videoPreludes: [UInt32: LoLaCompatibilityVideoPrelude] = [:]
        var videoFragments: [UInt32: [LoLaCompatibilityNormalFragment]] = [:]

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
            case .video:
                if let prelude = mediaPacket.videoPrelude {
                    guard videoPreludes[prelude.frameID] == nil else {
                        throw LoLaCompatibilityMediaCodecError.duplicateVideoPrelude(prelude.frameID)
                    }
                    videoPreludes[prelude.frameID] = prelude
                } else if let fragment = mediaPacket.normalFragment {
                    guard videoPreludes[fragment.header.frameID] != nil else {
                        throw LoLaCompatibilityMediaCodecError.missingVideoPrelude(fragment.header.frameID)
                    }
                    videoFragments[fragment.header.frameID, default: []].append(fragment)
                } else {
                    throw LoLaCompatibilityMediaCodecError.invalidFragmentMagic
                }
            }
        }

        for frameID in videoFragments.keys where videoPreludes[frameID] == nil {
            throw LoLaCompatibilityMediaCodecError.missingVideoPrelude(frameID)
        }
        for prelude in videoPreludes.values {
            _ = try LoLaCompatibilityMediaCodec.reassemble(
                prelude: prelude,
                fragments: videoFragments[prelude.frameID] ?? []
            )
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
        guard body.payloadLength == expectedPayloadByteCount else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
                expected: 8 + expectedPayloadByteCount,
                actual: fragment.fragmentBytes.count
            )
        }
    }
}
