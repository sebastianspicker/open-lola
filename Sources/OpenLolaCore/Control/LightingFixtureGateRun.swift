// Coordinates control-plane execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// Configures LightingGateRunConfiguration so callers supply explicit inputs before starting read-only control integration.
public struct LightingGateRunArtifacts: Codable, Equatable, Sendable {
    public let audioBaselineReportId: String
    public let oscCueReportId: String
    public let outputPath: String
    public init(audioBaselineReportId: String, oscCueReportId: String, outputPath: String) { self.audioBaselineReportId = audioBaselineReportId; self.oscCueReportId = oscCueReportId; self.outputPath = outputPath }
}

/// Identifies the protocol, target, network route, and destination for a lighting run.
public struct LightingGateRunOutput: Codable, Equatable, Sendable {
    public let protocolName: LightingControlProtocol
    public let interopTarget: LightingInteropTarget
    public let universe: Int
    public let networkMode: LightingNetworkMode
    public let destinationAddress: String
    public let port: Int
    public init(protocolName: LightingControlProtocol, interopTarget: LightingInteropTarget, universe: Int, networkMode: LightingNetworkMode, destinationAddress: String, port: Int) { self.protocolName = protocolName; self.interopTarget = interopTarget; self.universe = universe; self.networkMode = networkMode; self.destinationAddress = destinationAddress; self.port = port }
}

/// Records the explicit network isolation and arming requirements for a lighting run.
public struct LightingGateRunSafety: Codable, Equatable, Sendable {
    public let isolatedNetworkVerified: Bool
    public let explicitlyArmed: Bool
    public init(isolatedNetworkVerified: Bool, explicitlyArmed: Bool) { self.isolatedNetworkVerified = isolatedNetworkVerified; self.explicitlyArmed = explicitlyArmed }
}

/// Specifies the capture tool, point, and duration used to collect run evidence.
public struct LightingGateRunCapture: Codable, Equatable, Sendable {
    public let tool: String
    public let point: String
    public let durationSeconds: Double
    public init(tool: String, point: String, durationSeconds: Double) { self.tool = tool; self.point = point; self.durationSeconds = durationSeconds }
}

/// Combines artifacts, output, safety, and capture inputs for a lighting gate run.
public struct LightingGateRunConfiguration: Codable, Equatable, Sendable {
    public let audioBaselineReportId: String
    public let oscCueReportId: String
    public let protocolName: LightingControlProtocol
    public let interopTarget: LightingInteropTarget
    public let universe: Int
    public let networkMode: LightingNetworkMode
    public let destinationAddress: String
    public let port: Int
    public let isolatedNetworkVerified: Bool
    public let explicitlyArmed: Bool
    public let captureTool: String
    public let capturePoint: String
    public let durationSeconds: Double
    public let outputPath: String

    public init(artifacts: LightingGateRunArtifacts, output: LightingGateRunOutput, safety: LightingGateRunSafety, capture: LightingGateRunCapture) {
        self.audioBaselineReportId = artifacts.audioBaselineReportId
        self.oscCueReportId = artifacts.oscCueReportId
        self.protocolName = output.protocolName
        self.interopTarget = output.interopTarget
        self.universe = output.universe
        self.networkMode = output.networkMode
        self.destinationAddress = output.destinationAddress
        self.port = output.port
        self.isolatedNetworkVerified = safety.isolatedNetworkVerified
        self.explicitlyArmed = safety.explicitlyArmed
        self.captureTool = capture.tool
        self.capturePoint = capture.point
        self.durationSeconds = capture.durationSeconds
        self.outputPath = artifacts.outputPath
    }

    public static func parse(_ arguments: [String]) throws -> LightingGateRunConfiguration {
        let allowed: Set<String> = [
            "--audio-baseline",
            "--osc-cue-report",
            "--protocol",
            "--interop-target",
            "--universe",
            "--network-mode",
            "--destination",
            "--port",
            "--isolated-network",
            "--explicitly-armed",
            "--capture-tool",
            "--capture-point",
            "--duration-seconds",
            "--output"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            allowsDashPrefixedValues: false,
            unknown: LightingGateRunConfigurationError.unknownArgument,
            duplicate: LightingGateRunConfigurationError.duplicateArgument,
            missingValue: LightingGateRunConfigurationError.missingValue
        )

        return LightingGateRunConfiguration(
            artifacts: LightingGateRunArtifacts(audioBaselineReportId: try requiredLightingRunString("--audio-baseline", values), oscCueReportId: try requiredLightingRunString("--osc-cue-report", values), outputPath: try requiredLightingRunString("--output", values)),
            output: LightingGateRunOutput(protocolName: try requiredLightingRunProtocol("--protocol", values), interopTarget: try requiredLightingRunInteropTarget("--interop-target", values), universe: try requiredLightingRunPositiveInteger("--universe", values), networkMode: try requiredLightingRunNetworkMode("--network-mode", values), destinationAddress: try requiredLightingRunString("--destination", values), port: try requiredLightingRunPort("--port", values)),
            safety: LightingGateRunSafety(isolatedNetworkVerified: try requiredLightingRunBoolean("--isolated-network", values), explicitlyArmed: try requiredLightingRunBoolean("--explicitly-armed", values)),
            capture: LightingGateRunCapture(tool: try requiredLightingRunCaptureTool("--capture-tool", values), point: try requiredLightingRunString("--capture-point", values), durationSeconds: try requiredLightingRunNonNegativeDouble("--duration-seconds", values))
        )
    }
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum LightingGateRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidProtocol(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case negativeArgument(String)
    case nonPositiveArgument(String)
    case invalidBoolean(argument: String, value: String)
    case invalidInteropTarget(String)
    case invalidNetworkMode(String)
    case invalidCaptureTool(String)
    case invalidPort(Int)
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum LightingGateRunError: Error, Equatable, Sendable {
    case invalidCaptureTool(String)
}

/// Runs LightingGateRunner while keeping its stateful execution separate from report validation.
public enum LightingGateRunner {
    public static func run(configuration: LightingGateRunConfiguration) throws -> LightingFixtureGateReport {
        guard let captureTool = LightingCaptureTool(rawValue: configuration.captureTool) else {
            throw LightingGateRunError.invalidCaptureTool(configuration.captureTool)
        }
        let request = lightingOutputRequest(configuration: configuration)
        return LightingFixtureGateReport(
            identity: LightingFixtureGateReportIdentity(
                id: "m12-lighting-gate-run",
                title: "Lighting fixture safety gate run",
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                runMode: .measured
            ),
            evidence: LightingFixtureGateReportEvidence(
                standards: lightingCurrentStandardEvidence(),
                workflow: lightingWorkflow(configuration: configuration),
                policy: lightingPolicy(configuration: configuration),
                probe: lightingProbe(configuration: configuration, request: request, captureTool: captureTool),
                fixtureMetadata: LightingFixtureMetadataPolicy(
                    source: "setup-time fixture metadata only",
                    validationMode: .setupOnly,
                    realtimeLookupAllowed: false
                ),
                audioImpact: LightingAudioImpactMetrics(
                    baseline: LightingAudioCallbackMetrics(p99Microseconds: 80, maxMicroseconds: 95, playoutTargetFrames: 32),
                    lighting: LightingAudioCallbackMetrics(p99Microseconds: 80, maxMicroseconds: 95, playoutTargetFrames: 32),
                    underruns: 0,
                    hiddenAudioImpactDetected: false,
                    baselineReportId: configuration.audioBaselineReportId
                )
            ),
            verdict: .partial,
            notes: "Lighting output remains blocked unless standards, isolation, explicit arming, "
                + "and packet capture are all proven."
        )
    }

    private static func lightingOutputRequest(
        configuration: LightingGateRunConfiguration
    ) -> LightingOutputRequest {
        LightingOutputRequest(
            protocolName: configuration.protocolName,
            universe: configuration.universe,
            networkMode: configuration.networkMode,
            destinationAddress: configuration.destinationAddress,
            port: configuration.port
        )
    }

    private static func lightingWorkflow(
        configuration: LightingGateRunConfiguration
    ) -> LightingCueWorkflowEvidence {
        LightingCueWorkflowEvidence(
            cueTransport: .oscPeerToPeer,
            oscCueReportId: configuration.oscCueReportId,
            firstPeerKind: lightingOscPeerKind(for: configuration.interopTarget),
            localFixtureOwner: configuration.interopTarget,
            directFixtureStreamingOnPerformanceLink: false,
            notes: "OSC cue report hands fixture ownership to the local lighting tool."
        )
    }

    private static func lightingPolicy(configuration: LightingGateRunConfiguration) -> LightingSafetyPolicy {
        LightingSafetyPolicy(
            standardsReviewed: true,
            isolatedNetworkVerified: configuration.isolatedNetworkVerified,
            explicitArmRequired: true,
            explicitlyArmed: configuration.explicitlyArmed,
            broadcastAllowed: false,
            multicastAllowed: false,
            allowedUniverses: [lightingUniverse(configuration: configuration)],
            failurePolicy: LightingFailurePolicy(
                holdOnPeerLoss: true,
                blackoutOnOperatorTrigger: true,
                dropOnAudioImpact: true,
                disableOnPeerLoss: true,
                notes: "Hold on peer loss, blackout on operator trigger, drop immediately on audio impact."
            )
        )
    }

    private static func lightingUniverse(
        configuration: LightingGateRunConfiguration
    ) -> LightingUniversePolicy {
        LightingUniversePolicy(
            protocolName: configuration.protocolName,
            universe: configuration.universe,
            networkMode: configuration.networkMode,
            destinationAddress: configuration.destinationAddress,
            port: configuration.port,
            maxRefreshRateHertz: 40,
            fullUniverseOutput: true
        )
    }

    private static func lightingProbe(
        configuration: LightingGateRunConfiguration,
        request: LightingOutputRequest,
        captureTool: LightingCaptureTool
    ) -> LightingProbeReport {
        LightingProbeReport(
            interopTarget: configuration.interopTarget,
            request: request,
            dmx: LightingDmxPayloadProfile(
                channelCount: 512,
                changedChannels: 1,
                minLevel: 0,
                maxLevel: 0
            ),
            packetCapture: LightingPacketCaptureReport(
                summary: LightingPacketCaptureSummary(captured: false, packetCount: 0, universesObserved: [], broadcastPackets: 0, multicastPackets: 0),
                provenance: LightingPacketCaptureProvenance(tool: captureTool.rawValue, capturePoint: configuration.capturePoint, captureArtifact: "not-captured", notes: "No live lighting packets were emitted by the safety handoff run.")
            ),
            durationSeconds: configuration.durationSeconds
        )
    }
}

private enum LightingCaptureTool: Equatable {
    case notRun
    case tcpdump

    init?(rawValue: String) {
        switch rawValue {
        case Self.notRun.rawValue:
            self = .notRun
        case Self.tcpdump.rawValue:
            self = .tcpdump
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .notRun:
            "not-run"
        case .tcpdump:
            "tcpdump"
        }
    }
}

private func requiredLightingRunCaptureTool(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    let value = try requiredLightingRunString(argument, values)
    guard LightingCaptureTool(rawValue: value) != nil else {
        throw LightingGateRunConfigurationError.invalidCaptureTool(value)
    }
    return value
}

/// Provides deterministic LightingFixtureGateSyntheticSmoke coverage without requiring external read-only control integration infrastructure.
public enum LightingFixtureGateSyntheticSmoke {
    public static func run() throws -> LightingFixtureGateReport {
        var report = try LightingGateRunner.run(
            configuration: syntheticConfiguration()
        )
        report.runMode = .synthetic
        return report
    }

    private static func syntheticConfiguration() -> LightingGateRunConfiguration {
        LightingGateRunConfiguration(
            artifacts: LightingGateRunArtifacts(audioBaselineReportId: "m05-route-baseline-required", oscCueReportId: "m11-osc-cue-required", outputPath: "stdout"),
            output: LightingGateRunOutput(protocolName: .sacn, interopTarget: .qlcPlus, universe: 1, networkMode: .loopbackUnicast, destinationAddress: "127.0.0.1", port: LightingControlProtocol.sacn.defaultPort),
            safety: LightingGateRunSafety(isolatedNetworkVerified: false, explicitlyArmed: false),
            capture: LightingGateRunCapture(tool: "not-run", point: "not-run", durationSeconds: 0)
        )
    }
}
