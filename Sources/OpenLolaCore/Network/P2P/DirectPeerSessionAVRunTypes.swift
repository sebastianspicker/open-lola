// Declares direct-peer session configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Selects which media planes a direct-peer session activates.
public enum DirectPeerSessionMediaMode: String, Codable, Equatable, Sendable {
    case audio
    case audioVideo = "audio-video"
}

/// Selects coordinated latency and quality defaults for a direct-peer A/V session.
public enum DirectPeerSessionAVProfile: String, Codable, Equatable, Sendable {
    case balanced
    case fastest
}

/// Selects how received video is previewed during a direct-peer session.
public enum DirectPeerSessionPreviewMode: String, Codable, Equatable, Sendable {
 // swiftlint:disable:next identifier_name
 case on
    case off
}

/// Defines DirectPeerSessionAVRunQualityPolicy acceptance rules so callers receive deterministic pass or failure evidence.
public enum DirectPeerSessionAVRunQualityPolicy: String, Codable, Equatable, Sendable {
    case structural
    case requireUsefulMedia = "require-useful-media"
}

/// Selects the video payload encoding used by a direct-peer session.
public enum DirectPeerSessionVideoCompression: String, Codable, Equatable, Sendable {
    case raw
    case jpegXS = "jpeg-xs"

    public var payloadType: SessionPayloadType {
        switch self {
        case .raw:
            .videoRawFrameFragment
        case .jpegXS:
            .videoJpegXSFrameFragment
        }
    }

    public var transportFormat: VideoTransportFormat {
        switch self {
        case .raw:
            .rawFrameFragment
        case .jpegXS:
            .jpegXSFrameFragment
        }
    }
}

/// Selects the audio payload encoding used by a direct-peer session.
public enum DirectPeerSessionAudioCompression: String, Codable, Equatable, Sendable {
    case raw
    case opusCELTLowDelay = "opus-celt-ld"

    public var audioTransport: DirectPeerSessionAudioTransport {
        switch self {
        case .raw:
            .openLolaRaw
        case .opusCELTLowDelay:
            .openLolaOpusCeltLowDelay
        }
    }

    public var payloadType: SessionPayloadType {
        audioTransport.payloadType
    }
}

/// Provides the DirectPeerSessionAudioTransport boundary that isolates I/O lifetime from direct peer sessions policy.
public enum DirectPeerSessionAudioTransport: String, Codable, Equatable, Sendable {
    case openLolaRaw = "openlola-raw"
    case openLolaOpusCeltLowDelay = "openlola-opus-celt-ld"
    case aes67ST2110L24 = "aes67-st2110-l24"

    public var payloadType: SessionPayloadType {
        switch self {
        case .openLolaRaw:
            .audioPcmV2
        case .openLolaOpusCeltLowDelay:
            .audioOpusCeltLowDelayFrame
        case .aes67ST2110L24:
            .audioRtpL24
        }
    }

    public var legacyAudioCompression: DirectPeerSessionAudioCompression? {
        switch self {
        case .openLolaRaw:
            .raw
        case .openLolaOpusCeltLowDelay:
            .opusCELTLowDelay
        case .aes67ST2110L24:
            nil
        }
    }
}

/// Selects where runtime audio and video frames are sourced.
public enum DirectPeerSessionAVMediaSourceMode: String, Codable, Equatable, Sendable {
    case production
    case syntheticFixture
}

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerSessionAVRuntimeError: Error, Equatable, Sendable {
    case inputOutputUIDMismatch(input: String, output: String)
    case missingAudioDeviceUID
    case missingOutputDeviceUID
    case unsupportedRXBufferProfile(avProfile: DirectPeerSessionAVProfile, rxBufferProfile: RxBufferProfile)
    case avFoundationPermission(AVFoundationPermissionStatus)
    case avFoundationDeviceUnavailable(String)
    case avFoundationCaptureStartFailed(String)
    case avFoundationFrameUnavailable
    case invalidVideoFrameRate(Int)
    case unsupportedAudioCompressionShape(String)
    case unsafeRawVideoPacketBudget(estimatedFragmentsPerFrame: Int, maxFragmentsPerFrame: Int)
    case videoSequenceExhausted
    case acceptedVideoStreamMismatch(String)
    case noUsefulMediaMoved(String)
}

/// Represents DirectPeerVideoPacketBudgetEstimate values used by direct peer sessions.
public struct DirectPeerVideoPacketBudgetEstimate: Codable, Equatable, Sendable {
    public var payloadBytesPerFrame: Int
    public var estimatedFragmentsPerFrame: Int
    public var estimatedFragmentsPerSecond: Int
    public var maxFragmentsPerFrame: Int
    public var maxFragmentsPerSecond: Int

    public init(
        payloadBytesPerFrame: Int,
        estimatedFragmentsPerFrame: Int,
        estimatedFragmentsPerSecond: Int,
        maxFragmentsPerFrame: Int,
        maxFragmentsPerSecond: Int
    ) {
        self.payloadBytesPerFrame = payloadBytesPerFrame
        self.estimatedFragmentsPerFrame = estimatedFragmentsPerFrame
        self.estimatedFragmentsPerSecond = estimatedFragmentsPerSecond
        self.maxFragmentsPerFrame = maxFragmentsPerFrame
        self.maxFragmentsPerSecond = maxFragmentsPerSecond
    }
}

/// Computes video packet and payload budgets that preserve the negotiated MTU and audio priority.
public enum DirectPeerVideoPacketBudget {
    public static let maxUdpPacketBytes = 1_200

    public static func estimate(
_ configuration: DirectPeerSessionAVRunConfiguration
) -> DirectPeerVideoPacketBudgetEstimate {
        let normalizedPixelFormat = directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat)
        let rawPayloadBytes = MediaGeometrySizing.clampedRawFrameByteCount(
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bytesPerPixel: videoBytesPerPixel(for: normalizedPixelFormat)
        )
        let payloadBytes = configuration.videoCompression == .jpegXS
            ? directPeerJPEGXSEstimatedPayloadBytes(
                width: configuration.videoWidth,
                height: configuration.videoHeight
            )
            : rawPayloadBytes
        let fingerprintBytes = "budget".utf8.count
        let overheadBytes = UdpMediaPacketHeader.byteCount
            + VideoTransportFragment.fixedHeaderByteCount
            + fingerprintBytes
            + VideoStreamRole.avFoundationDevice.rawValue.utf8.count
            + normalizedPixelFormat.utf8.count
        let maxFragmentPayloadBytes = max(1, maxUdpPacketBytes - overheadBytes)
        let fragmentsPerFrame = directPeerFragmentsPerFrame(
            payloadBytes: payloadBytes,
            maxFragmentPayloadBytes: maxFragmentPayloadBytes
        )
        let profileMaxFragmentsPerFrame = rawVideoMaxFragmentsPerFrame(
            avProfile: configuration.avProfile,
            rxBufferProfile: configuration.rxBufferProfile
        )
        let maxFragmentsPerFrame = configuration.videoCompression == .jpegXS
            ? max(
                profileMaxFragmentsPerFrame,
                directPeerJPEGXSFragmentCapacity(estimatedFragmentsPerFrame: fragmentsPerFrame)
            )
            : profileMaxFragmentsPerFrame
        return DirectPeerVideoPacketBudgetEstimate(
            payloadBytesPerFrame: payloadBytes,
            estimatedFragmentsPerFrame: fragmentsPerFrame,
            estimatedFragmentsPerSecond: directPeerClampedProduct(
                fragmentsPerFrame,
                configuration.videoFrameRate
            ),
            maxFragmentsPerFrame: maxFragmentsPerFrame,
            maxFragmentsPerSecond: directPeerClampedProduct(
                maxFragmentsPerFrame,
                configuration.videoFrameRate
            )
        )
    }

    public static func validate(
_ configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerVideoPacketBudgetEstimate {
        let estimate = estimate(configuration)
        guard configuration.videoCompression == .raw else {
            return estimate
        }
        guard estimate.estimatedFragmentsPerFrame <= estimate.maxFragmentsPerFrame else {
            throw DirectPeerSessionAVRuntimeError.unsafeRawVideoPacketBudget(
                estimatedFragmentsPerFrame: estimate.estimatedFragmentsPerFrame,
                maxFragmentsPerFrame: estimate.maxFragmentsPerFrame
            )
        }
        return estimate
    }

    private static func rawVideoMaxFragmentsPerFrame(
        avProfile: DirectPeerSessionAVProfile,
        rxBufferProfile: RxBufferProfile
    ) -> Int {
        switch (avProfile, rxBufferProfile) {
        case (.fastest, .direct):
            128
        case (.balanced, .small):
            512
        case (.balanced, .adaptive):
            768
        case (.balanced, .stableWan):
            256
        default:
            preconditionFailure("unsupported raw video packet budget profile combination")
        }
    }
}

private func directPeerJPEGXSEstimatedPayloadBytes(width: Int, height: Int) -> Int {
    let pixelCount = MediaGeometrySizing.clampedRawFrameByteCount(
        width: width,
        height: height,
        bytesPerPixel: 1
    )
    guard pixelCount < Int.max else {
        return Int.max
    }
    return (pixelCount + 1) / 2
}

private func directPeerJPEGXSFragmentCapacity(estimatedFragmentsPerFrame: Int) -> Int {
    let headroom = max(2, estimatedFragmentsPerFrame / 10)
    let capacity = estimatedFragmentsPerFrame.addingReportingOverflow(headroom)
    return capacity.overflow ? Int.max : capacity.partialValue
}

private func directPeerFragmentsPerFrame(
    payloadBytes: Int,
    maxFragmentPayloadBytes: Int
) -> Int {
    guard payloadBytes < Int.max else {
        return Int.max
    }
    let (biasedPayloadBytes, overflow) = payloadBytes.addingReportingOverflow(maxFragmentPayloadBytes - 1)
    guard !overflow else {
        return Int.max
    }
    return max(1, biasedPayloadBytes / maxFragmentPayloadBytes)
}

private func directPeerClampedProduct(_ values: Int...) -> Int {
    var product = 1
    for value in values {
        let multiplied = product.multipliedReportingOverflow(by: value)
        if multiplied.overflow {
            return Int.max
        }
        product = multiplied.partialValue
    }
    return product
}

/// Defines DirectPeerSessionAVBufferPolicy acceptance rules so callers receive deterministic pass or failure evidence.
public struct DirectPeerSessionAVBufferPolicy: Codable, Equatable, Sendable {
    public var latencyProfile: SessionLatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var ringCapacityBlocks: Int
    public var rxBufferPolicy: RxBufferPolicy

    public init(
        latencyProfile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        ringCapacityBlocks: Int,
        rxBufferPolicy: RxBufferPolicy
    ) {
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
        self.ringCapacityBlocks = ringCapacityBlocks
        self.rxBufferPolicy = rxBufferPolicy
    }

    public static func resolve(
        avProfile: DirectPeerSessionAVProfile,
        rxBufferProfile: RxBufferProfile,
        framesPerPacket: Int = 32,
        sampleRateHertz: Int = 48_000
    ) throws -> DirectPeerSessionAVBufferPolicy {
        DirectPeerSessionAVBufferPolicy(
            latencyProfile: try latencyProfile(avProfile: avProfile, rxBufferProfile: rxBufferProfile),
            rxBufferProfile: rxBufferProfile,
            ringCapacityBlocks: rxBufferProfile.directP2PAVRingCapacityBlocks,
            rxBufferPolicy: try rxBufferProfile.policy(
                framesPerPacket: framesPerPacket,
                sampleRateHertz: sampleRateHertz
            )
        )
    }

    private static func latencyProfile(
        avProfile: DirectPeerSessionAVProfile,
        rxBufferProfile: RxBufferProfile
    ) throws -> SessionLatencyProfile {
        switch (avProfile, rxBufferProfile) {
        case (.fastest, .direct): .directAudioFirst
        case (.balanced, .small): .balancedAV
        case (.balanced, .adaptive): .multiVideoPerformance
        case (.balanced, .stableWan): .wanStable
        default: throw DirectPeerSessionAVRuntimeError.unsupportedRXBufferProfile(
            avProfile: avProfile,
            rxBufferProfile: rxBufferProfile
        )
        }
    }
}

public extension DirectPeerSessionAVProfile {
    var defaultRXBufferProfile: RxBufferProfile {
        switch self {
        case .fastest:
            .direct
        case .balanced:
            .small
        }
    }
}

public extension RxBufferProfile {
    var directP2PAVRingCapacityBlocks: Int {
        switch self {
        case .direct:
            4
        case .small:
            8
        case .adaptive:
            16
        case .stableWan:
            32
        }
    }
}

/// Configures DirectPeerSessionAVRunConfiguration so callers supply explicit inputs before starting direct peer sessions.
public struct DirectPeerSessionAVRunConfiguration: Codable, Equatable, Sendable {
    public struct DeviceRouting: Equatable, Sendable {
        public var audioDeviceUID: String?
        public var inputDeviceUID: String
        public var outputDeviceUID: String

        public init(audioDeviceUID: String? = nil, inputDeviceUID: String, outputDeviceUID: String) {
            self.audioDeviceUID = audioDeviceUID
            self.inputDeviceUID = inputDeviceUID
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Audio: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var framesPerPacket: Int
        public var sampleFormat: UdpPcmSampleFormat
        public var inputChannels: [Int]
        public var outputChannels: [Int]
        public var transport: DirectPeerSessionAudioTransport?
        public var compression: DirectPeerSessionAudioCompression

        public init(sampleRateHertz: Int = 48_000, framesPerPacket: Int = 32, sampleFormat: UdpPcmSampleFormat = .float32LittleEndian, inputChannels: [Int] = [0, 1], outputChannels: [Int] = [0, 1], transport: DirectPeerSessionAudioTransport? = nil, compression: DirectPeerSessionAudioCompression = .raw) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.sampleFormat = sampleFormat
            self.inputChannels = inputChannels
            self.outputChannels = outputChannels
            self.transport = transport
            self.compression = compression
        }
    }

    public struct Video: Equatable, Sendable {
        public var deviceID: String
        public var width: Int
        public var height: Int
        public var pixelFormat: String
        public var compression: DirectPeerSessionVideoCompression
        public var frameRate: Int
        public var streamID: Int

        public init(deviceID: String, width: Int = 1_280, height: Int = 720, pixelFormat: String = "bgra8", compression: DirectPeerSessionVideoCompression = .raw, frameRate: Int = 30, streamID: Int = 100) {
            self.deviceID = deviceID
            self.width = width
            self.height = height
            self.pixelFormat = pixelFormat
            self.compression = compression
            self.frameRate = frameRate
            self.streamID = streamID
        }
    }

    public struct Quality: Equatable, Sendable {
        public var profile: DirectPeerSessionAVProfile
        public var rxBufferProfile: RxBufferProfile?
        public var preview: DirectPeerSessionPreviewMode
        public var mediaSourceMode: DirectPeerSessionAVMediaSourceMode
        public var policy: DirectPeerSessionAVRunQualityPolicy

        public init(profile: DirectPeerSessionAVProfile = .balanced, rxBufferProfile: RxBufferProfile? = nil, preview: DirectPeerSessionPreviewMode = .on, mediaSourceMode: DirectPeerSessionAVMediaSourceMode = .production, policy: DirectPeerSessionAVRunQualityPolicy = .requireUsefulMedia) {
            self.profile = profile
            self.rxBufferProfile = rxBufferProfile
            self.preview = preview
            self.mediaSourceMode = mediaSourceMode
            self.policy = policy
        }
    }

    public struct AoIP: Equatable, Sendable {
        public var sdpOutputPath: String?
        public var sdpInputPath: String?

        public init(sdpOutputPath: String? = nil, sdpInputPath: String? = nil) {
            self.sdpOutputPath = sdpOutputPath
            self.sdpInputPath = sdpInputPath
        }
    }
    public var manual: DirectPeerSessionManualRunConfiguration
    public var durationSeconds: Int
    public var audioDeviceUID: String
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var inputChannels: [Int]
    public var outputChannels: [Int]
    public var videoDeviceID: String
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoPixelFormat: String
    public var audioTransport: DirectPeerSessionAudioTransport
    public var videoCompression: DirectPeerSessionVideoCompression
    public var videoFrameRate: Int
    public var videoStreamID: Int
    public var avProfile: DirectPeerSessionAVProfile
    public var rxBufferProfile: RxBufferProfile
    public var preview: DirectPeerSessionPreviewMode
    public var mediaSourceMode: DirectPeerSessionAVMediaSourceMode
    public var qualityPolicy: DirectPeerSessionAVRunQualityPolicy
    public var aoipSDPOutputPath: String?
    public var aoipSDPInputPath: String?

    public init(manual: DirectPeerSessionManualRunConfiguration, durationSeconds: Int, devices: DeviceRouting, audio: Audio = .init(), video: Video, quality: Quality = .init(), aoip: AoIP = .init()) {
        (
            self.manual, self.durationSeconds, self.audioDeviceUID, self.inputDeviceUID, self.outputDeviceUID,
            self.sampleRateHertz, self.framesPerPacket, self.sampleFormat, self.inputChannels, self.outputChannels,
            self.videoDeviceID, self.videoWidth, self.videoHeight, self.videoPixelFormat, self.audioTransport,
            self.videoCompression, self.videoFrameRate, self.videoStreamID, self.avProfile, self.rxBufferProfile,
            self.preview, self.mediaSourceMode, self.qualityPolicy, self.aoipSDPOutputPath, self.aoipSDPInputPath
        ) = (
            manual, durationSeconds, devices.audioDeviceUID ?? devices.inputDeviceUID, devices.inputDeviceUID, devices.outputDeviceUID,
            audio.sampleRateHertz, audio.framesPerPacket, audio.sampleFormat, audio.inputChannels, audio.outputChannels, video.deviceID,
            video.width, video.height, video.pixelFormat, audio.transport ?? audio.compression.audioTransport,
            video.compression, video.frameRate, video.streamID, quality.profile,
            quality.rxBufferProfile ?? quality.profile.defaultRXBufferProfile, quality.preview, quality.mediaSourceMode, quality.policy,
            aoip.sdpOutputPath, aoip.sdpInputPath
        )
    }

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }
}
