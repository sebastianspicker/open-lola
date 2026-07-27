// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

struct DirectPeerSessionAVRuntimeResult {
    var metrics: DirectPeerSessionAVRuntimeMetrics
    var videoFormat: DirectPeerSessionVideoFormatReport?
    var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
}

func directPeerUsefulMediaProof(
    runtime: DirectPeerSessionAVRuntimeResult,
    policy: DirectPeerSessionAVRunQualityPolicy
) -> DirectPeerSessionUsefulMediaProof {
    switch policy {
    case .structural:
        return .notRequired
    case .requireUsefulMedia:
        return directPeerUsefulMediaMissingReasons(runtime: runtime).isEmpty
            ? .requiredAndProven
            : .requiredButNotProven
    }
}

func directPeerUsefulMediaMissingReasons(runtime: DirectPeerSessionAVRuntimeResult) -> [String] {
    let metrics = runtime.metrics
    var missing: [String] = []
    if metrics.audioPayloadsSent <= 0 {
        missing.append("audio sent")
    }
    if metrics.audioPayloadsQueuedForPlayout <= 0 {
        missing.append("audio received for playout")
    }
    if metrics.videoFramesSent <= 0 {
        missing.append("video frames sent")
    }
    if metrics.videoFramesReassembled <= 0 {
        missing.append("video frames reassembled")
    }
    if metrics.videoFramesReassembled <= metrics.videoFramesDroppedOutsideAudioWindow {
        missing.append("video frames accepted inside audio window")
    }
    if runtime.receiveProof == nil {
        missing.append("video receive proof")
    }
    return missing
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
        request: .init(deviceID: configuration.videoDeviceID, frameRate: configuration.videoFrameRate),
        selection: .init(
            deviceID: configuration.videoDeviceID, deviceLabel: "synthetic BGRA fixture",
            width: configuration.videoWidth, height: configuration.videoHeight,
            selectedPixelFormat: directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat),
            outputPixelFormat: directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat),
            frameRate: Double(configuration.videoFrameRate), sourcePolicy: nil
        )
    )
}
