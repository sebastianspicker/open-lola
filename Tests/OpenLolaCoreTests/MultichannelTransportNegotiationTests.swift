// Verifies that multichannel negotiation accepts v2 and falls back to explicit stereo v1 compatibility.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func multichannelNegotiationAcceptsV2AndFallsBackToExplicitStereoV1Compatibility() throws {
    try multichannelNegotiationAcceptsV2AndFallsBackToExplicitStereoV1CompatibilityAssertions()
}

@Test
func rmeMatrixMetadataRoundTripsRateLimitsAndAllowsUnavailablePlayback() throws {
    try rmeMatrixMetadataRoundTripsRateLimitsAndAllowsUnavailablePlaybackAssertions()
}

private func multichannelNegotiationAcceptsV2AndFallsBackToExplicitStereoV1CompatibilityAssertions() throws {
    let mode = try multichannelSixtyFourChannelV2Mode()
    let sender64 = sixtyFourChannelSenderCapabilities()
    let receiver64 = sixtyFourChannelReceiverCapabilities()

    let v2Result = try AudioTransportNegotiation.negotiate(
        sender: sender64,
        receiver: receiver64,
        request: AudioTransportModeRequest(
            preferredProtocolVersion: .udpPcmV2,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 64,
            sampleFormat: .float32LittleEndian,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct
        )
    )

    #expect(v2Result.mode.protocolVersion == .udpPcmV2)
    #expect(v2Result.mode.channelCount == 64)
    #expect(v2Result.mode.sampleFormat == .float32LittleEndian)
    #expect(v2Result.mode.fragments.count == 8)
    #expect(mode.payloadByteCount == 32 * 64 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
    #expect(v2Result.mode.channelOrder.map(\.stableSourceIndex) == Array(0..<64))
    #expect(v2Result.warnings.isEmpty)

    let sender = stereoFallbackSenderCapabilities()
    let receiver = stereoFallbackReceiverCapabilities()

    let result = try AudioTransportNegotiation.negotiate(
        sender: sender,
        receiver: receiver,
        request: AudioTransportModeRequest(
            preferredProtocolVersion: .udpPcmV2,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 64,
            sampleFormat: .float32LittleEndian,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct
        )
    )

    #expect(result.mode.protocolVersion == .udpPcmV1)
    #expect(result.mode.channelCount == 2)
    #expect(result.mode.sampleFormat == .int16LittleEndian)
    #expect(result.mode.fragments.isEmpty)
    #expect(result.mode.channelOrder.map(\.stableSourceIndex) == [0, 1])
    #expect(result.warnings == [
        .preferredV2NotAvailable,
        .fallbackToStereoV1(requestedChannelCount: 64)
    ])
}

private func sixtyFourChannelSenderCapabilities() -> AudioTransportCapabilities {
    return AudioTransportCapabilities(
        transport: .init(protocolVersions: [.udpPcmV2, .udpPcmV1]),
        audio: .init(channelSet: AudioChannelSet(
            channels: (0..<64).reversed().map { index in
                AudioChannelDescriptor(
                    stableSourceIndex: index,
                    label: "madi-input-\(index + 1)"
                )
            }
        ), sampleRatesHertz: [48_000, 96_000], framesPerPacketOptions: [16, 32], sampleFormats: [.float32LittleEndian, .int16LittleEndian]),
        limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct], supportsMatrixMetadata: false)
    )
}

private func sixtyFourChannelReceiverCapabilities() -> AudioTransportCapabilities {
    return AudioTransportCapabilities(transport: .init(protocolVersions: [.udpPcmV2]), audio: .init(channelSet: .defaultOutput(count: 64), sampleRatesHertz: [48_000], framesPerPacketOptions: [32], sampleFormats: [.float32LittleEndian]), limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct], supportsMatrixMetadata: false))
}

private func stereoFallbackSenderCapabilities() -> AudioTransportCapabilities {
    return AudioTransportCapabilities(transport: .init(protocolVersions: [.udpPcmV2, .udpPcmV1]), audio: .init(channelSet: .defaultInput(count: 64), sampleRatesHertz: [48_000], framesPerPacketOptions: [32], sampleFormats: [.float32LittleEndian, .int16LittleEndian]), limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct], supportsMatrixMetadata: true))
}

private func stereoFallbackReceiverCapabilities() -> AudioTransportCapabilities {
    return AudioTransportCapabilities(transport: .init(protocolVersions: [.udpPcmV1]), audio: .init(channelSet: .defaultOutput(count: 2), sampleRatesHertz: [48_000], framesPerPacketOptions: [32], sampleFormats: [.int16LittleEndian]), limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 1, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct], supportsMatrixMetadata: false))
}

private func rmeMatrixMetadataRoundTripsRateLimitsAndAllowsUnavailablePlaybackAssertions() throws {
    let snapshot = operatorRmeRoutingSnapshot()

    try snapshot.validate()
    let decoded = try JSONDecoder().decode(
        RmeMatrixMetadataSnapshot.self,
        from: JSONEncoder().encode(snapshot)
    )
    var control = RmeMatrixMetadataControlState(minUpdateIntervalNanoseconds: 1_000)
    var newer = snapshot
    newer.revision = 2

    #expect(decoded == snapshot)
    #expect(control.record(snapshot, nowNanoseconds: 10_000) == .accepted(revision: 1))
    #expect(control.record(newer, nowNanoseconds: 10_500) == .rateLimited(
        revision: 2,
        nextAllowedNanoseconds: 11_000
    ))
    #expect(control.record(newer, nowNanoseconds: 11_000) == .accepted(revision: 2))

    let unavailable = RmeMatrixMetadataSnapshot.unavailable(
        revision: 0,
        capturedAt: "2026-05-04T00:00:00Z",
        notes: "RME matrix metadata unavailable; receiver uses local identity mix."
    )

    try unavailable.validate()

    #expect(unavailable.provider == .unavailable)
    #expect(unavailable.channels.isEmpty)
    #expect(unavailable.routes.isEmpty)
    #expect(!unavailable.requiresMetadataForPlayback)
}

private func operatorRmeRoutingSnapshot() -> RmeMatrixMetadataSnapshot {
    rmeRoutingSnapshot(
        channelLabel: "violin-close",
        destinationBusID: "phones-a",
        gainDb: -4,
        pan: -0.2,
        routeLabel: "player monitor"
    )
}

func rmeRoutingSnapshot(
    channelLabel: String,
    destinationBusID: String,
    gainDb: Double,
    pan: Double,
    routeLabel: String
) -> RmeMatrixMetadataSnapshot {
    RmeMatrixMetadataSnapshot(
        identity: .init(
            snapshotID: "operator-rme-routing",
            provider: .userProvidedSnapshot,
            revision: 1,
            capturedAt: "2026-05-04T00:00:00Z"
        ),
        provenance: .init(
            legalBasis: "operator-provided routing snapshot",
            confidence: .operatorConfirmed,
            notes: "Metadata is advisory; media playback does not depend on it."
        ),
        matrix: .init(
            channels: [
                AudioChannelDescriptor(
                    stableSourceIndex: 0,
                    label: channelLabel,
                    sourceKind: .userProvided
                )
            ],
            routes: [
                RmeMatrixRouteMetadata(
                    sourceChannelIndex: 0,
                    destinationBusID: destinationBusID,
                    gainDb: gainDb,
                    muted: false,
                    solo: false,
                    pan: pan,
                    stereoPairID: nil,
                    label: routeLabel
                )
            ]
        )
    )
}

func multichannelSixtyFourChannelV2Mode() throws -> AudioTransportMode {
    try plannedV2TestAudioTransportMode(
        .init(
            streamID: 1,
            channelCount: 64,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 3
        )
    )
}
