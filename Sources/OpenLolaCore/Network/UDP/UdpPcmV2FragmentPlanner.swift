import Foundation

public struct UdpPcmV2PacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLPC".utf8)
    public static let currentVersion: UInt8 = 2
    public static let byteCount = 80
    public static let reservedPaddingByteCount = 12
    public static let headerGuard: UInt32 = 0x3243_504C

    public var version: UInt8
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64
    public var sampleRateHertz: UInt32
    public var framesPerPacket: UInt32
    public var totalChannelCount: UInt16
    public var channelOffset: UInt16
    public var channelsInFragment: UInt16
    public var fragmentIndex: UInt16
    public var fragmentCount: UInt16
    public var sampleFormat: UdpPcmSampleFormat
    public var metadataRevision: UInt32
    public var packingMode: AudioWirePackingMode
    public var payloadByteCount: UInt32

    public var packetByteCount: Int {
        Self.byteCount + Int(payloadByteCount)
    }

    public init(
        version: UInt8 = Self.currentVersion,
        streamID: UInt32,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        sampleRateHertz: UInt32,
        framesPerPacket: UInt32,
        totalChannelCount: UInt16,
        channelOffset: UInt16,
        channelsInFragment: UInt16,
        fragmentIndex: UInt16,
        fragmentCount: UInt16,
        sampleFormat: UdpPcmSampleFormat,
        metadataRevision: UInt32,
        packingMode: AudioWirePackingMode,
        payloadByteCount: UInt32 = 0
    ) {
        self.version = version
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.senderFrameIndex = senderFrameIndex
        self.senderHostTimeNanoseconds = senderHostTimeNanoseconds
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.totalChannelCount = totalChannelCount
        self.channelOffset = channelOffset
        self.channelsInFragment = channelsInFragment
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.sampleFormat = sampleFormat
        self.metadataRevision = metadataRevision
        self.packingMode = packingMode
        self.payloadByteCount = payloadByteCount
    }
}

public struct UdpPcmV2FragmentPlanRequest: Codable, Equatable, Sendable {
    public var streamID: Int
    public var totalChannelCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var maxTransmissionUnitBytes: Int
    public var maxFragmentsPerDeadline: Int
    public var metadataRevision: Int
    public var packingMode: AudioWirePackingMode

    public init(
        streamID: Int,
        totalChannelCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        metadataRevision: Int,
        packingMode: AudioWirePackingMode
    ) {
        self.streamID = streamID
        self.totalChannelCount = totalChannelCount
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.sampleFormat = sampleFormat
        self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
        self.metadataRevision = metadataRevision
        self.packingMode = packingMode
    }
}

public enum UdpPcmV2FragmentPlanningError: Error, Codable, Equatable, Sendable {
    case nonPositiveField(String)
    case arithmeticOverflow(String)
    case mtuTooSmallForSingleChannel(mtuBytes: Int, requiredBytes: Int)
    case tooManyFragments(required: Int, maximum: Int)
    case channelCoverageMismatch(planned: Int, expected: Int)
}

public struct UdpPcmV2ChannelFragmentPlan: Codable, Equatable, Sendable {
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

    public init(
        streamID: Int,
        totalChannelCount: Int,
        channelOffset: Int,
        channelsInFragment: Int,
        fragmentIndex: Int,
        fragmentCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        metadataRevision: Int,
        packingMode: AudioWirePackingMode,
        payloadByteCount: Int,
        packetByteCount: Int
    ) {
        self.streamID = streamID
        self.totalChannelCount = totalChannelCount
        self.channelOffset = channelOffset
        self.channelsInFragment = channelsInFragment
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.sampleFormat = sampleFormat
        self.metadataRevision = metadataRevision
        self.packingMode = packingMode
        self.payloadByteCount = payloadByteCount
        self.packetByteCount = packetByteCount
    }
}

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
        let fragments = try (0..<fragmentCount).map { fragmentIndex in
            let channelOffset = fragmentIndex * channelsPerFragment
            let channelsInFragment = min(
                channelsPerFragment,
                request.totalChannelCount - channelOffset
            )
            let payloadByteCount = try checkedFragmentPlanningProduct(
                channelsInFragment,
                bytesPerChannel,
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
            return UdpPcmV2ChannelFragmentPlan(
                streamID: request.streamID,
                totalChannelCount: request.totalChannelCount,
                channelOffset: channelOffset,
                channelsInFragment: channelsInFragment,
                fragmentIndex: fragmentIndex,
                fragmentCount: fragmentCount,
                framesPerPacket: request.framesPerPacket,
                sampleRateHertz: request.sampleRateHertz,
                sampleFormat: request.sampleFormat,
                metadataRevision: request.metadataRevision,
                packingMode: request.packingMode,
                payloadByteCount: payloadByteCount,
                packetByteCount: packetByteCount
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

    private static func requirePositive(_ value: Int, _ field: String) throws {
        if value <= 0 {
            throw UdpPcmV2FragmentPlanningError.nonPositiveField(field)
        }
    }
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
