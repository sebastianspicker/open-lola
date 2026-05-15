import Foundation

let directPeerOpenLolaRawAudioMaxFragmentsPerDeadline: UInt16 = 16

extension PeerSessionRunner {
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
            id: 1,
            direction: .bidirectional,
            sampleRateHertz: sampleRateHertz,
            sampleFormat: sampleFormat,
            channelCount: channelCount,
            channelOrder: Array(localCapabilities.audio.channelSet.sortedByStableSourceIndex.prefix(channelCount)),
            clockDomain: "core-audio-device:m06-direct-p2p",
            framesPerPacket: framesPerPacket,
            payloadType: payloadType
        )
    }

    func makeAudioPackets(streamID: Int, sequenceNumber: UInt64) throws -> [UdpPcmV2Packet] {
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }) else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let mode = try audioMode(for: audioStream)
        return try UdpPcmV2Packetizer.packetize(
            Data(
                repeating: UInt8(sequenceNumber & 0xFF),
                count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
            ),
            sequenceNumber: sequenceNumber,
            senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
            senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            mode: mode
        )
    }

    func audioMode(for audioStream: AudioStreamDescription) throws -> AudioTransportMode {
        let mtuBytes = acceptedConfiguration?.mtuBytes ?? 1_200
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: audioStream.id,
                totalChannelCount: audioStream.channelCount,
                framesPerPacket: audioStream.framesPerPacket,
                sampleRateHertz: audioStream.sampleRateHertz,
                sampleFormat: audioStream.sampleFormat,
                maxTransmissionUnitBytes: mtuBytes,
                maxFragmentsPerDeadline: Int(directPeerOpenLolaRawAudioMaxFragmentsPerDeadline),
                metadataRevision: 0,
                packingMode: .interleavedChannelRange
            )
        )
        return AudioTransportMode(
            protocolVersion: .udpPcmV2,
            sampleRateHertz: audioStream.sampleRateHertz,
            framesPerPacket: audioStream.framesPerPacket,
            channelCount: audioStream.channelCount,
            sampleFormat: audioStream.sampleFormat,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: mtuBytes,
            channelOrder: audioStream.channelOrder,
            fragments: fragments
        )
    }
}
