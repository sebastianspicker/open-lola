// Resolves peer audio endpoints and derives packetization modes from negotiated streams so MTU and fragment limits remain consistent.
import Foundation

// swiftlint:disable:next identifier_name
let directPeerOpenLolaRawAudioMaxFragmentsPerDeadline: UInt16 = 16

struct PeerSessionRunningAudioContext {
    let transport: UdpMediaTransport
    let stream: AudioStreamDescription
}

extension PeerSessionRunner {
    func runningAudioContext(
        streamID: Int,
        requiredPayloadType: SessionPayloadType? = nil
    ) throws -> PeerSessionRunningAudioContext {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }),
              requiredPayloadType == nil || audioStream.payloadType == requiredPayloadType else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        return PeerSessionRunningAudioContext(transport: audioTransport, stream: audioStream)
    }

    func remoteEndpoints(in configuration: SessionConfiguration) throws -> SessionPeerMediaEndpoints {
        guard let endpoint = configuration.peerMediaEndpoints?.first(where: { $0.peerID == remotePeerID }) else {
            throw PeerSessionRunnerError.missingPeerMediaEndpoint(remotePeerID)
        }
        return endpoint
    }

    func makeDefaultAudioStream() -> AudioStreamDescription {
        let channelCount = min(2, localCapabilities.audio.channelSet.channels.count)
        return makeAudioStream(
            channelCount: channelCount,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: .int16LittleEndian
        )
    }

    func makeAudioStream(
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormat: UdpPcmSampleFormat,
        payloadType: SessionPayloadType = .audioPcmV2
    ) -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: 1, direction: .bidirectional, clockDomain: "core-audio-device:m06-direct-p2p"),
            format: .init(sampleRateHertz: sampleRateHertz, sampleFormat: sampleFormat, channelCount: channelCount, channelOrder: Array(localCapabilities.audio.channelSet.sortedByStableSourceIndex.prefix(channelCount))),
            packet: .init(framesPerPacket: framesPerPacket, payloadType: payloadType)
        )
    }

    func makeAudioPackets(streamID: Int, sequenceNumber: UInt64) throws -> [UdpPcmV2Packet] {
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }) else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let mode = try audioMode(for: audioStream)
        return try directPeerSyntheticAudioPackets(sequenceNumber: sequenceNumber, mode: mode)
    }

    func audioMode(for audioStream: AudioStreamDescription) throws -> AudioTransportMode {
        let mtuBytes = acceptedConfiguration?.mtuBytes ?? 1_200
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                .init(
                    streamID: audioStream.id,
                    audio: .init(
                        totalChannelCount: audioStream.channelCount,
                        framesPerPacket: audioStream.framesPerPacket,
                        sampleRateHertz: audioStream.sampleRateHertz,
                        sampleFormat: audioStream.sampleFormat
                    ),
                    fragmentationLimits: .init(
                        maxTransmissionUnitBytes: mtuBytes,
                        maxFragmentsPerDeadline: Int(directPeerOpenLolaRawAudioMaxFragmentsPerDeadline)
                    ),
                    metadata: .init(
                        metadataRevision: 0,
                        packingMode: .interleavedChannelRange
                    )
                )
            )
        )
        return udpPcmV2AudioTransportMode(
            stream: audioStream,
            fragments: fragments,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: mtuBytes
        )
    }
}
