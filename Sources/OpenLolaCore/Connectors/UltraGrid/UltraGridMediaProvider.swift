// Produces validated PCM audio and video frames for UltraGrid compatibility transmission.
import Dispatch
import Foundation

/// Requires conformers to audioPCM, videoFrame operations for UltraGrid media providing.
public protocol UltraGridMediaProviding {
    var providerReport: ExternalConnectorMediaProviderReport { get }

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int
    ) throws -> Data

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int
    ) throws -> Data

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds: UInt64?
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

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        guard deadlineNanoseconds == nil else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "ultragrid-full-duplex-provider-without-deadline"
            )
        }
        return try audioPCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            framesPerPacket: framesPerPacket
        )
    }

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        guard deadlineNanoseconds == nil else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "ultragrid-full-duplex-provider-without-deadline"
            )
        }
        return try videoFrame(
            frameID: frameID,
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel
        )
    }
}

/// Defines the validated fields for UltraGrid synthetic media provider.
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

    public func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        try checkUltraGridProviderDeadline(deadlineNanoseconds)
        return try audioPCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            framesPerPacket: framesPerPacket
        )
    }

    public func videoFrame(frameID _: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        let byteCount = max(1, width * height * max(1, bitsPerPixel / 8))
        return Data((0..<byteCount).map { UInt8($0 & 0xff) })
    }

    public func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        try checkUltraGridProviderDeadline(deadlineNanoseconds)
        return try videoFrame(
            frameID: frameID,
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel
        )
    }
}

protocol UltraGridMediaProviderLifecycle: ExternalConnectorLifecycle {
    func start() throws
}

final class UltraGridSessionMediaProvider:
    UltraGridMediaProviding,
    UltraGridMediaProviderLifecycle {
    private enum AudioSource {
        case synthetic
        case fixture(Data)
        case coreAudio

        var reportLabel: String {
            switch self {
            case .synthetic:
                "synthetic"
            case .fixture:
                "fixture"
            case .coreAudio:
                "coreaudio-live"
            }
        }

        var isLive: Bool {
            if case .coreAudio = self {
                return true
            }
            return false
        }
    }

    private enum VideoSource {
        case synthetic
        case fixture(Data)
        case avFoundationRaw8

        var reportLabel: String {
            switch self {
            case .synthetic:
                "synthetic"
            case .fixture:
                "fixture"
            case .avFoundationRaw8:
                "avfoundation-raw8-live"
            }
        }

        var isLive: Bool {
            if case .avFoundationRaw8 = self {
                return true
            }
            return false
        }
    }

    private let configuration: ExternalConnectorSessionConfiguration
    private let audioSource: AudioSource
    private let videoSource: VideoSource
    private let report: ExternalConnectorMediaProviderReport
    private var audioBridge: LoLaCoreAudioLiveBridge?
    private var liveVideoSource: (any LoLaLiveRaw8VideoSource)?

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        self.configuration = configuration
        self.audioSource = try Self.audioSource(configuration)
        self.videoSource = try Self.videoSource(configuration)
        self.report = Self.providerReport(audioSource: audioSource, videoSource: videoSource)
    }

    var providerReport: ExternalConnectorMediaProviderReport { report }

    func start() throws {
        do {
            if case .coreAudio = audioSource {
                audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
                guard let audioBridge else {
                    throw ExternalConnectorSessionError.missingRequiredArgument(
                        "--audio-capture coreaudio:<device-uid>"
                    )
                }
                try audioBridge.start()
            }
            if case .avFoundationRaw8 = videoSource {
                let source = LoLaAVFoundationLiveRaw8Source(configuration: liveVideoConfiguration())
                try source.start()
                liveVideoSource = source
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        liveVideoSource?.stop()
        liveVideoSource = nil
        audioBridge?.stop()
        audioBridge = nil
    }

    func audioPCM(sequenceNumber: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        try audioPCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            framesPerPacket: framesPerPacket,
            deadlineNanoseconds: nil
        )
    }

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        try checkUltraGridProviderDeadline(deadlineNanoseconds)
        switch audioSource {
        case .synthetic:
            return try UltraGridSyntheticMediaProvider().audioPCM(
                sequenceNumber: sequenceNumber,
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
            if let payload = try audioBridge.nextLoLaAudioPayload(
                until: deadlineNanoseconds.map(DispatchTime.init(uptimeNanoseconds:))
                    ?? .now() + .seconds(1)
            ) {
                return payload
            }
            throw ExternalConnectorSessionError.socketFailed(
                "Core Audio capture produced no UltraGrid audio payload before timeout"
            )
        }
    }

    func videoFrame(frameID: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        try videoFrame(
            frameID: frameID,
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel,
            deadlineNanoseconds: nil
        )
    }

    func videoFrame(
        frameID: Int,
        width _: Int,
        height _: Int,
        bitsPerPixel _: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        try checkUltraGridProviderDeadline(deadlineNanoseconds)
        switch videoSource {
        case .synthetic:
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: frameID
            )
        case let .fixture(data):
            return data
        case .avFoundationRaw8:
            guard let payload = try liveVideoSource?.nextPayload(
                until: try ultraGridProviderDeadlineDate(deadlineNanoseconds)
            ) else {
                throw LoLaVideoPayloadError.captureUnavailable
            }
            return payload
        }
    }

    private func liveVideoConfiguration() -> ExternalConnectorSessionConfiguration {
        var liveConfiguration = configuration
        if let videoCapture = configuration.videoCapture,
           videoCapture.hasPrefix("avfoundation:") {
            liveConfiguration.videoCapture = String(videoCapture.dropFirst("avfoundation:".count))
        } else if configuration.videoCapture == "avfoundation-raw8" {
            liveConfiguration.videoCapture = "auto"
        }
        liveConfiguration.lolaVideoPayload = .avFoundationRaw8
        return liveConfiguration
    }

    private static func audioSource(_ configuration: ExternalConnectorSessionConfiguration) throws -> AudioSource {
        switch try parseExternalConnectorAudioCaptureSource(configuration) {
        case .synthetic:
            return .synthetic
        case let .fixture(data):
            return .fixture(data)
        case .coreAudio:
            return .coreAudio
        }
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
        let hasLive = audioSource.isLive || videoSource.isLive
        return ExternalConnectorMediaProviderReport(
            audioSource: audioSource.reportLabel,
            videoSource: videoSource.reportLabel,
            observedEvidenceClasses: hasLive ? [.liveDevice] : [.synthetic],
            notes: "UltraGrid public session media provider selection for PT21 audio and PT20 raw-video packetization."
        )
    }
}

private func checkUltraGridProviderDeadline(_ deadlineNanoseconds: UInt64?) throws {
    guard let deadlineNanoseconds else { return }
    guard DispatchTime.now().uptimeNanoseconds < deadlineNanoseconds else {
        throw UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)
    }
}

private func ultraGridProviderDeadlineDate(_ deadlineNanoseconds: UInt64?) throws -> Date {
    guard let deadlineNanoseconds else {
        return Date().addingTimeInterval(1)
    }
    try checkUltraGridProviderDeadline(deadlineNanoseconds)
    let remaining = deadlineNanoseconds - DispatchTime.now().uptimeNanoseconds
    return Date().addingTimeInterval(Double(remaining) / 1_000_000_000)
}
