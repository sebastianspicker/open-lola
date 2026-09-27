// Handles MadiReceiveMixing receive-side processing, isolating input handling from compatibility and report policy.
import Foundation

struct MadiReceiverMixExecutionPlan: Sendable {
    let revision: UInt64
    let sampleFormat: UdpPcmSampleFormat
    let inputFrameStrideBytes: Int
    let outputFrameStrideBytes: Int
    let outputChannelCount: Int
    let routes: [MadiReceiverMixExecutionRoute]

    init(
        mode: AudioTransportMode,
        prepared: PreparedReceiverMixSnapshot,
        revision: UInt64,
        outputChannelCount: Int
    ) {
        let bytesPerSample = mode.sampleFormat.bytesPerSample
        self.revision = revision
        self.sampleFormat = mode.sampleFormat
        self.inputFrameStrideBytes = mode.channelCount * bytesPerSample
        self.outputFrameStrideBytes = outputChannelCount * bytesPerSample
        self.outputChannelCount = outputChannelCount
        self.routes = prepared.routes.compactMap {
            $0.muted ? nil : MadiReceiverMixExecutionRoute(route: $0, bytesPerSample: bytesPerSample)
        }
    }
}

struct MadiReceiverMixExecutionRoute: Sendable {
    let sourceChannelOffsetBytes: Int
    let destinationChannelOffsetBytes: Int
    let linearGain: Double
    let leftGain: Double
    let rightGain: Double
    let usesStereoPan: Bool

    init(route: PreparedReceiverMixRoute, bytesPerSample: Int) {
        sourceChannelOffsetBytes = route.sourceChannelIndex * bytesPerSample
        destinationChannelOffsetBytes = route.destinationChannelIndex * bytesPerSample
        linearGain = route.linearGain
        leftGain = route.leftGain
        rightGain = route.rightGain
        usesStereoPan = abs(route.pan) > receiverMixPanTolerance
    }
}

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
            try receiverMixScratch.withUnsafeMutableBufferPointer { outputBytes in
                try Self.applyMixPlan(
                    input: inputBytes,
                    output: &outputBytes,
                    plan: mixExecutionPlan,
                    framesPerPacket: mode.framesPerPacket
                )
            }
        }
        return Data(receiverMixScratch)
    }

    static func applyMixPlan(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        plan: MadiReceiverMixExecutionPlan,
        framesPerPacket: Int
    ) throws {
        switch plan.sampleFormat {
        case .int16LittleEndian:
            try applyInt16MixPlan(
                input: input,
                output: &output,
                plan: plan,
                framesPerPacket: framesPerPacket
            )
        case .float32LittleEndian:
            try applyFloat32MixPlan(
                input: input,
                output: &output,
                plan: plan,
                framesPerPacket: framesPerPacket
            )
        }
    }

    static func applyInt16MixPlan(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        plan: MadiReceiverMixExecutionPlan,
        framesPerPacket: Int
    ) throws {
        for frame in 0..<framesPerPacket {
            let inputOffset = frame * plan.inputFrameStrideBytes
            let outputOffset = frame * plan.outputFrameStrideBytes
            for route in plan.routes {
                let source = Double(try readInt16(input, offset: inputOffset + route.sourceChannelOffsetBytes))
                if plan.outputChannelCount == 2, route.usesStereoPan {
                    try mixInt16(source, output: &output, offset: outputOffset, gain: route.leftGain)
                    try mixInt16(source, output: &output, offset: outputOffset + 2, gain: route.rightGain)
                } else {
                    try mixInt16(
                        source,
                        output: &output,
                        offset: outputOffset + route.destinationChannelOffsetBytes,
                        gain: route.linearGain
                    )
                }
            }
        }
    }

    static func applyFloat32MixPlan(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        plan: MadiReceiverMixExecutionPlan,
        framesPerPacket: Int
    ) throws {
        for frame in 0..<framesPerPacket {
            let inputOffset = frame * plan.inputFrameStrideBytes
            let outputOffset = frame * plan.outputFrameStrideBytes
            for route in plan.routes {
                let source = Double(try readFloat32(input, offset: inputOffset + route.sourceChannelOffsetBytes))
                if plan.outputChannelCount == 2, route.usesStereoPan {
                    try mixFloat32(source, output: &output, offset: outputOffset, gain: route.leftGain)
                    try mixFloat32(source, output: &output, offset: outputOffset + 4, gain: route.rightGain)
                } else {
                    try mixFloat32(
                        source,
                        output: &output,
                        offset: outputOffset + route.destinationChannelOffsetBytes,
                        gain: route.linearGain
                    )
                }
            }
        }
    }

    static func mixInt16(
        _ source: Double,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        offset: Int,
        gain: Double
    ) throws {
        let existing = Double(try readInt16(output, offset: offset))
        let mixed = max(Double(Int16.min), min(Double(Int16.max), existing + source * gain))
        writeInt16(Int16(mixed.rounded()), to: &output, offset: offset)
    }

    static func mixFloat32(
        _ source: Double,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        offset: Int,
        gain: Double
    ) throws {
        let existing = Double(try readFloat32(output, offset: offset))
        writeFloat32(Float(existing + source * gain), to: &output, offset: offset)
    }

}
