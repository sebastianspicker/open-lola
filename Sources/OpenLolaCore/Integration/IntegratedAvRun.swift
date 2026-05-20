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

    public init(
        audioBaselineReportId: String,
        videoCaptureEnabled: Bool,
        videoTransportEnabled: Bool,
        videoPreviewEnabled: Bool = false,
        oscControlEnabled: Bool,
        atemReadOnlyHost: String?,
        durationSeconds: Int,
        videoTransportReportPath: String? = nil,
        outputPath: String
    ) {
        self.audioBaselineReportId = audioBaselineReportId
        self.videoCaptureEnabled = videoCaptureEnabled
        self.videoTransportEnabled = videoTransportEnabled
        self.videoPreviewEnabled = videoPreviewEnabled
        self.oscControlEnabled = oscControlEnabled
        self.atemReadOnlyHost = atemReadOnlyHost
        self.durationSeconds = durationSeconds
        self.videoTransportReportPath = videoTransportReportPath
        self.outputPath = outputPath
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
            audioBaselineReportId: try requiredIntegratedAvRunString("--audio-baseline", values),
            videoCaptureEnabled: try requiredIntegratedAvRunSwitch("--video-capture", values),
            videoTransportEnabled: try requiredIntegratedAvRunSwitch("--video-transport", values),
            videoPreviewEnabled: try optionalIntegratedAvRunSwitch(
                "--video-preview",
                values,
                defaultValue: false
            ),
            oscControlEnabled: try requiredIntegratedAvRunSwitch("--osc-control", values),
            atemReadOnlyHost: try requiredIntegratedAvRunAtemHost(values),
            durationSeconds: try requiredIntegratedAvRunPositiveInteger("--duration-seconds", values),
            videoTransportReportPath: values["--video-transport-report"],
            outputPath: try requiredIntegratedAvRunString("--output", values)
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
            proof: IntegratedProofEvidence(
                closureGate: .p04IntegratedAvProof,
                audioOnlyBaselineFirst: true,
                audioOnlyBaselineReportId: configuration.audioBaselineReportId,
                integratedRunReportId: "m10-integrated-av-run",
                audioRoutePacketCapturePoint: nil,
                rmeAudioDeviceVisible: false,
                rmeAudioDeviceUid: "not-detected",
                videoCaptureEnabled: configuration.videoCaptureEnabled,
                videoCaptureReportId: configuration.videoCaptureEnabled ? "m08-video-capture-synthetic-smoke" : nil,
                videoTransportEnabled: configuration.videoTransportEnabled,
                videoTransportReportId: videoTransportReport.map(\.id)
                    ?? (configuration.videoTransportEnabled ? "m09-video-transport-run" : nil),
                videoTransportPacketCapturePoint: videoTransportReport?.routeEvidence?.packetCapturePoint
                    ?? (configuration.videoTransportEnabled ? "integrated-av-run-loopback" : nil),
                videoPreviewEnabled: configuration.videoPreviewEnabled,
                videoPreviewReportId: configuration.videoPreviewEnabled ? "m10-video-preview-local" : nil,
                oscPollingEnabled: configuration.oscControlEnabled,
                oscControlReportId: configuration.oscControlEnabled ? "osc-enabled-no-live-report" : "osc-disabled",
                atemReadOnlyPollingEnabled: configuration.atemReadOnlyHost != nil,
                atemControlReportId: configuration.atemReadOnlyHost.map { "atem-readonly-\($0)" } ?? "atem-readonly-disabled",
                atemArmedCommandsAllowed: false,
                baselineRouteVerdict: .partial,
                integratedRouteVerdict: .partial
            ),
            baselineReportId: configuration.audioBaselineReportId,
            videoTransportReport: videoTransportReport
        )
    }
}

public enum IntegratedHeadlessAvSyntheticSmoke {
    public static func run() -> IntegratedAvReport {
        makeIntegratedAvReport(
            id: "m10-integrated-av-synthetic-smoke",
            title: "Synthetic integrated headless A/V report",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            durationSeconds: 60,
            runWindow: nil,
            proof: IntegratedProofEvidence(
                closureGate: .p04IntegratedAvProof,
                audioOnlyBaselineFirst: true,
                audioOnlyBaselineReportId: "m05-route-baseline-required",
                integratedRunReportId: "m10-integrated-av-synthetic-smoke",
                audioRoutePacketCapturePoint: nil,
                rmeAudioDeviceVisible: false,
                rmeAudioDeviceUid: "not-detected",
                videoCaptureEnabled: true,
                videoCaptureReportId: "m08-video-capture-synthetic-smoke",
                videoTransportEnabled: true,
                videoTransportReportId: "m09-video-transport-run",
                videoTransportPacketCapturePoint: "synthetic-loopback",
                videoPreviewEnabled: false,
                videoPreviewReportId: nil,
                oscPollingEnabled: true,
                oscControlReportId: "osc-enabled-no-live-report",
                atemReadOnlyPollingEnabled: false,
                atemControlReportId: "atem-readonly-disabled",
                atemArmedCommandsAllowed: false,
                baselineRouteVerdict: .partial,
                integratedRouteVerdict: .partial
            ),
            baselineReportId: "m05-route-baseline-required",
            videoTransportReport: nil
        )
    }
}

private func makeIntegratedAvReport(
    id: String,
    title: String,
    capturedAt: String,
    runMode: ReportRunMode,
    durationSeconds: Double,
    runWindow: IntegratedAvRunWindowEvidence?,
    proof: IntegratedProofEvidence?,
    baselineReportId: String,
    videoTransportReport: VideoTransportReport?
) -> IntegratedAvReport {
    IntegratedAvReport(
        id: id,
        title: title,
        capturedAt: capturedAt,
        runMode: runMode,
        durationSeconds: durationSeconds,
        runWindow: runWindow,
        sync: .audioMaster,
        headless: HeadlessOwnershipReport(
            audioLaneOwner: "core-audio-udp-pcm",
            videoLaneOwner: "camera-transport",
            uiOwnsRealtimePaths: false,
            recordingEnabled: false
        ),
        audio: IntegratedAudioMetrics(
            baselineRouteReportId: baselineReportId,
            baselineVerdict: .partial,
            integratedVerdict: .partial,
            baselineCallbackP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            integratedCallbackP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            baselineCallbackMaxMicroseconds: SyntheticPlaceholderMetrics.microseconds,
            integratedCallbackMaxMicroseconds: SyntheticPlaceholderMetrics.microseconds,
            baselinePlayoutTargetFrames: 32,
            integratedPlayoutTargetFrames: 32,
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: SyntheticPlaceholderMetrics.microseconds,
                p95Microseconds: SyntheticPlaceholderMetrics.microseconds,
                p99Microseconds: SyntheticPlaceholderMetrics.microseconds,
                maxMicroseconds: SyntheticPlaceholderMetrics.microseconds
            ),
            lostPackets: 0,
            latePackets: 0,
            underruns: 0,
            hiddenPlayoutGrowthDetected: false
        ),
        video: makeIntegratedVideoMetrics(
            durationSeconds: durationSeconds,
            videoTransportReport: videoTransportReport
        ),
        systemLoad: IntegratedSystemLoadMetrics(
            cpuStressEnabled: false,
            gpuStressEnabled: false,
            networkStressEnabled: false,
            cpuP99Percent: SyntheticPlaceholderMetrics.cpuPercent,
            gpuP99Percent: 0,
            networkMegabitsPerSecond: videoTransportReport?.multiVideo?.aggregateBandwidthMegabitsPerSecond
                ?? 22.1184
        ),
        proof: proof,
        verdict: .partial,
        notes: videoTransportReport == nil
            ? "Synthetic integrated A/V report; no 30-minute hardware stress run."
            : "Measured partial integrated A/V aggregate from a video transport report. Audio baseline, RME hardware, Blackmagic/ATEM source, external control, and 30-minute physical evidence remain required for PASS."
    )
}

private func makeIntegratedVideoMetrics(
    durationSeconds: Double,
    videoTransportReport: VideoTransportReport?
) -> IntegratedVideoMetrics {
    guard let videoTransportReport else {
        return makeSyntheticIntegratedVideoMetrics(durationSeconds: durationSeconds)
    }

    return IntegratedVideoMetrics(
        source: videoTransportReport.source,
        format: videoTransportReport.format,
        captureFrameAge: videoTransportReport.frameAge,
        captureDroppedFrames: videoTransportReport.transmitted.framesDroppedBeforeSend,
        transportMode: videoTransportReport.transport.mode,
        transportFrameAge: videoTransportReport.frameAge,
        receiverDroppedFrames: videoTransportReport.receiver.droppedFrames,
        receiverLateFrames: videoTransportReport.receiver.lateFrames,
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
        captureFrameAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p95Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            maxMicroseconds: SyntheticPlaceholderMetrics.microseconds
        ),
        captureDroppedFrames: 2,
        transportMode: .raw,
        transportFrameAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p95Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            maxMicroseconds: SyntheticPlaceholderMetrics.microseconds
        ),
        receiverDroppedFrames: 2,
        receiverLateFrames: 0,
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
        renderedFrameAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p95Microseconds: SyntheticPlaceholderMetrics.microseconds,
            p99Microseconds: SyntheticPlaceholderMetrics.microseconds,
            maxMicroseconds: SyntheticPlaceholderMetrics.microseconds
        ),
        staleFramesDropped: 2,
        staleFramesRendered: 0,
        audioHoldEvents: 0
    )
}
