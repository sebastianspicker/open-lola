// Declares UDP media configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation
import OpenLolaContracts

/// Identifies the sender or receiver role for a routed UDP PCM run.
public enum UdpPcmRouteRunRole: String, Codable, Equatable, Sendable {
    case sender
    case receiver
}

/// Configures UdpPcmRouteRunConfiguration so callers supply explicit inputs before starting UDP media transport.
public struct UdpPcmRouteRunConfiguration: Codable, Equatable, Sendable {
    public let role: UdpPcmRouteRunRole
    public let bindHost: String
    public let peer: String
    public let port: UInt16
    public let packetMode: UdpPcmPacketMode
    public let durationSeconds: Int
    public let outputPath: String
    public let dscp: Int?
    public let routeKind: UdpPcmRouteKind
    public let routeLabel: String
    public let routeTopology: String
    public let sender: UdpPcmRouteEndpoint
    public let receiver: UdpPcmRouteEndpoint
    public let linkRateMbps: Int?
    public let vlan: String
    public let multicastPolicy: String
    public let dscpObserved: Int?
    public let dscpClassification: UdpPcmDscpClassification
    public let dscpNotTestedReason: String?
    public let packetCapture: UdpPcmPacketCapture
    public let reportID: String?
    public let title: String?
    public let notes: String?
    public let verdict: MeasurementVerdict

    public var packetCount: Int {
        let (sampleFrames, overflow) = durationSeconds.multipliedReportingOverflow(
            by: packetMode.sampleRateHertz
        )
        precondition(!overflow && sampleFrames <= Int.max, "packetCount sample frame total must fit Int")
        return sampleFrames / packetMode.framesPerPacket
    }

    public struct Input: Equatable, Sendable {
        public var role: UdpPcmRouteRunRole
        public var bindHost: String = "0.0.0.0"
        public var peer: String
        public var port: UInt16
        public var packetMode: UdpPcmPacketMode
        public var durationSeconds: Int
        public var outputPath: String
        public var dscp: Int?
        public var routeKind: UdpPcmRouteKind?
        public var routeLabel: String?
        public var routeTopology: String?
        public var sender: UdpPcmRouteEndpoint?
        public var receiver: UdpPcmRouteEndpoint?
        public var linkRateMbps: Int?
        public var vlan: String = "unknown"
        public var multicastPolicy: String = "unicast-only"
        public var dscpObserved: Int?
        public var dscpClassification: UdpPcmDscpClassification = .notTested
        public var dscpNotTestedReason: String?
        public var packetCapture: UdpPcmPacketCapture?
        public var reportID: String?
        public var title: String?
        public var notes: String?
        public var verdict: MeasurementVerdict = .partial

        public struct Transport: Equatable, Sendable {
            public var role: UdpPcmRouteRunRole
            public var bindHost: String
            public var peer: String
            public var port: UInt16
            public var packetMode: UdpPcmPacketMode
            public var durationSeconds: Int
            public var outputPath: String
            public var dscp: Int?

            public init(
                role: UdpPcmRouteRunRole,
                bindHost: String = "0.0.0.0",
                peer: String,
                port: UInt16,
                packetMode: UdpPcmPacketMode,
                durationSeconds: Int,
                outputPath: String,
                dscp: Int? = nil
            ) {
                self.role = role
                self.bindHost = bindHost
                self.peer = peer
                self.port = port
                self.packetMode = packetMode
                self.durationSeconds = durationSeconds
                self.outputPath = outputPath
                self.dscp = dscp
            }
        }

        public struct Route: Equatable, Sendable {
            public var kind: UdpPcmRouteKind?
            public var label: String?
            public var topology: String?
            public var sender: UdpPcmRouteEndpoint?
            public var receiver: UdpPcmRouteEndpoint?
            public var linkRateMbps: Int?
            public var vlan: String
            public var multicastPolicy: String

            public init(
                kind: UdpPcmRouteKind? = nil,
                label: String? = nil,
                topology: String? = nil,
                sender: UdpPcmRouteEndpoint? = nil,
                receiver: UdpPcmRouteEndpoint? = nil,
                linkRateMbps: Int? = nil,
                vlan: String = "unknown",
                multicastPolicy: String = "unicast-only"
            ) {
                self.kind = kind
                self.label = label
                self.topology = topology
                self.sender = sender
                self.receiver = receiver
                self.linkRateMbps = linkRateMbps
                self.vlan = vlan
                self.multicastPolicy = multicastPolicy
            }
        }

        public struct Evidence: Equatable, Sendable {
            public var dscpObserved: Int?
            public var dscpClassification: UdpPcmDscpClassification
            public var dscpNotTestedReason: String?
            public var packetCapture: UdpPcmPacketCapture?
            public var reportID: String?
            public var title: String?
            public var notes: String?
            public var verdict: MeasurementVerdict

            public init(
                dscpObserved: Int? = nil,
                dscpClassification: UdpPcmDscpClassification = .notTested,
                dscpNotTestedReason: String? = nil,
                packetCapture: UdpPcmPacketCapture? = nil,
                reportID: String? = nil,
                title: String? = nil,
                notes: String? = nil,
                verdict: MeasurementVerdict = .partial
            ) {
                self.dscpObserved = dscpObserved
                self.dscpClassification = dscpClassification
                self.dscpNotTestedReason = dscpNotTestedReason
                self.packetCapture = packetCapture
                self.reportID = reportID
                self.title = title
                self.notes = notes
                self.verdict = verdict
            }
        }

        public init(
            transport: Transport,
            route: Route = Route(),
            evidence: Evidence = Evidence()
        ) {
            role = transport.role
            bindHost = transport.bindHost
            peer = transport.peer
            port = transport.port
            packetMode = transport.packetMode
            durationSeconds = transport.durationSeconds
            outputPath = transport.outputPath
            dscp = transport.dscp
            routeKind = route.kind
            routeLabel = route.label
            routeTopology = route.topology
            sender = route.sender
            receiver = route.receiver
            linkRateMbps = route.linkRateMbps
            vlan = route.vlan
            multicastPolicy = route.multicastPolicy
            dscpObserved = evidence.dscpObserved
            dscpClassification = evidence.dscpClassification
            dscpNotTestedReason = evidence.dscpNotTestedReason
            packetCapture = evidence.packetCapture
            reportID = evidence.reportID
            title = evidence.title
            notes = evidence.notes
            verdict = evidence.verdict
        }
    }

    public init(_ input: Input) {
        let resolvedRouteKind = input.routeKind ?? inferredRouteKind(forPeer: input.peer)
        self.role = input.role
        self.bindHost = input.bindHost
        self.peer = input.peer
        self.port = input.port
        self.packetMode = input.packetMode
        self.durationSeconds = input.durationSeconds
        self.outputPath = input.outputPath
        self.dscp = input.dscp
        self.routeKind = resolvedRouteKind
        self.routeLabel = input.routeLabel ?? defaultRouteLabel(for: resolvedRouteKind)
        self.routeTopology = input.routeTopology ?? defaultRouteTopology(for: resolvedRouteKind)
        self.sender = input.sender ?? defaultSenderEndpoint(
            role: input.role,
            bindHost: input.bindHost,
            peer: input.peer
        )
        self.receiver = input.receiver ?? defaultReceiverEndpoint(
            role: input.role,
            bindHost: input.bindHost,
            peer: input.peer
        )
        self.linkRateMbps = input.linkRateMbps
        self.vlan = input.vlan
        self.multicastPolicy = input.multicastPolicy
        self.dscpObserved = input.dscpObserved
        self.dscpClassification = input.dscpClassification
        self.dscpNotTestedReason = input.dscpNotTestedReason
        self.packetCapture = input.packetCapture ?? UdpPcmPacketCapture(
            point: nil,
            receiverCorrelation: nil,
            notes: "continuous runner did not attach packet capture; external capture correlation is required PASS"
        )
        self.reportID = input.reportID
        self.title = input.title
        self.notes = input.notes
        self.verdict = input.verdict
    }

    public func validate() throws {
        guard durationSeconds > 0 else {
            throw UdpPcmRouteRunConfigurationError.nonPositiveArgument("durationSeconds")
        }
        guard packetMode.sampleRateHertz > 0 else {
            throw UdpPcmRouteRunConfigurationError.nonPositiveArgument("sampleRateHertz")
        }
        guard packetMode.framesPerPacket > 0 else {
            throw UdpPcmRouteRunConfigurationError.nonPositiveArgument("framesPerPacket")
        }
        guard packetMode.channelCount > 0 else {
            throw UdpPcmRouteRunConfigurationError.nonPositiveArgument("channelCount")
        }
        let (sampleFrames, overflow) = durationSeconds.multipliedReportingOverflow(
            by: packetMode.sampleRateHertz
        )
        guard !overflow && sampleFrames <= Int.max else {
            throw UdpPcmRouteRunConfigurationError.packetCountOverflow
        }
    }

    public static func parse(_ arguments: [String]) throws -> UdpPcmRouteRunConfiguration {
        let values = try parseRouteRunArgumentValues(arguments)
        let role = try parseRouteRunRole(values)
        let dscp = try validatedOptionalDscp("--dscp", values)
        let bindHost = values["--bind-host"] ?? "0.0.0.0"
        let peer = try requiredRouteRunString("--peer", values)

        let configuration = UdpPcmRouteRunConfiguration(
            UdpPcmRouteRunConfiguration.Input(
                transport: try routeRunTransport(values, role: role, bindHost: bindHost, peer: peer, dscp: dscp),
                route: try routeRunRoute(values, role: role, bindHost: bindHost, peer: peer),
                evidence: try routeRunEvidence(values)
            )
        )
        try configuration.validate()
        return configuration
    }
}

private func routeRunTransport(
    _ values: [String: String],
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String,
    dscp: Int?
) throws -> UdpPcmRouteRunConfiguration.Input.Transport {
    UdpPcmRouteRunConfiguration.Input.Transport(
        role: role,
        bindHost: bindHost,
        peer: peer,
        port: try requiredRouteRunPort(values),
        packetMode: try routeRunPacketMode(values),
        durationSeconds: try requiredRouteRunPositiveInteger("--duration-seconds", values),
        outputPath: try requiredRouteRunString("--output", values),
        dscp: dscp
    )
}

private func routeRunRoute(
    _ values: [String: String],
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String
) throws -> UdpPcmRouteRunConfiguration.Input.Route {
    UdpPcmRouteRunConfiguration.Input.Route(
        kind: try optionalRouteKind(values["--route-kind"]),
        label: values["--route-label"],
        topology: values["--route-topology"],
        sender: routeRunSenderEndpoint(values, role: role, bindHost: bindHost, peer: peer),
        receiver: routeRunReceiverEndpoint(values, role: role, bindHost: bindHost, peer: peer),
        linkRateMbps: try optionalRouteRunPositiveInteger("--link-rate-mbps", values),
        vlan: values["--vlan"] ?? "unknown",
        multicastPolicy: values["--multicast-policy"] ?? "unicast-only"
    )
}

private func routeRunEvidence(
    _ values: [String: String]
) throws -> UdpPcmRouteRunConfiguration.Input.Evidence {
    UdpPcmRouteRunConfiguration.Input.Evidence(
        dscpObserved: try validatedOptionalDscp("--dscp-observed", values),
        dscpClassification: try optionalDscpClassification(
            values["--dscp-classification"]
        ) ?? .notTested,
        dscpNotTestedReason: values["--dscp-not-tested-reason"],
        packetCapture: try routeRunPacketCapture(values),
        reportID: values["--report-id"],
        title: values["--title"],
        notes: values["--notes"],
        verdict: try optionalVerdict(values["--verdict"]) ?? .partial
    )
}

private let routeRunAllowedArguments: Set<String> = [
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
    "--route-kind",
    "--route-label",
    "--route-topology",
    "--sender-label",
    "--sender-host",
    "--sender-interface",
    "--sender-ip",
    "--receiver-label",
    "--receiver-host",
    "--receiver-interface",
    "--receiver-ip",
    "--link-rate-mbps",
    "--vlan",
    "--multicast-policy",
    "--dscp-observed",
    "--dscp-classification",
    "--dscp-not-tested-reason",
    "--capture-point",
    "--capture-correlated",
    "--capture-notes",
    "--report-id",
    "--title",
    "--notes",
    "--verdict"
]

private func parseRouteRunArgumentValues(_ arguments: [String]) throws -> [String: String] {
    var values: [String: String] = [:]
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        guard routeRunAllowedArguments.contains(argument) else {
            throw UdpPcmRouteRunConfigurationError.unknownArgument(argument)
        }
        guard values[argument] == nil else {
            throw UdpPcmRouteRunConfigurationError.duplicateArgument(argument)
        }
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw UdpPcmRouteRunConfigurationError.missingValue(argument)
        }
        values[argument] = arguments[valueIndex]
        index += 2
    }
    return values
}

private func parseRouteRunRole(_ values: [String: String]) throws -> UdpPcmRouteRunRole {
    let roleText = try requiredRouteRunString("--role", values)
    guard let role = UdpPcmRouteRunRole(rawValue: roleText) else {
        throw UdpPcmRouteRunConfigurationError.invalidRole(roleText)
    }
    return role
}

private func validatedOptionalDscp(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    let dscp = try optionalRouteRunInteger(argument, values)
    if let dscp, dscp < 0 || dscp > 63 {
        throw UdpPcmRouteRunConfigurationError.invalidDscp(dscp)
    }
    return dscp
}

private func routeRunPacketMode(_ values: [String: String]) throws -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: try requiredRouteRunPositiveInteger("--sample-rate", values),
        framesPerPacket: try requiredRouteRunPositiveInteger("--frames", values),
        channelCount: try requiredRouteRunPositiveInteger("--channels", values),
        sampleFormat: .int16LittleEndian
    )
}

private func routeRunSenderEndpoint(
    _ values: [String: String],
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: values["--sender-label"] ?? "udp-pcm-sender",
        hostName: values["--sender-host"] ?? defaultEndpointHostName(local: role == .sender),
        interfaceName: values["--sender-interface"] ?? "unknown",
        ipAddress: values["--sender-ip"] ?? (role == .sender ? bindHost : peer)
    )
}

private func routeRunReceiverEndpoint(
    _ values: [String: String],
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: values["--receiver-label"] ?? "udp-pcm-receiver",
        hostName: values["--receiver-host"] ?? defaultEndpointHostName(local: role == .receiver),
        interfaceName: values["--receiver-interface"] ?? "unknown",
        ipAddress: values["--receiver-ip"] ?? (role == .receiver ? bindHost : peer)
    )
}

private func routeRunPacketCapture(_ values: [String: String]) throws -> UdpPcmPacketCapture {
    UdpPcmPacketCapture(
        point: values["--capture-point"],
        receiverCorrelation: try optionalRouteRunBoolean("--capture-correlated", values),
        notes: values["--capture-notes"]
            ?? "continuous runner did not attach packet capture; external capture correlation is required for PASS"
    )
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmRouteRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidRouteKind(String)
    case invalidDscpClassification(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidRole(String)
    case invalidPort(Int)
    case invalidDscp(Int)
    case invalidBoolean(argument: String, value: String)
    case invalidVerdict(String)
    case packetCountOverflow
}

/// Represents the UdpPcmRouteRunSummary produced by UDP media transport without exposing its execution state.
public struct UdpPcmRouteRunSummary: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let capturedAt: String
    public let hostName: String
    public let role: UdpPcmRouteRunRole
    public let configuration: UdpPcmRouteRunConfiguration
    public let packetsSent: Int
    public let packetsReceived: Int
    public let sendErrors: Int
    public let receiveErrors: Int
    public let verdict: MeasurementVerdict
    public let notes: String

}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmRouteProbeError: Error, Equatable, Sendable {
    case invalidPacketCount(Int)
    case socketFailed
    case bindFailed(Int32)
    case getsocknameFailed(Int32)
    case invalidHost(String)
    case connectFailed(Int32)
    case fcntlFailed(Int32)
    case setSocketOptionFailed(Int32)
    case socketBufferTooSmall(option: Int32, requested: Int32, actual: Int32)
    case sendFailed(Int32)
    case receiveFailed(Int32)
    case shortSend(expected: Int, actual: Int)
}
