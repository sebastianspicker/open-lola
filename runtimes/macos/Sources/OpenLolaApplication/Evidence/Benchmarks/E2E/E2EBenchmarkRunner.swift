import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates end-to-end benchmark execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation
import OpenLolaContracts

/// Captures run configuration required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkRunConfiguration: Codable, Equatable, Sendable {
    public let audioBenchmarkPath: String
    public let integratedAvPath: String
    public let videoTransportPath: String
    public let performanceAuditPath: String
    public let durationSeconds: Double
    public let outputPath: String

    public init(
        audioBenchmarkPath: String,
        integratedAvPath: String,
        videoTransportPath: String,
        performanceAuditPath: String,
        durationSeconds: Double,
        outputPath: String
    ) {
        self.audioBenchmarkPath = audioBenchmarkPath
        self.integratedAvPath = integratedAvPath
        self.videoTransportPath = videoTransportPath
        self.performanceAuditPath = performanceAuditPath
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> E2EBenchmarkRunConfiguration {
        let allowed: Set<String> = [
            "--audio-benchmark",
            "--integrated-av",
            "--video-transport",
            "--performance-audit",
            "--duration-seconds",
            "--output"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            unknown: E2EBenchmarkRunConfigurationError.unknownArgument,
            duplicate: E2EBenchmarkRunConfigurationError.duplicateArgument,
            missingValue: E2EBenchmarkRunConfigurationError.missingValue
        )
        return E2EBenchmarkRunConfiguration(
            audioBenchmarkPath: try requiredE2EBenchmarkRunString("--audio-benchmark", values),
            integratedAvPath: try requiredE2EBenchmarkRunString("--integrated-av", values),
            videoTransportPath: try requiredE2EBenchmarkRunString("--video-transport", values),
            performanceAuditPath: try requiredE2EBenchmarkRunString("--performance-audit", values),
            durationSeconds: try requiredE2EBenchmarkRunPositiveDouble("--duration-seconds", values),
            outputPath: try requiredE2EBenchmarkRunString("--output", values)
        )
    }
}

/// Describes failures that prevent end-to-end benchmark inputs or evidence from satisfying the required validation invariants.
public enum E2EBenchmarkRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidNumber(argument: String, value: String)
    case nonPositiveArgument(String)
}

/// Runs the end-to-end benchmark evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum E2EBenchmarkRunner {
    public static func run(
        configuration: E2EBenchmarkRunConfiguration,
        audioBenchmark: LatencyBenchmarkReport,
        integratedAv: IntegratedAvReport,
        videoTransport: VideoTransportReport,
        performanceAudit: PerformanceAuditReport,
        sessions: E2EBenchmarkSessionInputs = E2EBenchmarkSessionInputs()
    ) throws -> E2EBenchmarkReport {
        let physical = physicalInputs(
            audioBenchmark: audioBenchmark,
            integratedAv: integratedAv,
            videoTransport: videoTransport,
            performanceAudit: performanceAudit
        )
        let verdict = e2eVerdict(
            physicalInputs: physical,
            durationSeconds: configuration.durationSeconds,
            componentVerdicts: componentVerdicts(
                audioBenchmark,
                integratedAv,
                videoTransport,
                performanceAudit
            )
        )
        return withholdingUnmeasuredPass(E2EBenchmarkReport(
            id: "m13-e2e-integrated-benchmark-run",
            title: "M13 E2E integrated benchmark aggregate run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: configuration.durationSeconds,
            runMode: physical ? .measured : .synthetic,
            evidenceKind: physical ? .physicalTwoPeerRig : .synthetic,
            hardware: hardware(
                from: audioBenchmark,
                videoTransport: videoTransport,
                performanceAudit: performanceAudit,
                sessions: sessions
            ),
            componentReports: componentReports(
                audioBenchmark: audioBenchmark,
                integratedAv: integratedAv,
                videoTransport: videoTransport,
                performanceAudit: performanceAudit
            ),
            profiles: profiles(context: E2EBenchmarkProfileBuildContext(
                audioBenchmark: audioBenchmark, integratedAv: integratedAv,
                videoTransport: videoTransport, performanceAudit: performanceAudit, sessions: sessions,
                measured: physical, physicalEvidence: physical,
                verdict: verdict == .fail ? .fail : (physical ? .pass : .partial)
            )),
            impairments: impairments(),
            recovery: recoveryMetrics(),
            thresholds: thresholds(),
            verdict: verdict,
            notes: notes(for: configuration, sessions: sessions)
        ))
    }

    private static func componentReports(
        audioBenchmark: LatencyBenchmarkReport,
        integratedAv: IntegratedAvReport,
        videoTransport: VideoTransportReport,
        performanceAudit: PerformanceAuditReport
    ) -> E2EBenchmarkComponentReports {
        E2EBenchmarkComponentReports(
            audioBenchmarkReportId: audioBenchmark.id,
            integratedAvReportId: integratedAv.id,
            videoTransportReportId: videoTransport.id,
            performanceAuditReportId: performanceAudit.id
        )
    }

    // No input report records a reconnect or shutdown run, so recovery is reported as not measured.
    private static func recoveryMetrics() -> E2EBenchmarkRecoveryMetrics {
        E2EBenchmarkRecoveryMetrics(
            measured: false,
            reconnectEvents: 0,
            reconnectP99Microseconds: nil,
            cleanShutdownObserved: false,
            leakedRealtimeCallbacksAfterShutdown: 0,
            recoveryReportId: "m13-reconnect-not-measured",
            shutdownReportId: "m13-shutdown-not-measured"
        )
    }

    private static func thresholds() -> E2EBenchmarkThresholds {
        E2EBenchmarkThresholds(
            methodologyDocument: "docs/benchmark-methodology.md",
            packetLossMaxPercent: 0,
            cpuP99MaxPercent: 80,
            audioP99DeltaFromBaselineToleranceMicroseconds: 50,
            audioUnderrunMaxCount: 0,
            droppedFrameMaxCount: 0
        )
    }

    private static func componentVerdicts(
        _ audioBenchmark: LatencyBenchmarkReport,
        _ integratedAv: IntegratedAvReport,
        _ videoTransport: VideoTransportReport,
        _ performanceAudit: PerformanceAuditReport
    ) -> [MeasurementVerdict] {
        [
            audioBenchmark.verdict,
            integratedAv.verdict,
            videoTransport.verdict,
            performanceAudit.verdict
        ]
    }

    private static func notes(
        for configuration: E2EBenchmarkRunConfiguration,
        sessions: E2EBenchmarkSessionInputs
    ) -> String {
        "Aggregate M13 report generated from \(configuration.audioBenchmarkPath), " +
            "\(configuration.integratedAvPath), \(configuration.videoTransportPath), " +
            "and \(configuration.performanceAuditPath)." + sessions.provenanceNote
    }
}
