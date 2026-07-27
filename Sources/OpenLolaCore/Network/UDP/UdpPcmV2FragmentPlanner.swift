// Declares UDP media configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Configures UdpPcmV2FragmentPlanRequest so callers supply explicit inputs before starting UDP media transport.
public struct UdpPcmV2FragmentPlanRequest: Codable, Equatable, Sendable {
    /// Groups the audio metadata shared by each planned fragment.
    public struct AudioDescription: Codable, Equatable, Sendable {
        public var totalChannelCount: Int
        public var framesPerPacket: Int
        public var sampleRateHertz: Int
        public var sampleFormat: UdpPcmSampleFormat

        public init(
            totalChannelCount: Int,
            framesPerPacket: Int,
            sampleRateHertz: Int,
            sampleFormat: UdpPcmSampleFormat
        ) {
            self.totalChannelCount = totalChannelCount
            self.framesPerPacket = framesPerPacket
            self.sampleRateHertz = sampleRateHertz
            self.sampleFormat = sampleFormat
        }
    }

    /// Groups the packet metadata replicated across each planned fragment.
    public struct Metadata: Codable, Equatable, Sendable {
        public var metadataRevision: Int
        public var packingMode: AudioWirePackingMode

        public init(
            metadataRevision: Int,
            packingMode: AudioWirePackingMode
        ) {
            self.metadataRevision = metadataRevision
            self.packingMode = packingMode
        }
    }

    /// Limits the packet fragmentation work allowed for one deadline.
    public struct FragmentationLimits: Codable, Equatable, Sendable {
        public var maxTransmissionUnitBytes: Int
        public var maxFragmentsPerDeadline: Int

        public init(maxTransmissionUnitBytes: Int, maxFragmentsPerDeadline: Int) {
            self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
            self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
        }
    }

    /// Supplies the semantic inputs required to create a fragment plan request.
    public struct Input: Codable, Equatable, Sendable {
        public var streamID: Int
        public var audio: AudioDescription
        public var fragmentationLimits: FragmentationLimits
        public var metadata: Metadata

        public init(
            streamID: Int,
            audio: AudioDescription,
            fragmentationLimits: FragmentationLimits,
            metadata: Metadata
        ) {
            self.streamID = streamID
            self.audio = audio
            self.fragmentationLimits = fragmentationLimits
            self.metadata = metadata
        }
    }

    public var streamID: Int
    public var totalChannelCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var maxTransmissionUnitBytes: Int
    public var maxFragmentsPerDeadline: Int
    public var metadataRevision: Int
    public var packingMode: AudioWirePackingMode

    public init(_ input: Input) {
        self.streamID = input.streamID
        self.totalChannelCount = input.audio.totalChannelCount
        self.framesPerPacket = input.audio.framesPerPacket
        self.sampleRateHertz = input.audio.sampleRateHertz
        self.sampleFormat = input.audio.sampleFormat
        self.maxTransmissionUnitBytes = input.fragmentationLimits.maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = input.fragmentationLimits.maxFragmentsPerDeadline
        self.metadataRevision = input.metadata.metadataRevision
        self.packingMode = input.metadata.packingMode
    }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmV2FragmentPlanningError: Error, Codable, Equatable, Sendable {
    case nonPositiveField(String)
    case arithmeticOverflow(String)
    case mtuTooSmallForSingleChannel(mtuBytes: Int, requiredBytes: Int)
    case tooManyFragments(required: Int, maximum: Int)
    case channelCoverageMismatch(planned: Int, expected: Int)
}

/// Represents UdpPcmV2ChannelFragmentPlan values used by UDP media transport.
public struct UdpPcmV2ChannelFragmentPlan: Codable, Equatable, Sendable {
    /// Identifies the channels represented by one UDP fragment.
    public struct ChannelRange: Codable, Equatable, Sendable {
        public var offset: Int
        public var count: Int

        public init(offset: Int, count: Int) {
            self.offset = offset
            self.count = count
        }
    }

    /// Identifies one fragment's position in the plan.
    public struct Position: Codable, Equatable, Sendable {
        public var index: Int
        public var count: Int

        public init(index: Int, count: Int) {
            self.index = index
            self.count = count
        }
    }

    /// Records the payload and complete-packet sizes for a fragment.
    public struct ByteCounts: Codable, Equatable, Sendable {
        public var payload: Int
        public var packet: Int

        public init(payload: Int, packet: Int) {
            self.payload = payload
            self.packet = packet
        }
    }

    /// Supplies the semantic inputs required to create one planned channel fragment.
    public struct Input: Codable, Equatable, Sendable {
        public var streamID: Int
        public var audio: UdpPcmV2FragmentPlanRequest.AudioDescription
        public var metadata: UdpPcmV2FragmentPlanRequest.Metadata
        public var channelRange: ChannelRange
        public var position: Position
        public var byteCounts: ByteCounts

        public init(
            streamID: Int,
            audio: UdpPcmV2FragmentPlanRequest.AudioDescription,
            metadata: UdpPcmV2FragmentPlanRequest.Metadata,
            channelRange: ChannelRange,
            position: Position,
            byteCounts: ByteCounts
        ) {
            self.streamID = streamID
            self.audio = audio
            self.metadata = metadata
            self.channelRange = channelRange
            self.position = position
            self.byteCounts = byteCounts
        }
    }

    public var streamID: Int
    public var totalChannelCount: Int
    public var channelOffset: Int
    public var channelsInFragment: Int
    public var fragmentIndex: Int
    public var fragmentCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var metadataRevision: Int
    public var packingMode: AudioWirePackingMode
    public var payloadByteCount: Int
    public var packetByteCount: Int

    public init(_ input: Input) {
        self.streamID = input.streamID
        self.totalChannelCount = input.audio.totalChannelCount
        self.channelOffset = input.channelRange.offset
        self.channelsInFragment = input.channelRange.count
        self.fragmentIndex = input.position.index
        self.fragmentCount = input.position.count
        self.framesPerPacket = input.audio.framesPerPacket
        self.sampleRateHertz = input.audio.sampleRateHertz
        self.sampleFormat = input.audio.sampleFormat
        self.metadataRevision = input.metadata.metadataRevision
        self.packingMode = input.metadata.packingMode
        self.payloadByteCount = input.byteCounts.payload
        self.packetByteCount = input.byteCounts.packet
    }
}

/// Plans complete channel-range fragments that fit the negotiated MTU and per-deadline fragment limit.
public enum UdpPcmV2FragmentPlanner {
    public static func plan(
        _ request: UdpPcmV2FragmentPlanRequest
    ) throws -> [UdpPcmV2ChannelFragmentPlan] {
        try requirePositive(request.streamID, "streamID")
        try requirePositive(request.totalChannelCount, "totalChannelCount")
        try requirePositive(request.framesPerPacket, "framesPerPacket")
        try requirePositive(request.sampleRateHertz, "sampleRateHertz")
        try requirePositive(request.maxTransmissionUnitBytes, "maxTransmissionUnitBytes")
        try requirePositive(request.maxFragmentsPerDeadline, "maxFragmentsPerDeadline")

        let layout = try fragmentLayout(for: request)
        let fragments = try (0..<layout.fragmentCount).map { fragmentIndex in
            try fragment(
                for: request,
                layout: layout,
                fragmentIndex: fragmentIndex
            )
        }
        let plannedChannelCount = fragments.reduce(0) { $0 + $1.channelsInFragment }
        guard plannedChannelCount == request.totalChannelCount else {
            throw UdpPcmV2FragmentPlanningError.channelCoverageMismatch(
                planned: plannedChannelCount,
                expected: request.totalChannelCount
            )
        }
        return fragments
    }

    static func plan(
        stream: AudioStreamDescription,
        mtuBytes: Int,
        maxFragmentsPerDeadline: Int = 16,
        metadataRevision: Int = 0
    ) throws -> [UdpPcmV2ChannelFragmentPlan] {
        let audio = UdpPcmV2FragmentPlanRequest.AudioDescription(
            totalChannelCount: stream.channelCount,
            framesPerPacket: stream.framesPerPacket,
            sampleRateHertz: stream.sampleRateHertz,
            sampleFormat: stream.sampleFormat
        )
        let limits = UdpPcmV2FragmentPlanRequest.FragmentationLimits(
            maxTransmissionUnitBytes: mtuBytes,
            maxFragmentsPerDeadline: maxFragmentsPerDeadline
        )
        let metadata = UdpPcmV2FragmentPlanRequest.Metadata(
            metadataRevision: metadataRevision,
            packingMode: .interleavedChannelRange
        )
        let input = UdpPcmV2FragmentPlanRequest.Input(
            streamID: stream.id,
            audio: audio,
            fragmentationLimits: limits,
            metadata: metadata
        )
        return try plan(UdpPcmV2FragmentPlanRequest(input))
    }

    private static func fragmentLayout(
        for request: UdpPcmV2FragmentPlanRequest
    ) throws -> UdpPcmV2FragmentLayout {
        let bytesPerChannel = try checkedFragmentPlanningProduct(
            request.framesPerPacket,
            request.sampleFormat.bytesPerSample,
            field: "bytesPerChannel"
        )
        let bytesPerSingleChannelPacket = try checkedFragmentPlanningSum(
            UdpPcmV2PacketHeader.byteCount,
            bytesPerChannel,
            field: "bytesPerSingleChannelPacket"
        )
        guard request.maxTransmissionUnitBytes >= bytesPerSingleChannelPacket else {
            throw UdpPcmV2FragmentPlanningError.mtuTooSmallForSingleChannel(
                mtuBytes: request.maxTransmissionUnitBytes,
                requiredBytes: bytesPerSingleChannelPacket
            )
        }

        let payloadBudget = request.maxTransmissionUnitBytes - UdpPcmV2PacketHeader.byteCount
        let channelsPerFragment = max(1, payloadBudget / bytesPerChannel)
        let baseFragmentCount = request.totalChannelCount / channelsPerFragment
        let fragmentCount = request.totalChannelCount % channelsPerFragment == 0
            ? baseFragmentCount
            : try checkedFragmentPlanningSum(
                baseFragmentCount,
                1,
                field: "fragmentCount"
            )
        let plannedChannelCapacity = try checkedFragmentPlanningProduct(
            fragmentCount,
            channelsPerFragment,
            field: "plannedChannelCapacity"
        )
        guard fragmentCount > 0, plannedChannelCapacity >= request.totalChannelCount else {
            throw UdpPcmV2FragmentPlanningError.arithmeticOverflow("fragmentCount")
        }
        guard fragmentCount <= request.maxFragmentsPerDeadline else {
            throw UdpPcmV2FragmentPlanningError.tooManyFragments(
                required: fragmentCount,
                maximum: request.maxFragmentsPerDeadline
            )
        }
        return UdpPcmV2FragmentLayout(
            bytesPerChannel: bytesPerChannel,
            channelsPerFragment: channelsPerFragment,
            fragmentCount: fragmentCount
        )
    }

    private static func fragment(
        for request: UdpPcmV2FragmentPlanRequest,
        layout: UdpPcmV2FragmentLayout,
        fragmentIndex: Int
    ) throws -> UdpPcmV2ChannelFragmentPlan {
        let channelOffset = fragmentIndex * layout.channelsPerFragment
        let channelsInFragment = min(
            layout.channelsPerFragment,
            request.totalChannelCount - channelOffset
        )
        let payloadByteCount = try checkedFragmentPlanningProduct(
            channelsInFragment,
            layout.bytesPerChannel,
            field: "payloadByteCount"
        )
        let packetByteCount = try checkedFragmentPlanningSum(
            UdpPcmV2PacketHeader.byteCount,
            payloadByteCount,
            field: "packetByteCount"
        )
        guard packetByteCount <= request.maxTransmissionUnitBytes else {
            throw UdpPcmV2FragmentPlanningError.mtuTooSmallForSingleChannel(
                mtuBytes: request.maxTransmissionUnitBytes,
                requiredBytes: packetByteCount
            )
        }
        let channelRange = UdpPcmV2ChannelFragmentPlan.ChannelRange(
            offset: channelOffset,
            count: channelsInFragment
        )
        let position = UdpPcmV2ChannelFragmentPlan.Position(
            index: fragmentIndex,
            count: layout.fragmentCount
        )
        let byteCounts = UdpPcmV2ChannelFragmentPlan.ByteCounts(
            payload: payloadByteCount,
            packet: packetByteCount
        )
        return makeChannelFragmentPlan(
            request: request,
            channelRange: channelRange,
            position: position,
            byteCounts: byteCounts
        )
    }

    private static func makeChannelFragmentPlan(
        request: UdpPcmV2FragmentPlanRequest,
        channelRange: UdpPcmV2ChannelFragmentPlan.ChannelRange,
        position: UdpPcmV2ChannelFragmentPlan.Position,
        byteCounts: UdpPcmV2ChannelFragmentPlan.ByteCounts
    ) -> UdpPcmV2ChannelFragmentPlan {
        let audio = UdpPcmV2FragmentPlanRequest.AudioDescription(
            totalChannelCount: request.totalChannelCount,
            framesPerPacket: request.framesPerPacket,
            sampleRateHertz: request.sampleRateHertz,
            sampleFormat: request.sampleFormat
        )
        let metadata = UdpPcmV2FragmentPlanRequest.Metadata(
            metadataRevision: request.metadataRevision,
            packingMode: request.packingMode
        )
        let input = UdpPcmV2ChannelFragmentPlan.Input(
            streamID: request.streamID,
            audio: audio,
            metadata: metadata,
            channelRange: channelRange,
            position: position,
            byteCounts: byteCounts
        )
        return UdpPcmV2ChannelFragmentPlan(input)
    }

    private static func requirePositive(_ value: Int, _ field: String) throws {
        if value <= 0 {
            throw UdpPcmV2FragmentPlanningError.nonPositiveField(field)
        }
    }
}

private struct UdpPcmV2FragmentLayout {
    var bytesPerChannel: Int
    var channelsPerFragment: Int
    var fragmentCount: Int
}

private func checkedFragmentPlanningProduct(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    guard !result.overflow, result.partialValue >= 0 else {
        throw UdpPcmV2FragmentPlanningError.arithmeticOverflow(field)
    }
    return result.partialValue
}

private func checkedFragmentPlanningSum(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
    let result = lhs.addingReportingOverflow(rhs)
    guard !result.overflow, result.partialValue >= 0 else {
        throw UdpPcmV2FragmentPlanningError.arithmeticOverflow(field)
    }
    return result.partialValue
}
