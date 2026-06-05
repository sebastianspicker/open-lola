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
        encryptionConfiguration: UltraGridEncryptionConfiguration?
    ) throws -> ExternalConnectorMediaSinkReport {
        var state = RuntimeMediaSinkState()
        for datagram in datagrams {
            consumeReceivedDatagram(
                datagram,
                encryptionConfiguration: encryptionConfiguration,
                state: &state
            )
        }
        consumeVideoFrames(state: &state)
        return mediaSinkReport(state)
    }

    private static func consumeReceivedDatagram(
        _ datagram: UltraGridCompatibilityDatagram,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        state: inout RuntimeMediaSinkState
    ) {
        switch datagram.stream {
        case .audio:
            consumeAudioDatagram(datagram, encryptionConfiguration: encryptionConfiguration, state: &state)
        case .video:
            consumeVideoDatagram(datagram, encryptionConfiguration: encryptionConfiguration, state: &state)
        }
    }

    private static func consumeAudioDatagram(
        _ datagram: UltraGridCompatibilityDatagram,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        state: inout RuntimeMediaSinkState
    ) {
        do {
            let audioRTP = try decodedRTP(
                datagram.rtp,
                encryptedPayloadType: UltraGridCompatibility.encryptedAudioPayloadType,
                encryptionConfiguration: encryptionConfiguration
            )
            let audio = try UltraGridAudioPayload.decode(audioRTP.payload)
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

    private static func decodedRTP(
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

    private static func consumeVideoFrames(state: inout RuntimeMediaSinkState) {
        let videoFragments: [UltraGridVideoRawFragmentPayload]
        do {
            videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: state.videoPackets)
        } catch {
            videoFragments = []
            state.rejectedMediaCount += state.videoPackets.isEmpty ? 0 : 1
        }
        for fragments in Dictionary(grouping: videoFragments, by: \.frameID).values {
            do {
                let frame = try UltraGridCompatibility.reassembleVideoFrame(fragments)
                state.videoFrameCount += 1
                state.videoPayloadByteCount += frame.count
            } catch {
                state.rejectedMediaCount += 1
            }
        }
    }

    private static func mediaSinkReport(_ state: RuntimeMediaSinkState) -> ExternalConnectorMediaSinkReport {
        ExternalConnectorMediaSinkReport(
            audioPacketCount: state.audioPacketCount,
            audioPayloadByteCount: state.audioPayloadByteCount,
            videoFrameCount: state.videoFrameCount,
            videoPayloadByteCount: state.videoPayloadByteCount,
            rejectedMediaCount: state.rejectedMediaCount,
            notes: "Decoded UltraGrid PT21 PCM, optional PT22 single-parity FEC, and reassembled PT20 raw-video frames into bounded artifact sink counters."
        )
    }
}
