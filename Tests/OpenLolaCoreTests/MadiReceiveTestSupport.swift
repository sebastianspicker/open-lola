// Shared MADI receive helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func expectCompletedMadiReceiveMetrics(_ metrics: MadiReceiveMetrics) {
    #expect(metrics.completedBlocks == 1)
    #expect(metrics.allocationWarnings == 0)
    #expect(metrics.lastPacketAgeMicroseconds == 0.001)
    #expect(metrics.maximumPacketAgeMicroseconds == 0.001)
    #expect(metrics.rxBuffer.maximumObservedBufferedPackets == 1)
}

func udpPcmV2FragmentPlanRequest(
    streamID: Int,
    audio: UdpPcmV2FragmentPlanRequest.AudioDescription,
    fragmentationLimits: UdpPcmV2FragmentPlanRequest.FragmentationLimits,
    metadata: UdpPcmV2FragmentPlanRequest.Metadata
) -> UdpPcmV2FragmentPlanRequest {
    .init(.init(
        streamID: streamID,
        audio: audio,
        fragmentationLimits: fragmentationLimits,
        metadata: metadata
    ))
}

func madiRxPackets(
    payload: Data,
    sequenceNumber: UInt64 = 0,
    senderFrameIndex: UInt64 = 0,
    senderHostTimeNanoseconds: UInt64 = 1,
    mode: AudioTransportMode
) throws -> [UdpPcmV2Packet] {
    try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        senderHostTimeNanoseconds: senderHostTimeNanoseconds,
        mode: mode
    )
}

func madiRxV2Mode(
    channelCount: Int,
    framesPerPacket: Int = 32,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    rxBufferProfile: RxBufferProfile = .direct
) throws -> AudioTransportMode {
    try udpPcmV2TestMode(
        channelCount: channelCount,
        framesPerPacket: framesPerPacket,
        sampleFormat: sampleFormat,
        rxBufferProfile: rxBufferProfile,
        metadataRevision: 3
    )
}

func udpPcmV2TestMode(
    channelCount: Int,
    framesPerPacket: Int = 32,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    rxBufferProfile: RxBufferProfile = .direct,
    metadataRevision: Int
) throws -> AudioTransportMode {
    let audio = UdpPcmV2FragmentPlanRequest.AudioDescription(
        totalChannelCount: channelCount,
        framesPerPacket: framesPerPacket,
        sampleRateHertz: 48_000,
        sampleFormat: sampleFormat
    )
    let fragmentationLimits = UdpPcmV2FragmentPlanRequest.FragmentationLimits(
        maxTransmissionUnitBytes: 1_200,
        maxFragmentsPerDeadline: 16
    )
    let metadata = UdpPcmV2FragmentPlanRequest.Metadata(
        metadataRevision: metadataRevision,
        packingMode: .interleavedChannelRange
    )
    let fragments = try UdpPcmV2FragmentPlanner.plan(udpPcmV2FragmentPlanRequest(
        streamID: 1,
        audio: audio,
        fragmentationLimits: fragmentationLimits,
        metadata: metadata
    ))
    return AudioTransportMode(
        transport: .init(protocolVersion: .udpPcmV2, latencyProfile: .safeLowLatency, rxBufferProfile: rxBufferProfile, maxTransmissionUnitBytes: 1_200),
        format: .init(sampleRateHertz: 48_000, framesPerPacket: framesPerPacket, channelCount: channelCount, sampleFormat: sampleFormat),
        layout: .init(channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex, fragments: fragments)
    )
}

func patternedPayload(mode: AudioTransportMode, seed: Int = 0) -> Data {
    Data((0..<mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
        .map { UInt8(($0 + seed) % 251) })
}

func int16InterleavedRxPayload(frameCount: Int, channelCount: Int) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in 0..<channelCount {
            appendRxInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    return data
}

func int16InterleavedRxPayload(
    frameCount: Int,
    sourceChannelCount: Int,
    selectedChannels: [Int]
) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in selectedChannels {
            appendRxInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    _ = sourceChannelCount
    return data
}

func int16RxPayload(_ values: [Int16]) -> Data {
    var data = Data()
    for value in values {
        appendRxInt16Sample(value, to: &data)
    }
    return data
}

func appendRxInt16Sample(_ value: Int16, to data: inout Data) {
    let littleEndian = value.littleEndian
    withUnsafeBytes(of: littleEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

func madiReceivePlayoutBlock(sequenceNumber: UInt64, startFrame: UInt64) -> MadiReceivePlayoutBlock {
    MadiReceivePlayoutBlock(
        streamID: 1,
        sequenceNumber: sequenceNumber,
        startFrame: startFrame,
        senderFrameIndex: startFrame,
        frameCount: 32,
        inputChannelCount: 2,
        outputChannelCount: 2,
        sampleFormat: .float32LittleEndian,
        payload: Data([UInt8(sequenceNumber & 0xff)]),
        mixRevision: 0,
        latency: MadiReceiveBufferLatency(frames: 32, packets: 1, microseconds: 666.67)
    )
}
