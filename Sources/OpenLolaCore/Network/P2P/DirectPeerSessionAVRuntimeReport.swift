public enum DirectPeerSessionUsefulMediaProof: String, Codable, Equatable, Sendable {
    case unknown
    case notRequired = "not-required"
    case requiredAndProven = "required-and-proven"
    case requiredButNotProven = "required-but-not-proven"
}

public struct DirectPeerSessionAVRuntimeMetadata: Codable, Equatable, Sendable {
    public var avProfile: DirectPeerSessionAVProfile
    public var previewMode: DirectPeerSessionPreviewMode
    public var mediaSourceMode: DirectPeerSessionAVMediaSourceMode
    public var qualityPolicy: DirectPeerSessionAVRunQualityPolicy?
    public var usefulMediaProof: DirectPeerSessionUsefulMediaProof
    public var audioDeviceUID: String
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var sampleRateHertz: Int
    public var selectedBufferFrameSize: Int
    public var latencyProfile: SessionLatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var videoDeviceID: String
    public var audioTransport: DirectPeerSessionAudioTransport
    public var opusBitrateBitsPerSecond: Int?
    public var opusFrameDurationMilliseconds: Double?
    public var aoipProfile: String?
    public var rtpPayloadType: UInt8?
    public var rtpClockRate: Int?
    public var rtpPacketTimeMilliseconds: Int?
    public var rtpSSRC: UInt32?
    public var sdpPath: String?
    public var ptpEvidenceSummary: String?
    public var videoCompression: DirectPeerSessionVideoCompression
    public var jpegXSRateBitsPerPixel: Float?
    public var videoFrameRate: Int
    public var videoStreamID: Int
    public var fastestPassBlockedReason: String
    public var runtimeMetrics: DirectPeerSessionAVRuntimeMetrics
    public var videoFormat: DirectPeerSessionVideoFormatReport?
    public var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
    public var fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison?

    public init(
        avProfile: DirectPeerSessionAVProfile,
        previewMode: DirectPeerSessionPreviewMode,
        mediaSourceMode: DirectPeerSessionAVMediaSourceMode,
        qualityPolicy: DirectPeerSessionAVRunQualityPolicy? = nil,
        usefulMediaProof: DirectPeerSessionUsefulMediaProof = .unknown,
        audioDeviceUID: String,
        inputDeviceUID: String? = nil,
        outputDeviceUID: String? = nil,
        sampleRateHertz: Int,
        selectedBufferFrameSize: Int,
        latencyProfile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        videoDeviceID: String,
        audioTransport: DirectPeerSessionAudioTransport = .openLolaRaw,
        opusBitrateBitsPerSecond: Int? = nil,
        opusFrameDurationMilliseconds: Double? = nil,
        aoipProfile: String? = nil,
        rtpPayloadType: UInt8? = nil,
        rtpClockRate: Int? = nil,
        rtpPacketTimeMilliseconds: Int? = nil,
        rtpSSRC: UInt32? = nil,
        sdpPath: String? = nil,
        ptpEvidenceSummary: String? = nil,
        videoCompression: DirectPeerSessionVideoCompression = .raw,
        jpegXSRateBitsPerPixel: Float? = nil,
        videoFrameRate: Int,
        videoStreamID: Int,
        fastestPassBlockedReason: String,
        runtimeMetrics: DirectPeerSessionAVRuntimeMetrics = .empty,
        videoFormat: DirectPeerSessionVideoFormatReport? = nil,
        receiveProof: DirectPeerSessionVideoReceiveProofArtifact? = nil,
        fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison? = nil
    ) {
        self.avProfile = avProfile
        self.previewMode = previewMode
        self.mediaSourceMode = mediaSourceMode
        self.qualityPolicy = qualityPolicy
        self.usefulMediaProof = usefulMediaProof
        self.audioDeviceUID = audioDeviceUID
        self.inputDeviceUID = inputDeviceUID ?? audioDeviceUID
        self.outputDeviceUID = outputDeviceUID ?? audioDeviceUID
        self.sampleRateHertz = sampleRateHertz
        self.selectedBufferFrameSize = selectedBufferFrameSize
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
        self.videoDeviceID = videoDeviceID
        self.audioTransport = audioTransport
        self.opusBitrateBitsPerSecond = opusBitrateBitsPerSecond
        self.opusFrameDurationMilliseconds = opusFrameDurationMilliseconds
        self.aoipProfile = aoipProfile
        self.rtpPayloadType = rtpPayloadType
        self.rtpClockRate = rtpClockRate
        self.rtpPacketTimeMilliseconds = rtpPacketTimeMilliseconds
        self.rtpSSRC = rtpSSRC
        self.sdpPath = sdpPath
        self.ptpEvidenceSummary = ptpEvidenceSummary
        self.videoCompression = videoCompression
        self.jpegXSRateBitsPerPixel = jpegXSRateBitsPerPixel
        self.videoFrameRate = videoFrameRate
        self.videoStreamID = videoStreamID
        self.fastestPassBlockedReason = fastestPassBlockedReason
        self.runtimeMetrics = runtimeMetrics
        self.videoFormat = videoFormat
        self.receiveProof = receiveProof
        self.fastestAVBaselineComparison = fastestAVBaselineComparison
    }

    enum CodingKeys: String, CodingKey {
        case avProfile
        case previewMode
        case mediaSourceMode
        case qualityPolicy
        case usefulMediaProof
        case audioDeviceUID
        case inputDeviceUID
        case outputDeviceUID
        case sampleRateHertz
        case selectedBufferFrameSize
        case latencyProfile
        case rxBufferProfile
        case videoDeviceID
        case audioTransport
        case audioCompression
        case opusBitrateBitsPerSecond
        case opusFrameDurationMilliseconds
        case aoipProfile
        case rtpPayloadType
        case rtpClockRate
        case rtpPacketTimeMilliseconds
        case rtpSSRC
        case sdpPath
        case ptpEvidenceSummary
        case videoCompression
        case jpegXSRateBitsPerPixel
        case videoFrameRate
        case videoStreamID
        case fastestPassBlockedReason
        case runtimeMetrics
        case videoFormat
        case receiveProof
        case fastestAVBaselineComparison
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avProfile = try container.decode(DirectPeerSessionAVProfile.self, forKey: .avProfile)
        previewMode = try container.decode(DirectPeerSessionPreviewMode.self, forKey: .previewMode)
        mediaSourceMode = try container.decode(DirectPeerSessionAVMediaSourceMode.self, forKey: .mediaSourceMode)
        qualityPolicy = try container.decodeIfPresent(DirectPeerSessionAVRunQualityPolicy.self, forKey: .qualityPolicy)
        usefulMediaProof = try container.decodeIfPresent(
            DirectPeerSessionUsefulMediaProof.self,
            forKey: .usefulMediaProof
        ) ?? .unknown
        audioDeviceUID = try container.decode(String.self, forKey: .audioDeviceUID)
        inputDeviceUID = try container.decodeIfPresent(String.self, forKey: .inputDeviceUID) ?? audioDeviceUID
        outputDeviceUID = try container.decodeIfPresent(String.self, forKey: .outputDeviceUID) ?? audioDeviceUID
        sampleRateHertz = try container.decode(Int.self, forKey: .sampleRateHertz)
        selectedBufferFrameSize = try container.decode(Int.self, forKey: .selectedBufferFrameSize)
        latencyProfile = try container.decode(SessionLatencyProfile.self, forKey: .latencyProfile)
        rxBufferProfile = try container.decode(RxBufferProfile.self, forKey: .rxBufferProfile)
        videoDeviceID = try container.decode(String.self, forKey: .videoDeviceID)
        if let transport = try container.decodeIfPresent(DirectPeerSessionAudioTransport.self, forKey: .audioTransport) {
            audioTransport = transport
        } else {
            audioTransport = try container.decodeIfPresent(
                DirectPeerSessionAudioCompression.self,
                forKey: .audioCompression
            )?.audioTransport ?? .openLolaRaw
        }
        opusBitrateBitsPerSecond = try container.decodeIfPresent(Int.self, forKey: .opusBitrateBitsPerSecond)
        opusFrameDurationMilliseconds = try container.decodeIfPresent(
            Double.self,
            forKey: .opusFrameDurationMilliseconds
        )
        aoipProfile = try container.decodeIfPresent(String.self, forKey: .aoipProfile)
        rtpPayloadType = try container.decodeIfPresent(UInt8.self, forKey: .rtpPayloadType)
        rtpClockRate = try container.decodeIfPresent(Int.self, forKey: .rtpClockRate)
        rtpPacketTimeMilliseconds = try container.decodeIfPresent(Int.self, forKey: .rtpPacketTimeMilliseconds)
        rtpSSRC = try container.decodeIfPresent(UInt32.self, forKey: .rtpSSRC)
        sdpPath = try container.decodeIfPresent(String.self, forKey: .sdpPath)
        ptpEvidenceSummary = try container.decodeIfPresent(String.self, forKey: .ptpEvidenceSummary)
        videoCompression = try container.decodeIfPresent(
            DirectPeerSessionVideoCompression.self,
            forKey: .videoCompression
        ) ?? .raw
        jpegXSRateBitsPerPixel = try container.decodeIfPresent(Float.self, forKey: .jpegXSRateBitsPerPixel)
        videoFrameRate = try container.decode(Int.self, forKey: .videoFrameRate)
        videoStreamID = try container.decode(Int.self, forKey: .videoStreamID)
        fastestPassBlockedReason = try container.decode(String.self, forKey: .fastestPassBlockedReason)
        runtimeMetrics = try container.decodeIfPresent(
            DirectPeerSessionAVRuntimeMetrics.self,
            forKey: .runtimeMetrics
        ) ?? .empty
        videoFormat = try container.decodeIfPresent(DirectPeerSessionVideoFormatReport.self, forKey: .videoFormat)
        receiveProof = try container.decodeIfPresent(
            DirectPeerSessionVideoReceiveProofArtifact.self,
            forKey: .receiveProof
        )
        fastestAVBaselineComparison = try container.decodeIfPresent(
            DirectPeerSessionFastestAVBaselineComparison.self,
            forKey: .fastestAVBaselineComparison
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(avProfile, forKey: .avProfile)
        try container.encode(previewMode, forKey: .previewMode)
        try container.encode(mediaSourceMode, forKey: .mediaSourceMode)
        try container.encodeIfPresent(qualityPolicy, forKey: .qualityPolicy)
        try container.encode(usefulMediaProof, forKey: .usefulMediaProof)
        try container.encode(audioDeviceUID, forKey: .audioDeviceUID)
        try container.encode(inputDeviceUID, forKey: .inputDeviceUID)
        try container.encode(outputDeviceUID, forKey: .outputDeviceUID)
        try container.encode(sampleRateHertz, forKey: .sampleRateHertz)
        try container.encode(selectedBufferFrameSize, forKey: .selectedBufferFrameSize)
        try container.encode(latencyProfile, forKey: .latencyProfile)
        try container.encode(rxBufferProfile, forKey: .rxBufferProfile)
        try container.encode(videoDeviceID, forKey: .videoDeviceID)
        try container.encode(audioTransport, forKey: .audioTransport)
        if let legacy = audioTransport.legacyAudioCompression {
            try container.encode(legacy, forKey: .audioCompression)
        }
        try container.encodeIfPresent(opusBitrateBitsPerSecond, forKey: .opusBitrateBitsPerSecond)
        try container.encodeIfPresent(opusFrameDurationMilliseconds, forKey: .opusFrameDurationMilliseconds)
        try container.encodeIfPresent(aoipProfile, forKey: .aoipProfile)
        try container.encodeIfPresent(rtpPayloadType, forKey: .rtpPayloadType)
        try container.encodeIfPresent(rtpClockRate, forKey: .rtpClockRate)
        try container.encodeIfPresent(rtpPacketTimeMilliseconds, forKey: .rtpPacketTimeMilliseconds)
        try container.encodeIfPresent(rtpSSRC, forKey: .rtpSSRC)
        try container.encodeIfPresent(sdpPath, forKey: .sdpPath)
        try container.encodeIfPresent(ptpEvidenceSummary, forKey: .ptpEvidenceSummary)
        try container.encode(videoCompression, forKey: .videoCompression)
        try container.encodeIfPresent(jpegXSRateBitsPerPixel, forKey: .jpegXSRateBitsPerPixel)
        try container.encode(videoFrameRate, forKey: .videoFrameRate)
        try container.encode(videoStreamID, forKey: .videoStreamID)
        try container.encode(fastestPassBlockedReason, forKey: .fastestPassBlockedReason)
        try container.encode(runtimeMetrics, forKey: .runtimeMetrics)
        try container.encodeIfPresent(videoFormat, forKey: .videoFormat)
        try container.encodeIfPresent(receiveProof, forKey: .receiveProof)
        try container.encodeIfPresent(fastestAVBaselineComparison, forKey: .fastestAVBaselineComparison)
    }

    public var audioCompression: DirectPeerSessionAudioCompression {
        audioTransport.legacyAudioCompression ?? .raw
    }
}

public struct DirectPeerSessionVideoFormatReport: Codable, Equatable, Sendable {
    public var requestedDeviceID: String
    public var selectedDeviceID: String
    public var selectedDeviceLabel: String
    public var requestedFrameRate: Int
    public var selectedWidth: Int
    public var selectedHeight: Int
    public var selectedPixelFormat: String
    public var outputPixelFormat: String
    public var selectedFrameRate: Double
    public var sourcePolicy: AVFoundationVideoSourcePolicy?

    public init(
        requestedDeviceID: String,
        selectedDeviceID: String,
        selectedDeviceLabel: String,
        requestedFrameRate: Int,
        selectedWidth: Int,
        selectedHeight: Int,
        selectedPixelFormat: String,
        outputPixelFormat: String,
        selectedFrameRate: Double,
        sourcePolicy: AVFoundationVideoSourcePolicy? = nil
    ) {
        self.requestedDeviceID = requestedDeviceID
        self.selectedDeviceID = selectedDeviceID
        self.selectedDeviceLabel = selectedDeviceLabel
        self.requestedFrameRate = requestedFrameRate
        self.selectedWidth = selectedWidth
        self.selectedHeight = selectedHeight
        self.selectedPixelFormat = selectedPixelFormat
        self.outputPixelFormat = outputPixelFormat
        self.selectedFrameRate = selectedFrameRate
        self.sourcePolicy = sourcePolicy
    }
}

public struct DirectPeerSessionVideoFrameProof: Codable, Equatable, Sendable {
    public var streamID: Int
    public var sequenceNumber: UInt64
    public var width: Int
    public var height: Int
    public var pixelFormat: String
    public var payloadByteCount: Int
    public var fingerprint: String
    public var payloadDigest: String?

    public init(
        streamID: Int,
        sequenceNumber: UInt64,
        width: Int,
        height: Int,
        pixelFormat: String,
        payloadByteCount: Int,
        fingerprint: String,
        payloadDigest: String? = nil
    ) {
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.payloadByteCount = payloadByteCount
        self.fingerprint = fingerprint
        self.payloadDigest = payloadDigest
    }
}

public struct DirectPeerSessionVideoReceiveProofArtifact: Codable, Equatable, Sendable {
    public var framesProven: Int
    public var previewFramesSubmitted: Int
    public var firstFrame: DirectPeerSessionVideoFrameProof
    public var latestFrame: DirectPeerSessionVideoFrameProof

    public init(
        framesProven: Int,
        previewFramesSubmitted: Int,
        firstFrame: DirectPeerSessionVideoFrameProof,
        latestFrame: DirectPeerSessionVideoFrameProof
    ) {
        self.framesProven = framesProven
        self.previewFramesSubmitted = previewFramesSubmitted
        self.firstFrame = firstFrame
        self.latestFrame = latestFrame
    }
}
