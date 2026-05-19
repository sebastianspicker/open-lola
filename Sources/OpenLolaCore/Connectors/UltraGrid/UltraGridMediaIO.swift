import Darwin
import Foundation

public protocol UltraGridCompatibilityMediaTransmitting {
    func transmit(_ datagrams: [UltraGridCompatibilityDatagram], localHost: String, peer: String) throws -> Int
}

public protocol UltraGridCompatibilityMediaReceiving {
    func receive(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        timeoutSeconds: Int
    ) throws -> [UltraGridCompatibilityDatagram]
}

public final class UltraGridMemoryMediaTransmitter: UltraGridCompatibilityMediaTransmitting {
    public private(set) var transmittedDatagrams: [UltraGridCompatibilityDatagram] = []

    public init() {}

    public func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        transmittedDatagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}

public struct UltraGridMemoryMediaReceiver: UltraGridCompatibilityMediaReceiving {
    public var datagrams: [UltraGridCompatibilityDatagram]

    public init(datagrams: [UltraGridCompatibilityDatagram]) {
        self.datagrams = datagrams
    }

    public func receive(
        expectedDatagrams: Int,
        localHost _: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16,
        payloadRegistry _: UltraGridRTPPayloadRegistry,
        encryptionConfiguration _: UltraGridEncryptionConfiguration?,
        timeoutSeconds _: Int
    ) throws -> [UltraGridCompatibilityDatagram] {
        Array(datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == peer || peer == "0.0.0.0")
                && ($0.destinationPort == audioPort || $0.destinationPort == videoPort)
        }.prefix(expectedDatagrams))
    }
}

public struct UltraGridSocketMediaTransmitter: UltraGridCompatibilityMediaTransmitting {
    public init() {}

    public func transmit(_ datagrams: [UltraGridCompatibilityDatagram], localHost _: String, peer: String) throws -> Int {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { closeUdpSocket(socket) }
        for datagram in datagrams {
            try sendDatagram(try datagram.rtp.encoded(), socket: socket, host: peer, port: datagram.destinationPort.bigEndian)
        }
        return datagrams.count
    }
}

public struct UltraGridSocketMediaReceiver: UltraGridCompatibilityMediaReceiving {
    public init() {}

    public func receive(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        timeoutSeconds: Int
    ) throws -> [UltraGridCompatibilityDatagram] {
        let audioSocket = try makeUdpSocket(receiveTimeoutSeconds: timeoutSeconds)
        let videoSocket = try makeUdpSocket(receiveTimeoutSeconds: timeoutSeconds)
        defer {
            closeUdpSocket(audioSocket)
            closeUdpSocket(videoSocket)
        }
        try bindIPv4(audioSocket, host: localHost, port: audioPort.bigEndian)
        try bindIPv4(videoSocket, host: localHost, port: videoPort.bigEndian)
        try setNonBlocking(audioSocket)
        try setNonBlocking(videoSocket)

        var received: [UltraGridCompatibilityDatagram] = []
        let deadline = Date().addingTimeInterval(TimeInterval(max(1, timeoutSeconds)))
        var audioBuffer: [UInt8] = []
        var videoBuffer: [UInt8] = []
        while received.count < expectedDatagrams, Date() < deadline {
            try receiveAvailable(
                socket: audioSocket,
                port: audioPort,
                stream: .audio,
                peer: peer,
                payloadRegistry: payloadRegistry,
                encryptionConfiguration: encryptionConfiguration,
                into: &received,
                buffer: &audioBuffer
            )
            try receiveAvailable(
                socket: videoSocket,
                port: videoPort,
                stream: .video,
                peer: peer,
                payloadRegistry: payloadRegistry,
                encryptionConfiguration: encryptionConfiguration,
                into: &received,
                buffer: &videoBuffer
            )
            if received.count < expectedDatagrams {
                usleep(1_000)
            }
        }
        return received
    }

    private func receiveAvailable(
        socket: Int32,
        port: UInt16,
        stream: LoLaCompatibilityMediaStream,
        peer: String,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        into received: inout [UltraGridCompatibilityDatagram],
        buffer: inout [UInt8]
    ) throws {
        while let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: socket,
            byteCount: 65_535,
            buffer: &buffer
        ) {
            guard peer == "0.0.0.0" || datagram.host == peer else {
                continue
            }
            let rtp = try RTPPacket.decode(datagram.data)
            _ = try UltraGridCompatibility.decode(
                rtp,
                registry: payloadRegistry,
                encryptionConfiguration: encryptionConfiguration
            )
            received.append(UltraGridCompatibilityDatagram(
                stream: stream,
                sourceHost: datagram.host,
                sourcePort: datagram.port,
                destinationPort: port,
                rtp: rtp
            ))
        }
    }
}
