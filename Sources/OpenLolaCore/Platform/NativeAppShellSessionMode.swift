// Maps native-shell session modes to settings visibility, execution routes, and peer configuration.
import Foundation

/// Enumerates the supported operating modes for native app shell session.
public enum NativeAppShellSessionMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case directMacPeer
    case windowsLoLa
    case jackTrip
    case ultraGrid
}

/// Defines the supported choices for native app shell app execution route.
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

/// Enumerates the supported operating modes for native app shell control.
public enum NativeAppShellControlMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case normal
    case advanced
}

/// Defines the supported choices for native app shell settings group.
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

/// Defines the values accepted for native app shell settings visibility.
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
            return "JackTrip native connector flow. The app launches the Open LoLa "
                + "external connector runner and validates its session report."
        case .ultraGrid:
            return "UltraGrid native connector flow. The app launches the Open LoLa "
                + "external connector runner and validates its session report."
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

/// Defines the validated fields for native app shell windows LoLa peer fields.
public struct NativeAppShellWindowsLoLaPeerFields: Codable, Equatable, Sendable {
    public struct Connection: Equatable, Sendable {
        public let executablePath: String
        public let localHost: String
        public let windowsHost: String
        public let role: ExternalConnectorSessionRole

        public init(executablePath: String, localHost: String, windowsHost: String, role: ExternalConnectorSessionRole) {
            self.executablePath = executablePath
            self.localHost = localHost
            self.windowsHost = windowsHost
            self.role = role
        }
    }

    public struct Ports: Equatable, Sendable {
        public let control: UInt16
        public let audio: UInt16
        public let video: UInt16

        public init(control: UInt16, audio: UInt16, video: UInt16) {
            self.control = control
            self.audio = audio
            self.video = video
        }
    }

    public struct Video: Equatable, Sendable {
        public let mediaMode: ExternalConnectorMediaMode
        public let payloadMode: LoLaVideoPayloadKind
        public let width: Int
        public let height: Int
        public let frameRate: Int
        public let bitsPerPixel: Int

        public init(
            mediaMode: ExternalConnectorMediaMode,
            payloadMode: LoLaVideoPayloadKind,
            width: Int,
            height: Int,
            frameRate: Int,
            bitsPerPixel: Int
        ) {
            self.mediaMode = mediaMode
            self.payloadMode = payloadMode
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.bitsPerPixel = bitsPerPixel
        }
    }

    public struct Audio: Equatable, Sendable {
        public let sampleRateHertz: Int
        public let framesPerPacket: Int
        public let channelCount: Int
        public let compression: Int

        public init(sampleRateHertz: Int, framesPerPacket: Int, channelCount: Int, compression: Int) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.channelCount = channelCount
            self.compression = compression
        }
    }

    public struct Run: Equatable, Sendable {
        public let durationSeconds: Int
        public let outputPath: String
        public let bayer: Int

        public init(durationSeconds: Int, outputPath: String, bayer: Int) {
            self.durationSeconds = durationSeconds
            self.outputPath = outputPath
            self.bayer = bayer
        }
    }

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

    public init(connection: Connection, ports: Ports, video: Video, audio: Audio, run: Run) {
        executablePath = connection.executablePath
        localHost = connection.localHost
        windowsHost = connection.windowsHost
        role = connection.role
        controlPort = ports.control
        audioPort = ports.audio
        videoPort = ports.video
        mediaMode = video.mediaMode
        payloadMode = video.payloadMode
        videoWidth = video.width
        videoHeight = video.height
        videoFrameRate = video.frameRate
        videoBitsPerPixel = video.bitsPerPixel
        durationSeconds = run.durationSeconds
        outputPath = run.outputPath
        sampleRateHertz = audio.sampleRateHertz
        framesPerPacket = audio.framesPerPacket
        channelCount = audio.channelCount
        compression = audio.compression
        bayer = run.bayer
    }

    public static let appDefault = NativeAppShellWindowsLoLaPeerFields(
        connection: .init(executablePath: ".build/debug/open-lola", localHost: "0.0.0.0", windowsHost: "192.0.2.30", role: .txRx),
        ports: .init(control: 7_000, audio: 19_788, video: 19_798),
        video: .init(mediaMode: .audioVideo, payloadMode: .generated, width: 640, height: 480, frameRate: 25, bitsPerPixel: 8),
        audio: .init(sampleRateHertz: 44_100, framesPerPacket: 64, channelCount: 2, compression: 0),
        run: .init(durationSeconds: 20, outputPath: "/tmp/open-lola-app/windows-lola-session.json", bayer: 0)
    )

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
            "--media-packets", "\(mediaPacketCount)"
        ]
    }

    public func validatorArguments(executablePath resolvedExecutablePath: String) throws -> [String] {
        try validateAppSettings()
        try requireWindowsLoLaCommandText(resolvedExecutablePath, "executablePath")
        return [
            resolvedExecutablePath,
            "validate-external-connector-session-report",
            outputPath
        ]
    }

    private func validateWindowsLoLaPorts() throws {
        let ports: [(name: String, value: UInt16)] = [
            ("controlPort", controlPort),
            ("audioPort", audioPort),
            ("videoPort", videoPort)
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

private func requirePositiveWindowsLoLaCommandValue(_ value: Int, _ field: String) throws {
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
