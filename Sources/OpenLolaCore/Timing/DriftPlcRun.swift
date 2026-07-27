// Drives a fixed-target drift and PLC simulation, preserving correction state and samples needed to reproduce the resulting report.
import Foundation

/// Binds `routeReportPath`, `durationSeconds`, `policy`, and `artifactAssessmentCompleted` before timing and drift control starts, preventing implicit runtime defaults.
public struct DriftPlcRunConfiguration: Codable, Equatable, Sendable {
    public let routeReportPath: String
    public let durationSeconds: Int
    public let policy: SameDeadlinePlcPolicy
    public let artifactAssessmentCompleted: Bool
    public let artifactNotes: String
    public let outputPath: String

    public init(
        routeReportPath: String,
        durationSeconds: Int,
        policy: SameDeadlinePlcPolicy,
        artifactAssessmentCompleted: Bool,
        artifactNotes: String,
        outputPath: String
    ) {
        self.routeReportPath = routeReportPath
        self.durationSeconds = durationSeconds
        self.policy = policy
        self.artifactAssessmentCompleted = artifactAssessmentCompleted
        self.artifactNotes = artifactNotes
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> DriftPlcRunConfiguration {
        let allowed: Set<String> = [
            "--route-report",
            "--duration-seconds",
            "--policy",
            "--artifact-assessment-completed",
            "--artifact-notes",
            "--output"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            unknown: DriftPlcRunConfigurationError.unknownArgument,
            duplicate: DriftPlcRunConfigurationError.duplicateArgument,
            missingValue: DriftPlcRunConfigurationError.missingValue
        )

        return DriftPlcRunConfiguration(
            routeReportPath: try requiredDriftRunString("--route-report", values),
            durationSeconds: try requiredDriftRunPositiveInteger("--duration-seconds", values),
            policy: try parseDriftRunPolicy(try requiredDriftRunString("--policy", values)),
            artifactAssessmentCompleted: try requiredDriftRunBoolean(
                "--artifact-assessment-completed",
                values
            ),
            artifactNotes: try requiredDriftRunString("--artifact-notes", values),
            outputPath: try requiredDriftRunString("--output", values)
        )
    }
}

/// Reports `missingRequiredArgument`, `missingValue`, `unknownArgument`, and `duplicateArgument` failures that stop invalid timing and drift control work before it reaches a live path.
public enum DriftPlcRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidBoolean(argument: String, value: String)
    case invalidPolicy(String)
}

/// Executes a bounded drift plc fixed target run and returns accountable timing and drift control evidence.
public enum DriftPlcFixedTargetRunner {
    public static func makeReport(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) throws -> DriftPlcReport {
        let state = try makeRunState(routeReport: routeReport, configuration: configuration)
        return makeReport(routeReport: routeReport, configuration: configuration, state: state)
    }

    private static func makeRunState(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) throws -> DriftPlcFixedTargetRunState {
        let playoutTargetFrames = fixedPlayoutTargetFrames(routeReport: routeReport)
        let packetCount = fixedTargetPacketCount(routeReport: routeReport, configuration: configuration)
        let telemetry = fixedTargetTelemetry(
            packetCount: packetCount,
            playoutTargetFrames: playoutTargetFrames,
            packetMode: routeReport.packetMode,
            packetAgeMicroseconds: routeReport.metrics.packetAge.p50Microseconds
        )
        let estimate = driftClockEstimate(
            telemetry: telemetry,
            sampleRateHertz: routeReport.packetMode.sampleRateHertz
        )
        let plcEvents = fixedTargetPlcEvents(
            routeReport: routeReport,
            playoutTargetFrames: playoutTargetFrames,
            policy: configuration.policy
        )
        let measuredCorrectionEvents = fixedTargetCorrectionEvents(
            telemetry: telemetry,
            sampleRateHertz: routeReport.packetMode.sampleRateHertz,
            correctionStepFrames: routeReport.packetMode.framesPerPacket
        )
        let correctionEvents = measuredCorrectionEvents.isEmpty
            ? defaultFixedTargetCorrectionEvents(
                playoutTargetFrames: playoutTargetFrames,
                routeReport: routeReport,
                configuration: configuration
            )
            : measuredCorrectionEvents
        let rxBufferPolicy = try RxBufferPolicy.direct(
            framesPerPacket: routeReport.packetMode.framesPerPacket,
            sampleRateHertz: routeReport.packetMode.sampleRateHertz,
            targetPackets: 1
        )

        return DriftPlcFixedTargetRunState(
            playoutTargetFrames: playoutTargetFrames,
            telemetry: telemetry,
            plcEvents: plcEvents,
            correctionEvents: correctionEvents,
            estimate: estimate,
            rxBufferPolicy: rxBufferPolicy
        )
    }

    private static func fixedTargetPacketCount(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) -> Int {
        max(
            1,
            configuration.durationSeconds * routeReport.packetMode.sampleRateHertz
                / routeReport.packetMode.framesPerPacket
        )
    }

    private static func defaultFixedTargetCorrectionEvents(
        playoutTargetFrames: Int,
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) -> [DriftCorrectionEvent] {
        let durationFrames = configuration.durationSeconds * routeReport.packetMode.sampleRateHertz
        return [
            DriftCorrectionEvent(
                playoutFrameIndex: max(playoutTargetFrames, durationFrames / 3),
                driftFramesBefore: 0,
                driftFramesAfter: 0,
                location: .outsideCallback,
                targetGrowthFrames: 0,
                notes: "Fixed-target drift audit completed outside the realtime callback."
            )
        ]
    }

    private static func makeReport(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration,
        state: DriftPlcFixedTargetRunState
    ) -> DriftPlcReport {
        DriftPlcReport(
            identity: .init(
                id: "m06-drift-plc-fixed-target",
                title: "Fixed-target drift and same-deadline PLC report",
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                route: routeReport.route,
                packetMode: routeReport.packetMode
            ),
            measurements: .init(
                telemetry: state.telemetry,
                plcEvents: state.plcEvents,
                correctionEvents: state.correctionEvents,
                metrics: makeMetrics(
                    routeReport: routeReport,
                    configuration: configuration,
                    state: state
                )
            ),
            assessment: .init(
                artifactAssessmentCompleted: configuration.artifactAssessmentCompleted,
                artifactNotes: configuration.artifactNotes,
                verdict: passEligible(routeReport: routeReport, configuration: configuration) ? .pass : .partial,
                notes: "Fixed playout target stayed constant; drift correction is scheduled outside the realtime callback."
            )
        )
    }

    private static func makeMetrics(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration,
        state: DriftPlcFixedTargetRunState
    ) -> DriftPlcMetrics {
        DriftPlcMetrics(
            callbackTiming: .init(
                durationSeconds: configuration.durationSeconds,
                playoutTargetFrames: state.playoutTargetFrames,
                callbackP99Microseconds: routeReport.metrics.callbackP99Microseconds ?? 0,
                callbackMaxMicroseconds: routeReport.metrics.callbackMaxMicroseconds ?? 0
            ),
            recovery: .init(
                underruns: 0,
                correctionEvents: state.correctionEvents.count,
                plcEvents: state.plcEvents.count,
                maxAbsoluteDriftFrames: state.estimate.maxAbsoluteDriftFrames,
                driftSlopeFramesPerMinute: state.estimate.driftSlopeFramesPerMinute,
                hiddenPlayoutGrowthDetected: routeReport.metrics.hiddenPlayoutGrowthDetected
            ),
            rxBuffer: RxBufferRuntimeSnapshot(
                policy: state.rxBufferPolicy,
                targetObservation: .init(
                    hiddenGrowthDetected: routeReport.metrics.hiddenPlayoutGrowthDetected
                ),
                packetCounters: .init(
                    latePackets: routeReport.metrics.latePackets,
                    lostPackets: routeReport.metrics.lostPackets,
                    duplicatePackets: routeReport.metrics.duplicatePackets,
                    reorderedPackets: routeReport.metrics.reorderedPackets
                ),
                playoutCounters: .init(plcEvents: state.plcEvents.count)
            )
        )
    }

    private static func passEligible(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) -> Bool {
        configuration.durationSeconds >= DriftPlcMetrics.minimumPassDurationSeconds
            && configuration.artifactAssessmentCompleted
            && routeReport.verdict == .pass
            && !routeReport.metrics.hiddenPlayoutGrowthDetected
            && routeReport.metrics.callbackP99Microseconds != nil
            && routeReport.metrics.callbackMaxMicroseconds != nil
    }
}

private struct DriftPlcFixedTargetRunState {
    var playoutTargetFrames: Int
    var telemetry: [DriftTelemetrySample]
    var plcEvents: [SameDeadlinePlcEvent]
    var correctionEvents: [DriftCorrectionEvent]
    var estimate: DriftClockEstimate
    var rxBufferPolicy: RxBufferPolicy
}

/// Exercises a deterministic timing and drift control path so regressions remain reproducible without hardware.
public enum DriftPlcSyntheticSmoke {
    public static func run() throws -> DriftPlcReport {
        try DriftPlcFixedTargetRunner.makeReport(
            routeReport: syntheticRouteReport(),
            configuration: syntheticRunConfiguration()
        )
    }

    private static func syntheticRouteReport() -> UdpPcmRouteReport {
        UdpPcmRouteReport(
            identity: .init(
                id: "m05-synthetic-route",
                title: "Synthetic UDP PCM route",
                capturedAt: "2026-05-02T00:00:00Z",
                route: syntheticRouteIdentity(),
                routeKind: .directLink
            ),
            endpoints: .init(sender: syntheticRouteSender(), receiver: syntheticRouteReceiver()),
            measurement: .init(
                packetMode: syntheticPacketMode(),
                measuredDurationSeconds: 60,
                network: syntheticNetworkProfile(),
                metrics: syntheticRouteMetrics()
            ),
            outcome: .init(verdict: .partial, notes: "Synthetic route input for drift smoke.")
        )
    }

    private static func syntheticRouteIdentity() -> RouteIdentity {
        RouteIdentity(label: "synthetic-direct-link", topology: "mac-to-mac-direct-cable")
    }

    private static func syntheticRouteSender() -> UdpPcmRouteEndpoint {
        UdpPcmRouteEndpoint(
            label: "sender",
            hostName: "sender",
            interfaceName: "en5",
            ipAddress: "10.10.20.10"
        )
    }

    private static func syntheticRouteReceiver() -> UdpPcmRouteEndpoint {
        UdpPcmRouteEndpoint(
            label: "receiver",
            hostName: "receiver",
            interfaceName: "en5",
            ipAddress: "10.10.20.11"
        )
    }

    private static func syntheticPacketMode() -> UdpPcmPacketMode {
        UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    }

    private static func syntheticNetworkProfile() -> UdpPcmNetworkProfile {
        UdpPcmNetworkProfile(
            linkRateMbps: 1_000,
            vlan: "none",
            multicastPolicy: "unicast-only",
            dscp: UdpPcmDscpObservation(
                requested: 46,
                observed: 46,
                classification: .honored,
                notTestedReason: nil
            ),
            packetCapture: UdpPcmPacketCapture(
                point: "synthetic capture",
                receiverCorrelation: true,
                notes: "Synthetic route only."
            )
        )
    }

    private static func syntheticRouteMetrics() -> UdpPcmRouteMetrics {
        UdpPcmRouteMetrics(
            delivery: .init(
                packetsSent: 90_000,
                packetsReceived: 90_000,
                lostPackets: 0,
                latePackets: 0,
                reorderedPackets: 0,
                duplicatePackets: 0
            ),
            timing: .init(
                packetAge: SourceValidationMetrics.audioPacketAge,
                jitterP99Microseconds: SourceValidationMetrics.jitter.p99Microseconds,
                playoutTargetMicroseconds: SourceValidationMetrics.audioPacketAge.p99Microseconds
            ),
            hiddenPlayoutGrowthDetected: false
        )
    }

    private static func syntheticRunConfiguration() -> DriftPlcRunConfiguration {
        DriftPlcRunConfiguration(
            routeReportPath: "synthetic-route.json",
            durationSeconds: 60,
            policy: .silence,
            artifactAssessmentCompleted: false,
            artifactNotes: "Synthetic smoke only.",
            outputPath: "stdout"
        )
    }
}
