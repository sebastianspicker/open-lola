public enum LoLaCompatibilityMediaModel {
    public static let ethernetHeaderByteCount = 14
    public static let ipv4HeaderByteCount = 20
    public static let udpHeaderByteCount = 8

    /// Recovered LoLa compatibility envelope: Ethernet(14) + IPv4(20) + UDP(8).
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "Linux seed audio wire sizing is 42 + 1066".
    public static let wirePayloadOffset = 0x2a

    /// Recovered LoLa compatibility media fragment body: payload starts after the 0x21-byte fragment header.
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "fragment helper evidence exposes a 0x21 payload offset".
    public static let fragmentPayloadOffset = 0x21

    /// Recovered LoLa compatibility fragment sentinel observed before serialized fragment metadata.
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "0xeeeeeeee marker".
    public static let fragmentMarker: UInt32 = 0xeeeeeeee

    /// Encoder seed used only for generated compatibility frames; decoded captures may carry variable IPv4 IDs.
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "encoder seed IPv4 ID 0x1337, variable decoded IPv4 IDs".
    public static let ipv4Identification: UInt16 = 0x1337

    /// Recovered video sendqueue/ring slot count for source-level compatibility packetization.
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "30-slot video ring/sendqueue".
    public static let videoRingSlotCount = 0x1e

    public static let maxAudioChannels = 256

    /// Recovered per-channel audio payload span: 128 bytes per channel before fixed UDP padding.
    /// Two 16-bit-channel evidence implies 64 samples per packet per channel.
    public static let defaultAudioPayloadBytesPerChannel = 0x80

    /// Fixed recovered LoLa audio UDP payload size: 1066 padded payload bytes, independent of channel count.
    /// Evidence anchor: `LoLaConnectorLaunchPlan.protocolFacts`, "1066-byte padded audio payloads".
    public static let audioUdpPayloadByteCount = 0x42a

    public static func audioPayloadByteCount(channels: Int) throws -> Int {
        guard channels > 0, channels <= maxAudioChannels else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("channels", String(channels))
        }
        return channels * defaultAudioPayloadBytesPerChannel
    }

    public static func audioWireFrameByteCount(channels: Int) throws -> Int {
        _ = try audioPayloadByteCount(channels: channels)
        return wirePayloadOffset + audioUdpPayloadByteCount
    }

    public static func samplesPerPacketPerChannel(bitsPerSample: Int) throws -> Int {
        guard bitsPerSample > 0, bitsPerSample % 8 == 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "bitsPerSample",
                String(bitsPerSample)
            )
        }
        return defaultAudioPayloadBytesPerChannel / (bitsPerSample / 8)
    }

    public static func mediaBpfFilter(
        sourceHost: String,
        destinationHost: String,
        audioPort: UInt16,
        videoPort: UInt16
    ) -> String {
        "ip and src host \(sourceHost) and dst host \(destinationHost) and (udp port \(audioPort) or udp port \(videoPort))"
    }

    public static var evidenceBoundary: String {
        "Source-level clean-room LoLa media grammar is implemented for little-endian serialized media bodies, normal 0x21-byte fragments, 1066-byte padded audio UDP payloads with fragment frameID sequence+1, and Linux-seed video prelude-plus-fragment packetization; real Windows LoLa interoperability remains PARTIAL until measured Windows-originated captures validate the behavior."
    }
}
