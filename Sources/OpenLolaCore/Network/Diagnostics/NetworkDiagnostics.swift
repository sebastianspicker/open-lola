import Dispatch
import Foundation

public struct NetworkPingResult: Codable, Equatable, Sendable {
    public var transmitted: Int
    public var received: Int
    public var packetLossPercent: Double
    public var minRttMilliseconds: Double
    public var averageRttMilliseconds: Double
    public var maxRttMilliseconds: Double
    public var standardDeviationMilliseconds: Double

    public init(
        transmitted: Int,
        received: Int,
        packetLossPercent: Double,
        minRttMilliseconds: Double,
        averageRttMilliseconds: Double,
        maxRttMilliseconds: Double,
        standardDeviationMilliseconds: Double
    ) {
        self.transmitted = transmitted
        self.received = received
        self.packetLossPercent = packetLossPercent
        self.minRttMilliseconds = minRttMilliseconds
        self.averageRttMilliseconds = averageRttMilliseconds
        self.maxRttMilliseconds = maxRttMilliseconds
        self.standardDeviationMilliseconds = standardDeviationMilliseconds
    }
}

public struct NetworkTracerouteHop: Codable, Equatable, Sendable {
    public var index: Int
    public var address: String
    public var timingsMilliseconds: [Double]

    public init(index: Int, address: String, timingsMilliseconds: [Double]) {
        self.index = index
        self.address = address
        self.timingsMilliseconds = timingsMilliseconds
    }
}

public struct NetworkTracerouteResult: Codable, Equatable, Sendable {
    public var hops: [NetworkTracerouteHop]
    public var blocked: Bool
    public var blockedReason: String?

    public init(
        hops: [NetworkTracerouteHop],
        blocked: Bool,
        blockedReason: String?
    ) {
        self.hops = hops
        self.blocked = blocked
        self.blockedReason = blockedReason
    }
}

public enum NetworkDiagnosticsValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case passWithoutPing
    case passWithPingLoss
    case passExceedsThreshold(field: String, actual: Double, maximum: Double)
    case passWithBlockedTraceroute
    case blockedTracerouteMissingReason
}

public enum NetworkDiagnosticsPassThresholds {
    public static let maximumAverageRttMilliseconds = 2.0
    public static let maximumRttMilliseconds = 5.0
    public static let maximumStandardDeviationMilliseconds = 1.0
}

public struct NetworkDiagnosticsReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var peer: String
    public var ping: NetworkPingResult?
    public var traceroute: NetworkTracerouteResult
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        peer: String,
        ping: NetworkPingResult?,
        traceroute: NetworkTracerouteResult,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.peer = peer
        self.ping = ping
        self.traceroute = traceroute
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> NetworkDiagnosticsReport {
        try JSONDecoder().decode(NetworkDiagnosticsReport.self, from: data)
    }

    public func validate() throws {
        try requireNetworkDiagnosticsNonEmpty(id, "id")
        try requireNetworkDiagnosticsNonEmpty(capturedAt, "capturedAt")
        try requireNetworkDiagnosticsNonEmpty(peer, "peer")
        try requireNetworkDiagnosticsNonEmpty(notes, "notes")
        if let ping {
            try requireNetworkDiagnosticsPositive(ping.transmitted, "ping.transmitted")
            try requireNetworkDiagnosticsNonNegative(ping.received, "ping.received")
            try requireNetworkDiagnosticsNonNegative(
                ping.packetLossPercent,
                "ping.packetLossPercent"
            )
            try requireNetworkDiagnosticsNonNegative(
                ping.minRttMilliseconds,
                "ping.minRttMilliseconds"
            )
            try requireNetworkDiagnosticsNonNegative(
                ping.averageRttMilliseconds,
                "ping.averageRttMilliseconds"
            )
            try requireNetworkDiagnosticsNonNegative(
                ping.maxRttMilliseconds,
                "ping.maxRttMilliseconds"
            )
            try requireNetworkDiagnosticsNonNegative(
                ping.standardDeviationMilliseconds,
                "ping.standardDeviationMilliseconds"
            )
        }
        for hop in traceroute.hops {
            try requireNetworkDiagnosticsPositive(hop.index, "traceroute.hops.index")
            try requireNetworkDiagnosticsNonEmpty(hop.address, "traceroute.hops.address")
            for timing in hop.timingsMilliseconds {
                try requireNetworkDiagnosticsNonNegative(timing, "traceroute.hops.timing")
            }
        }
        if traceroute.blocked, traceroute.blockedReason?.isEmpty != false {
            throw NetworkDiagnosticsValidationError.blockedTracerouteMissingReason
        }
        guard verdict == .pass else {
            return
        }
        guard let ping else {
            throw NetworkDiagnosticsValidationError.passWithoutPing
        }
        if ping.packetLossPercent > 0 || ping.received <= 0 {
            throw NetworkDiagnosticsValidationError.passWithPingLoss
        }
        try requireNetworkDiagnosticsPassThresholds(ping)
        if traceroute.blocked {
            throw NetworkDiagnosticsValidationError.passWithBlockedTraceroute
        }
    }
}

public enum NetworkDiagnosticsParseError: Error, Equatable, Sendable {
    case missingPingSummary
    case missingPingTiming
}

public enum NetworkDiagnosticsParser {
    public static func parsePing(_ output: String) throws -> NetworkPingResult {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard let summary = lines.first(where: { $0.contains("packets transmitted") }) else {
            throw NetworkDiagnosticsParseError.missingPingSummary
        }
        guard let timing = lines.first(where: { $0.contains("round-trip") && $0.contains("=") }) else {
            throw NetworkDiagnosticsParseError.missingPingTiming
        }

        let summaryParts = summary
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ")
        let transmitted = Int(summaryParts.first ?? "") ?? 0
        let receivedIndex = summaryParts.firstIndex(of: "received")
        let received = receivedIndex.flatMap { index in
            let valueIndex = summaryParts.index(index, offsetBy: -2, limitedBy: summaryParts.startIndex)
            return valueIndex.map { Int(summaryParts[$0]) } ?? nil
        } ?? 0
        let lossIndex = summaryParts.firstIndex(of: "packet")
        let packetLoss = lossIndex.flatMap { index in
            guard index > summaryParts.startIndex else { return nil }
            let valueIndex = summaryParts.index(before: index)
            return Double(summaryParts[valueIndex])
        } ?? 100

        let valueText = timing.components(separatedBy: "=").last ?? ""
        let values = valueText
            .replacingOccurrences(of: "ms", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count == 4 else {
            throw NetworkDiagnosticsParseError.missingPingTiming
        }

        return NetworkPingResult(
            transmitted: transmitted,
            received: received,
            packetLossPercent: packetLoss,
            minRttMilliseconds: values[0],
            averageRttMilliseconds: values[1],
            maxRttMilliseconds: values[2],
            standardDeviationMilliseconds: values[3]
        )
    }

    public static func parseTraceroute(_ output: String) throws -> NetworkTracerouteResult {
        let blocked = output.localizedCaseInsensitiveContains("operation not permitted")
            || output.localizedCaseInsensitiveContains("permission denied")
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let hops = lines.compactMap(parseTracerouteHop)
        return NetworkTracerouteResult(
            hops: hops,
            blocked: blocked,
            blockedReason: blocked ? blockedReason(from: output) : nil
        )
    }

    private static func parseTracerouteHop(_ line: String) -> NetworkTracerouteHop? {
        let fields = line.split(separator: " ").map(String.init)
        guard fields.count >= 2, let index = Int(fields[0]) else {
            return nil
        }
        let address = stripTracerouteAddressBrackets(fields[1])
        var timings: [Double] = []
        for fieldIndex in fields.indices where fields[fieldIndex] == "ms" {
            let valueIndex = fields.index(before: fieldIndex)
            if let value = Double(fields[valueIndex]) {
                timings.append(value)
            }
        }
        return NetworkTracerouteHop(
            index: index,
            address: address,
            timingsMilliseconds: timings
        )
    }

    private static func stripTracerouteAddressBrackets(_ address: String) -> String {
        guard address.first == "[", address.last == "]" else {
            return address
        }
        return String(address.dropFirst().dropLast())
    }

    private static func blockedReason(from output: String) -> String {
        output.split(whereSeparator: \.isNewline).first.map(String.init)
            ?? "traceroute blocked"
    }
}

public struct NetworkDiagnosticsRunConfiguration: Codable, Equatable, Sendable {
    public let peer: String
    public let pingCount: Int
    public let maxHops: Int
    public let outputPath: String

    public init(peer: String, pingCount: Int, maxHops: Int, outputPath: String) {
        self.peer = peer
        self.pingCount = pingCount
        self.maxHops = maxHops
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NetworkDiagnosticsRunConfiguration {
        let values = try parseNetworkDiagnosticsArguments(
            arguments,
            allowed: ["--peer", "--ping-count", "--max-hops", "--output"]
        )
        return NetworkDiagnosticsRunConfiguration(
            peer: try requiredNetworkDiagnosticsString("--peer", values),
            pingCount: try requiredNetworkDiagnosticsPositiveInteger("--ping-count", values),
            maxHops: try requiredNetworkDiagnosticsPositiveInteger("--max-hops", values),
            outputPath: try requiredNetworkDiagnosticsString("--output", values)
        )
    }
}

public enum NetworkDiagnosticsRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

public enum NetworkDiagnosticsRunner {
    public static func run(configuration: NetworkDiagnosticsRunConfiguration) -> NetworkDiagnosticsReport {
        let ping = parsePingResult(configuration: configuration)
        let traceroute = parseTracerouteResult(configuration: configuration)
        return NetworkDiagnosticsReport(
            id: "network-diagnostics-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            peer: configuration.peer,
            ping: ping,
            traceroute: traceroute,
            verdict: networkDiagnosticsVerdict(ping: ping, traceroute: traceroute),
            notes: "ICMP ping and traceroute are diagnostic comparisons only; they do not prove audio latency."
        )
    }

    private static func parsePingResult(
        configuration: NetworkDiagnosticsRunConfiguration
    ) -> NetworkPingResult? {
        let result = runNetworkDiagnosticsProcess(
            executable: "/sbin/ping",
            arguments: ["-c", "\(configuration.pingCount)", "-n", configuration.peer],
            timeoutSeconds: max(2, configuration.pingCount + 2)
        )
        guard result.exitCode == 0,
              let ping = try? NetworkDiagnosticsParser.parsePing(result.output) else {
            return nil
        }
        return ping
    }

    private static func parseTracerouteResult(
        configuration: NetworkDiagnosticsRunConfiguration
    ) -> NetworkTracerouteResult {
        let result = runNetworkDiagnosticsProcess(
            executable: "/usr/sbin/traceroute",
            arguments: ["-n", "-m", "\(configuration.maxHops)", configuration.peer],
            timeoutSeconds: max(2, configuration.maxHops + 2)
        )
        if result.spawnError != nil {
            return NetworkTracerouteResult(
                hops: [],
                blocked: true,
                blockedReason: result.spawnError
            )
        }
        let parsed = (try? NetworkDiagnosticsParser.parseTraceroute(result.output))
            ?? NetworkTracerouteResult(hops: [], blocked: false, blockedReason: nil)
        if result.timedOut {
            return NetworkTracerouteResult(
                hops: parsed.hops,
                blocked: true,
                blockedReason: "traceroute timed out"
            )
        }
        return parsed
    }
}

func networkDiagnosticsVerdict(
    ping: NetworkPingResult?,
    traceroute: NetworkTracerouteResult
) -> MeasurementVerdict {
    guard let ping,
          ping.received > 0,
          ping.packetLossPercent == 0,
          networkDiagnosticsPingMeetsPassThresholds(ping),
          !traceroute.blocked else {
        return .partial
    }
    return .pass
}

public enum NetworkDiagnosticsSyntheticSmoke {
    public static func run() -> NetworkDiagnosticsReport {
        NetworkDiagnosticsReport(
            id: "network-diagnostics-synthetic",
            capturedAt: "2026-05-03T00:00:00Z",
            peer: "127.0.0.1",
            ping: NetworkPingResult(
                transmitted: 2,
                received: 2,
                packetLossPercent: 0,
                minRttMilliseconds: 0.05,
                averageRttMilliseconds: 0.08,
                maxRttMilliseconds: 0.10,
                standardDeviationMilliseconds: 0.01
            ),
            traceroute: NetworkTracerouteResult(
                hops: [
                    NetworkTracerouteHop(
                        index: 1,
                        address: "127.0.0.1",
                        timingsMilliseconds: [0.1, 0.1, 0.1]
                    )
                ],
                blocked: false,
                blockedReason: nil
            ),
            verdict: .partial,
            notes: "Synthetic diagnostics fixture."
        )
    }
}

struct ProcessResult {
    let output: String
    let exitCode: Int32
    let timedOut: Bool
    let spawnError: String?
}

func runNetworkDiagnosticsProcess(
    executable: String,
    arguments: [String],
    timeoutSeconds: Int
) -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let outputPipe = Pipe()
    let outputCapture = BoundedPipeCapture(pipe: outputPipe)
    process.standardOutput = outputPipe
    process.standardError = outputPipe
    let terminated = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
        terminated.signal()
    }
    do {
        try process.run()
        outputCapture.closeWriteHandle()
    } catch {
        outputCapture.closeWriteHandle()
        return ProcessResult(
            output: "",
            exitCode: -1,
            timedOut: false,
            spawnError: "\(error)"
        )
    }

    let timedOut = terminated.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut
    if timedOut {
        process.terminate()
        let exitedAfterTerminate = terminated.wait(timeout: .now() + .milliseconds(500)) == .success
        if !exitedAfterTerminate, process.isRunning {
            _ = kill(process.processIdentifier, SIGKILL)
            _ = terminated.wait(timeout: .now() + .seconds(2))
        }
    }
    let didExit = !process.isRunning
    return ProcessResult(
        output: outputCapture.prefix(drainToEnd: didExit),
        exitCode: didExit ? process.terminationStatus : -1,
        timedOut: timedOut,
        spawnError: nil
    )
}

private func parseNetworkDiagnosticsArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        guard allowed.contains(argument) else {
            throw NetworkDiagnosticsRunConfigurationError.unknownArgument(argument)
        }
        guard values[argument] == nil else {
            throw NetworkDiagnosticsRunConfigurationError.duplicateArgument(argument)
        }
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw NetworkDiagnosticsRunConfigurationError.missingValue(argument)
        }
        values[argument] = arguments[valueIndex]
        index += 2
    }
    return values
}

private func requiredNetworkDiagnosticsString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw NetworkDiagnosticsRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func requiredNetworkDiagnosticsPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredNetworkDiagnosticsString(argument, values)
    guard let integer = Int(value) else {
        throw NetworkDiagnosticsRunConfigurationError.invalidInteger(
            argument: argument,
            value: value
        )
    }
    guard integer > 0 else {
        throw NetworkDiagnosticsRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

private func requireNetworkDiagnosticsNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NetworkDiagnosticsValidationError.emptyField(field)
    }
}

private func requireNetworkDiagnosticsPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw NetworkDiagnosticsValidationError.nonPositiveField(field)
    }
}

private func requireNetworkDiagnosticsNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw NetworkDiagnosticsValidationError.negativeField(field)
    }
}

private func requireNetworkDiagnosticsNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw NetworkDiagnosticsValidationError.negativeField(field)
    }
}

private func networkDiagnosticsPingMeetsPassThresholds(_ ping: NetworkPingResult) -> Bool {
    ping.averageRttMilliseconds <= NetworkDiagnosticsPassThresholds.maximumAverageRttMilliseconds
        && ping.maxRttMilliseconds <= NetworkDiagnosticsPassThresholds.maximumRttMilliseconds
        && ping.standardDeviationMilliseconds
            <= NetworkDiagnosticsPassThresholds.maximumStandardDeviationMilliseconds
}

private func requireNetworkDiagnosticsPassThresholds(_ ping: NetworkPingResult) throws {
    try requireNetworkDiagnosticsMaximum(
        ping.averageRttMilliseconds,
        "ping.averageRttMilliseconds",
        NetworkDiagnosticsPassThresholds.maximumAverageRttMilliseconds
    )
    try requireNetworkDiagnosticsMaximum(
        ping.maxRttMilliseconds,
        "ping.maxRttMilliseconds",
        NetworkDiagnosticsPassThresholds.maximumRttMilliseconds
    )
    try requireNetworkDiagnosticsMaximum(
        ping.standardDeviationMilliseconds,
        "ping.standardDeviationMilliseconds",
        NetworkDiagnosticsPassThresholds.maximumStandardDeviationMilliseconds
    )
}

private func requireNetworkDiagnosticsMaximum(
    _ value: Double,
    _ field: String,
    _ maximum: Double
) throws {
    if value > maximum {
        throw NetworkDiagnosticsValidationError.passExceedsThreshold(
            field: field,
            actual: value,
            maximum: maximum
        )
    }
}
