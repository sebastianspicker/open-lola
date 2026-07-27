// Shared UDP media transport packet fixtures builders keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

// Reuses the canonical M06 packet payload so packet tests isolate header and sequence handling.
func m06MediaAudioPacket(
    streamID: Int,
    sequenceNumber: UInt64
) throws -> UdpMediaPacket {
    let audio = try m06AudioPackets(streamID: streamID, sequenceNumber: sequenceNumber)[0]
    return UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: UInt32(streamID),
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: try audio.encoded()
    )
}

// Builds a keepalive-only packet to exercise liveness paths without coupling them to media decoding.
func keepaliveMediaPacket(
    streamID: UInt32,
    sequenceNumber: UInt64,
    timestamp: UInt64
) -> UdpMediaPacket {
    UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .keepalive,
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: timestamp
        ),
        payload: Data()
    )
}

func singleVideoMediaPacket(
    streamID: UInt32,
    sequenceNumber: UInt64
) throws -> UdpMediaPacket {
    let frame = CapturedVideoFrame(
        streamID: streamID,
        sequenceNumber: sequenceNumber,
        timestampNanoseconds: sequenceNumber,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .avFoundationDevice,
        width: 4,
        height: 4,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "adverse-video-\(sequenceNumber)"
    )
    return try #require(VideoMediaPacketizer.packets(for: frame, maxPacketBytes: 1_200).first)
}

func m06AudioPackets(
    streamID: Int,
    sequenceNumber: UInt64
) throws -> [UdpPcmV2Packet] {
    let mode = try m06AudioMode(streamID: streamID)
    return try UdpPcmV2Packetizer.packetize(
        Data(
            repeating: UInt8(sequenceNumber),
            count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
        ),
        sequenceNumber: sequenceNumber,
        senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: sequenceNumber + 1,
        mode: mode
    )
}

func m06AudioMode(streamID: Int) throws -> AudioTransportMode {
    try plannedV2TestAudioTransportMode(
        .init(
            streamID: streamID,
            channelCount: 2,
            sampleFormat: .int16LittleEndian,
            metadataRevision: 0
        )
    )
}

struct V2TestAudioTransportModeConfiguration {
    let streamID: Int
    let channelCount: Int
    let sampleFormat: UdpPcmSampleFormat
    let metadataRevision: Int
}

func plannedV2TestAudioTransportMode(
    _ configuration: V2TestAudioTransportModeConfiguration
) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            .init(
                streamID: configuration.streamID,
                audio: .init(
                    totalChannelCount: configuration.channelCount,
                    framesPerPacket: 32,
                    sampleRateHertz: 48_000,
                    sampleFormat: configuration.sampleFormat
                ),
                fragmentationLimits: .init(
                    maxTransmissionUnitBytes: 1_200,
                    maxFragmentsPerDeadline: 16
                ),
                metadata: .init(
                    metadataRevision: configuration.metadataRevision,
                    packingMode: .interleavedChannelRange
                )
            )
        )
    )
    return v2TestAudioTransportMode(configuration, fragments: fragments)
}

func v2TestAudioTransportMode(
    _ configuration: V2TestAudioTransportModeConfiguration,
    fragments: [UdpPcmV2ChannelFragmentPlan]
) -> AudioTransportMode {
    AudioTransportMode(
        transport: .init(protocolVersion: .udpPcmV2, latencyProfile: .safeLowLatency, rxBufferProfile: .direct, maxTransmissionUnitBytes: 1_200),
        format: .init(sampleRateHertz: 48_000, framesPerPacket: 32, channelCount: configuration.channelCount, sampleFormat: configuration.sampleFormat),
        layout: .init(channelOrder: AudioChannelSet.defaultInput(count: configuration.channelCount).sortedByStableSourceIndex, fragments: fragments)
    )
}
