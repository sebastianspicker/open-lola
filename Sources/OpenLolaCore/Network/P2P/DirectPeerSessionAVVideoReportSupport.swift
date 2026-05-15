import Foundation

struct DirectPeerSessionAVRuntimeResult {
    var metrics: DirectPeerSessionAVRuntimeMetrics
    var videoFormat: DirectPeerSessionVideoFormatReport?
    var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
}

func directPeerSessionVideoFrameProof(
    for frame: RawCapturedVideoFrame
) -> DirectPeerSessionVideoFrameProof {
    DirectPeerSessionVideoFrameProof(
        streamID: Int(frame.metadata.streamID),
        sequenceNumber: frame.metadata.sequenceNumber,
        width: frame.metadata.width,
        height: frame.metadata.height,
        pixelFormat: frame.metadata.pixelFormat,
        payloadByteCount: frame.payload.count,
        fingerprint: frame.metadata.fingerprint,
        payloadDigest: directPeerVideoPayloadDigest(frame.payload)
    )
}

func directPeerVideoPayloadDigest(_ payload: Data) -> String {
    // Compact evidence label only: receive-proof validation also checks frame
    // shape, counters, and packet-capture metadata. Do not use this FNV-1a
    // value as a cryptographic payload-integrity proof.
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in payload {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return "fnv1a64-\(String(hash, radix: 16))"
}

func syntheticAVVideoFormatReport(
    for configuration: DirectPeerSessionAVRunConfiguration
) -> DirectPeerSessionVideoFormatReport {
    DirectPeerSessionVideoFormatReport(
        requestedDeviceID: configuration.videoDeviceID,
        selectedDeviceID: configuration.videoDeviceID,
        selectedDeviceLabel: "synthetic BGRA fixture",
        requestedFrameRate: configuration.videoFrameRate,
        selectedWidth: configuration.videoWidth,
        selectedHeight: configuration.videoHeight,
        selectedPixelFormat: directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat),
        outputPixelFormat: directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat),
        selectedFrameRate: Double(configuration.videoFrameRate)
    )
}
