import Foundation
import OpenLolaContracts

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
            "--output",
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

public enum IntegratedAvRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidSwitch(argument: String, value: String)
}

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

private func makeIntegratedProofEvidence(
    configuration: IntegratedAvRunConfiguration,
    videoTransportReport: VideoTransportReport?
) -> IntegratedProofEvidence {
    IntegratedProofEvidence(
        identity: IntegratedProofEvidence.Identity(
            closureGate: .p04IntegratedAvProof,
            audioOnlyBaselineFirst: true,
            audioOnlyBaselineReportId: configuration.audioBaselineReportId,
            integratedRunReportId: "m10-integrated-av-run"
        ),
        audioRoute: IntegratedProofEvidence.AudioRoute(
            packetCapturePoint: nil,
            rmeAudioDeviceVisible: false,
            rmeAudioDeviceUid: "not-detected",
            baselineRouteVerdict: .partial,
            integratedRouteVerdict: .partial
        ),
        video: makeIntegratedProofVideoEvidence(
            configuration: configuration,
            videoTransportReport: videoTransportReport
        ),
        control: IntegratedProofEvidence.ControlEvidence(
            oscPollingEnabled: configuration.oscControlEnabled,
            oscControlReportId: configuration.oscControlEnabled ? "osc-enabled-no-live-report" : "osc-disabled",
            atemReadOnlyPollingEnabled: configuration.atemReadOnlyHost != nil,
            atemControlReportId: configuration.atemReadOnlyHost.map { "atem-readonly-\($0)" }
                ?? "atem-readonly-disabled",
            atemArmedCommandsAllowed: false
        )
    )
}

private func makeIntegratedProofVideoEvidence(
    configuration: IntegratedAvRunConfiguration,
    videoTransportReport: VideoTransportReport?
) -> IntegratedProofEvidence.VideoEvidence {
    IntegratedProofEvidence.VideoEvidence(
        captureEnabled: configuration.videoCaptureEnabled,
        captureReportId: configuration.videoCaptureEnabled ? "m08-video-capture-synthetic-smoke" : nil,
        transportEnabled: configuration.videoTransportEnabled,
        transportReportId: videoTransportReport.map(\.id)
            ?? (configuration.videoTransportEnabled ? "m09-video-transport-run" : nil),
        transportPacketCapturePoint: videoTransportReport?.routeEvidence?.packetCapturePoint
            ?? (configuration.videoTransportEnabled ? "integrated-av-run-loopback" : nil),
        previewEnabled: configuration.videoPreviewEnabled,
        previewReportId: configuration.videoPreviewEnabled ? "m10-video-preview-local" : nil
    )
}

private func makeSyntheticIntegratedProofEvidence() -> IntegratedProofEvidence {
    IntegratedProofEvidence(
        identity: IntegratedProofEvidence.Identity(
            closureGate: .p04IntegratedAvProof,
            audioOnlyBaselineFirst: true,
            audioOnlyBaselineReportId: "m05-route-baseline-required",
            integratedRunReportId: "m10-integrated-av-synthetic-smoke"
        ),
        audioRoute: IntegratedProofEvidence.AudioRoute(
            packetCapturePoint: nil,
            rmeAudioDeviceVisible: false,
            rmeAudioDeviceUid: "not-detected",
            baselineRouteVerdict: .partial,
            integratedRouteVerdict: .partial
        ),
        video: IntegratedProofEvidence.VideoEvidence(
            captureEnabled: true,
            captureReportId: "m08-video-capture-synthetic-smoke",
            transportEnabled: true,
            transportReportId: "m09-video-transport-run",
            transportPacketCapturePoint: "synthetic-loopback",
            previewEnabled: false,
            previewReportId: nil
        ),
        control: IntegratedProofEvidence.ControlEvidence(
            oscPollingEnabled: true,
            oscControlReportId: "osc-enabled-no-live-report",
            atemReadOnlyPollingEnabled: false,
            atemControlReportId: "atem-readonly-disabled",
            atemArmedCommandsAllowed: false
        )
    )
}

private struct IntegratedAvReportDraft {
    var id: String
    var title: String
    var capturedAt: String
    var runMode: ReportRunMode
    var durationSeconds: Double
    var runWindow: IntegratedAvRunWindowEvidence?
    var proof: IntegratedProofEvidence?
    var baselineReportId: String
    var videoTransportReport: VideoTransportReport?
}

private func makeIntegratedAvReport(_ draft: IntegratedAvReportDraft) -> IntegratedAvReport {
    IntegratedAvReport(
        metadata: IntegratedAvReport.Metadata(
            id: draft.id,
            title: draft.title,
            capturedAt: draft.capturedAt,
            runMode: draft.runMode,
            durationSeconds: draft.durationSeconds,
            runWindow: draft.runWindow
        ),
        sync: .audioMaster,
        evidence: IntegratedAvReport.Evidence(
            headless: HeadlessOwnershipReport(
                audioLaneOwner: "core-audio-udp-pcm",
                videoLaneOwner: "camera-transport",
                uiOwnsRealtimePaths: false,
                recordingEnabled: false
            ),
            audio: makeIntegratedAudioMetrics(baselineReportId: draft.baselineReportId),
            video: makeIntegratedVideoMetrics(
                durationSeconds: draft.durationSeconds,
                videoTransportReport: draft.videoTransportReport
            ),
            systemLoad: makeIntegratedSystemLoadMetrics(videoTransportReport: draft.videoTransportReport),
            proof: draft.proof
        ),
        verdict: .partial,
        notes: makeIntegratedAvNotes(videoTransportReport: draft.videoTransportReport)
    )
}

private func makeIntegratedAudioMetrics(baselineReportId: String) -> IntegratedAudioMetrics {
    IntegratedAudioMetrics(
        verdicts: IntegratedAudioMetrics.Verdicts(
            baselineRouteReportId: baselineReportId,
            baselineVerdict: .partial,
            integratedVerdict: .partial
        ),
        callbackTiming: IntegratedAudioMetrics.CallbackTiming(
            baselineP99Microseconds: SourceValidationMetrics.callback.p99Microseconds,
            integratedP99Microseconds: SourceValidationMetrics.callback.p99Microseconds,
            baselineMaxMicroseconds: SourceValidationMetrics.callback.maxMicroseconds,
            integratedMaxMicroseconds: SourceValidationMetrics.callback.maxMicroseconds
        ),
        playoutTargets: IntegratedAudioMetrics.PlayoutTargets(
            baselineFrames: 32,
            integratedFrames: 32
        ),
        packetHealth: IntegratedAudioMetrics.PacketHealth(
            packetAge: SourceValidationMetrics.audioPacketAge,
            lostPackets: 0,
            latePackets: 0,
            underruns: 0,
            hiddenPlayoutGrowthDetected: false
        )
    )
}

private func makeIntegratedSystemLoadMetrics(
    videoTransportReport: VideoTransportReport?
) -> IntegratedSystemLoadMetrics {
    IntegratedSystemLoadMetrics(
        cpuStressEnabled: false,
        gpuStressEnabled: false,
        networkStressEnabled: false,
        cpuP99Percent: SourceValidationMetrics.cpuP99Percent,
        gpuP99Percent: 0,
        networkMegabitsPerSecond: videoTransportReport?.multiVideo?.aggregateBandwidthMegabitsPerSecond
            ?? 22.1184
    )
}

private func makeIntegratedAvNotes(videoTransportReport: VideoTransportReport?) -> String {
    if videoTransportReport == nil {
        return "Synthetic integrated A/V report; no 30-minute hardware stress run."
    }
    return "Measured partial integrated A/V aggregate from a video transport report. Audio baseline, RME hardware, Blackmagic/ATEM source, external control, and 30-minute physical evidence remain required for PASS."
}

private func makeIntegratedVideoMetrics(
    durationSeconds: Double,
    videoTransportReport: VideoTransportReport?
) -> IntegratedVideoMetrics {
    guard let videoTransportReport else {
        return makeSyntheticIntegratedVideoMetrics(durationSeconds: durationSeconds)
    }

    return IntegratedVideoMetrics(
        capture: IntegratedVideoMetrics.Capture(
            source: videoTransportReport.source,
            format: videoTransportReport.format,
            frameAge: videoTransportReport.frameAge,
            droppedFrames: videoTransportReport.transmitted.framesDroppedBeforeSend
        ),
        transport: IntegratedVideoMetrics.Transport(
            mode: videoTransportReport.transport.mode,
            frameAge: videoTransportReport.frameAge,
            receiverDroppedFrames: videoTransportReport.receiver.droppedFrames,
            receiverLateFrames: videoTransportReport.receiver.lateFrames
        ),
        frameTiming: makeIntegratedVideoFrameTiming(
            durationSeconds: videoTransportReport.durationSeconds,
            frameCount: videoTransportReport.transmitted.framesSent
        ),
        renderSync: IntegratedVideoRenderSync(
            selectionPolicy: .nearestUseful,
            staleFrameLimitMicroseconds: 100_000,
            renderedFrameAge: videoTransportReport.frameAge,
            staleFramesDropped: videoTransportReport.receiver.droppedFrames,
            staleFramesRendered: 0,
            audioHoldEvents: videoTransportReport.avSync?.audioDelayFramesAddedForVideo ?? 0
        ),
        degradation: videoTransportReport.degradation
    )
}

private func makeSyntheticIntegratedVideoMetrics(durationSeconds: Double) -> IntegratedVideoMetrics {
    IntegratedVideoMetrics(
        capture: IntegratedVideoMetrics.Capture(
            source: VideoSourceDescription(
                kind: .testPattern,
                label: "synthetic-test-pattern",
                deviceUniqueId: nil,
                permissionStatus: "notRequired"
            ),
            format: VideoCaptureFormat(
                width: 1_280,
                height: 720,
                nominalFrameRate: 30,
                pixelFormat: "synthetic-rgb"
            ),
            frameAge: SourceValidationMetrics.videoFrameAge,
            droppedFrames: 2
        ),
        transport: IntegratedVideoMetrics.Transport(
            mode: .raw,
            frameAge: SourceValidationMetrics.videoFrameAge,
            receiverDroppedFrames: 2,
            receiverLateFrames: 0
        ),
        frameTiming: makeIntegratedVideoFrameTiming(durationSeconds: durationSeconds),
        renderSync: makeIntegratedVideoRenderSync(),
        degradation: VideoDegradationPolicy(
            actions: [.dropFrame, .disableVideo],
            triggeredBeforeAudioTargetChange: true,
            triggeredBeforeAudioOrRouteImpact: true
        )
    )
}

private func makeIntegratedVideoFrameTiming(
    durationSeconds: Double,
    frameCount: Int? = nil
) -> IntegratedVideoFrameTiming {
    let frameCount = frameCount ?? max(1, Int((durationSeconds * 30).rounded()))
    return IntegratedVideoFrameTiming(
        timestampClock: .continuousMonotonic,
        frameIdentity: .monotonicFrameCounter,
        firstFrameId: 1,
        lastFrameId: frameCount,
        firstFrameMonotonicNanoseconds: 0,
        lastFrameMonotonicNanoseconds: max(0, Int(durationSeconds * 1_000_000_000)),
        nonMonotonicTimestampCount: 0,
        duplicateFrameIdentityCount: 0
    )
}

private func makeIntegratedVideoRenderSync() -> IntegratedVideoRenderSync {
    IntegratedVideoRenderSync(
        selectionPolicy: .nearestUseful,
        staleFrameLimitMicroseconds: 100_000,
        renderedFrameAge: SourceValidationMetrics.videoFrameAge,
        staleFramesDropped: 2,
        staleFramesRendered: 0,
        audioHoldEvents: 0
    )
}
