import Foundation

public enum DirectPeerSessionMediaMode: String, Codable, Equatable, Sendable {
    case audio
    case audioVideo = "audio-video"
}

public enum DirectPeerSessionAVProfile: String, Codable, Equatable, Sendable {
    case balanced
    case fastest
}

public enum DirectPeerSessionPreviewMode: String, Codable, Equatable, Sendable {
    case on
    case off
}

public enum DirectPeerSessionAVRunQualityPolicy: String, Codable, Equatable, Sendable {
    case structural
    case requireUsefulMedia = "require-useful-media"
}

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

public enum DirectPeerSessionAVMediaSourceMode: String, Codable, Equatable, Sendable {
    case production
    case syntheticFixture
}

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

public enum DirectPeerVideoPacketBudget {
    public static let maxUdpPacketBytes = 1_200

    public static func estimate(_ configuration: DirectPeerSessionAVRunConfiguration) -> DirectPeerVideoPacketBudgetEstimate {
        let normalizedPixelFormat = directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat)
        let payloadBytes = MediaGeometrySizing.clampedRawFrameByteCount(
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bytesPerPixel: videoBytesPerPixel(for: normalizedPixelFormat)
        )
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
        let maxFragmentsPerFrame = rawVideoMaxFragmentsPerFrame(
            avProfile: configuration.avProfile,
            rxBufferProfile: configuration.rxBufferProfile
        )
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

    public static func validate(_ configuration: DirectPeerSessionAVRunConfiguration) throws -> DirectPeerVideoPacketBudgetEstimate {
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
        switch (avProfile, rxBufferProfile) {
        case (.fastest, .direct):
            DirectPeerSessionAVBufferPolicy(
                latencyProfile: .directAudioFirst,
                rxBufferProfile: .direct,
                ringCapacityBlocks: rxBufferProfile.directP2PAVRingCapacityBlocks,
                rxBufferPolicy: try rxBufferProfile.policy(
                    framesPerPacket: framesPerPacket,
                    sampleRateHertz: sampleRateHertz
                )
            )
        case (.balanced, .small):
            DirectPeerSessionAVBufferPolicy(
                latencyProfile: .balancedAV,
                rxBufferProfile: .small,
                ringCapacityBlocks: rxBufferProfile.directP2PAVRingCapacityBlocks,
                rxBufferPolicy: try rxBufferProfile.policy(
                    framesPerPacket: framesPerPacket,
                    sampleRateHertz: sampleRateHertz
                )
            )
        case (.balanced, .adaptive):
            DirectPeerSessionAVBufferPolicy(
                latencyProfile: .multiVideoPerformance,
                rxBufferProfile: .adaptive,
                ringCapacityBlocks: rxBufferProfile.directP2PAVRingCapacityBlocks,
                rxBufferPolicy: try rxBufferProfile.policy(
                    framesPerPacket: framesPerPacket,
                    sampleRateHertz: sampleRateHertz
                )
            )
        case (.balanced, .stableWan):
            DirectPeerSessionAVBufferPolicy(
                latencyProfile: .wanStable,
                rxBufferProfile: .stableWan,
                ringCapacityBlocks: rxBufferProfile.directP2PAVRingCapacityBlocks,
                rxBufferPolicy: try rxBufferProfile.policy(
                    framesPerPacket: framesPerPacket,
                    sampleRateHertz: sampleRateHertz
                )
            )
        default:
            throw DirectPeerSessionAVRuntimeError.unsupportedRXBufferProfile(
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

public struct DirectPeerSessionAVRunConfiguration: Codable, Equatable, Sendable {
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

    public init(
        manual: DirectPeerSessionManualRunConfiguration,
        durationSeconds: Int,
        audioDeviceUID: String? = nil,
        inputDeviceUID: String,
        outputDeviceUID: String,
        sampleRateHertz: Int = 48_000,
        framesPerPacket: Int = 32,
        sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
        inputChannels: [Int] = [0, 1],
        outputChannels: [Int] = [0, 1],
        videoDeviceID: String,
        videoWidth: Int = 1_280,
        videoHeight: Int = 720,
        videoPixelFormat: String = "bgra8",
        audioTransport: DirectPeerSessionAudioTransport? = nil,
        audioCompression: DirectPeerSessionAudioCompression = .raw,
        videoCompression: DirectPeerSessionVideoCompression = .raw,
        videoFrameRate: Int = 30,
        videoStreamID: Int = 100,
        avProfile: DirectPeerSessionAVProfile = .balanced,
        rxBufferProfile: RxBufferProfile? = nil,
        preview: DirectPeerSessionPreviewMode = .on,
        mediaSourceMode: DirectPeerSessionAVMediaSourceMode = .production,
        qualityPolicy: DirectPeerSessionAVRunQualityPolicy = .requireUsefulMedia,
        aoipSDPOutputPath: String? = nil,
        aoipSDPInputPath: String? = nil
    ) {
        self.manual = manual
        self.durationSeconds = durationSeconds
        self.audioDeviceUID = audioDeviceUID ?? inputDeviceUID
        self.inputDeviceUID = inputDeviceUID
        self.outputDeviceUID = outputDeviceUID
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.sampleFormat = sampleFormat
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.videoDeviceID = videoDeviceID
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoPixelFormat = videoPixelFormat
        self.audioTransport = audioTransport ?? audioCompression.audioTransport
        self.videoCompression = videoCompression
        self.videoFrameRate = videoFrameRate
        self.videoStreamID = videoStreamID
        self.avProfile = avProfile
        self.rxBufferProfile = rxBufferProfile ?? avProfile.defaultRXBufferProfile
        self.preview = preview
        self.mediaSourceMode = mediaSourceMode
        self.qualityPolicy = qualityPolicy
        self.aoipSDPOutputPath = aoipSDPOutputPath
        self.aoipSDPInputPath = aoipSDPInputPath
    }

    public var audioCompression: DirectPeerSessionAudioCompression {
        get { audioTransport.legacyAudioCompression ?? .raw }
        set { audioTransport = newValue.audioTransport }
    }
}
