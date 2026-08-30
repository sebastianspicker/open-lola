// Builds the shared UDP PCM v2 transport mode used by synthetic MADI smoke measurements.

public func madiSyntheticUdpPcmV2AudioTransportMode(
    channelCount: Int,
    framesPerPacket: Int,
    sampleRateHertz: Int,
    sampleFormat: UdpPcmSampleFormat,
    maxTransmissionUnitBytes: Int
) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            .init(
                streamID: 1,
                audio: .init(
                    totalChannelCount: channelCount,
                    framesPerPacket: framesPerPacket,
                    sampleRateHertz: sampleRateHertz,
                    sampleFormat: sampleFormat
                ),
                fragmentationLimits: .init(
                    maxTransmissionUnitBytes: maxTransmissionUnitBytes,
                    maxFragmentsPerDeadline: 16
                ),
                metadata: .init(
                    metadataRevision: 3,
                    packingMode: .interleavedChannelRange
                )
            )
        )
    )
    return AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes
        ),
        format: .init(
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            channelCount: channelCount,
            sampleFormat: sampleFormat
        ),
        layout: .init(
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            fragments: fragments
        )
    )
}
