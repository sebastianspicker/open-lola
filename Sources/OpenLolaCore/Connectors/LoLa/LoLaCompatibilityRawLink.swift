import Darwin
import Foundation

public protocol LoLaRawLinkTransmitter {
    func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int]
}

public protocol LoLaRawLinkReceiver {
    func receive(maxFrames: Int) throws -> [Data]
}

public final class LoLaMemoryRawLinkTransmitter: LoLaRawLinkTransmitter {
    public private(set) var transmittedFrames: [Data] = []

    public init() {}

    public func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        transmittedFrames.append(contentsOf: frames.map(\.encodedFrame))
        return frames.map(\.wireByteCount)
    }
}

public struct LoLaMemoryRawLinkReceiver: LoLaRawLinkReceiver {
    public var frames: [Data]

    public init(frames: [Data]) {
        self.frames = frames
    }

    public func receive(maxFrames: Int) throws -> [Data] {
        Array(frames.prefix(maxFrames))
    }
}

public struct LoLaBpfRawLinkTransmitter: LoLaRawLinkTransmitter {
    public var interfaceName: String

    public init(interfaceName: String) {
        self.interfaceName = interfaceName
    }

    public func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        let descriptor = try openBpfDescriptor()
        defer { close(descriptor) }
        try configureBpfDescriptor(descriptor, interfaceName: interfaceName)
        return try frames.map { frame in
            try frame.encodedFrame.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    throw ExternalConnectorSessionError.socketFailed("empty raw-link frame")
                }
                let written = write(descriptor, baseAddress, rawBuffer.count)
                guard written == rawBuffer.count else {
                    throw ExternalConnectorSessionError.socketFailed("bpf write \(interfaceName)")
                }
                return written
            }
        }
    }
}

public struct LoLaBpfRawLinkReceiver: LoLaRawLinkReceiver {
    public var interfaceName: String
    public var timeoutSeconds: Int

    public init(interfaceName: String, timeoutSeconds: Int = 1) {
        self.interfaceName = interfaceName
        self.timeoutSeconds = timeoutSeconds
    }

    public func receive(maxFrames: Int) throws -> [Data] {
        let descriptor = try openBpfDescriptor()
        defer { close(descriptor) }
        try configureBpfDescriptor(descriptor, interfaceName: interfaceName)
        try configureNonBlockingRawLinkDescriptor(descriptor)
        var received: [Data] = []
        var buffer = [UInt8](repeating: 0, count: try bpfBufferLength(descriptor))
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, timeoutSeconds)))
        while received.count < maxFrames, deadline.hasTimeRemaining {
            let byteCount = read(descriptor, &buffer, buffer.count)
            if byteCount < 0 {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    Thread.sleep(forTimeInterval: 0.01)
                    continue
                }
                throw ExternalConnectorSessionError.socketFailed("bpf read errno \(errno)")
            }
            guard byteCount > 0 else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }
            received.append(contentsOf: try extractBpfPackets(Array(buffer.prefix(byteCount))))
        }
        guard received.count >= maxFrames else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        return Array(received.prefix(maxFrames))
    }
}

public struct LoLaRawLinkTransmitRunConfiguration: Equatable, Sendable {
    public var interfaceName: String
    public var sourceIP: String
    public var destinationIP: String
    public var sourceMAC: LoLaEthernetAddress
    public var destinationMAC: LoLaEthernetAddress
    public var outputPath: String
    public var dryRun: Bool
    public var packetCount: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoBitsPerPixel: Int

    public init(
        interfaceName: String,
        sourceIP: String,
        destinationIP: String,
        sourceMAC: LoLaEthernetAddress,
        destinationMAC: LoLaEthernetAddress,
        outputPath: String,
        dryRun: Bool = true,
        packetCount: Int = 1,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        channels: Int = 2,
        sampleRateHertz: Int = 44_100,
        framesPerPacket: Int = 64,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoBitsPerPixel: Int = 24
    ) {
        self.interfaceName = interfaceName
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sourceMAC = sourceMAC
        self.destinationMAC = destinationMAC
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.packetCount = packetCount
        self.mediaMode = mediaMode
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoBitsPerPixel = videoBitsPerPixel
    }

    public static func parse(_ arguments: [String]) throws -> LoLaRawLinkTransmitRunConfiguration {
        let values = try parseLoLaRawLinkArguments(arguments)
        return try LoLaRawLinkTransmitRunConfiguration(
            interfaceName: requiredExternalConnectorValue("--interface", values),
            sourceIP: requiredExternalConnectorValue("--source-ip", values),
            destinationIP: requiredExternalConnectorValue("--peer", values),
            sourceMAC: parseLoLaEthernetAddress(requiredExternalConnectorValue("--source-mac", values)),
            destinationMAC: parseLoLaEthernetAddress(requiredExternalConnectorValue("--destination-mac", values)),
            outputPath: requiredExternalConnectorValue("--output", values),
            dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
            packetCount: optionalExternalConnectorPositiveInteger("--packets", values) ?? 1,
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            channels: optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalExternalConnectorPositiveInteger("--sample-rate", values) ?? 44_100,
            framesPerPacket: optionalExternalConnectorPositiveInteger("--frames", values) ?? 64,
            videoWidth: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            videoHeight: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            videoBitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24
        )
    }
}

public struct LoLaRawLinkReceiveRunConfiguration: Equatable, Sendable {
    public var interfaceName: String
    public var localIP: String
    public var peerIP: String
    public var outputPath: String
    public var dryRun: Bool
    public var maxFrames: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var timeoutSeconds: Int

    public init(
        interfaceName: String,
        localIP: String,
        peerIP: String,
        outputPath: String,
        dryRun: Bool = true,
        maxFrames: Int = 3,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        timeoutSeconds: Int = 1
    ) {
        self.interfaceName = interfaceName
        self.localIP = localIP
        self.peerIP = peerIP
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.maxFrames = maxFrames
        self.mediaMode = mediaMode
        self.timeoutSeconds = timeoutSeconds
    }

    public static func parse(_ arguments: [String]) throws -> LoLaRawLinkReceiveRunConfiguration {
        let values = try parseLoLaRawLinkArguments(arguments)
        return try LoLaRawLinkReceiveRunConfiguration(
            interfaceName: requiredExternalConnectorValue("--interface", values),
            localIP: requiredExternalConnectorValue("--local-ip", values),
            peerIP: values["--peer"] ?? "0.0.0.0",
            outputPath: requiredExternalConnectorValue("--output", values),
            dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
            maxFrames: optionalExternalConnectorPositiveInteger("--frames", values) ?? 3,
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            timeoutSeconds: optionalExternalConnectorPositiveInteger("--timeout-seconds", values) ?? 1
        )
    }
}

public enum LoLaRawLinkTransmitRunner {
    public static func run(
        configuration: LoLaRawLinkTransmitRunConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let transmitter: LoLaRawLinkTransmitter = configuration.dryRun
            ? LoLaMemoryRawLinkTransmitter()
            : LoLaBpfRawLinkTransmitter(interfaceName: configuration.interfaceName)
        return try run(configuration: configuration, transmitter: transmitter)
    }

    public static func run(
        configuration: LoLaRawLinkTransmitRunConfiguration,
        transmitter: LoLaRawLinkTransmitter
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let session = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: configuration.destinationIP,
            localHost: configuration.sourceIP,
            outputPath: configuration.outputPath,
            dryRun: configuration.dryRun,
            mediaMode: configuration.mediaMode,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel
        )
        let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
            configuration: session,
            frameCountPerStream: configuration.packetCount,
            sourceMAC: configuration.sourceMAC,
            destinationMAC: configuration.destinationMAC
        )
        let writtenByteCounts = try transmitter.transmit(frames)
        return makeLoLaMediaSessionReport(
            id: "lola-raw-link-tx-\(configuration.interfaceName)",
            role: .tx,
            mediaMode: configuration.mediaMode,
            frames: frames,
            realLinkTransmitted: !configuration.dryRun,
            notes: "Raw-link TX wrote \(writtenByteCounts.reduce(0, +)) bytes through \(configuration.dryRun ? "memory sink" : "macOS BPF") on \(configuration.interfaceName). PASS still requires a measured peer capture and decoded LoLa media payload grammar."
        )
    }
}

public enum LoLaRawLinkReceiveRunner {
    public static func run(
        configuration: LoLaRawLinkReceiveRunConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let receiver: LoLaRawLinkReceiver
        if configuration.dryRun {
            receiver = LoLaMemoryRawLinkReceiver(frames: try syntheticReceiveFrames(configuration))
        } else {
            receiver = LoLaBpfRawLinkReceiver(
                interfaceName: configuration.interfaceName,
                timeoutSeconds: configuration.timeoutSeconds
            )
        }
        return try run(configuration: configuration, receiver: receiver)
    }

    public static func run(
        configuration: LoLaRawLinkReceiveRunConfiguration,
        receiver: LoLaRawLinkReceiver
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let session = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .rx,
            peer: configuration.peerIP,
            localHost: configuration.localIP,
            outputPath: configuration.outputPath,
            dryRun: configuration.dryRun,
            mediaMode: configuration.mediaMode
        )
        let frames: [Data]
        do {
            frames = try receiver.receive(maxFrames: configuration.maxFrames)
        } catch ExternalConnectorSessionError.receiveTimedOut {
            return timeoutReport(configuration)
        }
        var report = try LoLaCompatibilityMediaSession.receiveReport(
            configuration: session,
            encodedFrames: frames
        )
        report.id = "lola-raw-link-rx-\(configuration.interfaceName)"
        report.realLinkTransmitted = !configuration.dryRun
        report.notes = "Raw-link RX decoded \(frames.count) Ethernet frames from \(configuration.dryRun ? "memory source" : "macOS BPF") on \(configuration.interfaceName) with timeout \(configuration.timeoutSeconds)s. PASS still requires a measured peer capture and decoded LoLa media payload grammar."
        return report
    }

    private static func timeoutReport(
        _ configuration: LoLaRawLinkReceiveRunConfiguration
    ) -> LoLaCompatibilityMediaSessionReport {
        makeLoLaMediaSessionReport(
            id: "lola-raw-link-rx-timeout-\(configuration.interfaceName)",
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: !configuration.dryRun,
            verdict: .fail,
            runtimeError: String(describing: ExternalConnectorSessionError.receiveTimedOut),
            localHost: configuration.localIP,
            peer: configuration.peerIP,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxFrames,
            notes: "LoLa raw-link RX received no decodable Ethernet media frames before timeout \(configuration.timeoutSeconds)s. Expected \(configuration.maxFrames) frame(s) from peer \(configuration.peerIP) on \(configuration.interfaceName)."
        )
    }

    private static func syntheticReceiveFrames(
        _ configuration: LoLaRawLinkReceiveRunConfiguration
    ) throws -> [Data] {
        let session = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: configuration.localIP,
            localHost: configuration.peerIP == "0.0.0.0" ? "192.0.2.20" : configuration.peerIP,
            outputPath: configuration.outputPath,
            mediaMode: configuration.mediaMode
        )
        return try LoLaCompatibilityMediaSession.buildTransmitFrames(
            configuration: session,
            frameCountPerStream: max(1, configuration.maxFrames)
        ).map(\.encodedFrame)
    }
}

public func parseLoLaEthernetAddress(_ value: String) throws -> LoLaEthernetAddress {
    let parts = value.split(separator: ":")
    guard parts.count == LoLaEthernetAddress.byteCount else {
        throw ExternalConnectorSessionError.socketFailed("invalid MAC \(value)")
    }
    let octets = try parts.map { part -> UInt8 in
        guard part.count == 2, let octet = UInt8(part, radix: 16) else {
            throw ExternalConnectorSessionError.socketFailed("invalid MAC \(value)")
        }
        return octet
    }
    return try LoLaEthernetAddress(octets: octets)
}

private let bpfIoctlSetInterface: UInt = 0x8020_426c
private let bpfIoctlGetBufferLength: UInt = 0x4004_4266
private let bpfIoctlSetHeaderComplete: UInt = 0x8004_4275
private let bpfIoctlImmediate: UInt = 0x8004_4270
private let bpfHeaderMinimumByteCount = 26
private let bpfHeaderCapturedLengthOffset = 16
private let bpfHeaderLengthOffset = 24

private func openBpfDescriptor() throws -> Int32 {
    for index in 0..<256 {
        let descriptor = open("/dev/bpf\(index)", O_RDWR)
        if descriptor >= 0 {
            return descriptor
        }
        if errno != EBUSY {
            break
        }
    }
    throw ExternalConnectorSessionError.socketFailed("open /dev/bpf*")
}

private func bpfBufferLength(_ descriptor: Int32) throws -> Int {
    var bufferLength: UInt32 = 0
    guard ioctl(descriptor, bpfIoctlGetBufferLength, &bufferLength) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCGBLEN errno \(errno)")
    }
    guard bufferLength > 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCGBLEN returned empty buffer")
    }
    return Int(bufferLength)
}

private func configureBpfDescriptor(_ descriptor: Int32, interfaceName: String) throws {
    var request = ifreq()
    try withInterfaceName(interfaceName) { name in
        request.ifr_name = name
    }
    guard ioctl(descriptor, bpfIoctlSetInterface, &request) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCSETIF \(interfaceName) errno \(errno)")
    }
    var enabled: UInt32 = 1
    guard ioctl(descriptor, bpfIoctlSetHeaderComplete, &enabled) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCSHDRCMPLT errno \(errno)")
    }
    guard ioctl(descriptor, bpfIoctlImmediate, &enabled) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCIMMEDIATE errno \(errno)")
    }
}

private func configureNonBlockingRawLinkDescriptor(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFL, 0)
    guard flags >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("bpf fcntl get errno \(errno)")
    }
    guard fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("bpf fcntl nonblock errno \(errno)")
    }
}

func extractBpfPackets(_ bytes: [UInt8]) throws -> [Data] {
    var packets: [Data] = []
    var offset = 0
    // Uses the classic net/bpf.h bpf_hdr layout; bpf_xhdr is not supported here.
    while offset + bpfHeaderMinimumByteCount <= bytes.count {
        let capturedLength = Int(readLoLaRawLinkUInt32Native(
            bytes,
            offset: offset + bpfHeaderCapturedLengthOffset
        ))
        let headerLength = Int(readLoLaRawLinkUInt16Native(
            bytes,
            offset: offset + bpfHeaderLengthOffset
        ))
        let recordStride = bpfWordAlign(max(1, headerLength + capturedLength))
        guard headerLength > 0, capturedLength >= LoLaCompatibilityMediaModel.wirePayloadOffset else {
            offset += recordStride
            continue
        }
        let packetOffset = offset + headerLength
        guard packetOffset + capturedLength <= bytes.count else {
            offset += recordStride
            continue
        }
        packets.append(Data(bytes[packetOffset..<packetOffset + capturedLength]))
        offset += recordStride
    }
    return packets
}

private func bpfWordAlign(_ value: Int) -> Int {
    let alignment = MemoryLayout<Int32>.size
    return (value + alignment - 1) & ~(alignment - 1)
}

private func readLoLaRawLinkUInt16Native(_ bytes: [UInt8], offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
}

private func readLoLaRawLinkUInt32Native(_ bytes: [UInt8], offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
}

private func withInterfaceName<T>(
    _ value: String,
    _ body: ((Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) throws -> T
) throws -> T {
    let bytes = Array(value.utf8)
    guard bytes.count < Int(IFNAMSIZ) else {
        throw ExternalConnectorSessionError.socketFailed("interface name too long \(value)")
    }
    var name = [Int8](repeating: 0, count: Int(IFNAMSIZ))
    for index in bytes.indices {
        name[index] = Int8(bitPattern: bytes[index])
    }
    return try body((
        name[0], name[1], name[2], name[3],
        name[4], name[5], name[6], name[7],
        name[8], name[9], name[10], name[11],
        name[12], name[13], name[14], name[15]
    ))
}

private func parseLoLaRawLinkArguments(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--interface", "--source-ip", "--local-ip", "--peer", "--source-mac", "--destination-mac",
        "--output", "--dry-run", "--packets", "--media", "--channels", "--sample-rate", "--frames",
        "--video-width", "--video-height", "--video-bpp",
        "--timeout-seconds",
    ])
    return try parseExternalConnectorKeyValueArguments(arguments, allowed: allowed)
}
