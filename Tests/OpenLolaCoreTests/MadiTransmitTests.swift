// Verifies that MADI transmit packetizes captured payload for required channel counts.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func madiTransmitPacketizesCapturedPayloadForRequiredChannelCounts() throws {
    for channelCount in madiSyntheticRequiredChannelCounts {
        let mode = try madiRxV2Mode(channelCount: channelCount)
        let payloadByteCount = mode.framesPerPacket
            * channelCount
            * mode.sampleFormat.bytesPerSample
        let payload = Data((0..<payloadByteCount).map { UInt8($0 % 251) })
        var handoff = try RealtimeAudioPacketHandoff(
            configuration: madiHandoffConfiguration(channelCount: channelCount)
        )

        #expect(handoff.captureCallback(
            startFrame: 0,
            hostTimeNanoseconds: 1,
            payload: payload
        ) == .stored)
        let capturedPackets = try handoff.sendNextV2Packets(mode: mode)
        let packets = try #require(capturedPackets)
        let reassembled = try UdpPcmV2FragmentReassembler.reassemble(packets)

        #expect(reassembled.isComplete)
        #expect(reassembled.payload == payload)
        #expect(packets.allSatisfy { $0.header.packetByteCount <= mode.maxTransmissionUnitBytes })
        #expect(packets.allSatisfy { $0.header.totalChannelCount == UInt16(channelCount) })
        #expect(handoff.metrics.packetFragmentCount == packets.count)
        #expect(handoff.metrics.allocationWarnings == 0)
    }
}

@Test
func madiTransmitSelectedChannelMapPreservesConfiguredOrdering() throws {
    let channelMap = [2, 0, 3]
    let mode = try madiRxV2Mode(
        channelCount: channelMap.count,
        framesPerPacket: 2,
        sampleFormat: .int16LittleEndian
    )
    var handoff = try RealtimeAudioPacketHandoff(
        configuration: RealtimeAudioEngineConfiguration(
            devices: .init(inputDeviceUID: "rme-madi-uid", outputDeviceUID: "rme-madi-uid"),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 2, channelCount: channelMap.count, packetFormat: .int16LittleEndian),
            channelMaps: .init(input: channelMap, output: Array(0..<channelMap.count)),
            buffering: .init(playoutTargetFrames: 2, preallocatedBlockCount: 4, rxBufferPolicy: nil)
        )
    )
    let source = int16InterleavedRxPayload(frameCount: 2, channelCount: 4)
    let expected = int16InterleavedRxPayload(
        frameCount: 2,
        sourceChannelCount: 4,
        selectedChannels: channelMap
    )

    let captureResult = source.withUnsafeBytes { sourceBytes in
        handoff.captureInterleavedInputCallback(
            startFrame: 0,
            hostTimeNanoseconds: 1,
            sourceChannelCount: 4,
            sourceBytes: sourceBytes
        )
    }
    #expect(captureResult == .stored)
    let capturedPackets = try handoff.sendNextV2Packets(mode: mode)
    let packets = try #require(capturedPackets)
    let reassembled = try UdpPcmV2FragmentReassembler.reassemble(packets)

    #expect(reassembled.payload == expected)
    #expect(handoff.metrics.remappedInputBlocks == 1)
    #expect(handoff.metrics.directInputBlocks == 0)
}

@Test
func madiTransmitSequenceNumbersAndFrameIndexesAreMonotonic() throws {
    let mode = try madiRxV2Mode(channelCount: 8)
    var handoff = try RealtimeAudioPacketHandoff(
        configuration: madiHandoffConfiguration(channelCount: 8)
    )
    let payload = Data(
        repeating: 0x5A,
        count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
    )

    #expect(handoff.captureCallback(
        startFrame: 0,
        hostTimeNanoseconds: 1,
        payload: payload
    ) == .stored)
    #expect(handoff.captureCallback(
        startFrame: UInt64(mode.framesPerPacket),
        hostTimeNanoseconds: 2,
        payload: payload
    ) == .stored)
    let capturedFirst = try handoff.sendNextV2Packets(mode: mode)
    let capturedSecond = try handoff.sendNextV2Packets(mode: mode)
    let first = try #require(capturedFirst)
    let second = try #require(capturedSecond)

    #expect(Set(first.map(\.header.sequenceNumber)) == [0])
    #expect(Set(second.map(\.header.sequenceNumber)) == [1])
    #expect(Set(first.map(\.header.senderFrameIndex)) == [0])
    #expect(Set(second.map(\.header.senderFrameIndex)) == [UInt64(mode.framesPerPacket)])
}

private func madiHandoffConfiguration(channelCount: Int) -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
            devices: .init(inputDeviceUID: "rme-madi-uid", outputDeviceUID: "rme-madi-uid"),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: channelCount, packetFormat: .float32LittleEndian),
            channelMaps: .init(input: Array(0..<channelCount), output: Array(0..<channelCount)),
            buffering: .init(playoutTargetFrames: 32, preallocatedBlockCount: 4, rxBufferPolicy: nil)
        )
}
