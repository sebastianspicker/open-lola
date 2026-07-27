// Implements AudioTransportNegotiation media transport boundary, separating packet I/O from session policy.
import Foundation

/// Negotiates a shared UDP PCM mode, preferring multichannel v2 and reporting any stereo v1 fallback.
public enum AudioTransportNegotiation {
    public static func negotiate(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest
    ) throws -> AudioTransportNegotiationResult {
        try validateCommonFields(sender: sender, receiver: receiver, request: request)

        let senderChannels = sender.channelSet.sortedByStableSourceIndex
        guard senderChannels.count >= request.channelCount else {
            throw AudioTransportNegotiationError.insufficientSenderChannels(
                requested: request.channelCount,
                available: senderChannels.count
            )
        }

        let receiverChannels = receiver.channelSet.sortedByStableSourceIndex
        let sharedProtocols = Set(sender.supportedProtocolVersions)
            .intersection(receiver.supportedProtocolVersions)

        if request.preferredProtocolVersion == .udpPcmV2,
           sharedProtocols.contains(.udpPcmV2),
           sender.sampleFormats.contains(request.sampleFormat),
           receiver.sampleFormats.contains(request.sampleFormat),
           receiverChannels.count >= request.channelCount {
            return try negotiateV2(
                sender: sender,
                receiver: receiver,
                request: request,
                channelOrder: Array(senderChannels.prefix(request.channelCount))
            )
        }

        if sharedProtocols.contains(.udpPcmV1) {
            return try negotiateStereoV1(
                sender: sender,
                receiver: receiver,
                request: request,
                senderChannels: senderChannels,
                receiverChannels: receiverChannels
            )
        }

        if receiverChannels.count < request.channelCount {
            throw AudioTransportNegotiationError.insufficientReceiverChannels(
                requested: request.channelCount,
                available: receiverChannels.count
            )
        }
        guard sender.sampleFormats.contains(request.sampleFormat),
              receiver.sampleFormats.contains(request.sampleFormat) else {
            throw AudioTransportNegotiationError.unsupportedSampleFormat(request.sampleFormat)
        }
        throw AudioTransportNegotiationError.noCompatibleProtocol
    }

    private static func negotiateV2(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest,
        channelOrder: [AudioChannelDescriptor]
    ) throws -> AudioTransportNegotiationResult {
        let mtu = min(sender.maxTransmissionUnitBytes, receiver.maxTransmissionUnitBytes)
        let fragmentLimit = min(sender.maxFragmentsPerDeadline, receiver.maxFragmentsPerDeadline)
        let fragments: [UdpPcmV2ChannelFragmentPlan]
        do {
            fragments = try v2FragmentPlan(request: request, mtu: mtu, fragmentLimit: fragmentLimit)
        } catch let error as UdpPcmV2FragmentPlanningError {
            throw AudioTransportNegotiationError.v2FragmentationFailed(error)
        }

        return AudioTransportNegotiationResult(
            mode: AudioTransportMode(
                transport: .init(
                    protocolVersion: .udpPcmV2,
                    latencyProfile: request.latencyProfile,
                    rxBufferProfile: request.rxBufferProfile,
                    maxTransmissionUnitBytes: mtu
                ),
                format: .init(
                    sampleRateHertz: request.sampleRateHertz,
                    framesPerPacket: request.framesPerPacket,
                    channelCount: request.channelCount,
                    sampleFormat: request.sampleFormat
                ),
                layout: .init(channelOrder: channelOrder, fragments: fragments)
            ),
            warnings: []
        )
    }

    private static func v2FragmentPlan(
        request: AudioTransportModeRequest,
        mtu: Int,
        fragmentLimit: Int
    ) throws -> [UdpPcmV2ChannelFragmentPlan] {
        let audio = UdpPcmV2FragmentPlanRequest.AudioDescription(
            totalChannelCount: request.channelCount,
            framesPerPacket: request.framesPerPacket,
            sampleRateHertz: request.sampleRateHertz,
            sampleFormat: request.sampleFormat
        )
        let fragmentationLimits = UdpPcmV2FragmentPlanRequest.FragmentationLimits(
            maxTransmissionUnitBytes: mtu,
            maxFragmentsPerDeadline: fragmentLimit
        )
        let metadata = UdpPcmV2FragmentPlanRequest.Metadata(
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        )
        return try UdpPcmV2FragmentPlanner.plan(
            .init(.init(
                streamID: 1,
                audio: audio,
                fragmentationLimits: fragmentationLimits,
                metadata: metadata
            ))
        )
    }

    private static func negotiateStereoV1(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest,
        senderChannels: [AudioChannelDescriptor],
        receiverChannels: [AudioChannelDescriptor]
    ) throws -> AudioTransportNegotiationResult {
        guard senderChannels.count >= 2, receiverChannels.count >= 2 else {
            throw AudioTransportNegotiationError.noCompatibleV1StereoMode
        }
        guard let sampleFormat = v1SampleFormat(sender: sender, receiver: receiver) else {
            throw AudioTransportNegotiationError.noCompatibleV1StereoMode
        }

        return AudioTransportNegotiationResult(
            mode: AudioTransportMode(
                transport: .init(
                    protocolVersion: .udpPcmV1,
                    latencyProfile: request.latencyProfile,
                    rxBufferProfile: request.rxBufferProfile,
                    maxTransmissionUnitBytes: min(
                        sender.maxTransmissionUnitBytes,
                        receiver.maxTransmissionUnitBytes
                    )
                ),
                format: .init(
                    sampleRateHertz: request.sampleRateHertz,
                    framesPerPacket: request.framesPerPacket,
                    channelCount: 2,
                    sampleFormat: sampleFormat
                ),
                layout: .init(channelOrder: Array(senderChannels.prefix(2)), fragments: [])
            ),
            warnings: stereoV1FallbackWarnings(request: request)
        )
    }

    private static func stereoV1FallbackWarnings(
        request: AudioTransportModeRequest
    ) -> [AudioTransportNegotiationWarning] {
        var warnings: [AudioTransportNegotiationWarning] = []
        if request.preferredProtocolVersion == .udpPcmV2 {
            warnings.append(.preferredV2NotAvailable)
        }
        if request.channelCount != 2 {
            warnings.append(.fallbackToStereoV1(requestedChannelCount: request.channelCount))
        }
        return warnings
    }

    private static func validateCommonFields(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest
    ) throws {
        guard sender.sampleRatesHertz.contains(request.sampleRateHertz),
              receiver.sampleRatesHertz.contains(request.sampleRateHertz) else {
            throw AudioTransportNegotiationError.unsupportedSampleRate(request.sampleRateHertz)
        }
        guard sender.framesPerPacketOptions.contains(request.framesPerPacket),
              receiver.framesPerPacketOptions.contains(request.framesPerPacket) else {
            throw AudioTransportNegotiationError.unsupportedFramesPerPacket(
                request.framesPerPacket
            )
        }
        guard sender.latencyProfiles.contains(request.latencyProfile),
              receiver.latencyProfiles.contains(request.latencyProfile) else {
            throw AudioTransportNegotiationError.unsupportedLatencyProfile(request.latencyProfile)
        }
        guard sender.rxBufferProfiles.contains(request.rxBufferProfile),
              receiver.rxBufferProfiles.contains(request.rxBufferProfile) else {
            throw AudioTransportNegotiationError.unsupportedRxBufferProfile(request.rxBufferProfile)
        }
    }

    private static func v1SampleFormat(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities
    ) -> UdpPcmSampleFormat? {
        if sender.sampleFormats.contains(.int16LittleEndian),
           receiver.sampleFormats.contains(.int16LittleEndian) {
            return .int16LittleEndian
        }
        if sender.sampleFormats.contains(.float32LittleEndian),
           receiver.sampleFormats.contains(.float32LittleEndian) {
            return .float32LittleEndian
        }
        return nil
    }
}
