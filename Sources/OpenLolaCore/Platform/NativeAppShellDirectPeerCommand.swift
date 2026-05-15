import Foundation

public struct NativeAppShellDirectPeerCommandFields: Codable, Equatable, Sendable {
    public var executablePath: String
    public var role: DirectPeerSessionManualRole
    public var localPeer: String
    public var remotePeer: String
    public var localHost: String
    public var remoteHost: String
    public var controlPort: UInt16
    public var remoteControlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var metricsPort: UInt16
    public var outputPath: String
    public var durationSeconds: Int
    public var channelCount: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: String
    public var audioTransport: DirectPeerSessionAudioTransport
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoPixelFormat: String
    public var videoCompression: DirectPeerSessionVideoCompression
    public var videoFrameRate: Int
    public var videoStreamID: Int
    public var avProfile: DirectPeerSessionAVProfile
    public var rxBufferProfile: RxBufferProfile
    public var preview: DirectPeerSessionPreviewMode
    public var timeoutSeconds: Int

    public init(
        executablePath: String = ".build/debug/open-lola",
        role: DirectPeerSessionManualRole,
        localPeer: String,
        remotePeer: String,
        localHost: String,
        remoteHost: String,
        controlPort: UInt16,
        remoteControlPort: UInt16,
        audioPort: UInt16,
        videoPort: UInt16,
        metricsPort: UInt16,
        outputPath: String,
        durationSeconds: Int,
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormat: String,
        audioTransport: DirectPeerSessionAudioTransport? = nil,
        audioCompression: DirectPeerSessionAudioCompression = .raw,
        videoWidth: Int,
        videoHeight: Int,
        videoPixelFormat: String,
        videoCompression: DirectPeerSessionVideoCompression = .raw,
        videoFrameRate: Int,
        videoStreamID: Int,
        avProfile: DirectPeerSessionAVProfile,
        rxBufferProfile: RxBufferProfile? = nil,
        preview: DirectPeerSessionPreviewMode,
        timeoutSeconds: Int
    ) {
        self.executablePath = executablePath
        self.role = role
        self.localPeer = localPeer
        self.remotePeer = remotePeer
        self.localHost = localHost
        self.remoteHost = remoteHost
        self.controlPort = controlPort
        self.remoteControlPort = remoteControlPort
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.metricsPort = metricsPort
        self.outputPath = outputPath
        self.durationSeconds = durationSeconds
        self.channelCount = channelCount
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.sampleFormat = sampleFormat
        self.audioTransport = audioTransport ?? audioCompression.audioTransport
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoPixelFormat = videoPixelFormat
        self.videoCompression = videoCompression
        self.videoFrameRate = videoFrameRate
        self.videoStreamID = videoStreamID
        self.avProfile = avProfile
        self.rxBufferProfile = rxBufferProfile ?? avProfile.defaultRXBufferProfile
        self.preview = preview
        self.timeoutSeconds = timeoutSeconds
    }

    public static let appDefault = NativeAppShellDirectPeerCommandFields(
        role: .initiator,
        localPeer: "mac-a",
        remotePeer: "mac-b",
        localHost: "192.0.2.10",
        remoteHost: "192.0.2.20",
        controlPort: 57_000,
        remoteControlPort: 57_010,
        audioPort: 57_001,
        videoPort: 57_002,
        metricsPort: 57_003,
        outputPath: "/tmp/open-lola-app/direct-p2p-session-local.json",
        durationSeconds: 30,
        channelCount: 64,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        sampleFormat: "float32",
        videoWidth: 1_280,
        videoHeight: 720,
        videoPixelFormat: "bgra8",
        videoFrameRate: 30,
        videoStreamID: 101,
        avProfile: .fastest,
        rxBufferProfile: .direct,
        preview: .on,
        timeoutSeconds: 30
    )

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }
}

public struct NativeAppShellLocalDirectPeerCommand: Codable, Equatable, Sendable {
    public var arguments: [String]
    public var displayCommand: String

    public init(arguments: [String]) {
        self.arguments = arguments
        self.displayCommand = arguments.joined(separator: " ")
    }
}

public struct NativeAppShellLocalCommandHandoff: Codable, Equatable, Sendable {
    public var intent: NativeAppShellOperatorCommandIntent
    public var command: NativeAppShellLocalDirectPeerCommand
    public var remoteOrchestrationEnabled: Bool
    public var startsLongRunningProcess: Bool

    public init(
        intent: NativeAppShellOperatorCommandIntent,
        command: NativeAppShellLocalDirectPeerCommand,
        remoteOrchestrationEnabled: Bool,
        startsLongRunningProcess: Bool
    ) {
        self.intent = intent
        self.command = command
        self.remoteOrchestrationEnabled = remoteOrchestrationEnabled
        self.startsLongRunningProcess = startsLongRunningProcess
    }

    public func validate() throws {
        guard !command.arguments.isEmpty else { throw NativeAppShellSurfaceValidationError.emptyList("command.arguments") }
        try requireNativeAppSurfaceNonEmpty(command.displayCommand, "command.displayCommand")
        if remoteOrchestrationEnabled { throw NativeAppShellSurfaceValidationError.operatorEnablesRemoteOrchestration }
        if startsLongRunningProcess { throw NativeAppShellSurfaceValidationError.operatorStartsLongRunningProcess }
    }
}
