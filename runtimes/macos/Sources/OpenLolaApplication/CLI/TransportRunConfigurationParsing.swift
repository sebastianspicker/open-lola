// Keeps executable token parsing above the typed Transport configuration layer.
import Foundation
import OpenLolaContracts
import OpenLolaTransport

public extension NetworkDiagnosticsRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: ["--peer", "--ping-count", "--max-hops", "--output"],
            allowsDashPrefixedValues: false,
            unknown: NetworkDiagnosticsRunConfigurationError.unknownArgument,
            duplicate: NetworkDiagnosticsRunConfigurationError.duplicateArgument,
            missingValue: NetworkDiagnosticsRunConfigurationError.missingValue
        )
        return Self(
            peer: try KeyValueArgumentParser.requiredString("--peer", values, missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument),
            pingCount: try KeyValueArgumentParser.requiredPositiveInteger("--ping-count", values, missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument, invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger, nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument),
            maxHops: try KeyValueArgumentParser.requiredPositiveInteger("--max-hops", values, missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument, invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger, nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument),
            outputPath: try KeyValueArgumentParser.requiredString("--output", values, missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument)
        )
    }
}

public extension UdpPcmLoopbackRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
            arguments,
            allowed: ["--session-id", "--role", "--bind-host", "--peer", "--port", "--sample-rate", "--frames", "--channels", "--duration-seconds", "--output", "--dscp", "--diagnostics", "--debug-output"],
            unknown: UdpPcmLoopbackRunConfigurationError.unknownArgument,
            duplicate: UdpPcmLoopbackRunConfigurationError.duplicateArgument,
            missingValue: UdpPcmLoopbackRunConfigurationError.missingValue
        )
        let roleText = try loopbackRequired("--role", values)
        guard let role = UdpPcmLoopbackRole(rawValue: roleText) else { throw UdpPcmLoopbackRunConfigurationError.invalidRole(roleText) }
        let diagnosticsText = values["--diagnostics"] ?? "off"
        guard let diagnostics = UdpPcmLoopbackDiagnosticsState(rawValue: diagnosticsText) else { throw UdpPcmLoopbackRunConfigurationError.invalidDiagnostics(diagnosticsText) }
        let dscp = try loopbackInteger("--dscp", values)
        if let dscp, dscp < 0 || dscp > 63 { throw UdpPcmLoopbackRunConfigurationError.invalidDscp(dscp) }
        return Self(
            connection: .init(sessionID: try loopbackRequired("--session-id", values), role: role, bindHost: values["--bind-host"] ?? "0.0.0.0", peer: try loopbackRequired("--peer", values), port: try loopbackPort(values)),
            run: .init(packetMode: .init(sampleRateHertz: try loopbackPositive("--sample-rate", values), framesPerPacket: try loopbackPositive("--frames", values), channelCount: try loopbackPositive("--channels", values), sampleFormat: .int16LittleEndian), durationSeconds: try loopbackPositive("--duration-seconds", values), outputPath: try loopbackRequired("--output", values), dscp: dscp, diagnostics: diagnostics, debugOutputPath: values["--debug-output"])
        )
    }
}

private func loopbackRequired(_ key: String, _ values: [String: String]) throws -> String {
    try KeyValueArgumentParser.requiredString(key, values, missing: UdpPcmLoopbackRunConfigurationError.missingRequiredArgument)
}

private func loopbackPositive(_ key: String, _ values: [String: String]) throws -> Int {
    try KeyValueArgumentParser.requiredPositiveInteger(key, values, missing: UdpPcmLoopbackRunConfigurationError.missingRequiredArgument, invalid: UdpPcmLoopbackRunConfigurationError.invalidInteger, nonPositive: UdpPcmLoopbackRunConfigurationError.nonPositiveArgument)
}

private func loopbackInteger(_ key: String, _ values: [String: String]) throws -> Int? {
    try KeyValueArgumentParser.optionalInteger(key, values, invalid: UdpPcmLoopbackRunConfigurationError.invalidInteger)
}

private func loopbackPort(_ values: [String: String]) throws -> UInt16 {
    let port = try loopbackPositive("--port", values)
    guard port <= Int(UInt16.max) else { throw UdpPcmLoopbackRunConfigurationError.invalidPort(port) }
    return UInt16(port)
}

public extension NatFriendlyRouteRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try natValues(arguments, allowed: [
            "--role", "--bind-host", "--peer-id", "--rendezvous-host", "--rendezvous-port",
            "--relay-host", "--relay-port", "--session-id", "--port", "--duration-seconds",
            "--keepalive-interval-ms", "--raw-rtt-microseconds", "--output", "--debug-output"
        ])
        let roleText = try natRequired("--role", values)
        guard let role = NatFriendlyRouteRole(rawValue: roleText) else {
            throw NatFriendlyRouteRunConfigurationError.invalidRole(roleText)
        }
        return Self(.init(
            identity: .init(
                role: role,
                bindHost: try natRequired("--bind-host", values),
                peerID: try natRequired("--peer-id", values),
                sessionID: try natRequired("--session-id", values)
            ),
            traversal: .init(
                rendezvousHost: try natRequired("--rendezvous-host", values),
                rendezvousPort: try natPort("--rendezvous-port", values),
                relayHost: try natRelayHost(values),
                relayPort: try natRelayPort(values)
            ),
            runtime: .init(
                localUdpPort: try natLocalPort("--port", values),
                durationSeconds: try natPositive("--duration-seconds", values),
                keepaliveIntervalMilliseconds: try natOptionalPositive("--keepalive-interval-ms", values) ?? 100,
                rawRouteRttMicroseconds: try natOptionalNonNegativeDouble("--raw-rtt-microseconds", values)
            ),
            output: .init(
                reportPath: try natRequired("--output", values),
                debugPath: values["--debug-output"]
            )
        ))
    }
}

public extension NatRendezvousRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try natValues(arguments, allowed: [
            "--bind-host", "--port", "--session-id", "--mode", "--expected-peers", "--timeout-seconds", "--output"
        ])
        let modeText = try natRequired("--mode", values)
        guard let mode = NatFriendlyCompatibilityMode(rawValue: modeText) else {
            throw NatFriendlyRouteRunConfigurationError.invalidMode(modeText)
        }
        return Self(
            bindHost: try natRequired("--bind-host", values),
            port: try natPort("--port", values),
            sessionID: try natRequired("--session-id", values),
            mode: mode,
            expectedPeerCount: try natOptionalPositive("--expected-peers", values) ?? 2,
            timeoutSeconds: try natOptionalPositive("--timeout-seconds", values) ?? 30,
            outputPath: try natRequired("--output", values)
        )
    }
}

public extension NatRelayRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try natValues(arguments, allowed: [
            "--bind-host", "--port", "--session-id", "--expected-peers", "--timeout-seconds", "--output"
        ])
        let common = try natServerArguments(values)
        return Self(
            bindHost: common.bindHost,
            port: try natPort("--port", values),
            sessionID: common.sessionID,
            expectedPeerCount: common.expectedPeerCount,
            timeoutSeconds: common.timeoutSeconds,
            outputPath: common.outputPath
        )
    }
}

public extension NatRendezvousForwarderLauncherConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try natValues(arguments, allowed: [
            "--bind-host", "--rendezvous-port", "--forwarder-port", "--session-id", "--expected-peers", "--timeout-seconds", "--output"
        ])
        let rendezvousPort = try natPort("--rendezvous-port", values)
        let forwarderPort = try natPort("--forwarder-port", values)
        guard rendezvousPort != forwarderPort else {
            throw NatFriendlyRouteRunConfigurationError.conflictingPorts(
                "--rendezvous-port and --forwarder-port must differ"
            )
        }
        let common = try natServerArguments(values)
        return Self(
            bindHost: common.bindHost,
            rendezvousPort: rendezvousPort,
            forwarderPort: forwarderPort,
            sessionID: common.sessionID,
            expectedPeerCount: common.expectedPeerCount,
            timeoutSeconds: common.timeoutSeconds,
            outputPath: common.outputPath
        )
    }
}

private struct NatServerArguments {
    let bindHost: String
    let sessionID: String
    let expectedPeerCount: Int
    let timeoutSeconds: Int
    let outputPath: String
}

private let natPositiveIntegerBounds: [String: Int] = [
    "--duration-seconds": 86_400,
    "--timeout-seconds": 86_400,
    "--keepalive-interval-ms": 60_000,
    "--expected-peers": 1_024
]

private func natValues(_ arguments: [String], allowed: Set<String>) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: allowed,
        unknown: NatFriendlyRouteRunConfigurationError.unknownArgument,
        duplicate: NatFriendlyRouteRunConfigurationError.duplicateArgument,
        missingValue: NatFriendlyRouteRunConfigurationError.missingValue
    )
}

private func natRequired(_ argument: String, _ values: [String: String]) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: NatFriendlyRouteRunConfigurationError.missingRequiredArgument
    )
}

private func natPositive(_ argument: String, _ values: [String: String]) throws -> Int {
    let number = try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: NatFriendlyRouteRunConfigurationError.missingRequiredArgument,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
    try validateNatPositiveBound(number, argument: argument)
    return number
}

private func natOptionalPositive(_ argument: String, _ values: [String: String]) throws -> Int? {
    let number = try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
    if let number {
        try validateNatPositiveBound(number, argument: argument)
    }
    return number
}

private func validateNatPositiveBound(_ number: Int, argument: String) throws {
    guard let maximum = natPositiveIntegerBounds[argument], number > maximum else {
        return
    }
    throw NatFriendlyRouteRunConfigurationError.invalidInteger(argument: argument, value: String(number))
}

private func natOptionalNonNegativeDouble(_ argument: String, _ values: [String: String]) throws -> Double? {
    try KeyValueArgumentParser.optionalNonNegativeDouble(
        argument,
        values,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        negative: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
}

private func natRelayHost(_ values: [String: String]) throws -> String? {
    guard let relayHost = values["--relay-host"] else {
        if values["--relay-port"] != nil {
            throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-host")
        }
        return nil
    }
    guard !relayHost.isEmpty else {
        throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-host")
    }
    guard values["--relay-port"] != nil else {
        throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-port")
    }
    return relayHost
}

private func natRelayPort(_ values: [String: String]) throws -> UInt16? {
    guard values["--relay-host"] != nil || values["--relay-port"] != nil else {
        return nil
    }
    return try natPort("--relay-port", values)
}

private func natPort(_ argument: String, _ values: [String: String]) throws -> UInt16 {
    let port = try natPositive(argument, values)
    guard port <= Int(UInt16.max) else {
        throw NatFriendlyRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

private func natLocalPort(_ argument: String, _ values: [String: String]) throws -> UInt16 {
    let value = try natRequired(argument, values)
    guard let port = Int(value) else {
        throw NatFriendlyRouteRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard port >= 0, port <= Int(UInt16.max) else {
        throw NatFriendlyRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

private func natServerArguments(_ values: [String: String]) throws -> NatServerArguments {
    NatServerArguments(
        bindHost: try natRequired("--bind-host", values),
        sessionID: try natRequired("--session-id", values),
        expectedPeerCount: try natOptionalPositive("--expected-peers", values) ?? 2,
        timeoutSeconds: try natOptionalPositive("--timeout-seconds", values) ?? 30,
        outputPath: try natRequired("--output", values)
    )
}

public extension UdpPcmRouteRunConfiguration {
    static func parse(_ arguments: [String]) throws -> Self {
        let values = try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
            arguments,
            allowed: routeRunAllowedArguments,
            unknown: UdpPcmRouteRunConfigurationError.unknownArgument,
            duplicate: UdpPcmRouteRunConfigurationError.duplicateArgument,
            missingValue: UdpPcmRouteRunConfigurationError.missingValue
        )
        let role = try routeRunRole(values)
        let dscp = try routeRunDscp("--dscp", values)
        let bindHost = values["--bind-host"] ?? "0.0.0.0"
        let peer = try routeRunRequired("--peer", values)
        let configuration = Self(.init(
            transport: try routeRunTransport(values, role: role, bindHost: bindHost, peer: peer, dscp: dscp),
            route: try routeRunRoute(values, role: role, bindHost: bindHost, peer: peer),
            evidence: try routeRunEvidence(values)
        ))
        try configuration.validate()
        return configuration
    }
}

private let routeRunAllowedArguments: Set<String> = [
    "--role", "--bind-host", "--peer", "--port", "--sample-rate", "--frames", "--channels",
    "--duration-seconds", "--output", "--dscp", "--route-kind", "--route-label", "--route-topology",
    "--sender-label", "--sender-host", "--sender-interface", "--sender-ip", "--receiver-label",
    "--receiver-host", "--receiver-interface", "--receiver-ip", "--link-rate-mbps", "--vlan",
    "--multicast-policy", "--dscp-observed", "--dscp-classification", "--dscp-not-tested-reason",
    "--capture-point", "--capture-correlated", "--capture-notes", "--report-id", "--title", "--notes", "--verdict"
]

private let routeRunPositiveIntegerBounds: [String: Int] = [
    "--sample-rate": 384_000,
    "--frames": 4_096,
    "--channels": 256,
    "--duration-seconds": 86_400,
    "--link-rate-mbps": 1_000_000
]

private func routeRunTransport(
    _ values: [String: String], role: UdpPcmRouteRunRole, bindHost: String, peer: String, dscp: Int?
) throws -> UdpPcmRouteRunConfiguration.Input.Transport {
    .init(
        role: role,
        bindHost: bindHost,
        peer: peer,
        port: try routeRunPort(values),
        packetMode: try routeRunPacketMode(values),
        durationSeconds: try routeRunPositive("--duration-seconds", values),
        outputPath: try routeRunRequired("--output", values),
        dscp: dscp
    )
}

private func routeRunRoute(
    _ values: [String: String], role: UdpPcmRouteRunRole, bindHost: String, peer: String
) throws -> UdpPcmRouteRunConfiguration.Input.Route {
    .init(
        kind: try routeRunKind(values["--route-kind"]),
        label: values["--route-label"],
        topology: values["--route-topology"],
        sender: routeRunSender(values, role: role, bindHost: bindHost, peer: peer),
        receiver: routeRunReceiver(values, role: role, bindHost: bindHost, peer: peer),
        linkRateMbps: try routeRunOptionalPositive("--link-rate-mbps", values),
        vlan: values["--vlan"] ?? "unknown",
        multicastPolicy: values["--multicast-policy"] ?? "unicast-only"
    )
}

private func routeRunEvidence(_ values: [String: String]) throws -> UdpPcmRouteRunConfiguration.Input.Evidence {
    .init(
        dscpObserved: try routeRunDscp("--dscp-observed", values),
        dscpClassification: try routeRunDscpClassification(values["--dscp-classification"]) ?? .notTested,
        dscpNotTestedReason: values["--dscp-not-tested-reason"],
        packetCapture: try routeRunPacketCapture(values),
        reportID: values["--report-id"],
        title: values["--title"],
        notes: values["--notes"],
        verdict: try routeRunVerdict(values["--verdict"]) ?? .partial
    )
}

private func routeRunRole(_ values: [String: String]) throws -> UdpPcmRouteRunRole {
    let roleText = try routeRunRequired("--role", values)
    guard let role = UdpPcmRouteRunRole(rawValue: roleText) else {
        throw UdpPcmRouteRunConfigurationError.invalidRole(roleText)
    }
    return role
}

private func routeRunRequired(_ argument: String, _ values: [String: String]) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: UdpPcmRouteRunConfigurationError.missingRequiredArgument
    )
}

private func routeRunPositive(_ argument: String, _ values: [String: String]) throws -> Int {
    let number = try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: UdpPcmRouteRunConfigurationError.missingRequiredArgument,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: UdpPcmRouteRunConfigurationError.nonPositiveArgument
    )
    try validateRouteRunPositiveBound(number, argument: argument)
    return number
}

private func routeRunOptionalInteger(_ argument: String, _ values: [String: String]) throws -> Int? {
    try KeyValueArgumentParser.optionalInteger(
        argument,
        values,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) }
    )
}

private func routeRunOptionalPositive(_ argument: String, _ values: [String: String]) throws -> Int? {
    let number = try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: UdpPcmRouteRunConfigurationError.nonPositiveArgument
    )
    if let number {
        try validateRouteRunPositiveBound(number, argument: argument)
    }
    return number
}

private func validateRouteRunPositiveBound(_ number: Int, argument: String) throws {
    guard let maximum = routeRunPositiveIntegerBounds[argument], number > maximum else {
        return
    }
    throw UdpPcmRouteRunConfigurationError.invalidInteger(argument: argument, value: String(number))
}

private func routeRunPort(_ values: [String: String]) throws -> UInt16 {
    let port = try routeRunPositive("--port", values)
    guard port <= Int(UInt16.max) else {
        throw UdpPcmRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

private func routeRunDscp(_ argument: String, _ values: [String: String]) throws -> Int? {
    let dscp = try routeRunOptionalInteger(argument, values)
    if let dscp, dscp < 0 || dscp > 63 {
        throw UdpPcmRouteRunConfigurationError.invalidDscp(dscp)
    }
    return dscp
}

private func routeRunPacketMode(_ values: [String: String]) throws -> UdpPcmPacketMode {
    .init(
        sampleRateHertz: try routeRunPositive("--sample-rate", values),
        framesPerPacket: try routeRunPositive("--frames", values),
        channelCount: try routeRunPositive("--channels", values),
        sampleFormat: .int16LittleEndian
    )
}

private func routeRunSender(
    _ values: [String: String], role: UdpPcmRouteRunRole, bindHost: String, peer: String
) -> UdpPcmRouteEndpoint {
    .init(
        label: values["--sender-label"] ?? "udp-pcm-sender",
        hostName: values["--sender-host"] ?? routeRunEndpointHostName(local: role == .sender),
        interfaceName: values["--sender-interface"] ?? "unknown",
        ipAddress: values["--sender-ip"] ?? (role == .sender ? bindHost : peer)
    )
}

private func routeRunReceiver(
    _ values: [String: String], role: UdpPcmRouteRunRole, bindHost: String, peer: String
) -> UdpPcmRouteEndpoint {
    .init(
        label: values["--receiver-label"] ?? "udp-pcm-receiver",
        hostName: values["--receiver-host"] ?? routeRunEndpointHostName(local: role == .receiver),
        interfaceName: values["--receiver-interface"] ?? "unknown",
        ipAddress: values["--receiver-ip"] ?? (role == .receiver ? bindHost : peer)
    )
}

private func routeRunEndpointHostName(local: Bool) -> String {
    local ? Host.current().localizedName ?? "localhost" : "peer"
}

private func routeRunPacketCapture(_ values: [String: String]) throws -> UdpPcmPacketCapture {
    .init(
        point: values["--capture-point"],
        receiverCorrelation: try routeRunOptionalBoolean("--capture-correlated", values),
        notes: values["--capture-notes"]
            ?? "continuous runner did not attach packet capture; external capture correlation is required for PASS"
    )
}

private func routeRunOptionalBoolean(_ argument: String, _ values: [String: String]) throws -> Bool? {
    guard let value = values[argument] else {
        return nil
    }
    return try KeyValueArgumentParser.boolean(
        value,
        argument: argument,
        invalid: { UdpPcmRouteRunConfigurationError.invalidBoolean(argument: $0, value: $1) }
    )
}

private func routeRunKind(_ value: String?) throws -> UdpPcmRouteKind? {
    guard let value else { return nil }
    guard let routeKind = UdpPcmRouteKind(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidRouteKind(value)
    }
    return routeKind
}

private func routeRunDscpClassification(_ value: String?) throws -> UdpPcmDscpClassification? {
    guard let value else { return nil }
    guard let classification = UdpPcmDscpClassification(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidDscpClassification(value)
    }
    return classification
}

private func routeRunVerdict(_ value: String?) throws -> MeasurementVerdict? {
    guard let value else { return nil }
    guard let verdict = MeasurementVerdict(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidVerdict(value)
    }
    return verdict
}
