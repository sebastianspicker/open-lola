import Foundation

public protocol UltraGridMediaProviding {
    var providerReport: ExternalConnectorMediaProviderReport { get }

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int
    ) throws -> Data

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int
    ) throws -> Data
}

public extension UltraGridMediaProviding {
    var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "injected-fixture",
            videoSource: "injected-fixture",
            observedEvidenceClasses: [.synthetic],
            notes: "Injected deterministic UltraGrid media provider."
        )
    }
}

public struct UltraGridSyntheticMediaProvider: UltraGridMediaProviding {
    public init() {}

    public var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "synthetic",
            observedEvidenceClasses: [.synthetic],
            notes: "Generated UltraGrid PT21 audio and PT20 raw-video payload bytes."
        )
    }

    public func audioPCM(sequenceNumber _: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        Data(repeating: 0, count: max(1, channels * framesPerPacket * MemoryLayout<Int16>.size))
    }

    public func videoFrame(frameID _: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        let byteCount = max(1, width * height * max(1, bitsPerPixel / 8))
        return Data((0..<byteCount).map { UInt8($0 & 0xff) })
    }
}

protocol UltraGridMediaProviderLifecycle {
    func start() throws
    func stop()
}

final class UltraGridSessionMediaProvider: UltraGridMediaProviding, UltraGridMediaProviderLifecycle {
    private enum AudioSource {
        case synthetic
        case fixture(Data)
        case coreAudio
    }

    private enum VideoSource {
        case synthetic
        case fixture(Data)
        case avFoundationRaw8
    }

    private let configuration: ExternalConnectorSessionConfiguration
    private let audioSource: AudioSource
    private let videoSource: VideoSource
    private let report: ExternalConnectorMediaProviderReport
    private var audioBridge: LoLaCoreAudioLiveBridge?
    private var capturedVideoFrames: [Data]?

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        self.configuration = configuration
        self.audioSource = try Self.audioSource(configuration)
        self.videoSource = try Self.videoSource(configuration)
        self.report = Self.providerReport(audioSource: audioSource, videoSource: videoSource)
    }

    var providerReport: ExternalConnectorMediaProviderReport { report }

    func start() throws {
        if case .coreAudio = audioSource {
            audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            guard let audioBridge else {
                throw ExternalConnectorSessionError.missingRequiredArgument("--audio-capture coreaudio:<device-uid>")
            }
            try audioBridge.start()
        }
    }

    func stop() {
        audioBridge?.stop()
        audioBridge = nil
    }

    func audioPCM(sequenceNumber _: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        switch audioSource {
        case .synthetic:
            return try UltraGridSyntheticMediaProvider().audioPCM(
                sequenceNumber: 0,
                channels: channels,
                framesPerPacket: framesPerPacket
            )
        case let .fixture(data):
            return repeatedFixtureData(
                data,
                byteCount: max(1, channels * framesPerPacket * MemoryLayout<Int16>.size)
            )
        case .coreAudio:
            guard let audioBridge else {
                throw ExternalConnectorSessionError.socketFailed("Core Audio UltraGrid provider was not started")
            }
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline {
                if let payload = try audioBridge.nextLoLaAudioPayload() {
                    return payload
                }
                Thread.sleep(forTimeInterval: 0.001)
            }
            throw ExternalConnectorSessionError.socketFailed(
                "Core Audio capture produced no UltraGrid audio payload before timeout"
            )
        }
    }

    func videoFrame(frameID: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        switch videoSource {
        case .synthetic:
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: frameID
            )
        case let .fixture(data):
            return data
        case .avFoundationRaw8:
            let frames = try avFoundationRaw8Frames()
            return frames[min(frameID, frames.count - 1)]
        }
    }

    private func avFoundationRaw8Frames() throws -> [Data] {
        if let capturedVideoFrames {
            return capturedVideoFrames
        }
        var liveConfiguration = configuration
        if let videoCapture = configuration.videoCapture,
           videoCapture.hasPrefix("avfoundation:") {
            liveConfiguration.videoCapture = String(videoCapture.dropFirst("avfoundation:".count))
        }
        liveConfiguration.lolaVideoPayload = .avFoundationRaw8
        let frames = try LoLaVideoPayloadProvider.payloads(
            configuration: liveConfiguration,
            frameCount: max(1, configuration.mediaPacketCount)
        )
        capturedVideoFrames = frames
        return frames
    }

    private static func audioSource(_ configuration: ExternalConnectorSessionConfiguration) throws -> AudioSource {
        guard let value = configuration.audioCapture else {
            return .synthetic
        }
        if value.hasPrefix("fixture:") {
            return .fixture(try parseFixtureBytes(value, field: "audioCapture"))
        }
        if value.hasPrefix("coreaudio:") {
            return .coreAudio
        }
        return .synthetic
    }

    private static func videoSource(_ configuration: ExternalConnectorSessionConfiguration) throws -> VideoSource {
        if let value = configuration.videoCapture {
            if value.hasPrefix("fixture:") {
                return .fixture(try parseFixtureBytes(value, field: "videoCapture"))
            }
            if value == "avfoundation-raw8" || value == "auto" || value.hasPrefix("avfoundation:") {
                return .avFoundationRaw8
            }
        }
        if configuration.lolaVideoPayload == .avFoundationRaw8 {
            return .avFoundationRaw8
        }
        return .synthetic
    }

    private static func providerReport(
        audioSource: AudioSource,
        videoSource: VideoSource
    ) -> ExternalConnectorMediaProviderReport {
        let audio = switch audioSource {
        case .synthetic:
            "synthetic"
        case .fixture:
            "fixture"
        case .coreAudio:
            "coreaudio-live"
        }
        let video = switch videoSource {
        case .synthetic:
            "synthetic"
        case .fixture:
            "fixture"
        case .avFoundationRaw8:
            "avfoundation-raw8-live"
        }
        let hasLive: Bool = {
            if case .coreAudio = audioSource {
                return true
            }
            if case .avFoundationRaw8 = videoSource {
                return true
            }
            return false
        }()
        return ExternalConnectorMediaProviderReport(
            audioSource: audio,
            videoSource: video,
            observedEvidenceClasses: hasLive ? [.liveDevice] : [.synthetic],
            notes: "UltraGrid public session media provider selection for PT21 audio and PT20 raw-video packetization."
        )
    }
}
