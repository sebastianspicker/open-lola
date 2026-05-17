import Darwin
import Dispatch
import Foundation

public enum UdpPcmLoopbackRole: String, Codable, Equatable, Sendable {
    case sender
    case looper

    public var reciprocal: UdpPcmLoopbackRole {
        switch self {
        case .sender:
            .looper
        case .looper:
            .sender
        }
    }
}

public enum UdpPcmLoopbackDiagnosticsState: String, Codable, Equatable, Sendable {
    case on
    case off
}

public struct UdpPcmLoopbackRunConfiguration: Codable, Equatable, Sendable {
    public let sessionID: String
    public let role: UdpPcmLoopbackRole
    public let bindHost: String
    public let peer: String
    public let port: UInt16
    public let packetMode: UdpPcmPacketMode
    public let durationSeconds: Int
    public let outputPath: String
    public let dscp: Int?
    public let diagnostics: UdpPcmLoopbackDiagnosticsState
    public let debugOutputPath: String?

    public var packetCount: Int {
        expectedPacketCount(durationSeconds: durationSeconds, packetMode: packetMode)
    }

    public init(
        sessionID: String,
        role: UdpPcmLoopbackRole,
        bindHost: String,
        peer: String,
        port: UInt16,
        packetMode: UdpPcmPacketMode,
        durationSeconds: Int,
        outputPath: String,
        dscp: Int?,
        diagnostics: UdpPcmLoopbackDiagnosticsState,
        debugOutputPath: String?
    ) {
        self.sessionID = sessionID
        self.role = role
        self.bindHost = bindHost
        self.peer = peer
        self.port = port
        self.packetMode = packetMode
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
        self.dscp = dscp
        self.diagnostics = diagnostics
        self.debugOutputPath = debugOutputPath
    }

    public static func parse(_ arguments: [String]) throws -> UdpPcmLoopbackRunConfiguration {
        let allowed = [
            "--session-id",
            "--role",
            "--bind-host",
            "--peer",
            "--port",
            "--sample-rate",
            "--frames",
            "--channels",
            "--duration-seconds",
            "--output",
            "--dscp",
            "--diagnostics",
            "--debug-output"
        ]
        let values = try parseLoopbackArguments(arguments, allowed: Set(allowed))
        let roleText = try requiredLoopbackString("--role", values)
        guard let role = UdpPcmLoopbackRole(rawValue: roleText) else {
            throw UdpPcmLoopbackRunConfigurationError.invalidRole(roleText)
        }
        let diagnosticsText = values["--diagnostics"] ?? "off"
        guard let diagnostics = UdpPcmLoopbackDiagnosticsState(rawValue: diagnosticsText) else {
            throw UdpPcmLoopbackRunConfigurationError.invalidDiagnostics(diagnosticsText)
        }
        let dscp = try optionalLoopbackInteger("--dscp", values)
        if let dscp, dscp < 0 || dscp > 63 {
            throw UdpPcmLoopbackRunConfigurationError.invalidDscp(dscp)
        }

        return UdpPcmLoopbackRunConfiguration(
            sessionID: try requiredLoopbackString("--session-id", values),
            role: role,
            bindHost: values["--bind-host"] ?? "0.0.0.0",
            peer: try requiredLoopbackString("--peer", values),
            port: try requiredLoopbackPort(values),
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: try requiredLoopbackPositiveInteger("--sample-rate", values),
                framesPerPacket: try requiredLoopbackPositiveInteger("--frames", values),
                channelCount: try requiredLoopbackPositiveInteger("--channels", values),
                sampleFormat: .int16LittleEndian
            ),
            durationSeconds: try requiredLoopbackPositiveInteger("--duration-seconds", values),
            outputPath: try requiredLoopbackString("--output", values),
            dscp: dscp,
            diagnostics: diagnostics,
            debugOutputPath: values["--debug-output"]
        )
    }

    public var agreement: UdpPcmLoopbackSessionAgreement {
        UdpPcmLoopbackSessionAgreement(
            sessionID: sessionID,
            localEndpoint: bindHost,
            peerEndpoint: peer,
            port: port,
            localRole: role,
            peerRole: role.reciprocal,
            packetMode: packetMode,
            durationSeconds: durationSeconds
        )
    }

    public func reciprocalCommand(executable: String = "open-lola") -> String {
        let reciprocalRole = role.reciprocal
        var arguments = [
            executable,
            "udp-pcm-loopback-run",
            "--session-id", sessionID,
            "--role", reciprocalRole.rawValue,
            "--bind-host", peer,
            "--peer", bindHost,
            "--port", "\(port)",
            "--sample-rate", "\(packetMode.sampleRateHertz)",
            "--frames", "\(packetMode.framesPerPacket)",
            "--channels", "\(packetMode.channelCount)",
            "--duration-seconds", "\(durationSeconds)",
            "--output", reciprocalOutputPath()
        ]
        if let dscp {
            arguments += ["--dscp", "\(dscp)"]
        }
        if reciprocalRole == .sender || diagnostics == .on {
            arguments += ["--diagnostics", diagnostics.rawValue]
        }
        return arguments.map(shellArgument).joined(separator: " ")
    }

    private func reciprocalOutputPath() -> String {
        let roleName = role.reciprocal.rawValue
        let fileName = "udp-pcm-loopback-\(sessionID)-\(roleName).json"
        let directory = (outputPath as NSString).deletingLastPathComponent
        guard directory != ".", directory != outputPath else {
            return fileName
        }
        return "\(directory)/\(fileName)"
    }
}

public enum UdpPcmLoopbackRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidRole(String)
    case invalidPort(Int)
    case invalidDscp(Int)
    case invalidDiagnostics(String)
}

public struct LoopbackTimingMetrics: Codable, Equatable, Sendable {
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double

    public init(
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double
    ) {
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
    }
}

public struct UdpPcmLoopbackMetrics: Codable, Equatable, Sendable {
    public var packetsSent: Int
    public var packetsEchoed: Int
    public var lostPackets: Int
    public var byteExactEcho: Bool
    public var rtt: LoopbackTimingMetrics
    public var oneWayEstimateMicroseconds: Double
    public var jitterP99Microseconds: Double
    public var duplicatePackets: Int
    public var outOfOrderPackets: Int
    public var malformedEchoPackets: Int
    public var wrongSizeEchoPackets: Int
    public var fatalReceiveErrors: Int

    public init(
        packetsSent: Int,
        packetsEchoed: Int,
        lostPackets: Int,
        byteExactEcho: Bool,
        rtt: LoopbackTimingMetrics,
        oneWayEstimateMicroseconds: Double,
        jitterP99Microseconds: Double,
        duplicatePackets: Int,
        outOfOrderPackets: Int,
        malformedEchoPackets: Int = 0,
        wrongSizeEchoPackets: Int = 0,
        fatalReceiveErrors: Int = 0
    ) {
        self.packetsSent = packetsSent
        self.packetsEchoed = packetsEchoed
        self.lostPackets = lostPackets
        self.byteExactEcho = byteExactEcho
        self.rtt = rtt
        self.oneWayEstimateMicroseconds = oneWayEstimateMicroseconds
        self.jitterP99Microseconds = jitterP99Microseconds
        self.duplicatePackets = duplicatePackets
        self.outOfOrderPackets = outOfOrderPackets
        self.malformedEchoPackets = malformedEchoPackets
        self.wrongSizeEchoPackets = wrongSizeEchoPackets
        self.fatalReceiveErrors = fatalReceiveErrors
    }

    private enum CodingKeys: String, CodingKey {
        case packetsSent
        case packetsEchoed
        case lostPackets
        case byteExactEcho
        case rtt
        case oneWayEstimateMicroseconds
        case jitterP99Microseconds
        case duplicatePackets
        case outOfOrderPackets
        case malformedEchoPackets
        case wrongSizeEchoPackets
        case fatalReceiveErrors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsSent = try container.decode(Int.self, forKey: .packetsSent)
        packetsEchoed = try container.decode(Int.self, forKey: .packetsEchoed)
        lostPackets = try container.decode(Int.self, forKey: .lostPackets)
        byteExactEcho = try container.decode(Bool.self, forKey: .byteExactEcho)
        rtt = try container.decode(LoopbackTimingMetrics.self, forKey: .rtt)
        oneWayEstimateMicroseconds = try container.decode(Double.self, forKey: .oneWayEstimateMicroseconds)
        jitterP99Microseconds = try container.decode(Double.self, forKey: .jitterP99Microseconds)
        duplicatePackets = try container.decode(Int.self, forKey: .duplicatePackets)
        outOfOrderPackets = try container.decode(Int.self, forKey: .outOfOrderPackets)
        malformedEchoPackets = try container.decodeIfPresent(Int.self, forKey: .malformedEchoPackets) ?? 0
        wrongSizeEchoPackets = try container.decodeIfPresent(Int.self, forKey: .wrongSizeEchoPackets) ?? 0
        fatalReceiveErrors = try container.decodeIfPresent(Int.self, forKey: .fatalReceiveErrors) ?? 0
    }
}

public enum UdpPcmLoopbackDiagnosticsClassification: String, Codable, Equatable, Sendable {
    case udpHigher
    case similar
    case udpLower
}

private let loopbackDiagnosticsMinimumIcmpDenominatorMicroseconds = 0.001

public struct UdpPcmLoopbackDiagnosticsComparison: Codable, Equatable, Sendable {
    public var icmpAverageRttMicroseconds: Double
    public var udpAverageRttMicroseconds: Double
    public var deltaMicroseconds: Double
    public var percentDelta: Double
    public var classification: UdpPcmLoopbackDiagnosticsClassification

    public init(
        icmpAverageRttMicroseconds: Double,
        udpAverageRttMicroseconds: Double,
        deltaMicroseconds: Double,
        percentDelta: Double,
        classification: UdpPcmLoopbackDiagnosticsClassification
    ) {
        self.icmpAverageRttMicroseconds = icmpAverageRttMicroseconds
        self.udpAverageRttMicroseconds = udpAverageRttMicroseconds
        self.deltaMicroseconds = deltaMicroseconds
        self.percentDelta = percentDelta
        self.classification = classification
    }

    public static func compare(
        udpAverageRttMicroseconds: Double,
        ping: NetworkPingResult
    ) -> UdpPcmLoopbackDiagnosticsComparison {
        let icmp = ping.averageRttMilliseconds * 1_000
        let delta = udpAverageRttMicroseconds - icmp
        let percent = icmp > loopbackDiagnosticsMinimumIcmpDenominatorMicroseconds
            ? (delta / icmp) * 100
            : 0
        let classification: UdpPcmLoopbackDiagnosticsClassification
        if abs(percent) <= 10 {
            classification = .similar
        } else if delta > 0 {
            classification = .udpHigher
        } else {
            classification = .udpLower
        }
        return UdpPcmLoopbackDiagnosticsComparison(
            icmpAverageRttMicroseconds: icmp,
            udpAverageRttMicroseconds: udpAverageRttMicroseconds,
            deltaMicroseconds: delta,
            percentDelta: percent,
            classification: classification
        )
    }
}

public enum UdpPcmLoopbackValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case sessionRoleMismatch
    case sessionRolePairMismatch
    case sessionIDMismatch
    case sessionPacketModeMismatch
    case sessionPortMismatch
    case sessionEndpointMismatch
    case sessionDurationMismatch
    case unorderedTiming
    case packetAccountingMismatch(expectedLost: Int, actualLost: Int)
    case passWithoutByteExactEcho
    case passWithLoss
    case passWithDuplicateOrOutOfOrderPackets
    case passWithMalformedOrFatalEcho
}

public struct UdpPcmLoopbackSessionAgreement: Codable, Equatable, Sendable {
    public var sessionID: String
    public var localEndpoint: String
    public var peerEndpoint: String
    public var port: UInt16
    public var localRole: UdpPcmLoopbackRole
    public var peerRole: UdpPcmLoopbackRole
    public var packetMode: UdpPcmPacketMode
    public var durationSeconds: Int

    public init(
        sessionID: String,
        localEndpoint: String,
        peerEndpoint: String,
        port: UInt16,
        localRole: UdpPcmLoopbackRole,
        peerRole: UdpPcmLoopbackRole,
        packetMode: UdpPcmPacketMode,
        durationSeconds: Int
    ) {
        self.sessionID = sessionID
        self.localEndpoint = localEndpoint
        self.peerEndpoint = peerEndpoint
        self.port = port
        self.localRole = localRole
        self.peerRole = peerRole
        self.packetMode = packetMode
        self.durationSeconds = durationSeconds
    }
}

public struct UdpPcmLoopbackReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var route: RouteIdentity
    public var session: UdpPcmLoopbackSessionAgreement
    public var role: UdpPcmLoopbackRole
    public var peer: String
    public var packetMode: UdpPcmPacketMode
    public var metrics: UdpPcmLoopbackMetrics
    public var diagnostics: UdpPcmLoopbackDiagnosticsComparison?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        route: RouteIdentity,
        session: UdpPcmLoopbackSessionAgreement,
        role: UdpPcmLoopbackRole,
        peer: String,
        packetMode: UdpPcmPacketMode,
        metrics: UdpPcmLoopbackMetrics,
        diagnostics: UdpPcmLoopbackDiagnosticsComparison?,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.route = route
        self.session = session
        self.role = role
        self.peer = peer
        self.packetMode = packetMode
        self.metrics = metrics
        self.diagnostics = diagnostics
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> UdpPcmLoopbackReport {
        try JSONDecoder().decode(UdpPcmLoopbackReport.self, from: data)
    }

    public func validate() throws {
        try requireLoopbackNonEmpty(id, "id")
        try requireLoopbackNonEmpty(capturedAt, "capturedAt")
        try requireLoopbackNonEmpty(route.label, "route.label")
        try requireLoopbackNonEmpty(route.topology, "route.topology")
        try requireLoopbackNonEmpty(session.sessionID, "session.sessionID")
        try requireLoopbackNonEmpty(session.localEndpoint, "session.localEndpoint")
        try requireLoopbackNonEmpty(session.peerEndpoint, "session.peerEndpoint")
        try requireLoopbackPositive(Int(session.port), "session.port")
        try requireLoopbackPositive(session.durationSeconds, "session.durationSeconds")
        try requireLoopbackNonEmpty(peer, "peer")
        try requireLoopbackNonEmpty(notes, "notes")
        try requireLoopbackPositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try requireLoopbackPositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try requireLoopbackPositive(packetMode.channelCount, "packetMode.channelCount")
        try requireLoopbackNonNegative(metrics.packetsSent, "metrics.packetsSent")
        try requireLoopbackNonNegative(metrics.packetsEchoed, "metrics.packetsEchoed")
        try requireLoopbackNonNegative(metrics.lostPackets, "metrics.lostPackets")
        try requireLoopbackNonNegative(metrics.rtt.p50Microseconds, "metrics.rtt.p50Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.p95Microseconds, "metrics.rtt.p95Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.p99Microseconds, "metrics.rtt.p99Microseconds")
        try requireLoopbackNonNegative(metrics.rtt.maxMicroseconds, "metrics.rtt.maxMicroseconds")
        try requireLoopbackNonNegative(
            metrics.oneWayEstimateMicroseconds,
            "metrics.oneWayEstimateMicroseconds"
        )
        try requireLoopbackNonNegative(metrics.jitterP99Microseconds, "metrics.jitterP99Microseconds")
        try requireLoopbackNonNegative(metrics.duplicatePackets, "metrics.duplicatePackets")
        try requireLoopbackNonNegative(metrics.outOfOrderPackets, "metrics.outOfOrderPackets")
        try requireLoopbackNonNegative(metrics.malformedEchoPackets, "metrics.malformedEchoPackets")
        try requireLoopbackNonNegative(metrics.wrongSizeEchoPackets, "metrics.wrongSizeEchoPackets")
        try requireLoopbackNonNegative(metrics.fatalReceiveErrors, "metrics.fatalReceiveErrors")
        if session.localRole != role || session.peerRole != role.reciprocal {
            throw UdpPcmLoopbackValidationError.sessionRoleMismatch
        }
        if session.peerEndpoint != peer {
            throw UdpPcmLoopbackValidationError.sessionEndpointMismatch
        }
        if session.packetMode != packetMode {
            throw UdpPcmLoopbackValidationError.sessionPacketModeMismatch
        }
        guard metrics.rtt.p50Microseconds <= metrics.rtt.p95Microseconds,
              metrics.rtt.p95Microseconds <= metrics.rtt.p99Microseconds,
              metrics.rtt.p99Microseconds <= metrics.rtt.maxMicroseconds else {
            throw UdpPcmLoopbackValidationError.unorderedTiming
        }
        let expectedLost = max(0, metrics.packetsSent - metrics.packetsEchoed)
        if metrics.lostPackets != expectedLost {
            throw UdpPcmLoopbackValidationError.packetAccountingMismatch(
                expectedLost: expectedLost,
                actualLost: metrics.lostPackets
            )
        }
        guard verdict == .pass else {
            return
        }
        if !metrics.byteExactEcho {
            throw UdpPcmLoopbackValidationError.passWithoutByteExactEcho
        }
        if metrics.lostPackets > 0 {
            throw UdpPcmLoopbackValidationError.passWithLoss
        }
        if metrics.duplicatePackets > 0 || metrics.outOfOrderPackets > 0 {
            throw UdpPcmLoopbackValidationError.passWithDuplicateOrOutOfOrderPackets
        }
        if metrics.malformedEchoPackets > 0 || metrics.wrongSizeEchoPackets > 0 || metrics.fatalReceiveErrors > 0 {
            throw UdpPcmLoopbackValidationError.passWithMalformedOrFatalEcho
        }
    }

    public func validateSessionPair(with other: UdpPcmLoopbackReport) throws {
        try validate()
        try other.validate()
        guard role != other.role else {
            throw UdpPcmLoopbackValidationError.sessionRolePairMismatch
        }
        guard session.sessionID == other.session.sessionID else {
            throw UdpPcmLoopbackValidationError.sessionIDMismatch
        }
        guard session.packetMode == other.session.packetMode else {
            throw UdpPcmLoopbackValidationError.sessionPacketModeMismatch
        }
        guard session.port == other.session.port else {
            throw UdpPcmLoopbackValidationError.sessionPortMismatch
        }
        guard session.durationSeconds == other.session.durationSeconds else {
            throw UdpPcmLoopbackValidationError.sessionDurationMismatch
        }
        guard session.peerEndpoint == other.session.localEndpoint,
              other.session.peerEndpoint == session.localEndpoint else {
            throw UdpPcmLoopbackValidationError.sessionEndpointMismatch
        }
    }
}

public enum UdpPcmLoopbackRunner {
    public static func run(
        configuration: UdpPcmLoopbackRunConfiguration
    ) throws -> (report: UdpPcmLoopbackReport, debugTrace: DebugTrace?) {
        var debug = DebugTrace()
        debug.record(event: "run-configuration", fields: redactedConfigurationFields(configuration))
        debug.record(
            event: "loopback-start",
            fields: [
                "sessionID": configuration.sessionID,
                "role": configuration.role.rawValue,
                "bindHost": configuration.bindHost,
                "peer": configuration.peer,
                "port": "\(configuration.port)"
            ]
        )
        do {
            let report: UdpPcmLoopbackReport
            switch configuration.role {
            case .sender:
                report = try runSender(configuration: configuration, debug: &debug)
            case .looper:
                report = try runLooper(configuration: configuration, debug: &debug)
            }
            return (report, configuration.debugOutputPath == nil ? nil : debug)
        } catch {
            debug.record(
                event: "loopback-failed",
                fields: [
                    "role": configuration.role.rawValue,
                    "error": "\(error)"
                ]
            )
            guard configuration.debugOutputPath != nil else {
                throw error
            }
            throw DebugTracedRunFailure(
                failureDescription: "\(error)",
                debugTrace: debug
            )
        }
    }
}
