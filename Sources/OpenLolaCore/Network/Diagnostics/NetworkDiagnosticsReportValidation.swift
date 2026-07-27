// Validates NetworkDiagnosticsReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension NetworkDiagnosticsReport {
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

func networkDiagnosticsPingMeetsPassThresholds(_ ping: NetworkPingResult) -> Bool {
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
