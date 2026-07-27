// Defines UDP media packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation
/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmV2PacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case oversizedPacket(expected: Int, actual: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedSampleFormat(UInt8)
    case unsupportedPackingMode(UInt8)
    case invalidStreamID(UInt32)
    case invalidTotalChannelCount(UInt16)
    case invalidChannelRange(
        totalChannelCount: UInt16,
        channelOffset: UInt16,
        channelsInFragment: UInt16
    )
    case invalidFragmentCount(UInt16)
    case invalidFragmentIndex(index: UInt16, count: UInt16)
    case invalidFrameCount(UInt32)
    case invalidSampleRate(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
}
/// Defines the UdpPcmV2PacketHeader wire representation shared by codecs and UDP media transport.
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

    public struct Stream: Equatable, Sendable {
        public var version: UInt8
        public var streamID: UInt32

        public init(version: UInt8 = UdpPcmV2PacketHeader.currentVersion, streamID: UInt32) {
            self.version = version
            self.streamID = streamID
        }
    }

    public typealias Timing = UdpAudioPacketTiming

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: UInt32
        public var framesPerPacket: UInt32
        public var totalChannelCount: UInt16
        public var sampleFormat: UdpPcmSampleFormat
        public var metadataRevision: UInt32
        public var packingMode: AudioWirePackingMode

        public init(
            sampleRateHertz: UInt32,
            framesPerPacket: UInt32,
            totalChannelCount: UInt16,
            sampleFormat: UdpPcmSampleFormat,
            metadataRevision: UInt32,
            packingMode: AudioWirePackingMode
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.totalChannelCount = totalChannelCount
            self.sampleFormat = sampleFormat
            self.metadataRevision = metadataRevision
            self.packingMode = packingMode
        }
    }

    public struct Fragment: Equatable, Sendable {
        public var channelOffset: UInt16
        public var channelsInFragment: UInt16
        public var fragmentIndex: UInt16
        public var fragmentCount: UInt16

        public init(
            channelOffset: UInt16,
            channelsInFragment: UInt16,
            fragmentIndex: UInt16,
            fragmentCount: UInt16
        ) {
            self.channelOffset = channelOffset
            self.channelsInFragment = channelsInFragment
            self.fragmentIndex = fragmentIndex
            self.fragmentCount = fragmentCount
        }
    }

    public init(
        stream: Stream,
        timing: Timing,
        format: Format,
        fragment: Fragment,
        payloadByteCount: UInt32 = 0
    ) {
        version = stream.version
        streamID = stream.streamID
        sequenceNumber = timing.sequenceNumber
        senderFrameIndex = timing.senderFrameIndex
        senderHostTimeNanoseconds = timing.senderHostTimeNanoseconds
        sampleRateHertz = format.sampleRateHertz
        framesPerPacket = format.framesPerPacket
        totalChannelCount = format.totalChannelCount
        channelOffset = fragment.channelOffset
        channelsInFragment = fragment.channelsInFragment
        fragmentIndex = fragment.fragmentIndex
        fragmentCount = fragment.fragmentCount
        sampleFormat = format.sampleFormat
        metadataRevision = format.metadataRevision
        packingMode = format.packingMode
        self.payloadByteCount = payloadByteCount
    }
}
