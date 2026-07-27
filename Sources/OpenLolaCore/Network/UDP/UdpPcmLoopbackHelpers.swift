// Builds sender, looper, and diagnostic report sections from loopback observations so redaction and timing calculations stay consistent.
import Foundation

func makeDiagnosticsComparison(
    configuration: UdpPcmLoopbackRunConfiguration,
    udpAverageRttMicroseconds: Double
) -> UdpPcmLoopbackDiagnosticsComparison? {
    guard configuration.diagnostics == .on else {
        return nil
    }
    let diagnostics = NetworkDiagnosticsRunner.run(
        configuration: NetworkDiagnosticsRunConfiguration(
            peer: configuration.peer,
            pingCount: 2,
            maxHops: 8,
            outputPath: "stdout"
        )
    )
    guard let ping = diagnostics.ping else {
        return nil
    }
    return UdpPcmLoopbackDiagnosticsComparison.compare(
        udpAverageRttMicroseconds: udpAverageRttMicroseconds,
        ping: ping
    )
}

func makeSenderReport(
    configuration: UdpPcmLoopbackRunConfiguration,
    metrics: UdpPcmLoopbackMetrics,
    diagnostics: UdpPcmLoopbackDiagnosticsComparison?,
    notes: String
) -> UdpPcmLoopbackReport {
    UdpPcmLoopbackReport(
        identity: .init(
            id: udpPcmLoopbackReportID(role: .sender),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            route: RouteIdentity(label: "udp-pcm-loopback", topology: "byte-exact-echo")
        ),
        session: configuration.agreement,
        observation: .init(
            role: .sender,
            peer: configuration.peer,
            packetMode: configuration.packetMode,
            metrics: metrics,
            diagnostics: diagnostics
        ),
        outcome: .init(verdict: .partial, notes: notes)
    )
}

func makeLooperReport(
    configuration: UdpPcmLoopbackRunConfiguration,
    metrics: UdpPcmLoopbackMetrics,
    notes: String
) -> UdpPcmLoopbackReport {
    UdpPcmLoopbackReport(
        identity: .init(
            id: udpPcmLoopbackReportID(role: .looper),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            route: RouteIdentity(label: "udp-pcm-loopback", topology: "byte-exact-echo")
        ),
        session: configuration.agreement,
        observation: .init(
            role: .looper,
            peer: configuration.peer,
            packetMode: configuration.packetMode,
            metrics: metrics,
            diagnostics: nil
        ),
        outcome: .init(verdict: .partial, notes: notes)
    )
}

private func udpPcmLoopbackReportID(role: UdpPcmLoopbackRole) -> String {
    "udp-pcm-loopback-\(role.rawValue)-\(UUID().uuidString)"
}

func redactedConfigurationFields(
    _ configuration: UdpPcmLoopbackRunConfiguration
) -> [String: String] {
    [
        "sessionID": configuration.sessionID,
        "role": configuration.role.rawValue,
        "bindHost": configuration.bindHost,
        "peer": configuration.peer,
        "port": "\(configuration.port)",
        "sampleRateHertz": "\(configuration.packetMode.sampleRateHertz)",
        "framesPerPacket": "\(configuration.packetMode.framesPerPacket)",
        "channelCount": "\(configuration.packetMode.channelCount)",
        "sampleFormat": "\(configuration.packetMode.sampleFormat.rawValue)",
        "durationSeconds": "\(configuration.durationSeconds)",
        "dscp": configuration.dscp.map(String.init) ?? "none",
        "diagnostics": configuration.diagnostics.rawValue,
        "outputPath": "<redacted>",
        "debugOutputPath": configuration.debugOutputPath == nil ? "none" : "<redacted>"
    ]
}

func expectedByteCount(_ packetMode: UdpPcmPacketMode) -> Int {
    UdpPcmPacketHeader.byteCount
        + packetMode.framesPerPacket
        * packetMode.channelCount
        * packetMode.sampleFormat.bytesPerSample
}

func loopbackTimingMetrics(for values: [Double]) -> LoopbackTimingMetrics {
    LoopbackTimingMetrics(
        p50Microseconds: percentile(values, rank: 0.50),
        p95Microseconds: percentile(values, rank: 0.95),
        p99Microseconds: percentile(values, rank: 0.99),
        maxMicroseconds: values.max() ?? 0
    )
}

func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else {
        return 0
    }
    return values.reduce(0, +) / Double(values.count)
}

func parseLoopbackArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
        arguments,
        allowed: allowed,
        unknown: UdpPcmLoopbackRunConfigurationError.unknownArgument,
        duplicate: UdpPcmLoopbackRunConfigurationError.duplicateArgument,
        missingValue: UdpPcmLoopbackRunConfigurationError.missingValue
    )
}

func requiredLoopbackString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw UdpPcmLoopbackRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredLoopbackPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredLoopbackString(argument, values)
    guard let integer = Int(value) else {
        throw UdpPcmLoopbackRunConfigurationError.invalidInteger(
            argument: argument,
            value: value
        )
    }
    guard integer > 0 else {
        throw UdpPcmLoopbackRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalLoopbackInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    guard let value = values[argument] else {
        return nil
    }
    guard let integer = Int(value) else {
        throw UdpPcmLoopbackRunConfigurationError.invalidInteger(
            argument: argument,
            value: value
        )
    }
    return integer
}

func requiredLoopbackPort(_ values: [String: String]) throws -> UInt16 {
    let port = try requiredLoopbackPositiveInteger("--port", values)
    guard port <= Int(UInt16.max) else {
        throw UdpPcmLoopbackRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

func requireLoopbackNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw UdpPcmLoopbackValidationError.emptyField(field)
    }
}

func requireLoopbackPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw UdpPcmLoopbackValidationError.nonPositiveField(field)
    }
}

func requireLoopbackNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw UdpPcmLoopbackValidationError.negativeField(field)
    }
}

func requireLoopbackNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw UdpPcmLoopbackValidationError.negativeField(field)
    }
}

func shellArgument(_ value: String) -> String {
    let safeCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=@"
    )
    if value.rangeOfCharacter(from: safeCharacters.inverted) == nil {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
