func validateDirectPeerSessionAVRuntimeUsefulMediaProof(
    _ avRuntime: DirectPeerSessionAVRuntimeMetadata
) throws {
    switch avRuntime.qualityPolicy {
    case .structural:
        guard avRuntime.usefulMediaProof == .notRequired else {
            throw DirectPeerSessionReportError.invalidUsefulMediaProof("avRuntime.usefulMediaProof")
        }
    case .requireUsefulMedia:
        guard avRuntime.usefulMediaProof == .requiredAndProven
                || avRuntime.usefulMediaProof == .requiredButNotProven else {
            throw DirectPeerSessionReportError.invalidUsefulMediaProof("avRuntime.usefulMediaProof")
        }
    case nil:
        guard avRuntime.usefulMediaProof == .unknown else {
            throw DirectPeerSessionReportError.invalidUsefulMediaProof("avRuntime.usefulMediaProof")
        }
    }
}

func requireDirectPeerSessionPassDSCPEvidence(
    _ evidence: DirectPeerSessionDSCPEvidence?
) throws -> DirectPeerSessionDSCPEvidence {
    guard let evidence else {
        throw DirectPeerSessionReportError.passRequiresStructuredEvidence("measuredEvidence.dscp")
    }
    guard evidence.classification == .honored else {
        throw DirectPeerSessionReportError.passWithInvalidDSCPEvidence("measuredEvidence.dscp.classification")
    }
    guard evidence.observed != nil else {
        throw DirectPeerSessionReportError.passWithInvalidDSCPEvidence("measuredEvidence.dscp.observed")
    }
    return evidence
}

func requireDirectPeerSessionPassUsefulMediaProof(
    _ avRuntime: DirectPeerSessionAVRuntimeMetadata
) throws {
    guard avRuntime.qualityPolicy == .requireUsefulMedia,
          avRuntime.usefulMediaProof == .requiredAndProven else {
        throw DirectPeerSessionReportError.passRequiresUsefulMediaProof(avRuntime.usefulMediaProof)
    }
}
