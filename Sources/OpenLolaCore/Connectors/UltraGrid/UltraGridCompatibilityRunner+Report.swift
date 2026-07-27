// Builds the UltraGrid runtime report from the already-measured exchange state.
import Foundation

struct UltraGridRuntimeMediaReportBuilder {
    let context: UltraGridCompatibilityRunner.RuntimeMediaReportContext

    func report() -> UltraGridCompatibilityMediaReport {
        let zeroTransmission = context.configuration.role.transmits
            && context.configuration.mediaPacketCount > 0
            && context.transmittedDatagramCount == 0
        let error = context.runtimeError ?? (zeroTransmission ? noTransmissionError : nil)
        return UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
            identity: identity,
            packets: packets,
            quality: quality,
            reports: reports,
            evidence: evidence(runtimeError: error, zeroTransmission: zeroTransmission)
        ))
    }

    private var noTransmissionError: String {
        "no UltraGrid RTP/MVTP datagrams were successfully transmitted"
    }

    private var identity: UltraGridCompatibilityMediaIdentity {
        UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-mvtp-\(context.configuration.role.rawValue)-media",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            role: context.configuration.role,
            mediaMode: context.configuration.mediaMode
        )
    }

    private var packets: UltraGridCompatibilityPacketSummary {
        UltraGridCompatibilityPacketSummary(
            datagrams: context.datagrams,
            transmittedDatagramCount: context.transmittedDatagramCount,
            receivedDatagramCount: context.receivedDatagramCount
        )
    }

    private var quality: UltraGridCompatibilityQualityCounters {
        UltraGridCompatibilityQualityCounters(
            rtpPacketsLost: context.analysis.lost,
            rtpDuplicatePacketCount: context.analysis.duplicates,
            rtpOutOfOrderPacketCount: context.analysis.outOfOrder,
            rtpSsrcChangeCount: context.analysis.ssrcChanges,
            rtpTimestampRegressionCount: context.analysis.timestampRegressions,
            rtpJitterLikeArrivalDeltaCount: context.analysis.jitterLikeArrivalDeltaChanges,
            videoFrameReassemblyFailureCount: context.analysis.videoFrameReassemblyFailures
        )
    }

    private var reports: UltraGridCompatibilityNestedReports {
        UltraGridCompatibilityNestedReports(
            topology: context.topology,
            control: context.control,
            provider: context.provider,
            sink: context.sink
        )
    }

    private func evidence(
        runtimeError: String?,
        zeroTransmission: Bool
    ) -> UltraGridCompatibilityEvidenceState {
        UltraGridCompatibilityEvidenceState(
            observedEvidenceClasses: context.observedEvidenceClasses,
            missingEvidenceClassesForPass: context.missingEvidenceClassesForPass,
            realLinkTransmitted: !context.configuration.dryRun && context.transmittedDatagramCount > 0,
            verdict: runtimeError == nil ? .partial : .fail,
            runtimeError: runtimeError,
            notes: notes(zeroTransmission: zeroTransmission)
        )
    }

    private func notes(zeroTransmission: Bool) -> String {
        let base = "Swift-native UltraGrid RTP/MVTP \(context.configuration.role.rawValue) " +
            "run for PT20 raw video only (no JPEG/H.264 session support), " +
            "optional PT24/PT25 AES-GCM encryption, optional PT22 single-parity FEC, " +
            "PT21 PCM audio, and modeled TCP control commands. Provider selection is " +
            "recorded separately; reference-peer evidence remains required for PASS."
        return zeroTransmission ? base + " No UDP datagram was successfully sent, so the runtime verdict is FAIL." : base
    }
}
