import Foundation

public enum NativeAppShellSessionMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case directMacPeer
    case windowsLoLa
    case jackTrip
    case ultraGrid
}

public enum NativeAppShellAppExecutionRoute: Equatable, Sendable {
    case directMacPeer
    case windowsLoLa
    case externalConnector(ExternalConnectorKind)
    case unsupportedExternalConnector(reason: String)

    public var supportsExecution: Bool {
        switch self {
        case .directMacPeer, .windowsLoLa, .externalConnector:
            return true
        case .unsupportedExternalConnector:
            return false
        }
    }

    public var unavailableReason: String? {
        switch self {
        case .directMacPeer, .windowsLoLa, .externalConnector:
            return nil
        case .unsupportedExternalConnector(let reason):
            return reason
        }
    }
}

public enum NativeAppShellControlMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case normal
    case advanced
}

public enum NativeAppShellSettingsGroup: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case workflow
    case connection
    case execution
    case devices
    case audioCodec
    case videoCodec
    case lolaPayload
    case ports
    case buffers
    case reportPaths
    case sshFallback
    case preview
    case externalConnectorNotice
    case snapshot
}

public enum NativeAppShellSettingsVisibility {
    public static func visibleGroups(
        sessionMode: NativeAppShellSessionMode,
        controlMode: NativeAppShellControlMode
    ) -> [NativeAppShellSettingsGroup] {
        var groups: [NativeAppShellSettingsGroup] = [.workflow]
        switch sessionMode.appExecutionRoute {
        case .unsupportedExternalConnector:
            return groups + [.externalConnectorNotice]
        case .directMacPeer:
            groups += [.connection, .devices, .execution, .preview, .snapshot]
            guard controlMode == .advanced else {
                return groups
            }
            groups += [.audioCodec, .videoCodec, .ports, .buffers, .reportPaths, .sshFallback]
        case .windowsLoLa:
            groups += [.connection, .devices, .execution, .preview, .snapshot]
            guard controlMode == .advanced else {
                return groups
            }
            groups += [.lolaPayload, .ports, .reportPaths]
        case .externalConnector:
            groups += [.connection, .execution, .preview, .snapshot]
            guard controlMode == .advanced else {
                return groups
            }
            groups += [.ports, .reportPaths]
        }
        return groups
    }
}

public extension NativeAppShellControlMode {
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .advanced:
            return "Advanced"
        }
    }
}

public extension NativeAppShellSessionMode {
    var displayName: String {
        switch self {
        case .directMacPeer:
            return "Mac-to-Mac"
        case .windowsLoLa:
            return "Windows LoLa"
        case .jackTrip:
            return "JackTrip"
        case .ultraGrid:
            return "UltraGrid"
        }
    }

    var appStatusLabel: String {
        switch self {
        case .directMacPeer:
            return "IP/NAT preflight first"
        case .windowsLoLa:
            return "Windows LoLa connector"
        case .jackTrip:
            return "JackTrip connector"
        case .ultraGrid:
            return "UltraGrid connector"
        }
    }

    var appModeSummary: String {
        switch self {
        case .directMacPeer:
            return "Default Mac-to-Mac flow: IP/NAT preflight first, direct P2P media after validated routing."
        case .windowsLoLa:
            return "Windows LoLa connector flow. It remains separate from the default Mac-to-Mac path."
        case .jackTrip:
            return "JackTrip native connector flow. The app launches the Open LoLa external connector runner and validates its session report."
        case .ultraGrid:
            return "UltraGrid native connector flow. The app launches the Open LoLa external connector runner and validates its session report."
        }
    }

    var appExecutionRoute: NativeAppShellAppExecutionRoute {
        switch self {
        case .directMacPeer:
            return .directMacPeer
        case .windowsLoLa:
            return .windowsLoLa
        case .jackTrip:
            return .externalConnector(.jackTrip)
        case .ultraGrid:
            return .externalConnector(.mvtpUltraGrid)
        }
    }

    var supportsAppExecution: Bool {
        appExecutionRoute.supportsExecution
    }

    var externalConnectorKind: ExternalConnectorKind? {
        switch self {
        case .directMacPeer:
            return nil
        case .windowsLoLa:
            return .lola
        case .jackTrip:
            return .jackTrip
        case .ultraGrid:
            return .mvtpUltraGrid
        }
    }

    var unavailableAppReason: String? {
        appExecutionRoute.unavailableReason
    }

    var usesPostRunValidationStart: Bool {
        switch self {
        case .jackTrip, .ultraGrid:
            return true
        case .directMacPeer, .windowsLoLa:
            return false
        }
    }
}

public struct NativeAppShellExternalConnectorPeerFields: Codable, Equatable, Sendable {
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
        executablePath: String = ".build/debug/open-lola",
        localHost: String = "0.0.0.0",
        peerHost: String,
        role: ExternalConnectorSessionRole = .txRx,
        audioPort: UInt16,
        peerAudioPort: UInt16,
        videoPort: UInt16,
        mediaMode: ExternalConnectorMediaMode,
        durationSeconds: Int = 20,
        outputPath: String
    ) {
        self.executablePath = executablePath
        self.localHost = localHost
        self.peerHost = peerHost
        self.role = role
        self.audioPort = audioPort
        self.peerAudioPort = peerAudioPort
        self.videoPort = videoPort
        self.mediaMode = mediaMode
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
    }

    public static let jackTripAppDefault = NativeAppShellExternalConnectorPeerFields(
        peerHost: "203.0.113.10",
        audioPort: 4_464,
        peerAudioPort: 4_464,
        videoPort: 5_004,
        mediaMode: .audio,
        outputPath: "/tmp/open-lola-app/jacktrip-session.json"
    )

    public static let ultraGridAppDefault = NativeAppShellExternalConnectorPeerFields(
        peerHost: "198.51.100.10",
        audioPort: 5_006,
        peerAudioPort: 5_006,
        videoPort: 5_004,
        mediaMode: .audioVideo,
        outputPath: "/tmp/open-lola-app/ultragrid-session.json"
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
            "--video-port", "\(videoPort)",
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
            outputPath,
        ]
    }

    private func validateExternalConnectorPorts(connector: ExternalConnectorKind) throws {
        let ports: [(name: String, value: UInt16)] = [
            ("audioPort", audioPort),
            ("videoPort", videoPort),
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

public struct NativeAppShellWindowsLoLaPeerFields: Codable, Equatable, Sendable {
    public var executablePath: String
    public var localHost: String
    public var windowsHost: String
    public var role: ExternalConnectorSessionRole
    public var controlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var mediaMode: ExternalConnectorMediaMode
    public var payloadMode: LoLaVideoPayloadKind
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int
    public var durationSeconds: Int
    public var outputPath: String
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var channelCount: Int
    public var compression: Int
    public var bayer: Int

    public init(
        executablePath: String = ".build/debug/open-lola",
        localHost: String = "0.0.0.0",
        windowsHost: String = "192.0.2.30",
        role: ExternalConnectorSessionRole = .txRx,
        controlPort: UInt16 = 7_000,
        audioPort: UInt16 = 19_788,
        videoPort: UInt16 = 19_798,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        payloadMode: LoLaVideoPayloadKind = .generated,
        videoWidth: Int = 640,
        videoHeight: Int = 480,
        videoFrameRate: Int = 25,
        videoBitsPerPixel: Int = 8,
        durationSeconds: Int = 20,
        outputPath: String = "/tmp/open-lola-app/windows-lola-session.json",
        sampleRateHertz: Int = 44_100,
        framesPerPacket: Int = 64,
        channelCount: Int = 2,
        compression: Int = 0,
        bayer: Int = 0
    ) {
        self.executablePath = executablePath
        self.localHost = localHost
        self.windowsHost = windowsHost
        self.role = role
        self.controlPort = controlPort
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.mediaMode = mediaMode
        self.payloadMode = payloadMode
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoBitsPerPixel = videoBitsPerPixel
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.channelCount = channelCount
        self.compression = compression
        self.bayer = bayer
    }

    public static let appDefault = NativeAppShellWindowsLoLaPeerFields()

    public func mediaPacketCount() throws -> Int {
        let product = durationSeconds.multipliedReportingOverflow(by: videoFrameRate)
        guard !product.overflow else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("mediaPacketCount")
        }
        return product.partialValue
    }

    public func validateAppSettings() throws {
        try requireWindowsLoLaCommandText(executablePath, "executablePath")
        try requireWindowsLoLaCommandText(localHost, "localHost")
        try requireWindowsLoLaCommandText(windowsHost, "windowsHost")
        try requireWindowsLoLaCommandText(outputPath, "outputPath")
        try requirePositiveWindowsLoLaCommandValue(durationSeconds, "durationSeconds")
        try requirePositiveWindowsLoLaCommandValue(sampleRateHertz, "sampleRateHertz")
        try requirePositiveWindowsLoLaCommandValue(framesPerPacket, "framesPerPacket")
        try requireUInt32WindowsLoLaCommandValue(framesPerPacket, "framesPerPacket")
        try requirePositiveWindowsLoLaCommandValue(channelCount, "channelCount")
        try requirePositiveWindowsLoLaCommandValue(videoWidth, "videoWidth")
        try requirePositiveWindowsLoLaCommandValue(videoHeight, "videoHeight")
        try requirePositiveWindowsLoLaCommandValue(videoFrameRate, "videoFrameRate")
        try requirePositiveWindowsLoLaCommandValue(videoBitsPerPixel, "videoBitsPerPixel")
        try requireNonNegativeWindowsLoLaCommandValue(compression, "compression")
        try requireNonNegativeWindowsLoLaCommandValue(bayer, "bayer")
        _ = try mediaPacketCount()
        try validateWindowsLoLaPorts()
    }

    public func sessionArguments(executablePath resolvedExecutablePath: String, dryRun: Bool) throws -> [String] {
        try validateAppSettings()
        try requireWindowsLoLaCommandText(resolvedExecutablePath, "executablePath")
        let mediaPacketCount = try mediaPacketCount()
        return [
            resolvedExecutablePath,
            "external-connector-session-run",
            "--connector", "lola",
            "--role", role.rawValue,
            "--peer", windowsHost,
            "--local-host", localHost,
            "--output", outputPath,
            "--dry-run", dryRun ? "true" : "false",
            "--media", mediaMode.cliValue,
            "--control-transport", ExternalConnectorControlTransport.udp.rawValue,
            "--duration-seconds", "\(durationSeconds)",
            "--control-port", "\(controlPort)",
            "--audio-port", "\(audioPort)",
            "--video-port", "\(videoPort)",
            "--channels", "\(channelCount)",
            "--sample-rate", "\(sampleRateHertz)",
            "--frames", "\(framesPerPacket)",
            "--video-width", "\(videoWidth)",
            "--video-height", "\(videoHeight)",
            "--video-fps", "\(videoFrameRate)",
            "--video-bpp", "\(videoBitsPerPixel)",
            "--lola-video-payload", payloadMode.rawValue,
            "--video-compression", "\(compression)",
            "--video-bayer", "\(bayer)",
            "--media-packets", "\(mediaPacketCount)",
        ]
    }

    public func validatorArguments(executablePath resolvedExecutablePath: String) throws -> [String] {
        try validateAppSettings()
        try requireWindowsLoLaCommandText(resolvedExecutablePath, "executablePath")
        return [
            resolvedExecutablePath,
            "validate-external-connector-session-report",
            outputPath,
        ]
    }

    private func validateWindowsLoLaPorts() throws {
        let ports: [(name: String, value: UInt16)] = [
            ("controlPort", controlPort),
            ("audioPort", audioPort),
            ("videoPort", videoPort),
        ]
        var seen: Set<UInt16> = []
        for port in ports {
            guard port.value > 0 else {
                throw NativeAppShellSurfaceValidationError.invalidCommandField(port.name)
            }
            if !seen.insert(port.value).inserted {
                throw NativeAppShellSurfaceValidationError.duplicateCommandPort(port.name)
            }
        }
    }
}

public extension ExternalConnectorMediaMode {
    var cliValue: String {
        switch self {
        case .audio:
            return "audio"
        case .video:
            return "video"
        case .audioVideo:
            return "audio-video"
        }
    }
}

private func requireWindowsLoLaCommandText(_ value: String, _ field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requireExternalConnectorCommandText(_ value: String, _ field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requirePositiveWindowsLoLaCommandValue(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requirePositiveExternalConnectorCommandValue(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requireNonNegativeWindowsLoLaCommandValue(_ value: Int, _ field: String) throws {
    guard value >= 0 else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requireUInt32WindowsLoLaCommandValue(_ value: Int, _ field: String) throws {
    guard UInt32(exactly: value) != nil else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}
