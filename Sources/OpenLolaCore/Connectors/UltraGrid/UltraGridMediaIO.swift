import Darwin
import Foundation

public protocol UltraGridCompatibilityMediaTransmitting {
    func transmit(_ datagrams: [UltraGridCompatibilityDatagram], localHost: String, peer: String) throws -> Int
}

public struct UltraGridMediaReceiveRequest: Sendable {
    public var expectedDatagrams: Int
    public var localHost: String
    public var peer: String
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var payloadRegistry: UltraGridRTPPayloadRegistry
    public var encryptionConfiguration: UltraGridEncryptionConfiguration?
    public var timeoutSeconds: Int

    public init(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        timeoutSeconds: Int
    ) {
        self.expectedDatagrams = expectedDatagrams
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.payloadRegistry = payloadRegistry
        self.encryptionConfiguration = encryptionConfiguration
        self.timeoutSeconds = timeoutSeconds
    }
}

public protocol UltraGridCompatibilityMediaReceiving {
    func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram]
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

    public func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        Array(datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == request.peer || request.peer == "0.0.0.0")
                && ($0.destinationPort == request.audioPort || $0.destinationPort == request.videoPort)
        }.prefix(request.expectedDatagrams))
    }
}

public struct UltraGridSocketMediaTransmitter: UltraGridCompatibilityMediaTransmitting {
    public init() {}

    public func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost _: String,
        peer: String
    ) throws -> Int {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { closeUdpSocket(socket) }
        for datagram in datagrams {
            try sendDatagram(
                try datagram.rtp.encoded(),
                socket: socket,
                host: peer,
                port: datagram.destinationPort.bigEndian
            )
        }
        return datagrams.count
    }
}

private struct UltraGridSocketReceiveAvailableRequest {
    var socket: Int32
    var port: UInt16
    var stream: LoLaCompatibilityMediaStream
    var peer: String
    var payloadRegistry: UltraGridRTPPayloadRegistry
    var encryptionConfiguration: UltraGridEncryptionConfiguration?
}

public struct UltraGridSocketMediaReceiver: UltraGridCompatibilityMediaReceiving {
    public init() {}

    public func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        let audioSocket = try makeUdpSocket(receiveTimeoutSeconds: request.timeoutSeconds)
        let videoSocket = try makeUdpSocket(receiveTimeoutSeconds: request.timeoutSeconds)
        defer {
            closeUdpSocket(audioSocket)
            closeUdpSocket(videoSocket)
        }
        try bindIPv4(audioSocket, host: request.localHost, port: request.audioPort.bigEndian)
        try bindIPv4(videoSocket, host: request.localHost, port: request.videoPort.bigEndian)
        try setNonBlocking(audioSocket)
        try setNonBlocking(videoSocket)

        var received: [UltraGridCompatibilityDatagram] = []
        let deadline = Date().addingTimeInterval(TimeInterval(max(1, request.timeoutSeconds)))
        var audioBuffer: [UInt8] = []
        var videoBuffer: [UInt8] = []
        while received.count < request.expectedDatagrams, Date() < deadline {
            try receiveAvailable(
                UltraGridSocketReceiveAvailableRequest(
                    socket: audioSocket,
                    port: request.audioPort,
                    stream: .audio,
                    peer: request.peer,
                    payloadRegistry: request.payloadRegistry,
                    encryptionConfiguration: request.encryptionConfiguration
                ),
                into: &received,
                buffer: &audioBuffer
            )
            try receiveAvailable(
                UltraGridSocketReceiveAvailableRequest(
                    socket: videoSocket,
                    port: request.videoPort,
                    stream: .video,
                    peer: request.peer,
                    payloadRegistry: request.payloadRegistry,
                    encryptionConfiguration: request.encryptionConfiguration
                ),
                into: &received,
                buffer: &videoBuffer
            )
            if received.count < request.expectedDatagrams {
                usleep(1_000)
            }
        }
        return received
    }

    private func receiveAvailable(
        _ request: UltraGridSocketReceiveAvailableRequest,
        into received: inout [UltraGridCompatibilityDatagram],
        buffer: inout [UInt8]
    ) throws {
        while let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: request.socket,
            byteCount: 65_535,
            buffer: &buffer
        ) {
            guard request.peer == "0.0.0.0" || datagram.host == request.peer else {
                continue
            }
            let rtp = try RTPPacket.decode(datagram.data)
            _ = try UltraGridCompatibility.decode(
                rtp,
                registry: request.payloadRegistry,
                encryptionConfiguration: request.encryptionConfiguration
            )
            received.append(UltraGridCompatibilityDatagram(
                stream: request.stream,
                sourceHost: datagram.host,
                sourcePort: datagram.port,
                destinationPort: request.port,
                rtp: rtp
            ))
        }
    }
}
