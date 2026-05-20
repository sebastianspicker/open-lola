import Foundation

public enum IntegratedProfileSyntheticSmoke {
    public static func run() -> IntegratedProfileReport {
        IntegratedProfileReport(
            id: "m12-integrated-profile-synthetic-smoke",
            title: "Synthetic M12 integrated profile report",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            defaultProfile: .fastestAudio,
            profileOptions: integratedProfileDefaultOptions(
                fastestAudioReportId: "m07-fastest-audio-required",
                integratedAvReportId: "m10-integrated-av-required",
                lightingControlReportId: "m11-lighting-control-required",
                fullMatrixReportId: "m12-full-matrix-required"
            ),
            subordinateEvidence: integratedProfileDefaultSubordinateEvidence(
                fastestAudioReportId: "m07-fastest-audio-required",
                integratedAvReportId: "m10-integrated-av-required",
                lightingControlReportId: "m11-lighting-control-required"
            ),
            degradationOrder: integratedProfileDefaultDegradationOrder,
            benchmarkMatrix: integratedProfileDefaultBenchmarkMatrix(
                reportIds: integratedProfileDefaultMatrixReportIds()
            ),
            verdict: .partial,
            notes: "Synthetic M12 integrated profile report; no physical full-matrix evidence is supplied."
        )
    }
}

public struct IntegratedProfileRunConfiguration: Codable, Equatable, Sendable {
    public let fastestAudioReportId: String
    public let integratedAvReportId: String
    public let lightingControlReportId: String
    public let matrixReportIds: [IntegratedProfileBenchmarkScenario: String]
    public let fastestAudioReportPath: String?
    public let integratedAvReportPath: String?
    public let lightingControlReportPath: String?
    public let outputPath: String

    public init(
        fastestAudioReportId: String,
        integratedAvReportId: String,
        lightingControlReportId: String,
        matrixReportIds: [IntegratedProfileBenchmarkScenario: String],
        fastestAudioReportPath: String? = nil,
        integratedAvReportPath: String? = nil,
        lightingControlReportPath: String? = nil,
        outputPath: String
    ) {
        self.fastestAudioReportId = fastestAudioReportId
        self.integratedAvReportId = integratedAvReportId
        self.lightingControlReportId = lightingControlReportId
        self.matrixReportIds = matrixReportIds
        self.fastestAudioReportPath = fastestAudioReportPath
        self.integratedAvReportPath = integratedAvReportPath
        self.lightingControlReportPath = lightingControlReportPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> IntegratedProfileRunConfiguration {
        let allowed = Set([
            "--fastest-audio",
            "--integrated-av",
            "--lighting-control",
            "--audio-only",
            "--audio-video",
            "--audio-control",
            "--audio-video-control",
            "--fastest-audio-report",
            "--integrated-av-report",
            "--lighting-control-report",
            "--output",
        ])
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw IntegratedProfileRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw IntegratedProfileRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw IntegratedProfileRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        return IntegratedProfileRunConfiguration(
            fastestAudioReportId: try requiredIntegratedProfileRunString("--fastest-audio", values),
            integratedAvReportId: try requiredIntegratedProfileRunString("--integrated-av", values),
            lightingControlReportId: try requiredIntegratedProfileRunString("--lighting-control", values),
            matrixReportIds: [
                .audioOnly: try requiredIntegratedProfileRunString("--audio-only", values),
                .audioVideo: try requiredIntegratedProfileRunString("--audio-video", values),
                .audioControl: try requiredIntegratedProfileRunString("--audio-control", values),
                .audioVideoControl: try requiredIntegratedProfileRunString("--audio-video-control", values),
            ],
            fastestAudioReportPath: values["--fastest-audio-report"],
            integratedAvReportPath: values["--integrated-av-report"],
            lightingControlReportPath: values["--lighting-control-report"],
            outputPath: try requiredIntegratedProfileRunString("--output", values)
        )
    }
}

public enum IntegratedProfileRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

public enum IntegratedProfileRunner {
    public static func run(configuration: IntegratedProfileRunConfiguration) -> IntegratedProfileReport {
        run(configuration: configuration, runtimeEvidence: IntegratedProfileRuntimeEvidence())
    }

    public static func run(
        configuration: IntegratedProfileRunConfiguration,
        runtimeEvidence evidence: IntegratedProfileRuntimeEvidence
    ) -> IntegratedProfileReport {
        let report = IntegratedProfileReport(
            id: "m12-integrated-profile-run",
            title: "M12 integrated profile handoff",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .synthetic,
            defaultProfile: .fastestAudio,
            profileOptions: integratedProfileDefaultOptions(
                fastestAudioReportId: configuration.fastestAudioReportId,
                integratedAvReportId: configuration.integratedAvReportId,
                lightingControlReportId: configuration.lightingControlReportId,
                fullMatrixReportId: configuration.matrixReportIds[.audioVideoControl]
                    ?? "m12-full-matrix-required"
            ),
            subordinateEvidence: integratedProfileDefaultSubordinateEvidence(
                fastestAudioReportId: configuration.fastestAudioReportId,
                integratedAvReportId: configuration.integratedAvReportId,
                lightingControlReportId: configuration.lightingControlReportId
            ),
            degradationOrder: integratedProfileDefaultDegradationOrder,
            benchmarkMatrix: integratedProfileDefaultBenchmarkMatrix(reportIds: configuration.matrixReportIds),
            verdict: .partial,
            notes: "Bounded M12 handoff records profile and matrix report references; physical PASS evidence remains required."
        )
        return integratedProfileReportApplyingRuntimeEvidence(
            report,
            configuration: configuration,
            evidence: evidence
        )
    }
}


private let integratedProfileDefaultDegradationOrder: [IntegratedProfileDegradationStep] = [
    .reduceVideoQuality,
    .reduceVideoFrameRate,
    .disableLighting,
    .disableVideo,
    .increaseAudioLatency,
]

private func integratedProfileDefaultOptions(
    fastestAudioReportId: String,
    integratedAvReportId: String,
    lightingControlReportId: String,
    fullMatrixReportId: String
) -> [IntegratedProfileOption] {
    [
        IntegratedProfileOption(
            label: .fastestAudio,
            features: [],
            defaultProfile: true,
            latencyCostMicroseconds: 0,
            sourceReportId: fastestAudioReportId,
            costReportId: "m12-fastest-audio-cost-baseline",
            verdict: .partial,
            notes: "Default audio-first profile; optional video and lighting are disabled."
        ),
        IntegratedProfileOption(
            label: .audioVideo,
            features: [.video],
            defaultProfile: false,
            latencyCostMicroseconds: 500,
            sourceReportId: integratedAvReportId,
            costReportId: "m12-audio-video-cost-required",
            verdict: .partial,
            notes: "Optional video profile; field users must see the measured latency cost."
        ),
        IntegratedProfileOption(
            label: .audioLighting,
            features: [.lightingControl],
            defaultProfile: false,
            latencyCostMicroseconds: 100,
            sourceReportId: lightingControlReportId,
            costReportId: "m12-audio-lighting-cost-required",
            verdict: .partial,
            notes: "Optional lighting/control profile; local fixture ownership stays outside the audio deadline."
        ),
        IntegratedProfileOption(
            label: .audioVideoLighting,
            features: [.video, .lightingControl],
            defaultProfile: false,
            latencyCostMicroseconds: 700,
            sourceReportId: fullMatrixReportId,
            costReportId: "m12-audio-video-lighting-cost-required",
            verdict: .partial,
            notes: "Optional full integrated profile; cost must be measured against the fastest-audio baseline."
        ),
    ]
}

private func integratedProfileDefaultSubordinateEvidence(
    fastestAudioReportId: String,
    integratedAvReportId: String,
    lightingControlReportId: String
) -> [IntegratedProfileSubordinateEvidence] {
    [
        integratedProfilePartialEvidence(
            .fastestAudio,
            fastestAudioReportId,
            "M07 fastest audio selection is required before PASS."
        ),
        integratedProfilePartialEvidence(
            .audioRoute,
            "m05-m06-audio-route-required",
            "Accepted M05/M06 physical route evidence is required before PASS."
        ),
        integratedProfilePartialEvidence(
            .videoCapture,
            "m08-video-capture-required",
            "Accepted M08 physical capture evidence is required before PASS."
        ),
        integratedProfilePartialEvidence(
            .videoTransport,
            "m09-video-transport-required",
            "Accepted M09 video transport evidence is required before PASS."
        ),
        integratedProfilePartialEvidence(
            .integratedAv,
            integratedAvReportId,
            "Accepted M10 integrated A/V evidence is required before PASS."
        ),
        integratedProfilePartialEvidence(
            .lightingControl,
            lightingControlReportId,
            "Accepted M11 lighting/control evidence is required before PASS."
        ),
    ]
}

private func integratedProfilePartialEvidence(
    _ lane: IntegratedProfileSubordinateLane,
    _ reportId: String,
    _ notes: String
) -> IntegratedProfileSubordinateEvidence {
    IntegratedProfileSubordinateEvidence(
        lane: lane,
        reportId: reportId,
        verdict: .partial,
        measured: false,
        physicalPassEvidence: false,
        notes: notes
    )
}

private func integratedProfileDefaultMatrixReportIds() -> [IntegratedProfileBenchmarkScenario: String] {
    [
        .audioOnly: "m12-audio-only-synthetic-matrix",
        .audioVideo: "m12-audio-video-synthetic-matrix",
        .audioControl: "m12-audio-control-synthetic-matrix",
        .audioVideoControl: "m12-audio-video-control-synthetic-matrix",
    ]
}

private func integratedProfileDefaultBenchmarkMatrix(
    reportIds: [IntegratedProfileBenchmarkScenario: String]
) -> [IntegratedProfileBenchmarkRow] {
    [
        integratedProfileMatrixRow(
            .audioOnly,
            reportIds[.audioOnly] ?? "m12-audio-only-required",
            audioLatencyP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            audioJitterP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            droppedVideoFrames: 0,
            cueTimingP99Microseconds: 0,
            cpuP99Percent: SyntheticPlaceholderMetrics.cpuPercent,
            residentMemoryMegabytes: 96,
            notes: "Synthetic audio-only matrix row; physical fastest-audio benchmark not supplied."
        ),
        integratedProfileMatrixRow(
            .audioVideo,
            reportIds[.audioVideo] ?? "m12-audio-video-required",
            audioLatencyP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            audioJitterP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            droppedVideoFrames: 2,
            cueTimingP99Microseconds: 0,
            cpuP99Percent: SyntheticPlaceholderMetrics.cpuPercent,
            residentMemoryMegabytes: 160,
            notes: "Synthetic audio plus video matrix row; physical capture and transport evidence not supplied."
        ),
        integratedProfileMatrixRow(
            .audioControl,
            reportIds[.audioControl] ?? "m12-audio-control-required",
            audioLatencyP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            audioJitterP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            droppedVideoFrames: 0,
            cueTimingP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            cpuP99Percent: SyntheticPlaceholderMetrics.cpuPercent,
            residentMemoryMegabytes: 110,
            notes: "Synthetic audio plus control matrix row; physical lighting/control cue timing evidence not supplied."
        ),
        integratedProfileMatrixRow(
            .audioVideoControl,
            reportIds[.audioVideoControl] ?? "m12-audio-video-control-required",
            audioLatencyP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            audioJitterP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            droppedVideoFrames: 2,
            cueTimingP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            cpuP99Percent: SyntheticPlaceholderMetrics.cpuPercent,
            residentMemoryMegabytes: 190,
            notes: "Synthetic audio plus video plus control matrix row; physical full matrix evidence not supplied."
        ),
    ]
}

private func integratedProfileMatrixRow(
    _ scenario: IntegratedProfileBenchmarkScenario,
    _ reportId: String,
    audioLatencyP99Microseconds: Double,
    audioJitterP99Microseconds: Double,
    droppedVideoFrames: Int,
    cueTimingP99Microseconds: Double,
    cpuP99Percent: Double,
    residentMemoryMegabytes: Double,
    notes: String
) -> IntegratedProfileBenchmarkRow {
    IntegratedProfileBenchmarkRow(
        scenario: scenario,
        reportId: reportId,
        verdict: .partial,
        measured: false,
        physicalEvidence: false,
        metrics: IntegratedProfileBenchmarkMetrics(
            audioLatencyP99Microseconds: audioLatencyP99Microseconds,
            audioJitterP99Microseconds: audioJitterP99Microseconds,
            lostPackets: 0,
            latePackets: 1,
            underruns: 1,
            droppedVideoFrames: droppedVideoFrames,
            cueTimingP99Microseconds: cueTimingP99Microseconds,
            cpuP99Percent: cpuP99Percent,
            residentMemoryMegabytes: residentMemoryMegabytes,
            measurementDurationSeconds: nil,
            callbackDeadlineWarnings: 1,
            allocationWarnings: 1,
            threadSchedulingWarnings: 1
        ),
        notes: notes
    )
}


private func requiredIntegratedProfileRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw IntegratedProfileRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}
