import Foundation

func udpDatagram(
    _ frame: LoLaCompatibilityMediaFrame,
    videoFrameRate: Int? = nil
) throws -> LoLaUdpMediaDatagram {
    let decoded = try LoLaCompatibilityWireFrame.decode(frame.encodedFrame)
    return LoLaUdpMediaDatagram(
        stream: frame.stream,
        port: decoded.destinationPort,
        sourceHost: loLaUdpMediaHostString(decoded.sourceIP),
        sequenceNumber: frame.sequenceNumber,
        videoFrameRate: videoFrameRate,
        payload: decoded.payload
    )
}

func syntheticBidirectionalReceiveDatagrams(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> [LoLaUdpMediaDatagram] {
    try syntheticUdpMediaDatagrams(LoLaUdpMediaReceiveRunConfiguration(
        localHost: configuration.localHost,
        peer: configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer,
        outputPath: configuration.outputPath,
        dryRun: configuration.dryRun,
        maxDatagrams: max(1, lolaUdpMediaFrameReadCount(configuration)),
        mediaMode: configuration.mediaMode,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        videoWidth: configuration.videoWidth,
        videoHeight: configuration.videoHeight,
        videoBitsPerPixel: configuration.videoBitsPerPixel,
        timeoutSeconds: configuration.durationSeconds
    ))
}

func lolaUdpMediaFrameReadCount(_ configuration: ExternalConnectorSessionConfiguration) -> Int {
    LoLaCompatibilityMediaCodec.expectedDatagramCount(
        mediaMode: configuration.mediaMode,
        videoWidth: configuration.videoWidth,
        videoHeight: configuration.videoHeight,
        videoBitsPerPixel: configuration.videoBitsPerPixel,
        frameCountPerStream: configuration.mediaPacketCount
    )
}

func syntheticUdpMediaDatagrams(
    _ configuration: LoLaUdpMediaReceiveRunConfiguration
) throws -> [LoLaUdpMediaDatagram] {
    let session = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: configuration.localHost,
        localHost: configuration.peer == "0.0.0.0" ? "192.0.2.20" : configuration.peer,
        outputPath: configuration.outputPath,
        mediaMode: configuration.mediaMode,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        videoWidth: configuration.videoWidth,
        videoHeight: configuration.videoHeight,
        videoBitsPerPixel: configuration.videoBitsPerPixel
    )
    return try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: session,
        frameCountPerStream: 1
    ).prefix(configuration.maxDatagrams).map { try udpDatagram($0) }
}

func udpDatagramWireFrame(
    _ datagram: LoLaUdpMediaDatagram,
    configuration: LoLaUdpMediaReceiveRunConfiguration
) throws -> LoLaCompatibilityWireFrame {
    try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: parseLoLaUdpIPv4(configuration.peer == "0.0.0.0" ? "192.0.2.20" : configuration.peer),
        destinationIP: parseLoLaUdpIPv4(configuration.localHost),
        sourcePort: datagram.port,
        destinationPort: datagram.port,
        payload: datagram.payload
    )
}

func parseLoLaUdpIPv4(_ value: String) throws -> LoLaIPv4Address {
    let parts = value.split(separator: ".")
    guard parts.count == 4 else {
        throw ExternalConnectorSessionError.socketFailed("invalid IPv4 \(value)")
    }
    let octets = try parts.map { part -> UInt8 in
        guard let octet = UInt8(part) else {
            throw ExternalConnectorSessionError.socketFailed("invalid IPv4 \(value)")
        }
        return octet
    }
    return try LoLaIPv4Address(octets: octets)
}

func loLaUdpMediaDatagramMatchesPeer(_ datagram: LoLaUdpMediaDatagram, peer: String) -> Bool {
    guard peer != "0.0.0.0", let sourceHost = datagram.sourceHost else {
        return true
    }
    return sourceHost == peer
}

func loLaUdpMediaHostString(_ address: LoLaIPv4Address) -> String {
    address.octets.map(String.init).joined(separator: ".")
}

func parseLoLaUdpMediaArguments(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--local-host", "--peer", "--output", "--dry-run", "--packets", "--media",
        "--audio-port", "--video-port", "--channels", "--sample-rate", "--frames",
        "--video-width", "--video-height", "--video-bpp", "--timeout-seconds",
    ])
    return try parseExternalConnectorKeyValueArguments(arguments, allowed: allowed)
}
