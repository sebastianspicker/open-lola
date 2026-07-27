// Defines loopback timing, ICMP comparison, session agreement, and validation rules so diagnostic latency is not promoted to one-way evidence.
import Darwin
import Dispatch
import Foundation

/// Represents the UdpPcmLoopbackMetrics produced by UDP media transport without exposing its execution state.
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

    public struct Delivery: Equatable, Sendable {
        public var packetsSent: Int
        public var packetsEchoed: Int
        public var lostPackets: Int
        public var duplicatePackets: Int
        public var outOfOrderPackets: Int
        public var malformedEchoPackets: Int
        public var wrongSizeEchoPackets: Int
        public var fatalReceiveErrors: Int

        public init(
            packetsSent: Int,
            packetsEchoed: Int,
            lostPackets: Int,
            duplicatePackets: Int,
            outOfOrderPackets: Int,
            malformedEchoPackets: Int = 0,
            wrongSizeEchoPackets: Int = 0,
            fatalReceiveErrors: Int = 0
        ) {
            self.packetsSent = packetsSent
            self.packetsEchoed = packetsEchoed
            self.lostPackets = lostPackets
            self.duplicatePackets = duplicatePackets
            self.outOfOrderPackets = outOfOrderPackets
            self.malformedEchoPackets = malformedEchoPackets
            self.wrongSizeEchoPackets = wrongSizeEchoPackets
            self.fatalReceiveErrors = fatalReceiveErrors
        }
    }

    public struct Timing: Equatable, Sendable {
        public var rtt: LoopbackTimingMetrics
        public var oneWayEstimateMicroseconds: Double
        public var jitterP99Microseconds: Double

        public init(
            rtt: LoopbackTimingMetrics,
            oneWayEstimateMicroseconds: Double,
            jitterP99Microseconds: Double
        ) {
            self.rtt = rtt
            self.oneWayEstimateMicroseconds = oneWayEstimateMicroseconds
            self.jitterP99Microseconds = jitterP99Microseconds
        }
    }

    public init(delivery: Delivery, byteExactEcho: Bool, timing: Timing) {
        packetsSent = delivery.packetsSent
        packetsEchoed = delivery.packetsEchoed
        lostPackets = delivery.lostPackets
        self.byteExactEcho = byteExactEcho
        rtt = timing.rtt
        oneWayEstimateMicroseconds = timing.oneWayEstimateMicroseconds
        jitterP99Microseconds = timing.jitterP99Microseconds
        duplicatePackets = delivery.duplicatePackets
        outOfOrderPackets = delivery.outOfOrderPackets
        malformedEchoPackets = delivery.malformedEchoPackets
        wrongSizeEchoPackets = delivery.wrongSizeEchoPackets
        fatalReceiveErrors = delivery.fatalReceiveErrors
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

/// Classifies the relationship between UDP PCM loopback diagnostics and their comparison baseline.
public enum UdpPcmLoopbackDiagnosticsClassification: String, Codable, Equatable, Sendable {
    case udpHigher
    case similar
    case udpLower
}

// swiftlint:disable:next identifier_name
private let loopbackDiagnosticsMinimumIcmpDenominatorMicroseconds = 0.001

/// Represents UdpPcmLoopbackDiagnosticsComparison values used by UDP media transport.
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

/// Enumerates failures that callers must handle when working with UDP media transport.
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

/// Represents UdpPcmLoopbackSessionAgreement values used by UDP media transport.
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

/// Captures UdpPcmLoopbackReport evidence in a stable form for validation and serialized reporting.
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

    public struct Identity: Equatable, Sendable {
        public var id: String
        public var capturedAt: String
        public var route: RouteIdentity

        public init(id: String, capturedAt: String, route: RouteIdentity) {
            self.id = id
            self.capturedAt = capturedAt
            self.route = route
        }
    }

    public struct Observation: Equatable, Sendable {
        public var role: UdpPcmLoopbackRole
        public var peer: String
        public var packetMode: UdpPcmPacketMode
        public var metrics: UdpPcmLoopbackMetrics
        public var diagnostics: UdpPcmLoopbackDiagnosticsComparison?

        public init(
            role: UdpPcmLoopbackRole,
            peer: String,
            packetMode: UdpPcmPacketMode,
            metrics: UdpPcmLoopbackMetrics,
            diagnostics: UdpPcmLoopbackDiagnosticsComparison?
        ) {
            self.role = role
            self.peer = peer
            self.packetMode = packetMode
            self.metrics = metrics
            self.diagnostics = diagnostics
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public init(
        identity: Identity,
        session: UdpPcmLoopbackSessionAgreement,
        observation: Observation,
        outcome: Outcome
    ) {
        id = identity.id
        capturedAt = identity.capturedAt
        route = identity.route
        self.session = session
        role = observation.role
        peer = observation.peer
        packetMode = observation.packetMode
        metrics = observation.metrics
        diagnostics = observation.diagnostics
        verdict = outcome.verdict
        notes = outcome.notes
    }

}

/// Runs UdpPcmLoopbackRunner while keeping its stateful execution separate from report validation.
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
