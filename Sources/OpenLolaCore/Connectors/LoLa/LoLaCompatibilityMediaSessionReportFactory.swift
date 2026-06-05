import Foundation
import OpenLolaContracts

struct LoLaCompatibilityMediaSessionReportDraft {
    var id: String
    var role: LoLaCompatibilityMediaSessionRole
    var mediaMode: ExternalConnectorMediaMode
    var frames: [LoLaCompatibilityMediaFrame]
    var realLinkTransmitted: Bool
    var verdict: MeasurementVerdict = .partial
    var runtimeError: String?
    var localHost: String?
    var peer: String?
    var audioPort: UInt16?
    var videoPort: UInt16?
    var timeoutSeconds: Int?
    var expectedDatagramCount: Int?
    var sentBytesTotal: Int?
    var notes: String
}

func makeLoLaMediaSessionReport(
    _ draft: LoLaCompatibilityMediaSessionReportDraft
) -> LoLaCompatibilityMediaSessionReport {
    LoLaCompatibilityMediaSessionReport(fields: LoLaCompatibilityMediaSessionReportFields(
        id: draft.id,
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        role: draft.role,
        mediaMode: draft.mediaMode,
        frames: draft.frames,
        realLinkTransmitted: draft.realLinkTransmitted,
        verdict: draft.verdict,
        runtimeError: draft.runtimeError,
        localHost: draft.localHost,
        peer: draft.peer,
        audioPort: draft.audioPort,
        videoPort: draft.videoPort,
        timeoutSeconds: draft.timeoutSeconds,
        expectedDatagramCount: draft.expectedDatagramCount,
        sentBytesTotal: draft.sentBytesTotal,
        evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
        notes: draft.notes
    ))
}
