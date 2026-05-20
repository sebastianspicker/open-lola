import Foundation
import OpenLolaContracts

func makeLoLaMediaSessionReport(
    id: String,
    role: LoLaCompatibilityMediaSessionRole,
    mediaMode: ExternalConnectorMediaMode,
    frames: [LoLaCompatibilityMediaFrame],
    realLinkTransmitted: Bool,
    verdict: MeasurementVerdict = .partial,
    runtimeError: String? = nil,
    localHost: String? = nil,
    peer: String? = nil,
    audioPort: UInt16? = nil,
    videoPort: UInt16? = nil,
    timeoutSeconds: Int? = nil,
    expectedDatagramCount: Int? = nil,
    sentBytesTotal: Int? = nil,
    notes: String
) -> LoLaCompatibilityMediaSessionReport {
    LoLaCompatibilityMediaSessionReport(
        id: id,
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        role: role,
        mediaMode: mediaMode,
        frames: frames,
        realLinkTransmitted: realLinkTransmitted,
        verdict: verdict,
        runtimeError: runtimeError,
        localHost: localHost,
        peer: peer,
        audioPort: audioPort,
        videoPort: videoPort,
        timeoutSeconds: timeoutSeconds,
        expectedDatagramCount: expectedDatagramCount,
        sentBytesTotal: sentBytesTotal,
        evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
        notes: notes
    )
}
