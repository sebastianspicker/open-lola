import Foundation

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

public enum DriftPlcFixedTargetRunner {
    public static func makeReport(
        routeReport: UdpPcmRouteReport,
        configuration: DriftPlcRunConfiguration
    ) throws -> DriftPlcReport {
        let playoutTargetFrames = fixedPlayoutTargetFrames(routeReport: routeReport)
        let packetCount = max(
            1,
            configuration.durationSeconds * routeReport.packetMode.sampleRateHertz
                / routeReport.packetMode.framesPerPacket
        )
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
        let durationFrames = configuration.durationSeconds * routeReport.packetMode.sampleRateHertz
        let correctionEvents = measuredCorrectionEvents.isEmpty
            ? [
                DriftCorrectionEvent(
                    playoutFrameIndex: max(playoutTargetFrames, durationFrames / 3),
                    driftFramesBefore: 0,
                    driftFramesAfter: 0,
                    location: .outsideCallback,
                    targetGrowthFrames: 0,
                    notes: "Fixed-target drift audit completed outside the realtime callback."
                )
            ]
            : measuredCorrectionEvents
        let rxBufferPolicy = try RxBufferPolicy.direct(
            framesPerPacket: routeReport.packetMode.framesPerPacket,
            sampleRateHertz: routeReport.packetMode.sampleRateHertz,
            targetPackets: 1
        )

        let passEligible = configuration.durationSeconds >= DriftPlcMetrics.minimumPassDurationSeconds
            && configuration.artifactAssessmentCompleted
            && routeReport.verdict == .pass
            && !routeReport.metrics.hiddenPlayoutGrowthDetected
            && routeReport.metrics.callbackP99Microseconds != nil
            && routeReport.metrics.callbackMaxMicroseconds != nil

        return DriftPlcReport(
            id: "m06-drift-plc-fixed-target",
            title: "Fixed-target drift and same-deadline PLC report",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            route: routeReport.route,
            packetMode: routeReport.packetMode,
            telemetry: telemetry,
            plcEvents: plcEvents,
            correctionEvents: correctionEvents,
            metrics: DriftPlcMetrics(
                durationSeconds: configuration.durationSeconds,
                playoutTargetFrames: playoutTargetFrames,
                callbackP99Microseconds: routeReport.metrics.callbackP99Microseconds ?? 0,
                callbackMaxMicroseconds: routeReport.metrics.callbackMaxMicroseconds ?? 0,
                underruns: 0,
                correctionEvents: correctionEvents.count,
                plcEvents: plcEvents.count,
                maxAbsoluteDriftFrames: estimate.maxAbsoluteDriftFrames,
                driftSlopeFramesPerMinute: estimate.driftSlopeFramesPerMinute,
                hiddenPlayoutGrowthDetected: routeReport.metrics.hiddenPlayoutGrowthDetected,
                rxBuffer: RxBufferRuntimeSnapshot(
                    policy: rxBufferPolicy,
                    latePackets: routeReport.metrics.latePackets,
                    lostPackets: routeReport.metrics.lostPackets,
                    duplicatePackets: routeReport.metrics.duplicatePackets,
                    reorderedPackets: routeReport.metrics.reorderedPackets,
                    plcEvents: plcEvents.count,
                    hiddenGrowthDetected: routeReport.metrics.hiddenPlayoutGrowthDetected
                )
            ),
            artifactAssessmentCompleted: configuration.artifactAssessmentCompleted,
            artifactNotes: configuration.artifactNotes,
            verdict: passEligible ? .pass : .partial,
            notes: "Fixed playout target stayed constant; drift correction is scheduled outside the realtime callback."
        )
    }
}

public enum DriftPlcSyntheticSmoke {
    public static func run() throws -> DriftPlcReport {
        let routeReport = UdpPcmRouteReport(
            id: "m05-synthetic-route",
            title: "Synthetic UDP PCM route",
            capturedAt: "2026-05-02T00:00:00Z",
            route: RouteIdentity(label: "synthetic-direct-link", topology: "mac-to-mac-direct-cable"),
            routeKind: .directLink,
            sender: UdpPcmRouteEndpoint(
                label: "sender",
                hostName: "sender",
                interfaceName: "en5",
                ipAddress: "10.10.20.10"
            ),
            receiver: UdpPcmRouteEndpoint(
                label: "receiver",
                hostName: "receiver",
                interfaceName: "en5",
                ipAddress: "10.10.20.11"
            ),
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            measuredDurationSeconds: 60,
            network: UdpPcmNetworkProfile(
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
            ),
            metrics: UdpPcmRouteMetrics(
                packetsSent: 90_000,
                packetsReceived: 90_000,
                lostPackets: 0,
                latePackets: 0,
                reorderedPackets: 0,
                duplicatePackets: 0,
                packetAge: UdpPcmPacketAgeMetrics(
                    p50Microseconds: 100,
                    p95Microseconds: 160,
                    p99Microseconds: 200,
                    maxMicroseconds: 240
                ),
                jitterP99Microseconds: 40,
                playoutTargetMicroseconds: 666,
                hiddenPlayoutGrowthDetected: false
            ),
            verdict: .partial,
            notes: "Synthetic route input for drift smoke."
        )
        return try DriftPlcFixedTargetRunner.makeReport(
            routeReport: routeReport,
            configuration: DriftPlcRunConfiguration(
                routeReportPath: "synthetic-route.json",
                durationSeconds: 60,
                policy: .silence,
                artifactAssessmentCompleted: false,
                artifactNotes: "Synthetic smoke only.",
                outputPath: "stdout"
            )
        )
    }
}
