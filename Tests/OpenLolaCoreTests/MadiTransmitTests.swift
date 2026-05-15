import Foundation
import Testing

@testable import OpenLolaCore

@Test
func madiTransmitPacketizesCapturedPayloadForRequiredChannelCounts() throws {
    for channelCount in madiSyntheticRequiredChannelCounts {
        let mode = try madiV2Mode(channelCount: channelCount)
        let payloadByteCount = mode.framesPerPacket
            * channelCount
            * mode.sampleFormat.bytesPerSample
        let payload = Data((0..<payloadByteCount).map { UInt8($0 % 251) })
        var handoff = RealtimeAudioPacketHandoff(
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
func madiSyntheticSmokeUsesSharedAudioPayloadHelper() throws {
    #expect(SyntheticAudioPayload.make(seed: 2, byteCount: 5) == Data([2, 3, 4, 5, 6]))

    let sourceFiles = try [
        "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiChannelCounts.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift"
    ].map(readMadiTransmitSource)
    let combinedSources = sourceFiles.joined(separator: "\n")

    #expect(combinedSources.contains("SyntheticAudioPayload.make"))
    #expect(!combinedSources.contains("Data((0..<byteCount).map"))
    #expect(!combinedSources.contains("Data((0..<payloadByteCount).map"))
}

@Test
func madiSyntheticSmokeUsesSharedRequiredChannelCounts() throws {
    let channelCountSource = try readMadiTransmitSource(
        "Sources/OpenLolaCore/Audio/MADI/MadiChannelCounts.swift"
    )
    let transmitSource = try readMadiTransmitSource("Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift")
    let receiveSource = try readMadiTransmitSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift")

    #expect(madiSyntheticRequiredChannelCounts == [2, 8, 16, 32, 64])
    #expect(channelCountSource.contains("let madiSyntheticRequiredChannelCounts = [2, 8, 16, 32, 64]"))
    #expect(transmitSource.contains("Set(madiSyntheticRequiredChannelCounts)"))
    #expect(receiveSource.contains("Set(madiSyntheticRequiredChannelCounts)"))
    #expect(transmitSource.contains("try madiSyntheticRequiredChannelCounts.map"))
    #expect(receiveSource.contains("try madiSyntheticRequiredChannelCounts.map"))
}

@Test
func madiSyntheticSmokeUsesSharedTransportModePayloadByteCount() throws {
    let sourceFiles = try [
        "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift",
        "Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift",
        "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift",
    ].map(readMadiTransmitSource)
    let combinedSources = sourceFiles.joined(separator: "\n")

    #expect(combinedSources.contains("var payloadByteCount: Int"))
    #expect(combinedSources.contains("mode.payloadByteCount"))
    #expect(combinedSources.contains("localMode.payloadByteCount"))
    #expect(combinedSources.contains("remoteMode.payloadByteCount"))
    #expect(!combinedSources.contains("private static func payloadByteCount(for mode: AudioTransportMode)"))
}

@Test
func madiTransmitSelectedChannelMapPreservesConfiguredOrdering() throws {
    let channelMap = [2, 0, 3]
    let mode = try madiV2Mode(
        channelCount: channelMap.count,
        framesPerPacket: 2,
        sampleFormat: .int16LittleEndian
    )
    var handoff = RealtimeAudioPacketHandoff(
        configuration: RealtimeAudioEngineConfiguration(
            inputDeviceUID: "rme-madi-uid",
            outputDeviceUID: "rme-madi-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 2,
            channelCount: channelMap.count,
            packetFormat: .int16LittleEndian,
            inputChannelMap: channelMap,
            outputChannelMap: Array(0..<channelMap.count),
            playoutTargetFrames: 2,
            preallocatedBlockCount: 4
        )
    )
    let source = int16InterleavedPayload(frameCount: 2, channelCount: 4)
    let expected = int16InterleavedPayload(
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
    let mode = try madiV2Mode(channelCount: 8)
    var handoff = RealtimeAudioPacketHandoff(
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

@Test
func madiTransmitSyntheticSmokeCoversRequiredPacketizationMatrix() throws {
    let report = try MadiTransmitSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.measurements.map(\.channelCount) == madiSyntheticRequiredChannelCounts)
    #expect(report.measurements.allSatisfy { $0.allocationWarnings == 0 })
    #expect(report.measurements.allSatisfy { $0.maxPacketByteCount <= 1_200 })
}

private func madiHandoffConfiguration(channelCount: Int) -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: channelCount,
        packetFormat: .float32LittleEndian,
        inputChannelMap: Array(0..<channelCount),
        outputChannelMap: Array(0..<channelCount),
        playoutTargetFrames: 32,
        preallocatedBlockCount: 4
    )
}

private func madiV2Mode(
    channelCount: Int,
    framesPerPacket: Int = 32,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian
) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: channelCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: 48_000,
            sampleFormat: sampleFormat,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: framesPerPacket,
        channelCount: channelCount,
        sampleFormat: sampleFormat,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func int16InterleavedPayload(frameCount: Int, channelCount: Int) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in 0..<channelCount {
            appendInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    return data
}

private func int16InterleavedPayload(
    frameCount: Int,
    sourceChannelCount: Int,
    selectedChannels: [Int]
) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in selectedChannels {
            appendInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    _ = sourceChannelCount
    return data
}

private func appendInt16Sample(_ value: Int16, to data: inout Data) {
    let littleEndian = value.littleEndian
    withUnsafeBytes(of: littleEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func readMadiTransmitSource(_ relativePath: String) throws -> String {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 {
        root.deleteLastPathComponent()
    }
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
