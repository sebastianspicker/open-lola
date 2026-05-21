import Foundation

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

func appOperatorState(remoteSelectionComplete: Bool) -> NativeAppShellOperatorPrototypeState {
    var remoteInventory = NativeAppShellLocalMediaInventory.editableRemotePlaceholder(peerName: "remote-mac")
    if remoteSelectionComplete {
        remoteInventory = NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "remote-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME",
                    uid: "remote-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Remote ATEM",
                    uniqueId: "remote-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "remote-rme",
                audioOutputUID: "remote-rme",
                videoDeviceID: "remote-atem"
            ),
            inventoryErrors: []
        )
    }
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "192.0.2.10"
    fields.remoteHost = "192.0.2.20"
    return NativeAppShellOperatorPrototypeState(
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "local-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Local RME",
                    uid: "local-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Local ATEM",
                    uniqueId: "local-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "local-rme",
                audioOutputUID: "local-rme",
                videoDeviceID: "local-atem"
            ),
            inventoryErrors: []
        ),
        remoteInventory: remoteInventory,
        commandIntent: .idle,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: fields
    )
}

@MainActor
func seedValidatedRuntimeEvidence(_ controller: AppExecutionController) {
    controller.lastValidationExitCode = 0
    controller.lastValidationResult = .passed
    controller.lastValidationFinishedAt = "2026-05-20T00:00:00Z"
    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "validated-peer-report", peerID: "peer-a"),
    ])
    controller.status = "Validation passed."
    controller.phase = .validationPassed
}

func writeAppMeasuredPassSupervisorReport(directory: URL, supervisorURL: URL) throws {
    let reportAURL = directory.appendingPathComponent("peer-a-pass.json")
    let reportBURL = directory.appendingPathComponent("peer-b-pass.json")
    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass-report", peerID: "peer-a")
        .prettyJSONData()
        .write(to: reportAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass-report", peerID: "peer-b")
        .prettyJSONData()
        .write(to: reportBURL)
    let processResults = [
        appProcessResult(
            peerID: "peer-a",
            reportPath: reportAURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
        ),
        appProcessResult(
            peerID: "peer-b",
            reportPath: reportBURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
        ),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-20T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test measured supervisor report"
    ).prettyJSONData().write(to: supervisorURL)
}

func appDirectPeerSessionReport(
    id: String,
    packetsReceived: Int,
    packetsLost: Int,
    jitterMicroseconds: Double,
    latencyMicroseconds: Double
) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: packetsReceived + packetsLost,
            packetsReceived: packetsReceived,
            packetsLost: packetsLost,
            jitterMicroseconds: jitterMicroseconds,
            audioPacketsRouted: packetsReceived,
            videoPacketsRouted: 0,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .syntheticFixture,
            audioDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "unit test partial",
            fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison(
                audioOnlyBaselineReportID: "audio-only",
                audioOnlyBaselineReportPath: "reports/audio-only.json",
                comparisonArtifactPath: "reports/comparison.json",
                audioOnlyLatencyP99Microseconds: latencyMicroseconds,
                fastestAVAudioLatencyP99Microseconds: latencyMicroseconds,
                audioLatencyEqualToBaseline: true,
                rxBufferEqualToBaseline: true,
                lossJitterEqualToBaseline: true
            )
        ),
        verdict: .partial,
        notes: "unit test partial report"
    )
}

func appMeasuredPassDirectPeerSessionReport(id: String, peerID _: String) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: 90,
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            audioPacketsRouted: 90,
            videoPacketsRouted: 1,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .balanced,
            previewMode: .on,
            mediaSourceMode: .production,
            qualityPolicy: .requireUsefulMedia, usefulMediaProof: .requiredAndProven,
            audioDeviceUID: "local-rme",
            inputDeviceUID: "local-rme",
            outputDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .balancedAV,
            rxBufferProfile: .small,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "balanced profile selected for measured app-shell pass candidate",
            runtimeMetrics: DirectPeerSessionAVRuntimeMetrics(
                audioPayloadsCaptured: 1,
                audioPayloadsSent: 1,
                audioPayloadsQueuedForPlayout: 1,
                videoFramesCaptured: 1,
                videoFramesSent: 1,
                videoFragmentsSent: 2,
                videoFragmentsReceived: 2,
                videoFramesReassembled: 1,
                previewFramesSubmitted: 1,
                audioReceiveDrainIterations: 1,
                videoReceiveDrainIterations: 1
            ),
            videoFormat: measuredPassVideoFormat(),
            receiveProof: measuredPassReceiveProof()
        ),
        measuredEvidence: DirectPeerSessionMeasuredEvidence(
            kind: .physicalTwoPeerMacs,
            sourcePeerLabel: "mac-a-m4-lab",
            receiverPeerLabel: "mac-b-m4-lab",
            routeLabel: "direct-en6-cable-run",
            packetCapturePath: "reports/captures/direct-p2p-av-mac-b.pcapng",
            packetCapture: directPeerSessionPacketCaptureArtifact(),
            dscpObservation: "EF preserved at receiver ingress",
            dscp: directPeerSessionDSCPEvidence(),
            clockSyncSummary: "PTP offset below one millisecond",
            clock: directPeerSessionClockEvidence(),
            rawVideoReceiveEvidence: "m06-direct-p2p-av-mac-b videoFramesReassembled greater than zero",
            durationSeconds: 30
        ),
        verdict: .pass,
        notes: "unit test measured report"
    )
}

func appProcessResult(
    peerID: String,
    reportPath: String,
    receiveProofPath: String? = nil
) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        peerID: peerID,
        role: peerID == "peer-a" ? .initiator : .responder,
        reportPath: reportPath,
        command: ["open-lola", "direct-p2p-session-run"],
        exitCode: 0,
        collectedReportPath: reportPath,
        collectedReceiveProofPath: receiveProofPath
    )
}

func appExternalConnectorSessionReport(
    verdict: MeasurementVerdict,
    outputPath: String
) throws -> ExternalConnectorSessionReport {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: outputPath,
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .udp,
        durationSeconds: 1,
        controlPort: 7_000,
        audioPort: 19_788,
        videoPort: 19_798,
        channels: 2,
        sampleRateHertz: 44_100,
        framesPerPacket: 64,
        videoWidth: 640,
        videoHeight: 480,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    return ExternalConnectorSessionReport(
        id: "external-connector-\(verdict.rawValue)",
        capturedAt: "2026-05-15T00:00:00Z",
        connector: configuration.connector,
        role: configuration.role,
        dryRun: false,
        plan: try ExternalConnectorLaunchPlan.build(configuration: configuration),
        process: nil,
        auxiliaryProcesses: [],
        lolaControl: nil,
        lolaMedia: nil,
        runtimeError: verdict == .fail ? "unit test runtime failure" : nil,
        verdict: verdict,
        notes: "unit test Windows LoLa connector report"
    )
}

func appSessionConfiguration() -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "app-test-session",
        peers: [
            PeerIdentity(
                peerID: "peer-a",
                displayName: "Peer A",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
            PeerIdentity(
                peerID: "peer-b",
                displayName: "Peer B",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
        ],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: [],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_001),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_002),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_003),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_004),
        peerMediaEndpoints: [
            appPeerEndpoints(peerID: "peer-a", basePort: 19_001, host: "192.0.2.10"),
            appPeerEndpoints(peerID: "peer-b", basePort: 19_011, host: "192.0.2.20"),
        ],
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 1_000
    )
}

func appPeerEndpoints(peerID: String, basePort: UInt16, host: String) -> SessionPeerMediaEndpoints {
    SessionPeerMediaEndpoints(
        peerID: peerID,
        controlEndpoint: SessionNetworkEndpoint(host: host, port: basePort),
        audioEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 1),
        videoEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 2),
        metricsEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 3)
    )
}
