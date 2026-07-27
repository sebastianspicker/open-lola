// Sends and captures LoLa Ethernet frames through configurable raw-link transport boundaries.
import Darwin
import Foundation

/// Requires conformers to transmit, transmitGenerated, transmitGeneratedOutcome operations for LoLa raw link transmitter.
public protocol LoLaRawLinkTransmitter {
    func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int]
    func transmitGenerated(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> [Int]
    func transmitGeneratedOutcome(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> LoLaRawLinkTransmitOutcome
}

/// Defines the validated fields for LoLa raw link transmit outcome.
public struct LoLaRawLinkTransmitOutcome: Equatable, Sendable {
    public var writtenFrameCount: Int
    public var writtenBytesTotal: Int
    public var backpressureDroppedFrames: Int
    public var writtenByteCountEvidence: [Int]

    public init(
        writtenFrameCount: Int,
        writtenBytesTotal: Int,
        backpressureDroppedFrames: Int = 0,
        writtenByteCountEvidence: [Int]
    ) {
        self.writtenFrameCount = writtenFrameCount
        self.writtenBytesTotal = writtenBytesTotal
        self.backpressureDroppedFrames = backpressureDroppedFrames
        self.writtenByteCountEvidence = writtenByteCountEvidence
    }
}

let loLaRawLinkMaximumRetainedEvidenceFrames = 256

public extension LoLaRawLinkTransmitter {
    func transmitGenerated(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> [Int] {
        var frames: [LoLaCompatibilityMediaFrame] = []
        try generate { frames.append($0) }
        return try transmit(frames)
    }

    func transmitGeneratedOutcome(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> LoLaRawLinkTransmitOutcome {
        let byteCounts = try transmitGenerated(generate)
        return LoLaRawLinkTransmitOutcome(
            writtenFrameCount: byteCounts.count,
            writtenBytesTotal: byteCounts.reduce(0, +),
            writtenByteCountEvidence: Array(
                byteCounts.prefix(loLaRawLinkMaximumRetainedEvidenceFrames)
            )
        )
    }
}

/// Requires conformers to receive, transmit, transmitGenerated operations for LoLa raw link receiver.
public protocol LoLaRawLinkReceiver {
    func receive(maxFrames: Int) throws -> [Data]
}

/// Retains emitted datagrams in memory so callers can inspect LoLa memory raw link transmitter.
public final class LoLaMemoryRawLinkTransmitter: LoLaRawLinkTransmitter {
    public private(set) var transmittedFrames: [Data] = []

    public init() {}

    public func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        transmittedFrames.append(contentsOf: frames.prefix(
            max(0, loLaRawLinkMaximumRetainedEvidenceFrames - transmittedFrames.count)
        ).map(\.encodedFrame))
        return frames.map(\.wireByteCount)
    }

    public func transmitGenerated(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> [Int] {
        try transmitGeneratedOutcome(generate).writtenByteCountEvidence
    }

    public func transmitGeneratedOutcome(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> LoLaRawLinkTransmitOutcome {
        var writtenFrameCount = 0
        var writtenBytesTotal = 0
        var evidence: [Int] = []
        try generate { frame in
            writtenFrameCount += 1
            writtenBytesTotal += frame.wireByteCount
            if transmittedFrames.count < loLaRawLinkMaximumRetainedEvidenceFrames {
                transmittedFrames.append(frame.encodedFrame)
            }
            if evidence.count < loLaRawLinkMaximumRetainedEvidenceFrames {
                evidence.append(frame.wireByteCount)
            }
        }
        return LoLaRawLinkTransmitOutcome(
            writtenFrameCount: writtenFrameCount,
            writtenBytesTotal: writtenBytesTotal,
            writtenByteCountEvidence: evidence
        )
    }
}

/// Returns preloaded datagrams that match the requested route for LoLa memory raw link receiver.
public struct LoLaMemoryRawLinkReceiver: LoLaRawLinkReceiver {
    public var frames: [Data]

    public init(frames: [Data]) {
        self.frames = frames
    }

    public func receive(maxFrames: Int) throws -> [Data] {
        Array(frames.prefix(maxFrames))
    }
}

/// Defines the validated fields for LoLa raw link transmit run configuration.
public struct LoLaRawLinkTransmitRunConfiguration: Equatable, Sendable {
    public struct Link: Equatable, Sendable {
        public var interfaceName: String
        public var sourceIP: String
        public var destinationIP: String
        public var sourceMAC: LoLaEthernetAddress
        public var destinationMAC: LoLaEthernetAddress

        public init(
            interfaceName: String,
            sourceIP: String,
            destinationIP: String,
            sourceMAC: LoLaEthernetAddress,
            destinationMAC: LoLaEthernetAddress
        ) {
            self.interfaceName = interfaceName
            self.sourceIP = sourceIP
            self.destinationIP = destinationIP
            self.sourceMAC = sourceMAC
            self.destinationMAC = destinationMAC
        }
    }

    public struct Execution: Equatable, Sendable {
        public var outputPath: String
        public var dryRun: Bool
        public var packetCount: Int

        public init(outputPath: String, dryRun: Bool = true, packetCount: Int = 1) {
            self.outputPath = outputPath
            self.dryRun = dryRun
            self.packetCount = packetCount
        }
    }

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
        link: Link,
        execution: Execution,
        media: LoLaMediaFormat = .init()
    ) {
        interfaceName = link.interfaceName
        sourceIP = link.sourceIP
        destinationIP = link.destinationIP
        sourceMAC = link.sourceMAC
        destinationMAC = link.destinationMAC
        outputPath = execution.outputPath
        dryRun = execution.dryRun
        packetCount = execution.packetCount
        let values = LoLaMediaConfigurationValues(media)
        mediaMode = values.mode
        channels = values.channels
        sampleRateHertz = values.sampleRateHertz
        framesPerPacket = values.framesPerPacket
        videoWidth = values.videoWidth
        videoHeight = values.videoHeight
        videoBitsPerPixel = values.videoBitsPerPixel
    }

    public static func parse(_ arguments: [String]) throws -> LoLaRawLinkTransmitRunConfiguration {
        let values = try parseLoLaRawLinkArguments(arguments)
        return LoLaRawLinkTransmitRunConfiguration(
            link: try loLaRawLinkTransmitLink(values),
            execution: try loLaRawLinkTransmitExecution(values),
            media: try loLaRawLinkTransmitMedia(values)
        )
    }
}

private func loLaRawLinkTransmitLink(
    _ values: [String: String]
) throws -> LoLaRawLinkTransmitRunConfiguration.Link {
    try .init(
        interfaceName: requiredExternalConnectorValue("--interface", values),
        sourceIP: requiredExternalConnectorValue("--source-ip", values),
        destinationIP: requiredExternalConnectorValue("--peer", values),
        sourceMAC: parseLoLaEthernetAddress(requiredExternalConnectorValue("--source-mac", values)),
        destinationMAC: parseLoLaEthernetAddress(requiredExternalConnectorValue("--destination-mac", values))
    )
}

private func loLaRawLinkTransmitExecution(
    _ values: [String: String]
) throws -> LoLaRawLinkTransmitRunConfiguration.Execution {
    try .init(
        outputPath: requiredExternalConnectorValue("--output", values),
        dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
        packetCount: optionalExternalConnectorPositiveInteger("--packets", values) ?? 1
    )
}

private func loLaRawLinkTransmitMedia(_ values: [String: String]) throws -> LoLaMediaFormat {
    try loLaMediaFormat(from: values)
}

/// Defines the validated fields for LoLa raw link receive run configuration.
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

/// Validates a raw-link transmit configuration, emits Ethernet frames, and writes the outcome report.
public enum LoLaRawLinkTransmitRunner {
    public static func run(
        configuration: LoLaRawLinkTransmitRunConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let transmitter: LoLaRawLinkTransmitter = configuration.dryRun
            ? LoLaMemoryRawLinkTransmitter()
            : LoLaBpfRawLinkTransmitter(
                interfaceName: configuration.interfaceName,
                sequenceIntervalNanoseconds: loLaRawLinkSequenceIntervalNanoseconds(configuration)
            )
        return try run(configuration: configuration, transmitter: transmitter)
    }

    public static func run(
        configuration: LoLaRawLinkTransmitRunConfiguration,
        transmitter: LoLaRawLinkTransmitter
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let session = makeLoLaRawLinkTransmitSession(configuration)
        let profile = try ExternalConnectorMediaProfile.build(configuration: session)
        var frames: [LoLaCompatibilityMediaFrame] = []
        var generatedFrameCount = 0
        let outcome = try transmitter.transmitGeneratedOutcome { emit in
            for sequence in 0..<configuration.packetCount {
                let sequenceFrames = try LoLaCompatibilityMediaSession.buildTransmitFramesForSequence(
                    configuration: session,
                    sequence: sequence,
                    profile: profile,
                    sourceMAC: configuration.sourceMAC,
                    destinationMAC: configuration.destinationMAC
                )
                for frame in sequenceFrames {
                    generatedFrameCount += 1
                    if frames.count < loLaRawLinkMaximumRetainedEvidenceFrames {
                        frames.append(frame)
                    }
                    try emit(frame)
                }
            }
        }
        let writtenBytesTotal = outcome.writtenBytesTotal
        let zeroBytesError = !configuration.dryRun && writtenBytesTotal == 0
            ? "LoLa raw-link TX wrote zero bytes"
            : nil
        return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-raw-link-tx-\(configuration.interfaceName)",
            role: .tx,
            mediaMode: configuration.mediaMode,
            frames: frames,
            realLinkTransmitted: !configuration.dryRun && writtenBytesTotal > 0,
            verdict: zeroBytesError == nil ? .partial : .fail,
            runtimeError: zeroBytesError,
            expectedDatagramCount: generatedFrameCount,
            sentBytesTotal: writtenBytesTotal,
            notes: "Raw-link TX wrote \(writtenBytesTotal) bytes through "
                + "\(configuration.dryRun ? "memory sink" : "macOS BPF") on \(configuration.interfaceName). "
                + "Generated \(generatedFrameCount) frame(s), the sink accepted \(outcome.writtenFrameCount), "
                + "dropped \(outcome.backpressureDroppedFrames) whole frame(s) on backpressure, and retained "
                + "\(frames.count) frame(s) as bounded report evidence. "
                + "PASS still requires a measured peer capture and decoded LoLa media payload grammar."
        ))
    }
}

private func makeLoLaRawLinkTransmitSession(
    _ configuration: LoLaRawLinkTransmitRunConfiguration
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: configuration.destinationIP,
        outputPath: configuration.outputPath
    ) { input in
        input.localHost = configuration.sourceIP
        input.dryRun = configuration.dryRun
        applyLoLaMediaFields(to: &input, from: configuration)
    })
}

private func loLaRawLinkSequenceIntervalNanoseconds(
    _ configuration: LoLaRawLinkTransmitRunConfiguration
) -> UInt64 {
    if configuration.mediaMode.hasAudio {
        return max(1, UInt64(
            Double(configuration.framesPerPacket) / Double(configuration.sampleRateHertz) * 1_000_000_000
        ))
    }
    return 1_000_000_000 / 30
}

/// Captures LoLa Ethernet frames from a raw link and writes the validated receive report.
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
        let session = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: configuration.peerIP,
  outputPath: configuration.outputPath
) { input in
  input.localHost = configuration.localIP
  input.dryRun = configuration.dryRun
  input.mediaMode = configuration.mediaMode
})
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
        report.realLinkTransmitted = !configuration.dryRun && !frames.isEmpty
        report.notes = "Raw-link RX decoded \(frames.count) Ethernet frames from "
            + "\(configuration.dryRun ? "memory source" : "macOS BPF") on \(configuration.interfaceName) "
            + "with timeout \(configuration.timeoutSeconds)s. "
            + "PASS still requires a measured peer capture and decoded LoLa media payload grammar."
        return report
    }

    private static func timeoutReport(
        _ configuration: LoLaRawLinkReceiveRunConfiguration
    ) -> LoLaCompatibilityMediaSessionReport {
        makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-raw-link-rx-timeout-\(configuration.interfaceName)",
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: false,
            verdict: .fail,
            runtimeError: String(describing: ExternalConnectorSessionError.receiveTimedOut),
            localHost: configuration.localIP,
            peer: configuration.peerIP,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxFrames,
            notes: "LoLa raw-link RX received no decodable Ethernet media frames before timeout "
                + "\(configuration.timeoutSeconds)s. Expected \(configuration.maxFrames) frame(s) "
                + "from peer \(configuration.peerIP) on \(configuration.interfaceName)."
        ))
    }

    private static func syntheticReceiveFrames(
        _ configuration: LoLaRawLinkReceiveRunConfiguration
    ) throws -> [Data] {
        let session = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: configuration.localIP,
  outputPath: configuration.outputPath
) { input in
  input.localHost = configuration.peerIP == "0.0.0.0" ? "192.0.2.20" : configuration.peerIP
  input.mediaMode = configuration.mediaMode
})
        return try LoLaCompatibilityMediaSession.buildTransmitFrames(
            configuration: session,
            frameCountPerStream: max(1, configuration.maxFrames)
        ).map(\.encodedFrame)
    }
}

/// Executes parse LoLa ethernet address while enforcing the module's validation rules.
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

extension LoLaRawLinkTransmitRunConfiguration: LoLaMediaFieldSource {}
