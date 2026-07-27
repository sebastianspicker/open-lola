// Validates DirectPeerSessionReportValidationSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

func requireDirectPeerSessionConfiguration(
    _ configuration: SessionConfiguration?
) throws -> SessionConfiguration {
    guard let configuration else {
        throw DirectPeerSessionReportError.missingAcceptedConfiguration
    }
    return configuration
}

func requireDirectPeerSessionNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw DirectPeerSessionReportError.emptyField(field)
    }
}

func requireDirectPeerSessionNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

func requireDirectPeerSessionPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw DirectPeerSessionReportError.passWithoutRoutedMedia(field)
    }
}

func requireDirectPeerSessionNoPassDegradation(_ value: Int, _ field: String) throws {
    if value > 0 {
        throw DirectPeerSessionReportError.passWithRuntimeDegradation(field)
    }
}

func requireDirectPeerSessionNoPassDegradation(_ value: Int?, _ field: String) throws {
    if let value {
        try requireDirectPeerSessionNoPassDegradation(value, field)
    }
}

func requireDirectPeerSessionNonLoopbackEndpoint(
    _ endpoint: SessionNetworkEndpoint,
    _ field: String
) throws {
    if directPeerSessionIsLoopbackHost(endpoint.host) {
        throw DirectPeerSessionReportError.passRequiresNonLoopbackPeerEndpoint(field)
    }
}

func requireDirectPeerSessionNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 || !value.isFinite {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

func requireDirectPeerSessionPositiveReportValue(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

func requireDirectPeerSessionPositiveReportValue(_ value: Double, _ field: String) throws {
    if value <= 0 || !value.isFinite {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

func validateDirectPeerSessionVideoFormat(_ report: DirectPeerSessionVideoFormatReport) throws {
    try requireDirectPeerSessionNonEmpty(report.requestedDeviceID, "avRuntime.videoFormat.requestedDeviceID")
    try requireDirectPeerSessionNonEmpty(report.selectedDeviceID, "avRuntime.videoFormat.selectedDeviceID")
    try requireDirectPeerSessionNonEmpty(report.selectedDeviceLabel, "avRuntime.videoFormat.selectedDeviceLabel")
    try requireDirectPeerSessionPositiveReportValue(
        report.requestedFrameRate,
        "avRuntime.videoFormat.requestedFrameRate"
    )
    try requireDirectPeerSessionPositiveReportValue(report.selectedWidth, "avRuntime.videoFormat.selectedWidth")
    try requireDirectPeerSessionPositiveReportValue(report.selectedHeight, "avRuntime.videoFormat.selectedHeight")
    try requireDirectPeerSessionNonEmpty(report.selectedPixelFormat, "avRuntime.videoFormat.selectedPixelFormat")
    try requireDirectPeerSessionNonEmpty(report.outputPixelFormat, "avRuntime.videoFormat.outputPixelFormat")
    try requireDirectPeerSessionPositiveReportValue(report.selectedFrameRate, "avRuntime.videoFormat.selectedFrameRate")
}

func validateDirectPeerSessionVideoReceiveProof(_ proof: DirectPeerSessionVideoReceiveProofArtifact) throws {
    try requireDirectPeerSessionPositiveReportValue(proof.framesProven, "avRuntime.receiveProof.framesProven")
    try requireDirectPeerSessionNonNegative(
        proof.previewFramesSubmitted,
        "avRuntime.receiveProof.previewFramesSubmitted"
    )
    try validateDirectPeerSessionVideoFrameProof(proof.firstFrame, "avRuntime.receiveProof.firstFrame")
    try validateDirectPeerSessionVideoFrameProof(proof.latestFrame, "avRuntime.receiveProof.latestFrame")
}

func validateDirectPeerSessionVideoFrameProof(
    _ proof: DirectPeerSessionVideoFrameProof,
    _ fieldPrefix: String
) throws {
    try requireDirectPeerSessionNonNegative(proof.streamID, "\(fieldPrefix).streamID")
    try requireDirectPeerSessionPositiveReportValue(proof.width, "\(fieldPrefix).width")
    try requireDirectPeerSessionPositiveReportValue(proof.height, "\(fieldPrefix).height")
    try requireDirectPeerSessionNonEmpty(proof.pixelFormat, "\(fieldPrefix).pixelFormat")
    try requireDirectPeerSessionPositiveReportValue(proof.payloadByteCount, "\(fieldPrefix).payloadByteCount")
    try requireDirectPeerSessionNonEmpty(proof.fingerprint, "\(fieldPrefix).fingerprint")
    if let payloadDigest = proof.payloadDigest {
        try requireDirectPeerSessionNonEmpty(payloadDigest, "\(fieldPrefix).payloadDigest")
    }
}

func validatePassVideoProof(
    _ proof: DirectPeerSessionVideoReceiveProofArtifact,
    format: DirectPeerSessionVideoFormatReport,
    runtime: DirectPeerSessionAVRuntimeMetadata
) throws {
    let metrics = runtime.runtimeMetrics
    let videoFramesInsideAudioWindow = metrics.videoFramesReassembled
        - metrics.videoFramesDroppedOutsideAudioWindow
    if proof.framesProven != videoFramesInsideAudioWindow {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof("avRuntime.receiveProof.framesProven")
    }
    if proof.previewFramesSubmitted != metrics.previewFramesSubmitted {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.previewFramesSubmitted"
        )
    }
    try validatePassVideoFrameProof(proof.firstFrame, format: format, runtime: runtime, fieldPrefix: "firstFrame")
    try validatePassVideoFrameProof(proof.latestFrame, format: format, runtime: runtime, fieldPrefix: "latestFrame")
    if proof.latestFrame.sequenceNumber < proof.firstFrame.sequenceNumber {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.latestFrame.sequenceNumber"
        )
    }
}

func validatePassVideoFrameProof(
    _ frame: DirectPeerSessionVideoFrameProof,
    format: DirectPeerSessionVideoFormatReport,
    runtime: DirectPeerSessionAVRuntimeMetadata,
    fieldPrefix: String
) throws {
    if frame.streamID != runtime.videoStreamID {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).streamID"
        )
    }
    if frame.width != format.selectedWidth {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).width"
        )
    }
    if frame.height != format.selectedHeight {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).height"
        )
    }
    if directPeerNormalizedVideoPixelFormat(frame.pixelFormat)
        != directPeerNormalizedVideoPixelFormat(format.outputPixelFormat) {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).pixelFormat"
        )
    }
    let expectedPayloadBytes = format.selectedWidth
        * format.selectedHeight
        * directPeerVideoBytesPerPixel(format.outputPixelFormat)
    if frame.payloadByteCount != expectedPayloadBytes {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).payloadByteCount"
        )
    }
    guard let payloadDigest = frame.payloadDigest, !payloadDigest.isEmpty else {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).payloadDigest"
        )
    }
}

func validateMeasuredEvidence(_ evidence: DirectPeerSessionMeasuredEvidence) throws {
    try requireDirectPeerSessionNonPlaceholder(evidence.sourcePeerLabel, "measuredEvidence.sourcePeerLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.receiverPeerLabel, "measuredEvidence.receiverPeerLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.routeLabel, "measuredEvidence.routeLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.packetCapturePath, "measuredEvidence.packetCapturePath")
    try requireDirectPeerSessionNonPlaceholder(evidence.dscpObservation, "measuredEvidence.dscpObservation")
        try requireDirectPeerSessionNonPlaceholder(evidence.clockSyncSummary, "measuredEvidence.clockSyncSummary")
        if let packetCapture = evidence.packetCapture {
            try validateDirectPeerSessionEvidenceArtifact(
                packetCapture,
                "measuredEvidence.packetCapture",
                allowedExtensions: ["pcap", "pcapng"]
            )
        }
        if let dscp = evidence.dscp {
            try validateDirectPeerSessionDSCPEvidence(dscp)
        }
        if let clock = evidence.clock {
            try validateDirectPeerSessionClockEvidence(clock)
        }
        try requireDirectPeerSessionNonNegative(evidence.durationSeconds, "measuredEvidence.durationSeconds")
        if evidence.durationSeconds == 0 {
            throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("measuredEvidence.durationSeconds")
        }
}

func requireDirectPeerSessionNonPlaceholder(_ value: String?, _ field: String) throws {
    guard let value else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(field)
    }
    try requireDirectPeerSessionNonEmpty(value, field)
    if PlaceholderDetection.matches(
        value,
        containing: ["todo", "required", "synthetic", "placeholder", "not supplied", "localhost"],
        emptyIsPlaceholder: false
    ) {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(field)
    }
}

func requireDirectPeerSessionPassEvidenceArtifact(
    _ artifact: DirectPeerSessionEvidenceArtifact?,
    _ field: String,
    allowedExtensions: Set<String>
) throws {
    guard let artifact else {
        throw DirectPeerSessionReportError.passRequiresStructuredEvidence(field)
    }
    try validateDirectPeerSessionEvidenceArtifact(
        artifact,
        field,
        allowedExtensions: allowedExtensions
    )
    guard artifact.captured else {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).captured")
    }
    try requireDirectPeerSessionPassArtifactHash(artifact, field)
}

func validateDirectPeerSessionEvidenceArtifact(
    _ artifact: DirectPeerSessionEvidenceArtifact,
    _ field: String,
    allowedExtensions: Set<String>
) throws {
    try requireDirectPeerSessionNonPlaceholder(artifact.path, "\(field).path")
    if artifact.path.contains("\n") || artifact.path.hasSuffix("/") {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).path")
    }
    let ext = URL(fileURLWithPath: artifact.path).pathExtension.lowercased()
    if ext.isEmpty || !allowedExtensions.contains(ext) {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).path")
    }
    if let sha256 = artifact.sha256 {
        try requireDirectPeerSessionNonEmpty(sha256, "\(field).sha256")
    }
}

func requireDirectPeerSessionPassArtifactHash(
    _ artifact: DirectPeerSessionEvidenceArtifact,
    _ field: String
) throws {
    guard let sha256 = artifact.sha256 else {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).sha256")
    }
    try requireDirectPeerSessionNonEmpty(sha256, "\(field).sha256")
    let hex = Set("0123456789abcdefABCDEF")
    if sha256.count != 64 || sha256.contains(where: { !hex.contains($0) }) {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).sha256")
    }
}

func directPeerSessionIsLoopbackHost(_ host: String) -> Bool {
    let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "localhost"
        || normalized == "::1"
        || normalized == "[::1]"
        || normalized == "0:0:0:0:0:0:0:1"
        || normalized == "0000:0000:0000:0000:0000:0000:0000:0001"
        || normalized.hasPrefix("127.")
}
