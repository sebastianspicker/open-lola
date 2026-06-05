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
    public var pingError: String?
    public var traceroute: NetworkTracerouteResult
    public var tracerouteError: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        peer: String,
        ping: NetworkPingResult?,
        pingError: String? = nil,
        traceroute: NetworkTracerouteResult,
        tracerouteError: String? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.peer = peer
        self.ping = ping
        self.pingError = pingError
        self.traceroute = traceroute
        self.tracerouteError = tracerouteError
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> NetworkDiagnosticsReport {
        try JSONDecoder().decode(NetworkDiagnosticsReport.self, from: data)
    }

    public func validate() throws {
        try validateRequiredFields()
        try validatePingMetrics()
        try validateTraceroute()
        try validatePassVerdict()
    }

    private func validateRequiredFields() throws {
        try requireNetworkDiagnosticsNonEmpty(id, "id")
        try requireNetworkDiagnosticsNonEmpty(capturedAt, "capturedAt")
        try requireNetworkDiagnosticsNonEmpty(peer, "peer")
        try requireNetworkDiagnosticsNonEmpty(notes, "notes")
        if let pingError {
            try requireNetworkDiagnosticsNonEmpty(pingError, "pingError")
        }
        if let tracerouteError {
            try requireNetworkDiagnosticsNonEmpty(tracerouteError, "tracerouteError")
        }
    }

    private func validatePingMetrics() throws {
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
    }

    private func validateTraceroute() throws {
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
    }

    private func validatePassVerdict() throws {
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
    case malformedPingSummary(String)
    case missingTracerouteHops
}

public enum NetworkDiagnosticsParser {
    public static func parsePing(_ output: String) throws -> NetworkPingResult {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let summary = try parsePingSummary(from: lines)
        let timing = try parsePingTiming(from: lines)

        return NetworkPingResult(
            transmitted: summary.transmitted,
            received: summary.received,
            packetLossPercent: summary.packetLossPercent,
            minRttMilliseconds: timing.minRttMilliseconds,
            averageRttMilliseconds: timing.averageRttMilliseconds,
            maxRttMilliseconds: timing.maxRttMilliseconds,
            standardDeviationMilliseconds: timing.standardDeviationMilliseconds
        )
    }

    private static func parsePingSummary(
        from lines: [String]
    ) throws -> NetworkDiagnosticsPingSummary {
        guard let summary = lines.first(where: { $0.contains("packets transmitted") }) else {
            throw NetworkDiagnosticsParseError.missingPingSummary
        }
        let summaryParts = pingSummaryParts(summary)
        guard let transmittedText = summaryParts.first,
              let transmitted = Int(transmittedText),
              let received = pingReceivedCount(from: summaryParts),
              let packetLoss = pingPacketLossPercent(from: summaryParts) else {
            throw NetworkDiagnosticsParseError.malformedPingSummary(summary)
        }
        return NetworkDiagnosticsPingSummary(
            transmitted: transmitted,
            received: received,
            packetLossPercent: packetLoss
        )
    }

    private static func pingSummaryParts(_ summary: String) -> [Substring] {
        summary
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ")
    }

    private static func pingReceivedCount(from parts: [Substring]) -> Int? {
        guard let index = parts.firstIndex(of: "received"),
              index > parts.startIndex else {
            return nil
        }
        let previousIndex = parts.index(before: index)
        if let value = Int(parts[previousIndex]) {
            return value
        }
        let macOSPacketIndex = parts.index(index, offsetBy: -2, limitedBy: parts.startIndex)
        return macOSPacketIndex.map { Int(parts[$0]) } ?? nil
    }

    private static func pingPacketLossPercent(from parts: [Substring]) -> Double? {
        guard let index = parts.firstIndex(of: "packet"),
              index > parts.startIndex else {
            return nil
        }
        let valueIndex = parts.index(before: index)
        return Double(parts[valueIndex])
    }

    private static func parsePingTiming(
        from lines: [String]
    ) throws -> NetworkDiagnosticsPingTiming {
        guard let timing = lines.first(where: { pingTimingLine($0) }) else {
            throw NetworkDiagnosticsParseError.missingPingTiming
        }
        let values = timing.components(separatedBy: "=").last.map(pingTimingValues) ?? []
        guard values.count == 4 else {
            throw NetworkDiagnosticsParseError.missingPingTiming
        }
        return NetworkDiagnosticsPingTiming(
            minRttMilliseconds: values[0],
            averageRttMilliseconds: values[1],
            maxRttMilliseconds: values[2],
            standardDeviationMilliseconds: values[3]
        )
    }

    private static func pingTimingLine(_ line: String) -> Bool {
        (line.contains("round-trip") || line.contains("rtt")) && line.contains("=")
    }

    private static func pingTimingValues(_ valueText: String) -> [Double] {
        valueText
            .replacingOccurrences(of: "ms", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    public static func parseTraceroute(_ output: String) throws -> NetworkTracerouteResult {
        let blocked = output.localizedCaseInsensitiveContains("operation not permitted")
            || output.localizedCaseInsensitiveContains("permission denied")
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let hops = lines.compactMap(parseTracerouteHop)
        if hops.isEmpty, !blocked {
            throw NetworkDiagnosticsParseError.missingTracerouteHops
        }
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

private struct NetworkDiagnosticsPingSummary {
    var transmitted: Int
    var received: Int
    var packetLossPercent: Double
}

private struct NetworkDiagnosticsPingTiming {
    var minRttMilliseconds: Double
    var averageRttMilliseconds: Double
    var maxRttMilliseconds: Double
    var standardDeviationMilliseconds: Double
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
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: ["--peer", "--ping-count", "--max-hops", "--output"],
            allowsDashPrefixedValues: false,
            unknown: NetworkDiagnosticsRunConfigurationError.unknownArgument,
            duplicate: NetworkDiagnosticsRunConfigurationError.duplicateArgument,
            missingValue: NetworkDiagnosticsRunConfigurationError.missingValue
        )
        return NetworkDiagnosticsRunConfiguration(
            peer: try KeyValueArgumentParser.requiredString(
                "--peer",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument
            ),
            pingCount: try KeyValueArgumentParser.requiredPositiveInteger(
                "--ping-count",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument,
                invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger,
                nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument
            ),
            maxHops: try KeyValueArgumentParser.requiredPositiveInteger(
                "--max-hops",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument,
                invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger,
                nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument
            ),
            outputPath: try KeyValueArgumentParser.requiredString(
                "--output",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument
            )
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
        let pingProcess = runNetworkDiagnosticsProcess(
            executable: "/sbin/ping",
            arguments: ["-c", "\(configuration.pingCount)", "-n", configuration.peer],
            timeoutSeconds: max(2, configuration.pingCount + 2)
        )
        let tracerouteProcess = runNetworkDiagnosticsProcess(
            executable: "/usr/sbin/traceroute",
            arguments: ["-n", "-m", "\(configuration.maxHops)", configuration.peer],
            timeoutSeconds: max(2, configuration.maxHops + 2)
        )
        return makeReport(
            configuration: configuration,
            pingProcess: pingProcess,
            tracerouteProcess: tracerouteProcess
        )
    }

    static func makeReport(
        configuration: NetworkDiagnosticsRunConfiguration,
        pingProcess: ProcessResult,
        tracerouteProcess: ProcessResult
    ) -> NetworkDiagnosticsReport {
        let pingOutcome = parsePingResult(pingProcess)
        let tracerouteOutcome = parseTracerouteResult(tracerouteProcess)
        let verdict = pingOutcome.error == nil && tracerouteOutcome.error == nil
            ? networkDiagnosticsVerdict(ping: pingOutcome.result, traceroute: tracerouteOutcome.result)
            : .partial
        return NetworkDiagnosticsReport(
            id: "network-diagnostics-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            peer: configuration.peer,
            ping: pingOutcome.result,
            pingError: pingOutcome.error,
            traceroute: tracerouteOutcome.result,
            tracerouteError: tracerouteOutcome.error,
            verdict: verdict,
            notes: "ICMP ping and traceroute are diagnostic comparisons only; they do not prove audio latency."
        )
    }

    private static func parsePingResult(
        _ processResult: ProcessResult
    ) -> NetworkDiagnosticsPingOutcome {
        if let spawnError = processResult.spawnError {
            return NetworkDiagnosticsPingOutcome(
                result: nil,
                error: "ping process failed: \(spawnError)"
            )
        }
        if processResult.timedOut {
            return NetworkDiagnosticsPingOutcome(result: nil, error: "ping timed out")
        }
        do {
            let ping = try NetworkDiagnosticsParser.parsePing(processResult.output)
            let error = processResult.exitCode == 0 ? nil : "ping exited with status \(processResult.exitCode)"
            return NetworkDiagnosticsPingOutcome(result: ping, error: error)
        } catch {
            var reason = "ping parse failed: \(error)"
            if processResult.exitCode != 0 {
                reason += "; ping exited with status \(processResult.exitCode)"
            }
            return NetworkDiagnosticsPingOutcome(result: nil, error: reason)
        }
    }

    private static func parseTracerouteResult(
        _ processResult: ProcessResult
    ) -> NetworkDiagnosticsTracerouteOutcome {
        if let spawnError = processResult.spawnError {
            let traceroute = NetworkTracerouteResult(
                hops: [],
                blocked: true,
                blockedReason: "traceroute process failed: \(spawnError)"
            )
            return NetworkDiagnosticsTracerouteOutcome(
                result: traceroute,
                error: traceroute.blockedReason
            )
        }
        let parsed: NetworkTracerouteResult
        do {
            parsed = try NetworkDiagnosticsParser.parseTraceroute(processResult.output)
        } catch {
            let reason = "traceroute parse failed: \(error)"
            let traceroute = NetworkTracerouteResult(hops: [], blocked: true, blockedReason: reason)
            return NetworkDiagnosticsTracerouteOutcome(result: traceroute, error: reason)
        }
        if processResult.timedOut {
            let traceroute = NetworkTracerouteResult(
                hops: parsed.hops,
                blocked: true,
                blockedReason: "traceroute timed out"
            )
            return NetworkDiagnosticsTracerouteOutcome(
                result: traceroute,
                error: traceroute.blockedReason
            )
        }
        let error = processResult.exitCode == 0 ? nil : "traceroute exited with status \(processResult.exitCode)"
        return NetworkDiagnosticsTracerouteOutcome(result: parsed, error: error)
    }
}

private struct NetworkDiagnosticsPingOutcome {
    let result: NetworkPingResult?
    let error: String?
}

private struct NetworkDiagnosticsTracerouteOutcome {
    let result: NetworkTracerouteResult
    let error: String?
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
