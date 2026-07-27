// Parses NetworkDiagnosticsParser input at the boundary, keeping syntax errors out of the domain implementation.
import Foundation

/// Reports missing or malformed ping and traceroute sections in command output.
public enum NetworkDiagnosticsParseError: Error, Equatable, Sendable {
    case missingPingSummary
    case missingPingTiming
    case malformedPingSummary(String)
    case missingTracerouteHops
}

/// Parses macOS and Linux ping or traceroute output into validated diagnostic results.
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
