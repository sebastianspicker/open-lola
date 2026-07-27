// Shares the stream and sender-timeline prefix carried by UDP audio packet formats.
import Foundation

protocol UdpAudioPacketHeaderPrefixProviding {
    var streamID: UInt32 { get }
    var sequenceNumber: UInt64 { get }
    var senderFrameIndex: UInt64 { get }
    var senderHostTimeNanoseconds: UInt64 { get }
    var sampleRateHertz: UInt32 { get }
    var udpAudioFrameCount: UInt32 { get }
}

func appendUdpAudioPacketHeaderPrefix<Header: UdpAudioPacketHeaderPrefixProviding>(
    _ header: Header,
    to data: inout Data
) {
    appendUdpPcmUInt32LE(header.streamID, to: &data)
    appendUdpPcmUInt64LE(header.sequenceNumber, to: &data)
    appendUdpPcmUInt64LE(header.senderFrameIndex, to: &data)
    appendUdpPcmUInt64LE(header.senderHostTimeNanoseconds, to: &data)
    appendUdpPcmUInt32LE(header.sampleRateHertz, to: &data)
    appendUdpPcmUInt32LE(header.udpAudioFrameCount, to: &data)
}
