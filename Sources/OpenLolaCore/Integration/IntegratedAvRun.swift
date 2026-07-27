// Runs the integrated audio/video proof and records synchronized media and system-load evidence.
import Foundation
import OpenLolaContracts

/// Defines the validated fields for integrated AV run configuration.
public struct IntegratedAvRunConfiguration: Codable, Equatable, Sendable {
    public let audioBaselineReportId: String
    public let videoCaptureEnabled: Bool
    public let videoTransportEnabled: Bool
    public let videoPreviewEnabled: Bool
    public let oscControlEnabled: Bool
    public let atemReadOnlyHost: String?
    public let durationSeconds: Int
    public let videoTransportReportPath: String?
    public let outputPath: String

    public struct MediaOptions: Equatable, Sendable {
        public var videoCaptureEnabled: Bool
        public var videoTransportEnabled: Bool
        public var videoPreviewEnabled: Bool

        public init(
            videoCaptureEnabled: Bool,
            videoTransportEnabled: Bool,
            videoPreviewEnabled: Bool = false
        ) {
            self.videoCaptureEnabled = videoCaptureEnabled
            self.videoTransportEnabled = videoTransportEnabled
            self.videoPreviewEnabled = videoPreviewEnabled
        }
    }

    public struct ControlOptions: Equatable, Sendable {
        public var oscControlEnabled: Bool
        public var atemReadOnlyHost: String?

        public init(oscControlEnabled: Bool, atemReadOnlyHost: String?) {
            self.oscControlEnabled = oscControlEnabled
            self.atemReadOnlyHost = atemReadOnlyHost
        }
    }

    public struct ArtifactPaths: Equatable, Sendable {
        public var audioBaselineReportId: String
        public var videoTransportReportPath: String?
        public var outputPath: String

        public init(
            audioBaselineReportId: String,
            videoTransportReportPath: String? = nil,
            outputPath: String
        ) {
            self.audioBaselineReportId = audioBaselineReportId
            self.videoTransportReportPath = videoTransportReportPath
            self.outputPath = outputPath
        }
    }

    public init(
        artifacts: ArtifactPaths,
        media: MediaOptions,
        control: ControlOptions,
        durationSeconds: Int,
    ) {
        self.audioBaselineReportId = artifacts.audioBaselineReportId
        self.videoCaptureEnabled = media.videoCaptureEnabled
        self.videoTransportEnabled = media.videoTransportEnabled
        self.videoPreviewEnabled = media.videoPreviewEnabled
        self.oscControlEnabled = control.oscControlEnabled
        self.atemReadOnlyHost = control.atemReadOnlyHost
        self.durationSeconds = durationSeconds
        self.videoTransportReportPath = artifacts.videoTransportReportPath
        self.outputPath = artifacts.outputPath
    }

    public static func parse(_ arguments: [String]) throws -> IntegratedAvRunConfiguration {
        let allowed: Set<String> = [
            "--audio-baseline",
            "--video-capture",
            "--video-transport",
            "--video-preview",
            "--osc-control",
            "--atem-readonly",
            "--duration-seconds",
            "--video-transport-report",
            "--output"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            allowsDashPrefixedValues: false,
            unknown: IntegratedAvRunConfigurationError.unknownArgument,
            duplicate: IntegratedAvRunConfigurationError.duplicateArgument,
            missingValue: IntegratedAvRunConfigurationError.missingValue
        )

        return IntegratedAvRunConfiguration(
            artifacts: ArtifactPaths(
                audioBaselineReportId: try requiredIntegratedAvRunString("--audio-baseline", values),
                videoTransportReportPath: values["--video-transport-report"],
                outputPath: try requiredIntegratedAvRunString("--output", values)
            ),
            media: MediaOptions(
                videoCaptureEnabled: try requiredIntegratedAvRunSwitch("--video-capture", values),
                videoTransportEnabled: try requiredIntegratedAvRunSwitch("--video-transport", values),
                videoPreviewEnabled: try optionalIntegratedAvRunSwitch(
                    "--video-preview",
                    values,
                    defaultValue: false
                )
            ),
            control: ControlOptions(
                oscControlEnabled: try requiredIntegratedAvRunSwitch("--osc-control", values),
                atemReadOnlyHost: try requiredIntegratedAvRunAtemHost(values)
            ),
            durationSeconds: try requiredIntegratedAvRunPositiveInteger("--duration-seconds", values)
        )
    }
}

/// Defines failures reported when integrated AV run configuration error cannot continue.
public enum IntegratedAvRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidSwitch(argument: String, value: String)
}

/// Runs the integrated audio/video proof and records synchronized media and system-load evidence.
public enum IntegratedAvRunner {
    public static func run(configuration: IntegratedAvRunConfiguration) -> IntegratedAvReport {
        run(configuration: configuration, videoTransportReport: nil)
    }

    public static func run(
        configuration: IntegratedAvRunConfiguration,
        videoTransportReport: VideoTransportReport?
    ) -> IntegratedAvReport {
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        return makeIntegratedAvReport(
            IntegratedAvReportDraft(
                id: "m10-integrated-av-run",
                title: videoTransportReport == nil
                    ? "Integrated headless A/V run"
                    : "Integrated headless A/V aggregate run",
                capturedAt: capturedAt,
                runMode: videoTransportReport == nil ? .synthetic : .measured,
                durationSeconds: Double(configuration.durationSeconds),
                runWindow: IntegratedAvRunWindowEvidence(
                    startedAt: capturedAt,
                    endedAt: capturedAt,
                    audioVideoOverlapSeconds: Double(configuration.durationSeconds)
                ),
                proof: makeIntegratedProofEvidence(
                    configuration: configuration,
                    videoTransportReport: videoTransportReport
                ),
                baselineReportId: configuration.audioBaselineReportId,
                videoTransportReport: videoTransportReport
            )
        )
    }
}

/// Generates deterministic integrated AV evidence for headless validation smoke checks.
public enum IntegratedHeadlessAvSyntheticSmoke {
    public static func run() -> IntegratedAvReport {
        makeIntegratedAvReport(
            IntegratedAvReportDraft(
                id: "m10-integrated-av-synthetic-smoke",
                title: "Synthetic integrated headless A/V report",
                capturedAt: "2026-05-02T00:00:00Z",
                runMode: .synthetic,
                durationSeconds: 60,
                runWindow: nil,
                proof: makeSyntheticIntegratedProofEvidence(),
                baselineReportId: "m05-route-baseline-required",
                videoTransportReport: nil
            )
        )
    }
}
