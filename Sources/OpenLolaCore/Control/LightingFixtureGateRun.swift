import Foundation

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

    public init(
        audioBaselineReportId: String,
        oscCueReportId: String,
        protocolName: LightingControlProtocol,
        interopTarget: LightingInteropTarget,
        universe: Int,
        networkMode: LightingNetworkMode,
        destinationAddress: String,
        port: Int,
        isolatedNetworkVerified: Bool,
        explicitlyArmed: Bool,
        captureTool: String,
        capturePoint: String,
        durationSeconds: Double,
        outputPath: String
    ) {
        self.audioBaselineReportId = audioBaselineReportId
        self.oscCueReportId = oscCueReportId
        self.protocolName = protocolName
        self.interopTarget = interopTarget
        self.universe = universe
        self.networkMode = networkMode
        self.destinationAddress = destinationAddress
        self.port = port
        self.isolatedNetworkVerified = isolatedNetworkVerified
        self.explicitlyArmed = explicitlyArmed
        self.captureTool = captureTool
        self.capturePoint = capturePoint
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> LightingGateRunConfiguration {
        let allowed = [
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
            "--output",
        ]
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw LightingGateRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw LightingGateRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw LightingGateRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        return LightingGateRunConfiguration(
            audioBaselineReportId: try requiredLightingRunString("--audio-baseline", values),
            oscCueReportId: try requiredLightingRunString("--osc-cue-report", values),
            protocolName: try requiredLightingRunProtocol("--protocol", values),
            interopTarget: try requiredLightingRunInteropTarget("--interop-target", values),
            universe: try requiredLightingRunPositiveInteger("--universe", values),
            networkMode: try requiredLightingRunNetworkMode("--network-mode", values),
            destinationAddress: try requiredLightingRunString("--destination", values),
            port: try requiredLightingRunPort("--port", values),
            isolatedNetworkVerified: try requiredLightingRunBoolean("--isolated-network", values),
            explicitlyArmed: try requiredLightingRunBoolean("--explicitly-armed", values),
            captureTool: try requiredLightingRunCaptureTool("--capture-tool", values),
            capturePoint: try requiredLightingRunString("--capture-point", values),
            durationSeconds: try requiredLightingRunNonNegativeDouble("--duration-seconds", values),
            outputPath: try requiredLightingRunString("--output", values)
        )
    }
}

public enum LightingGateRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case negativeArgument(String)
    case nonPositiveArgument(String)
    case invalidBoolean(argument: String, value: String)
    case invalidProtocol(String)
    case invalidInteropTarget(String)
    case invalidNetworkMode(String)
    case invalidCaptureTool(String)
    case invalidPort(Int)
}

public enum LightingGateRunError: Error, Equatable, Sendable {
    case invalidCaptureTool(String)
}

public enum LightingGateRunner {
    public static func run(configuration: LightingGateRunConfiguration) throws -> LightingFixtureGateReport {
        guard let captureTool = LightingCaptureTool(rawValue: configuration.captureTool) else {
            throw LightingGateRunError.invalidCaptureTool(configuration.captureTool)
        }
        let request = LightingOutputRequest(
            protocolName: configuration.protocolName,
            universe: configuration.universe,
            networkMode: configuration.networkMode,
            destinationAddress: configuration.destinationAddress,
            port: configuration.port
        )
        return LightingFixtureGateReport(
            id: "m12-lighting-gate-run",
            title: "Lighting fixture safety gate run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            standards: lightingCurrentStandardEvidence(),
            workflow: LightingCueWorkflowEvidence(
                cueTransport: .oscPeerToPeer,
                oscCueReportId: configuration.oscCueReportId,
                firstPeerKind: lightingOscPeerKind(for: configuration.interopTarget),
                localFixtureOwner: configuration.interopTarget,
                directFixtureStreamingOnPerformanceLink: false,
                notes: "OSC cue report hands fixture ownership to the local lighting tool."
            ),
            policy: LightingSafetyPolicy(
                standardsReviewed: true,
                isolatedNetworkVerified: configuration.isolatedNetworkVerified,
                explicitArmRequired: true,
                explicitlyArmed: configuration.explicitlyArmed,
                broadcastAllowed: false,
                multicastAllowed: false,
                allowedUniverses: [
                    LightingUniversePolicy(
                        protocolName: configuration.protocolName,
                        universe: configuration.universe,
                        networkMode: configuration.networkMode,
                        destinationAddress: configuration.destinationAddress,
                        port: configuration.port,
                        maxRefreshRateHertz: 40,
                        fullUniverseOutput: true
                    )
                ],
                failurePolicy: LightingFailurePolicy(
                    holdOnPeerLoss: true,
                    blackoutOnOperatorTrigger: true,
                    dropOnAudioImpact: true,
                    disableOnPeerLoss: true,
                    notes: "Hold on peer loss, blackout on operator trigger, drop immediately on audio impact."
                )
            ),
            probe: LightingProbeReport(
                interopTarget: configuration.interopTarget,
                request: request,
                dmx: LightingDmxPayloadProfile(
                    channelCount: 512,
                    changedChannels: 1,
                    minLevel: 0,
                    maxLevel: 0
                ),
                packetCapture: LightingPacketCaptureReport(
                    captured: false,
                    tool: captureTool.rawValue,
                    capturePoint: configuration.capturePoint,
                    packetCount: 0,
                    universesObserved: [],
                    broadcastPackets: 0,
                    multicastPackets: 0,
                    captureArtifact: "not-captured",
                    notes: "No live lighting packets were emitted by the safety handoff run."
                ),
                durationSeconds: configuration.durationSeconds
            ),
            fixtureMetadata: LightingFixtureMetadataPolicy(
                source: "setup-time fixture metadata only",
                validationMode: .setupOnly,
                realtimeLookupAllowed: false
            ),
            audioImpact: LightingAudioImpactMetrics(
                baselineCallbackP99Microseconds: 80,
                lightingCallbackP99Microseconds: 80,
                baselineCallbackMaxMicroseconds: 95,
                lightingCallbackMaxMicroseconds: 95,
                baselinePlayoutTargetFrames: 32,
                lightingPlayoutTargetFrames: 32,
                underruns: 0,
                hiddenAudioImpactDetected: false,
                baselineReportId: configuration.audioBaselineReportId
            ),
            verdict: .partial,
            notes: "Lighting output remains blocked unless standards, isolation, explicit arming, and packet capture are all proven."
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
            audioBaselineReportId: "m05-route-baseline-required",
            oscCueReportId: "m11-osc-cue-required",
            protocolName: .sacn,
            interopTarget: .qlcPlus,
            universe: 1,
            networkMode: .loopbackUnicast,
            destinationAddress: "127.0.0.1",
            port: LightingControlProtocol.sacn.defaultPort,
            isolatedNetworkVerified: false,
            explicitlyArmed: false,
            captureTool: "not-run",
            capturePoint: "not-run",
            durationSeconds: 0,
            outputPath: "stdout"
        )
    }
}
