import Foundation

public struct DirectPeerSessionReceiveProofEvidenceMetadata: Codable, Equatable, Sendable {
    public var sourcePeerLabel: String?
    public var receiverPeerLabel: String?
    public var packetCapturePath: String?
    public var rawVideoReceiveEvidence: String?
    public var firstFrameFingerprint: String
    public var latestFrameFingerprint: String
    public var firstFramePayloadDigest: String?
    public var latestFramePayloadDigest: String?
    public var evidenceDigest: String

    public init(report: DirectPeerSessionReport, proof: DirectPeerSessionVideoReceiveProofArtifact) {
        sourcePeerLabel = report.measuredEvidence?.sourcePeerLabel
        receiverPeerLabel = report.measuredEvidence?.receiverPeerLabel
        packetCapturePath = report.measuredEvidence?.packetCapturePath
        rawVideoReceiveEvidence = report.measuredEvidence?.rawVideoReceiveEvidence
        firstFrameFingerprint = proof.firstFrame.fingerprint
        latestFrameFingerprint = proof.latestFrame.fingerprint
        firstFramePayloadDigest = proof.firstFrame.payloadDigest
        latestFramePayloadDigest = proof.latestFrame.payloadDigest
        evidenceDigest = directPeerSessionReceiveProofDigest(directPeerSessionReceiveProofDigestPayload([
            report.id,
            report.configuration.sessionID,
            sourcePeerLabel,
            receiverPeerLabel,
            packetCapturePath,
            rawVideoReceiveEvidence,
            firstFrameFingerprint,
            latestFrameFingerprint,
            firstFramePayloadDigest,
            latestFramePayloadDigest,
        ]))
    }
}

public struct DirectPeerSessionRawVideoReceiveEvidenceArtifact: Codable, Equatable, Sendable {
    public var id: String
    public var reportID: String
    public var capturedAt: String
    public var sessionID: String
    public var frameCount: Int
    public var previewFramesSubmitted: Int
    public var firstFrame: DirectPeerSessionVideoFrameProof
    public var latestFrame: DirectPeerSessionVideoFrameProof
    public var evidenceDigest: String

    public init(report: DirectPeerSessionReport, proof: DirectPeerSessionVideoReceiveProofArtifact) {
        id = "\(report.id)-raw-video-receive-evidence"
        reportID = report.id
        capturedAt = report.capturedAt
        sessionID = report.configuration.sessionID
        frameCount = proof.framesProven
        previewFramesSubmitted = proof.previewFramesSubmitted
        firstFrame = proof.firstFrame
        latestFrame = proof.latestFrame
        evidenceDigest = directPeerSessionReceiveProofDigest(directPeerSessionReceiveProofDigestPayload([
            report.id,
            report.configuration.sessionID,
            "\(proof.framesProven)",
            "\(proof.previewFramesSubmitted)",
            proof.firstFrame.payloadDigest,
            proof.latestFrame.payloadDigest,
        ]))
    }
}

private func directPeerSessionReceiveProofDigestPayload(_ values: [String?]) -> String {
    guard let data = try? JSONEncoder().encode(values),
          let payload = String(data: data, encoding: .utf8) else {
        preconditionFailure("Optional string digest payload must be JSON encodable")
    }
    return payload
}

public struct DirectPeerSessionReceiveProofArtifact: Codable, Equatable, Sendable {
    public var id: String
    public var reportID: String
    public var capturedAt: String
    public var sessionID: String
    public var peerLabels: [String]
    public var peerMediaEndpoints: [SessionPeerMediaEndpoints]
    public var videoFormat: DirectPeerSessionVideoFormatReport?
    public var receiveProof: DirectPeerSessionVideoReceiveProofArtifact
    public var reportCounters: DirectPeerSessionReportMetrics
    public var runtimeCounters: DirectPeerSessionAVRuntimeMetrics
    public var evidenceMetadata: DirectPeerSessionReceiveProofEvidenceMetadata

    public init(
        report: DirectPeerSessionReport,
        proof: DirectPeerSessionVideoReceiveProofArtifact,
        runtimeCounters: DirectPeerSessionAVRuntimeMetrics
    ) {
        id = "\(report.id)-rx-proof"
        reportID = report.id
        capturedAt = report.capturedAt
        sessionID = report.configuration.sessionID
        peerLabels = report.configuration.peers.map(\.peerID)
        peerMediaEndpoints = report.configuration.peerMediaEndpoints ?? []
        videoFormat = report.avRuntime?.videoFormat
        receiveProof = proof
        reportCounters = report.metrics
        self.runtimeCounters = runtimeCounters
        evidenceMetadata = DirectPeerSessionReceiveProofEvidenceMetadata(report: report, proof: proof)
    }
}

private func directPeerSessionReceiveProofDigest(_ value: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return "fnv1a64-\(String(hash, radix: 16))"
}
