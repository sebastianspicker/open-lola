import Foundation
import OpenLolaCore

func directP2PApplyMeasuredEvidence(
    _ report: DirectPeerSessionReport,
    values: [String: String]
) throws -> DirectPeerSessionReport {
    var report = report
    if let verdictValue = values["--verdict"] {
        guard let verdict = MeasurementVerdict(rawValue: verdictValue) else {
            throw CommandError.invalidArgument("invalid --verdict")
        }
        report.verdict = verdict
    }
    if directP2PHasMeasuredEvidence(values) {
        report.measuredEvidence = DirectPeerSessionMeasuredEvidence(
            kind: try directP2PMeasuredEvidenceKind(values["--measured-evidence-kind"]),
            sourcePeerLabel: try directP2PMeasuredEvidenceField("--source-peer-label", values),
            receiverPeerLabel: try directP2PMeasuredEvidenceField("--receiver-peer-label", values),
            routeLabel: try directP2PMeasuredEvidenceField("--route-label", values),
            packetCapturePath: try directP2PMeasuredEvidenceField("--packet-capture-path", values),
            packetCapture: try directP2PEvidenceArtifact(
                pathKey: "--packet-capture-artifact-path",
                capturedKey: "--packet-capture-artifact-captured",
                sha256Key: "--packet-capture-sha256",
                values: values,
                fallbackPathKey: "--packet-capture-path"
            ),
            dscpObservation: try directP2PMeasuredEvidenceField("--dscp-observation", values),
            dscp: try directP2PDSCPEvidence(values),
            clockSyncSummary: try directP2PMeasuredEvidenceField("--clock-sync-summary", values),
            clock: try directP2PClockEvidence(values),
            rawVideoReceiveEvidence: values["--raw-video-receive-evidence"],
            durationSeconds: try directP2PMeasuredDuration(values)
        )
    }
    if directP2PHasFastestAVBaseline(values) {
        guard report.avRuntime != nil else {
            throw CommandError.invalidArgument("fastest AV baseline comparison requires AV runtime")
        }
        report.avRuntime?.fastestAVBaselineComparison = try directP2PFastestAVBaselineComparison(values)
    }
    return report
}

func directP2PAttachGeneratedReceiveEvidence(
    _ report: DirectPeerSessionReport,
    values: [String: String]
) -> DirectPeerSessionReport {
    guard let outputPath = values["--rx-proof-output"],
          report.avRuntime?.receiveProof != nil,
          var measuredEvidence = report.measuredEvidence,
          measuredEvidence.rawVideoReceiveEvidence == nil else {
        return report
    }
    var report = report
    measuredEvidence.rawVideoReceiveEvidence = directP2PRawVideoReceiveEvidencePath(rxProofOutputPath: outputPath)
    report.measuredEvidence = measuredEvidence
    return report
}

func directP2PWriteReceiveProofArtifacts(
    _ report: DirectPeerSessionReport,
    values: [String: String]
) throws {
    guard let outputPath = values["--rx-proof-output"] else {
        return
    }
    guard let avRuntime = report.avRuntime,
          let proof = avRuntime.receiveProof else {
        throw CommandError.invalidArgument("--rx-proof-output requires AV receive proof")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let artifact = DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: proof,
        runtimeCounters: avRuntime.runtimeMetrics
    )
    try writeJSONData(try encoder.encode(artifact), to: outputPath)
    let rawEvidenceArtifact = DirectPeerSessionRawVideoReceiveEvidenceArtifact(report: report, proof: proof)
    try writeJSONData(
        try encoder.encode(rawEvidenceArtifact),
        to: directP2PRawVideoReceiveEvidencePath(rxProofOutputPath: outputPath)
    )
}

func directP2PWriteAutoEvidenceArtifact(
    _ report: DirectPeerSessionReport,
    values: [String: String]
) throws {
    guard let outputPath = values["--auto-evidence-output"] else {
        return
    }
    let artifact = DirectP2PAutoEvidenceArtifact(
        id: "m06-direct-p2p-auto-evidence-\(Int(Date().timeIntervalSince1970))",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        reportID: report.id,
        sessionID: report.configuration.sessionID,
        requestedDSCP: values["--dscp"].flatMap(Int.init),
        packetCapturePath: values["--packet-capture-path"],
        packetCaptureCaptured: values["--packet-capture-path"] != nil,
        dscpObservation: values["--dscp-observation"] ?? "not captured automatically; supply measured --dscp-observation for PASS",
        clockSyncSummary: values["--clock-sync-summary"] ?? "not captured automatically; supply measured --clock-sync-summary for PASS",
        receiveProofPresent: report.avRuntime?.receiveProof != nil,
        rawVideoReceiveEvidence: report.measuredEvidence?.rawVideoReceiveEvidence,
        verdict: .partial,
        notes: "CLI evidence artifact records local run metadata and declared capture inputs. It is not promoted to measured PASS evidence unless operator-supplied packet capture, DSCP observation, and clock sync fields are attached to the session report."
    )
    try writeJSONData(try artifact.prettyJSONData(), to: outputPath)
}

private struct DirectP2PAutoEvidenceArtifact: PrettyJSONCodable, Equatable, Sendable {
    var id: String
    var capturedAt: String
    var reportID: String
    var sessionID: String
    var requestedDSCP: Int?
    var packetCapturePath: String?
    var packetCaptureCaptured: Bool
    var dscpObservation: String
    var clockSyncSummary: String
    var receiveProofPresent: Bool
    var rawVideoReceiveEvidence: String?
    var verdict: MeasurementVerdict
    var notes: String
}

private func directP2PRawVideoReceiveEvidencePath(rxProofOutputPath: String) -> String {
    if rxProofOutputPath.hasSuffix(".json") {
        return String(rxProofOutputPath.dropLast(5)) + "-raw-video-evidence.json"
    }
    return rxProofOutputPath + "-raw-video-evidence.json"
}

private func directP2PHasMeasuredEvidence(_ values: [String: String]) -> Bool {
    [
        "--measured-evidence-kind",
        "--source-peer-label",
        "--receiver-peer-label",
        "--route-label",
        "--packet-capture-path",
        "--packet-capture-artifact-path",
        "--dscp-observation",
        "--dscp-artifact-path",
        "--clock-sync-summary",
        "--clock-artifact-path",
        "--raw-video-receive-evidence",
        "--measured-duration-seconds",
    ].contains { values[$0] != nil }
}

private func directP2PEvidenceArtifact(
    pathKey: String,
    capturedKey: String,
    sha256Key: String,
    values: [String: String],
    fallbackPathKey: String? = nil
) throws -> DirectPeerSessionEvidenceArtifact? {
    let path = values[pathKey] ?? fallbackPathKey.flatMap { values[$0] }
    guard let path, !path.isEmpty else {
        return nil
    }
    return DirectPeerSessionEvidenceArtifact(
        path: path,
        captured: try directP2PBool(values[capturedKey], defaultValue: false, label: capturedKey),
        sha256: values[sha256Key]
    )
}

private func directP2PDSCPEvidence(_ values: [String: String]) throws -> DirectPeerSessionDSCPEvidence? {
    guard values["--dscp-artifact-path"] != nil || values["--dscp-observed"] != nil else {
        return nil
    }
    guard let artifact = try directP2PEvidenceArtifact(
        pathKey: "--dscp-artifact-path",
        capturedKey: "--dscp-artifact-captured",
        sha256Key: "--dscp-artifact-sha256",
        values: values
    ) else {
        throw CommandError.invalidArgument("missing --dscp-artifact-path")
    }
    return DirectPeerSessionDSCPEvidence(
        requested: values["--dscp"].flatMap(Int.init),
        observed: values["--dscp-observed"].flatMap(Int.init),
        classification: try directP2PDSCPClassification(values["--dscp-classification"]),
        capturePoint: try directP2PMeasuredEvidenceField("--dscp-capture-point", values),
        artifact: artifact
    )
}

private func directP2PClockEvidence(_ values: [String: String]) throws -> DirectPeerSessionClockEvidence? {
    guard values["--clock-artifact-path"] != nil || values["--clock-source"] != nil else {
        return nil
    }
    guard let artifact = try directP2PEvidenceArtifact(
        pathKey: "--clock-artifact-path",
        capturedKey: "--clock-artifact-captured",
        sha256Key: "--clock-artifact-sha256",
        values: values
    ) else {
        throw CommandError.invalidArgument("missing --clock-artifact-path")
    }
    return DirectPeerSessionClockEvidence(
        clockSource: try directP2PMeasuredEvidenceField("--clock-source", values),
        method: try directP2PMeasuredEvidenceField("--clock-method", values),
        maxOffsetMicroseconds: try directP2PRequiredDouble("--clock-max-offset-microseconds", values),
        artifact: artifact
    )
}

private func directP2PDSCPClassification(
    _ value: String?
) throws -> DirectPeerSessionDSCPClassification {
    guard let value else {
        return .honored
    }
    guard let classification = DirectPeerSessionDSCPClassification(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --dscp-classification")
    }
    return classification
}

private func directP2PHasFastestAVBaseline(_ values: [String: String]) -> Bool {
    [
        "--fastest-baseline-report-id",
        "--fastest-baseline-report-path",
        "--fastest-baseline-comparison-path",
    ].contains { values[$0] != nil }
}

private func directP2PFastestAVBaselineComparison(
    _ values: [String: String]
) throws -> DirectPeerSessionFastestAVBaselineComparison {
    DirectPeerSessionFastestAVBaselineComparison(
        audioOnlyBaselineReportID: try directP2PMeasuredEvidenceField("--fastest-baseline-report-id", values),
        audioOnlyBaselineReportPath: try directP2PMeasuredEvidenceField("--fastest-baseline-report-path", values),
        comparisonArtifactPath: try directP2PMeasuredEvidenceField("--fastest-baseline-comparison-path", values),
        audioOnlyLatencyP99Microseconds: try directP2PRequiredDouble("--fastest-baseline-audio-p99-us", values),
        fastestAVAudioLatencyP99Microseconds: try directP2PRequiredDouble("--fastest-av-audio-p99-us", values),
        audioLatencyEqualToBaseline: try directP2PBool(values["--fastest-audio-latency-equal"], defaultValue: false, label: "--fastest-audio-latency-equal"),
        rxBufferEqualToBaseline: try directP2PBool(values["--fastest-rx-buffer-equal"], defaultValue: false, label: "--fastest-rx-buffer-equal"),
        lossJitterEqualToBaseline: try directP2PBool(values["--fastest-loss-jitter-equal"], defaultValue: false, label: "--fastest-loss-jitter-equal")
    )
}

private func directP2PRequiredDouble(_ key: String, _ values: [String: String]) throws -> Double {
    guard let value = values[key], let number = Double(value), number >= 0 else {
        throw CommandError.invalidArgument("invalid \(key)")
    }
    return number
}

private func directP2PBool(_ value: String?, defaultValue: Bool, label: String) throws -> Bool {
    guard let value else {
        return defaultValue
    }
    switch value {
    case "true":
        return true
    case "false":
        return false
    default:
        throw CommandError.invalidArgument("invalid \(label)")
    }
}

private func directP2PMeasuredEvidenceKind(
    _ value: String?
) throws -> DirectPeerSessionMeasuredEvidenceKind {
    guard let value else {
        return .physicalTwoPeerMacs
    }
    guard let kind = DirectPeerSessionMeasuredEvidenceKind(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --measured-evidence-kind")
    }
    return kind
}

private func directP2PMeasuredEvidenceField(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(argument)")
    }
    return value
}

private func directP2PMeasuredDuration(_ values: [String: String]) throws -> Double {
    let value = values["--measured-duration-seconds"] ?? values["--duration-seconds"]
    guard let value, let duration = Double(value), duration > 0 else {
        throw CommandError.invalidArgument("invalid --measured-duration-seconds")
    }
    return duration
}
