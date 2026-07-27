// Builds local direct-peer CLI commands and operator handoff metadata from native shell settings.
import Foundation

/// Defines the validated fields for native app shell direct peer command fields.
public struct NativeAppShellDirectPeerCommandFields: Codable, Equatable, Sendable {
    public struct Execution: Equatable, Sendable {
        public let executablePath: String
        public let outputPath: String
        public let durationSeconds: Int
        public let timeoutSeconds: Int

        public init(executablePath: String = ".build/debug/open-lola", outputPath: String, durationSeconds: Int, timeoutSeconds: Int) {
            self.executablePath = executablePath
            self.outputPath = outputPath
            self.durationSeconds = durationSeconds
            self.timeoutSeconds = timeoutSeconds
        }
    }

    public struct Participants: Equatable, Sendable {
        public let role: DirectPeerSessionManualRole
        public let localPeer: String
        public let remotePeer: String

        public init(role: DirectPeerSessionManualRole, localPeer: String, remotePeer: String) {
            self.role = role
            self.localPeer = localPeer
            self.remotePeer = remotePeer
        }
    }

    public struct Network: Equatable, Sendable {
        public let localHost: String
        public let remoteHost: String
        public let controlPort: UInt16
        public let remoteControlPort: UInt16
        public let audioPort: UInt16
        public let videoPort: UInt16
        public let metricsPort: UInt16

        public init(
            localHost: String,
            remoteHost: String,
            controlPort: UInt16,
            remoteControlPort: UInt16,
            audioPort: UInt16,
            videoPort: UInt16,
            metricsPort: UInt16
        ) {
            self.localHost = localHost
            self.remoteHost = remoteHost
            self.controlPort = controlPort
            self.remoteControlPort = remoteControlPort
            self.audioPort = audioPort
            self.videoPort = videoPort
            self.metricsPort = metricsPort
        }
    }

    public struct Audio: Equatable, Sendable {
        public let channelCount: Int
        public let sampleRateHertz: Int
        public let framesPerPacket: Int
        public let sampleFormat: String
        public let transport: DirectPeerSessionAudioTransport

        public init(
            channelCount: Int,
            sampleRateHertz: Int,
            framesPerPacket: Int,
            sampleFormat: String,
            transport: DirectPeerSessionAudioTransport
        ) {
            self.channelCount = channelCount
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.sampleFormat = sampleFormat
            self.transport = transport
        }
    }

    public struct Video: Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let pixelFormat: String
        public let compression: DirectPeerSessionVideoCompression
        public let frameRate: Int
        public let streamID: Int

        public init(
            width: Int,
            height: Int,
            pixelFormat: String,
            compression: DirectPeerSessionVideoCompression = .raw,
            frameRate: Int,
            streamID: Int
        ) {
            self.width = width
            self.height = height
            self.pixelFormat = pixelFormat
            self.compression = compression
            self.frameRate = frameRate
            self.streamID = streamID
        }
    }

    public struct Runtime: Equatable, Sendable {
        public let avProfile: DirectPeerSessionAVProfile
        public let rxBufferProfile: RxBufferProfile
        public let preview: DirectPeerSessionPreviewMode

        public init(avProfile: DirectPeerSessionAVProfile, rxBufferProfile: RxBufferProfile, preview: DirectPeerSessionPreviewMode) {
            self.avProfile = avProfile
            self.rxBufferProfile = rxBufferProfile
            self.preview = preview
        }
    }

    public var executablePath: String
    public var outputPath: String
    public var durationSeconds: Int
    public var timeoutSeconds: Int
    public var avProfile: DirectPeerSessionAVProfile
    public var rxBufferProfile: RxBufferProfile
    public var preview: DirectPeerSessionPreviewMode
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
    public var channelCount: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: String
    public var audioTransport: DirectPeerSessionAudioTransport
    public var videoStreamID: Int
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoPixelFormat: String
    public var videoCompression: DirectPeerSessionVideoCompression
    public var videoFrameRate: Int

    public init(
        execution: Execution,
        participants: Participants,
        network: Network,
        audio: Audio,
        video: Video,
        runtime: Runtime
    ) {
        executablePath = execution.executablePath
        outputPath = execution.outputPath
        durationSeconds = execution.durationSeconds
        timeoutSeconds = execution.timeoutSeconds
        role = participants.role
        localPeer = participants.localPeer
        remotePeer = participants.remotePeer
        localHost = network.localHost
        remoteHost = network.remoteHost
        controlPort = network.controlPort
        remoteControlPort = network.remoteControlPort
        audioPort = network.audioPort
        videoPort = network.videoPort
        metricsPort = network.metricsPort
        channelCount = audio.channelCount
        sampleRateHertz = audio.sampleRateHertz
        framesPerPacket = audio.framesPerPacket
        sampleFormat = audio.sampleFormat
        audioTransport = audio.transport
        videoWidth = video.width
        videoHeight = video.height
        videoPixelFormat = video.pixelFormat
        videoCompression = video.compression
        videoFrameRate = video.frameRate
        videoStreamID = video.streamID
        avProfile = runtime.avProfile
        rxBufferProfile = runtime.rxBufferProfile
        preview = runtime.preview
    }

    public static let appDefault = NativeAppShellDirectPeerCommandFields(
        execution: .init(outputPath: "/tmp/open-lola-app/direct-p2p-session-local.json", durationSeconds: 30, timeoutSeconds: 30),
        participants: .init(role: .initiator, localPeer: "mac-a", remotePeer: "mac-b"),
        network: .init(localHost: "192.0.2.10", remoteHost: "192.0.2.20", controlPort: 57_000, remoteControlPort: 57_010, audioPort: 57_001, videoPort: 57_002, metricsPort: 57_003),
        audio: .init(
            channelCount: 64,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: "float32",
            transport: DirectPeerSessionAudioCompression.raw.audioTransport
        ),
        video: .init(width: 1_280, height: 720, pixelFormat: "bgra8", frameRate: 30, streamID: 101),
        runtime: .init(avProfile: .fastest, rxBufferProfile: .direct, preview: .on)
    )

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }
}

/// Stores CLI arguments and their display form for one local direct-peer command.
public struct NativeAppShellLocalDirectPeerCommand: Codable, Equatable, Sendable {
    public var arguments: [String]
    public var displayCommand: String

    public init(arguments: [String]) {
        self.arguments = arguments
        self.displayCommand = arguments.joined(separator: " ")
    }
}

/// Defines the validated fields for native app shell local command handoff.
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
        guard !command.arguments.isEmpty else {
            throw NativeAppShellSurfaceValidationError.emptyList("command.arguments")
        }
        try requireNativeAppSurfaceNonEmpty(command.displayCommand, "command.displayCommand")
        if remoteOrchestrationEnabled { throw NativeAppShellSurfaceValidationError.operatorEnablesRemoteOrchestration }
        if startsLongRunningProcess { throw NativeAppShellSurfaceValidationError.operatorStartsLongRunningProcess }
    }
}
