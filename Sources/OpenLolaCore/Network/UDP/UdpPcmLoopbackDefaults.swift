import Foundation

enum UdpPcmLoopbackDefaults {
    static let port: UInt16 = 5_004
    static let sampleRateHertz = 48_000
    static let framesPerPacket = 32
    static let channelCount = 2
    static let packetMode = UdpPcmPacketMode(
        sampleRateHertz: sampleRateHertz,
        framesPerPacket: framesPerPacket,
        channelCount: channelCount,
        sampleFormat: .int16LittleEndian
    )
}
