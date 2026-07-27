// Declares direct-peer session configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerTwoPeerRunPlanError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidPositiveInt(String)
    case invalidEnumValue(String)
    case invalidHost(String)
    case invalidPortBase(String)
    case emptyField(String)
    case emptyList(String)
    case mismatchedReportReferences
    case passRequiresMeasuredDirectPeerReports
    case duplicatePeerID(String)
    case mismatchedReceiveProof(String)
    case passRequiresTwoPassingReports
    case passRequiresTwoReceiveProofArtifacts
    case missingCommandArgument(String)
}

/// Represents DirectPeerTwoPeerRunPlanPeer values used by direct peer sessions.
public struct DirectPeerTwoPeerRunPlanPeer: Codable, Equatable, Sendable {
    public var peerID: String
    public var host: String
    public var portBase: UInt16
    public var inputUID: String
    public var outputUID: String
    public var videoDeviceID: String

    public var audioPort: UInt16 { portBase + 1 }
    public var videoPort: UInt16 { portBase + 2 }
    public var metricsPort: UInt16 { portBase + 3 }

    public init(
        peerID: String,
        host: String,
        portBase: UInt16,
        inputUID: String,
        outputUID: String,
        videoDeviceID: String
    ) {
        self.peerID = peerID
        self.host = host
        self.portBase = portBase
        self.inputUID = inputUID
        self.outputUID = outputUID
        self.videoDeviceID = videoDeviceID
    }
}

/// Configures DirectPeerTwoPeerRunPlanConfiguration so callers supply explicit inputs before starting direct peer sessions.
public struct DirectPeerTwoPeerRunPlanConfiguration: Codable, Equatable, Sendable {
    public struct Paths: Codable, Equatable, Sendable {
        public var outputPath: String
        public var runDirectory: String
        public var executablePath: String

        public init(outputPath: String, runDirectory: String, executablePath: String = "open-lola") {
            self.outputPath = outputPath
            self.runDirectory = runDirectory
            self.executablePath = executablePath
        }
    }

    public struct Peers: Codable, Equatable, Sendable {
        public var macA: DirectPeerTwoPeerRunPlanPeer
        public var macB: DirectPeerTwoPeerRunPlanPeer

        public init(macA: DirectPeerTwoPeerRunPlanPeer, macB: DirectPeerTwoPeerRunPlanPeer) {
            self.macA = macA
            self.macB = macB
        }
    }

    public struct Audio: Codable, Equatable, Sendable {
        public var channelCount: Int
        public var sampleRateHertz: Int
        public var framesPerPacket: Int
        public var sampleFormat: String
        public var transport: DirectPeerSessionAudioTransport

        public init(
            channelCount: Int = 64,
            sampleRateHertz: Int = 48_000,
            framesPerPacket: Int = 32,
            sampleFormat: String = "float32",
            transport: DirectPeerSessionAudioTransport? = nil,
            compression: DirectPeerSessionAudioCompression = .raw
        ) {
            self.channelCount = channelCount
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.sampleFormat = sampleFormat
            self.transport = transport ?? compression.audioTransport
        }
    }

    public struct Video: Codable, Equatable, Sendable {
        public var width: Int
        public var height: Int
        public var pixelFormat: String
        public var compression: DirectPeerSessionVideoCompression
        public var frameRate: Int

        public init(
            width: Int = 1_280,
            height: Int = 720,
            pixelFormat: String = "bgra8",
            compression: DirectPeerSessionVideoCompression = .raw,
            frameRate: Int = 30
        ) {
            self.width = width
            self.height = height
            self.pixelFormat = pixelFormat
            self.compression = compression
            self.frameRate = frameRate
        }
    }

    public struct Runtime: Codable, Equatable, Sendable {
        public var durationSeconds: Int
        public var avProfile: DirectPeerSessionAVProfile
        public var rxBufferProfile: RxBufferProfile
        public var preview: DirectPeerSessionPreviewMode
        public var timeoutSeconds: Int

        public init(
            durationSeconds: Int,
            avProfile: DirectPeerSessionAVProfile = .balanced,
            rxBufferProfile: RxBufferProfile? = nil,
            preview: DirectPeerSessionPreviewMode = .on,
            timeoutSeconds: Int = 30
        ) {
            self.durationSeconds = durationSeconds
            self.avProfile = avProfile
            self.rxBufferProfile = rxBufferProfile ?? avProfile.defaultRXBufferProfile
            self.preview = preview
            self.timeoutSeconds = timeoutSeconds
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var paths: Paths
        public var peers: Peers
        public var audio: Audio
        public var video: Video
        public var runtime: Runtime

        public init(paths: Paths, peers: Peers, audio: Audio, video: Video, runtime: Runtime) {
            self.paths = paths
            self.peers = peers
            self.audio = audio
            self.video = video
            self.runtime = runtime
        }
    }

    public var outputPath: String
    public var runDirectory: String
    public var executablePath: String
    public var macA: DirectPeerTwoPeerRunPlanPeer
    public var macB: DirectPeerTwoPeerRunPlanPeer
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
    public var avProfile: DirectPeerSessionAVProfile
    public var rxBufferProfile: RxBufferProfile
    public var preview: DirectPeerSessionPreviewMode
    public var timeoutSeconds: Int

    public init(_ input: Input) {
        self.outputPath = input.paths.outputPath
        self.runDirectory = input.paths.runDirectory
        self.executablePath = input.paths.executablePath
        self.macA = input.peers.macA
        self.macB = input.peers.macB
        self.durationSeconds = input.runtime.durationSeconds
        self.channelCount = input.audio.channelCount
        self.sampleRateHertz = input.audio.sampleRateHertz
        self.framesPerPacket = input.audio.framesPerPacket
        self.sampleFormat = input.audio.sampleFormat
        self.audioTransport = input.audio.transport
        self.videoWidth = input.video.width
        self.videoHeight = input.video.height
        self.videoPixelFormat = input.video.pixelFormat
        self.videoCompression = input.video.compression
        self.videoFrameRate = input.video.frameRate
        self.avProfile = input.runtime.avProfile
        self.rxBufferProfile = input.runtime.rxBufferProfile
        self.preview = input.runtime.preview
        self.timeoutSeconds = input.runtime.timeoutSeconds
    }

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }

    public static func parse(_ arguments: [String]) throws -> DirectPeerTwoPeerRunPlanConfiguration {
        let values = try directPeerTwoPeerValues(arguments)
        let avProfile = try directPeerTwoPeerAVProfile(values["--av-profile"])
        let macA = try directPeerTwoPeerPeer(prefix: "mac-a", values)
        let macB = try directPeerTwoPeerPeer(prefix: "mac-b", values)
        try directPeerTwoPeerValidateNetworkShape(local: macA, remote: macB)
        let input = Input(
            paths: try parsedPaths(values),
            peers: Peers(macA: macA, macB: macB),
            audio: try parsedAudio(values),
            video: try parsedVideo(values),
            runtime: try parsedRuntime(values, avProfile: avProfile)
        )
        return DirectPeerTwoPeerRunPlanConfiguration(input)
    }

    private static func parsedPaths(_ values: [String: String]) throws -> Paths {
        Paths(
            outputPath: try directPeerTwoPeerRequired("--output", values),
            runDirectory: try directPeerTwoPeerRequired("--run-dir", values),
            executablePath: values["--executable"] ?? "open-lola"
        )
    }

    private static func parsedAudio(_ values: [String: String]) throws -> Audio {
        let audioTransport = try directPeerTwoPeerAudioTransport(values)
        let sampleRateHertz = try directPeerTwoPeerOptionalPositiveInt("--sample-rate", values) ?? 48_000
        let framesPerPacket = try directPeerTwoPeerOptionalPositiveInt("--frames", values) ?? 32
        let channelCount = try directPeerTwoPeerOptionalPositiveInt("--channels", values) ?? 64
        let sampleFormatText = values["--sample-format"] ?? "float32"
        let sampleFormat = try directPeerTwoPeerSampleFormat(sampleFormatText)
        try directPeerTwoPeerValidateAudioTransportShape(
            audioTransport,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormat,
            channelCount: channelCount
        )
        return Audio(
            channelCount: channelCount,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: sampleFormatText,
            transport: audioTransport
        )
    }

    private static func parsedVideo(_ values: [String: String]) throws -> Video {
        let videoPixelFormatText = values["--video-pixel-format"] ?? "bgra8"
        return Video(
            width: try directPeerTwoPeerOptionalPositiveInt("--video-width", values) ?? 1_280,
            height: try directPeerTwoPeerOptionalPositiveInt("--video-height", values) ?? 720,
            pixelFormat: try directPeerTwoPeerVideoPixelFormat(videoPixelFormatText),
            compression: try directPeerTwoPeerVideoCompression(values["--video-compression"]),
            frameRate: try directPeerTwoPeerOptionalPositiveInt("--video-frame-rate", values) ?? 30
        )
    }

    private static func parsedRuntime(
        _ values: [String: String],
        avProfile: DirectPeerSessionAVProfile
    ) throws -> Runtime {
        Runtime(
            durationSeconds: try directPeerTwoPeerPositiveInt("--duration-seconds", values),
            avProfile: avProfile,
            rxBufferProfile: try directPeerTwoPeerRXBufferProfile(
                values["--rx-buffer-profile"],
                avProfile: avProfile
            ),
            preview: try directPeerTwoPeerPreview(values["--preview"]),
            timeoutSeconds: try directPeerTwoPeerOptionalPositiveInt("--timeout-seconds", values) ?? 30
        )
    }
}
