// Declares UDP media configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Identifies the sender or receiver side of a UDP PCM loopback run.
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

/// Records whether loopback diagnostic evidence was produced, omitted, or failed.
public enum UdpPcmLoopbackDiagnosticsState: String, Codable, Equatable, Sendable {
// swiftlint:disable:next identifier_name
 case on
    case off
}

/// Configures UdpPcmLoopbackRunConfiguration so callers supply explicit inputs before starting UDP media transport.
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

    public struct Connection: Equatable, Sendable {
        public var sessionID: String
        public var role: UdpPcmLoopbackRole
        public var bindHost: String
        public var peer: String
        public var port: UInt16

        public init(
            sessionID: String,
            role: UdpPcmLoopbackRole,
            bindHost: String,
            peer: String,
            port: UInt16
        ) {
            self.sessionID = sessionID
            self.role = role
            self.bindHost = bindHost
            self.peer = peer
            self.port = port
        }
    }

    public struct Run: Equatable, Sendable {
        public var packetMode: UdpPcmPacketMode
        public var durationSeconds: Int
        public var outputPath: String
        public var dscp: Int?
        public var diagnostics: UdpPcmLoopbackDiagnosticsState
        public var debugOutputPath: String?

        public init(
            packetMode: UdpPcmPacketMode,
            durationSeconds: Int,
            outputPath: String,
            dscp: Int?,
            diagnostics: UdpPcmLoopbackDiagnosticsState,
            debugOutputPath: String?
        ) {
            self.packetMode = packetMode
            self.durationSeconds = durationSeconds
            self.outputPath = outputPath
            self.dscp = dscp
            self.diagnostics = diagnostics
            self.debugOutputPath = debugOutputPath
        }
    }

    public init(connection: Connection, run: Run) {
        sessionID = connection.sessionID
        role = connection.role
        bindHost = connection.bindHost
        peer = connection.peer
        port = connection.port
        packetMode = run.packetMode
        durationSeconds = run.durationSeconds
        outputPath = run.outputPath
        dscp = run.dscp
        diagnostics = run.diagnostics
        debugOutputPath = run.debugOutputPath
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
            connection: .init(
                sessionID: try requiredLoopbackString("--session-id", values),
                role: role,
                bindHost: values["--bind-host"] ?? "0.0.0.0",
                peer: try requiredLoopbackString("--peer", values),
                port: try requiredLoopbackPort(values)
            ),
            run: .init(
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

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmLoopbackRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidDiagnostics(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidRole(String)
    case invalidPort(Int)
    case invalidDscp(Int)
}
