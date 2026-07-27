// Handles MadiReceiveMixing receive-side processing, isolating input handling from compatibility and report policy.
import Foundation

extension MadiReceiveEngine {
    static func defaultRxBufferPolicy(for mode: AudioTransportMode) throws -> RxBufferPolicy {
        try audioTransportRxBufferPolicy(for: mode)
    }

    func validate(_ packet: UdpPcmV2Packet) throws {
        try validateTimingHeader(packet)
        try validateFormatHeader(packet)
        try validateFragmentPlan(packet)
    }

    func validateTimingHeader(_ packet: UdpPcmV2Packet) throws {
        guard packet.header.streamID == UInt32(mode.fragments.first?.streamID ?? 0) else {
            throw MadiReceiveError.transportModeMismatch("streamID")
        }
        guard packet.header.sampleRateHertz == UInt32(mode.sampleRateHertz) else {
            throw MadiReceiveError.transportModeMismatch("sampleRateHertz")
        }
        guard packet.header.framesPerPacket == UInt32(mode.framesPerPacket) else {
            throw MadiReceiveError.transportModeMismatch("framesPerPacket")
        }
    }

    func validateFormatHeader(_ packet: UdpPcmV2Packet) throws {
        guard packet.header.totalChannelCount == UInt16(mode.channelCount) else {
            throw MadiReceiveError.transportModeMismatch("totalChannelCount")
        }
        guard packet.header.sampleFormat == mode.sampleFormat else {
            throw MadiReceiveError.transportModeMismatch("sampleFormat")
        }
        guard packet.header.fragmentCount == UInt16(mode.fragments.count) else {
            throw MadiReceiveError.transportModeMismatch("fragmentCount")
        }
        guard packet.header.metadataRevision == UInt32(mode.fragments.first?.metadataRevision ?? 0) else {
            throw MadiReceiveError.transportModeMismatch("metadataRevision")
        }
        guard packet.header.packingMode == mode.fragments.first?.packingMode else {
            throw MadiReceiveError.transportModeMismatch("packingMode")
        }
    }

    func validateFragmentPlan(_ packet: UdpPcmV2Packet) throws {
        let matchesFragmentPlan = mode.fragments.contains { fragment in
            fragment.fragmentIndex == Int(packet.header.fragmentIndex)
                && fragment.channelOffset == Int(packet.header.channelOffset)
                && fragment.channelsInFragment == Int(packet.header.channelsInFragment)
                && fragment.payloadByteCount == packet.payload.count
                && fragment.metadataRevision == Int(packet.header.metadataRevision)
                && fragment.packingMode == packet.header.packingMode
        }
        guard matchesFragmentPlan else {
            throw MadiReceiveError.transportModeMismatch("fragmentPlan")
        }
    }

    static func outputPayloadByteCount(
        mode: AudioTransportMode,
        outputChannelCount: Int
    ) -> Int {
        mode.framesPerPacket
            * outputChannelCount
            * mode.sampleFormat.bytesPerSample
    }

    mutating func applyReceiverMix(_ inputPayload: Data) throws -> Data {
        receiverMixScratch.withUnsafeMutableBytes { scratchBytes in
            if let scratchBaseAddress = scratchBytes.baseAddress {
                memset(scratchBaseAddress, 0, scratchBytes.count)
            }
        }
        try inputPayload.withUnsafeBytes { inputBytes in
            let mode = self.mode
            let outputChannelCount = self.outputChannelCount
            let routes = self.mixStore.prepared.routes
            try receiverMixScratch.withUnsafeMutableBufferPointer { outputBytes in
                for frame in 0..<mode.framesPerPacket {
                    let context = MadiReceiveSampleMixContext(
                        frame: frame,
                        mode: mode,
                        outputChannelCount: outputChannelCount
                    )
                    for route in routes where !route.muted {
                        try Self.mixSample(
                            input: inputBytes,
                            output: &outputBytes,
                            route: route,
                            context: context
                        )
                    }
                }
            }
        }
        return Data(receiverMixScratch)
    }

    static func mixSample(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        route: PreparedReceiverMixRoute,
        context: MadiReceiveSampleMixContext
    ) throws {
        if context.outputChannelCount == 2, abs(route.pan) > receiverMixPanTolerance {
            try mixSample(
                input: input,
                output: &output,
                request: MadiReceiveSampleMixRequest(
                    sourceChannelIndex: route.sourceChannelIndex,
                    destinationChannelIndex: 0,
                    gain: route.leftGain,
                    context: context
                )
            )
            try mixSample(
                input: input,
                output: &output,
                request: MadiReceiveSampleMixRequest(
                    sourceChannelIndex: route.sourceChannelIndex,
                    destinationChannelIndex: 1,
                    gain: route.rightGain,
                    context: context
                )
            )
            return
        }
        try mixSample(
            input: input,
            output: &output,
            request: MadiReceiveSampleMixRequest(
                sourceChannelIndex: route.sourceChannelIndex,
                destinationChannelIndex: route.destinationChannelIndex,
                gain: route.linearGain,
                context: context
            )
        )
    }

    static func mixSample(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        request: MadiReceiveSampleMixRequest
    ) throws {
        let mode = request.context.mode
        let bytesPerSample = mode.sampleFormat.bytesPerSample
        let sourceOffset = ((request.context.frame * mode.channelCount) + request.sourceChannelIndex)
            * bytesPerSample
        let destinationOffset = ((request.context.frame * request.context.outputChannelCount)
            + request.destinationChannelIndex)
            * bytesPerSample
        switch mode.sampleFormat {
        case .int16LittleEndian:
            let source = Double(try readInt16(input, offset: sourceOffset))
            let existing = Double(try readInt16(output, offset: destinationOffset))
            let mixed = max(
                Double(Int16.min),
                min(Double(Int16.max), existing + source * request.gain)
            )
            writeInt16(Int16(mixed.rounded()), to: &output, offset: destinationOffset)
        case .float32LittleEndian:
            let source = Double(try readFloat32(input, offset: sourceOffset))
            let existing = Double(try readFloat32(output, offset: destinationOffset))
            writeFloat32(
                Float(existing + source * request.gain),
                to: &output,
                offset: destinationOffset
            )
        }
    }

}
