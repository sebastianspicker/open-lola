// Defines the external connector peer settings rendered by the native app shell.
import Foundation

// swiftlint:disable:next type_name
/// Defines the validated fields for native app shell external connector peer fields.
public struct NativeAppShellExternalConnectorPeerFields: Codable, Equatable, Sendable {
    public struct Connection: Equatable, Sendable {
        public var peerHost: String
        public var audioPort: UInt16
        public var peerAudioPort: UInt16
        public var videoPort: UInt16
        public var mediaMode: ExternalConnectorMediaMode

        public init(
            peerHost: String,
            audioPort: UInt16,
            peerAudioPort: UInt16,
            videoPort: UInt16,
            mediaMode: ExternalConnectorMediaMode
        ) {
            self.peerHost = peerHost
            self.audioPort = audioPort
            self.peerAudioPort = peerAudioPort
            self.videoPort = videoPort
            self.mediaMode = mediaMode
        }
    }

    public struct Execution: Equatable, Sendable {
        public var executablePath: String
        public var localHost: String
        public var role: ExternalConnectorSessionRole
        public var durationSeconds: Int
        public var outputPath: String

        public init(
            executablePath: String = ".build/debug/open-lola",
            localHost: String = "0.0.0.0",
            role: ExternalConnectorSessionRole = .txRx,
            durationSeconds: Int = 20,
            outputPath: String
        ) {
            self.executablePath = executablePath
            self.localHost = localHost
            self.role = role
            self.durationSeconds = durationSeconds
            self.outputPath = outputPath
        }
    }

    public var executablePath: String
    public var localHost: String
    public var peerHost: String
    public var role: ExternalConnectorSessionRole
    public var audioPort: UInt16
    public var peerAudioPort: UInt16
    public var videoPort: UInt16
    public var mediaMode: ExternalConnectorMediaMode
    public var durationSeconds: Int
    public var outputPath: String

    public init(
        connection: Connection,
        execution: Execution
    ) {
        executablePath = execution.executablePath
        localHost = execution.localHost
        peerHost = connection.peerHost
        role = execution.role
        audioPort = connection.audioPort
        peerAudioPort = connection.peerAudioPort
        videoPort = connection.videoPort
        mediaMode = connection.mediaMode
        durationSeconds = execution.durationSeconds
        outputPath = execution.outputPath
    }

    public static let jackTripAppDefault = NativeAppShellExternalConnectorPeerFields(
        connection: Connection(
            peerHost: "203.0.113.10",
            audioPort: 4_464,
            peerAudioPort: 4_464,
            videoPort: 5_004,
            mediaMode: .audio
        ),
        execution: Execution(outputPath: "/tmp/open-lola-app/jacktrip-session.json")
    )

    public static let ultraGridAppDefault = NativeAppShellExternalConnectorPeerFields(
        connection: Connection(
            peerHost: "198.51.100.10",
            audioPort: 5_006,
            peerAudioPort: 5_006,
            videoPort: 5_004,
            mediaMode: .audioVideo
        ),
        execution: Execution(outputPath: "/tmp/open-lola-app/ultragrid-session.json")
    )

    public func validateAppSettings(connector: ExternalConnectorKind) throws {
        try requireExternalConnectorCommandText(executablePath, "executablePath")
        try requireExternalConnectorCommandText(localHost, "localHost")
        try requireExternalConnectorCommandText(peerHost, "peerHost")
        try requireExternalConnectorCommandText(outputPath, "outputPath")
        try requirePositiveExternalConnectorCommandValue(durationSeconds, "durationSeconds")
        try validateExternalConnectorPorts(connector: connector)
        if connector == .jackTrip, mediaMode != .audio {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("mediaMode")
        }
    }

    public func sessionArguments(
        connector: ExternalConnectorKind,
        executablePath resolvedExecutablePath: String,
        dryRun: Bool
    ) throws -> [String] {
        try validateAppSettings(connector: connector)
        try requireExternalConnectorCommandText(resolvedExecutablePath, "executablePath")
        var arguments = [
            resolvedExecutablePath,
            "external-connector-session-run",
            "--connector", connector.appCLIValue,
            "--role", role.rawValue,
            "--peer", peerHost,
            "--local-host", localHost,
            "--output", outputPath,
            "--dry-run", dryRun ? "true" : "false",
            "--media", mediaMode.cliValue,
            "--control-transport", ExternalConnectorControlTransport.udp.rawValue,
            "--duration-seconds", "\(durationSeconds)",
            "--audio-port", "\(audioPort)",
            "--video-port", "\(videoPort)"
        ]
        if connector == .jackTrip, role.transmits {
            arguments += ["--peer-audio-port", "\(peerAudioPort)"]
        }
        return arguments
    }

    public func validatorArguments(
        connector: ExternalConnectorKind,
        executablePath resolvedExecutablePath: String
    ) throws -> [String] {
        try validateAppSettings(connector: connector)
        try requireExternalConnectorCommandText(resolvedExecutablePath, "executablePath")
        return [
            resolvedExecutablePath,
            "validate-external-connector-session-report",
            outputPath
        ]
    }

    private func validateExternalConnectorPorts(connector: ExternalConnectorKind) throws {
        let ports: [(name: String, value: UInt16)] = [
            ("audioPort", audioPort),
            ("videoPort", videoPort)
        ]
        for port in ports {
            guard port.value > 0 else {
                throw NativeAppShellSurfaceValidationError.invalidCommandField(port.name)
            }
        }
        if connector == .jackTrip, role.transmits, peerAudioPort == 0 {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("peerAudioPort")
        }
    }
}
public extension ExternalConnectorKind {
    var appCLIValue: String {
        switch self {
        case .lola:
            return "lola"
        case .mvtpUltraGrid:
            return "mvtp-ultragrid"
        case .jackTrip:
            return "jacktrip"
        }
    }
}

private func requireExternalConnectorCommandText(_ value: String, _ field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requirePositiveExternalConnectorCommandValue(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}
