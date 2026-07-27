// Shared App shell helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
// Polls UI-owned state on its actor instead of sleeping, keeping asynchronous shell tests deterministic.
func appShellWaitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            Issue.record("Timed out waiting for \(description)")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

func appOperatorState(remoteSelectionComplete: Bool) -> NativeAppShellOperatorPrototypeState {
    let remoteInventory = remoteSelectionComplete
        ? appRemoteInventory()
        : NativeAppShellLocalMediaInventory.editableRemotePlaceholder(peerName: "remote-mac")
    return NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(
            commandIntent: .idle,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false
        ),
        inventories: NativeAppShellOperatorInventories(local: appLocalInventory(), remote: remoteInventory),
        peerFields: NativeAppShellOperatorPeerFields(directPeer: appDirectPeerCommandFields())
    )
}

func appDirectPeerCommandFields() -> NativeAppShellDirectPeerCommandFields {
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "192.0.2.10"
    fields.remoteHost = "192.0.2.20"
    return fields
}

func appLocalInventory() -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
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
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Local ATEM",
                uniqueId: "local-atem",
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: "local-rme",
            audioOutputUID: "local-rme",
            videoDeviceID: "local-atem"
        ),
        inventoryErrors: []
    )
}

func appRemoteInventory() -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
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
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Remote ATEM",
                uniqueId: "remote-atem",
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: "remote-rme",
            audioOutputUID: "remote-rme",
            videoDeviceID: "remote-atem"
        ),
        inventoryErrors: []
    )
}

@MainActor
// Seeds the minimum coherent evidence set so callers can test presentation policy rather than evidence collection.
func seedValidatedRuntimeEvidence(_ controller: AppExecutionController) {
    controller.lastValidationExitCode = 0
    controller.lastValidationResult = .passed
    controller.lastValidationFinishedAt = "2026-05-20T00:00:00Z"
    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "validated-peer-report", peerID: "peer-a")
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
        )
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok")
    ]
    try DirectPeerTwoPeerLocalRunReport(
        .init(
            metadata: .init(
                id: "supervisor",
                capturedAt: "2026-05-20T00:00:00Z",
                planID: "plan",
                runDirectory: directory.path
            ),
            processExecution: .init(executed: true, processResults: processResults),
            aggregation: .init(
                command: ["open-lola", "direct-p2p-two-peer-local-run"],
                reportPath: directory.appendingPathComponent("aggregate.json").path,
                executed: true
            ),
            evidence: .init(
                preflightChecks: preflightChecks,
                gates: ["unit"],
                verdict: .pass,
                notes: "unit test measured supervisor report"
            )
        )
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
            traffic: .init(
                controlMessagesSent: 1,
                packetsSent: packetsReceived + packetsLost,
                packetsReceived: packetsReceived,
                packetsLost: packetsLost,
                jitterMicroseconds: jitterMicroseconds,
                audioPacketsRouted: packetsReceived,
                videoPacketsRouted: 0,
                recoveryEvents: 0
            ),
            control: .init(audioPayloadsSentOnControlChannel: 0),
            remote: .init(),
            remoteResources: .init()
        ),
        avRuntime: appPartialAVRuntime(latencyMicroseconds: latencyMicroseconds),
        verdict: .partial,
        notes: "unit test partial report"
    )
}

func appMeasuredPassDirectPeerSessionReport(id: String, peerID _: String) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: appMeasuredPassMetrics(),
        avRuntime: appMeasuredPassAVRuntime(),
        measuredEvidence: appMeasuredPassEvidence(),
        verdict: .pass,
        notes: "unit test measured report"
    )
}

func appMeasuredPassMetrics() -> DirectPeerSessionReportMetrics {
    DirectPeerSessionReportMetrics(
        traffic: .init(
            controlMessagesSent: 1,
            packetsSent: 90,
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            audioPacketsRouted: 90,
            videoPacketsRouted: 1,
            recoveryEvents: 0
        ),
        control: .init(audioPayloadsSentOnControlChannel: 0),
        remote: .init(),
        remoteResources: .init()
    )
}

func appMeasuredPassAVRuntime() -> DirectPeerSessionAVRuntimeMetadata {
    DirectPeerSessionAVRuntimeMetadata(
        session: .init(
            avProfile: .balanced,
            previewMode: .on,
            mediaSourceMode: .production,
            qualityPolicy: .requireUsefulMedia,
            usefulMediaProof: .requiredAndProven
        ),
 audio: directPeerSessionAudioFixture(
    deviceUID: "local-rme",
    inputDeviceUID: "local-rme",
    outputDeviceUID: "local-rme",
    latencyProfile: .balancedAV,
    rxBufferProfile: .small
 ),
 transport: directPeerSessionRawTransportFixture(),
 video: directPeerSessionRawVideoFixture(deviceID: "local-atem"),
        evidence: .init(
            fastestPassBlockedReason: "balanced profile selected for measured app-shell pass candidate",
            runtimeMetrics: directPeerMeasuredAVRuntimeMetrics(
                mediaUnitCount: 1,
                fragmentCount: 2,
                includePreview: true
            ),
            videoFormat: measuredPassVideoFormat(),
            receiveProof: measuredPassReceiveProof()
        )
    )
}

func appMeasuredPassEvidence() -> DirectPeerSessionMeasuredEvidence {
    directPeerSessionMeasuredEvidence(
        sourcePeerLabel: "mac-a-m4-lab",
        receiverPeerLabel: "mac-b-m4-lab",
        routeLabel: "direct-en6-cable-run",
        rawVideoReceiveEvidence: "m06-direct-p2p-av-mac-b videoFramesReassembled greater than zero"
    )
}

func appProcessResult(
    peerID: String,
    reportPath: String,
    receiveProofPath: String? = nil
) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        identity: .init(
            peerID: peerID,
            role: peerID == "peer-a" ? .initiator : .responder,
            reportPath: reportPath
        ),
        execution: .init(command: ["open-lola", "direct-p2p-session-run"], exitCode: 0),
        collection: .init(reportPath: reportPath, receiveProofPath: receiveProofPath)
    )
}

func appExternalConnectorSessionReport(
 verdict: MeasurementVerdict,
 outputPath: String
) throws -> ExternalConnectorSessionReport {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.20",
  outputPath: outputPath
) { input in
  input.localHost = "192.0.2.10"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.controlTransport = .udp
  input.durationSeconds = 1
  input.controlPort = 7_000
  input.audioPort = 19_788
  input.videoPort = 19_798
  input.channels = 2
  input.sampleRateHertz = 44_100
  input.framesPerPacket = 64
  input.videoWidth = 640
  input.videoHeight = 480
  input.videoFrameRate = 25
  input.videoBitsPerPixel = 8
  input.mediaPacketCount = 1
})
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-\(verdict.rawValue)",
    capturedAt: "2026-05-15T00:00:00Z",
    connector: configuration.connector,
    role: configuration.role,
    dryRun: false,
    plan: try ExternalConnectorLaunchPlan.build(configuration: configuration),
    verdict: verdict,
    notes: "unit test Windows LoLa connector report"
  )
  input.process = nil
  input.auxiliaryProcesses = []
  input.lolaControl = nil
  input.lolaMedia = nil
  input.runtimeError = verdict == .fail ? "unit test runtime failure" : nil
  return ExternalConnectorSessionReport(input)
}

func appSessionConfiguration() -> SessionConfiguration {
    let peers = [
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
        )
    ]
    let identity = SessionConfiguration.Identity(sessionID: "app-test-session", peers: peers)
    let profile = SessionMediaProfile(latencyProfile: .directAudioFirst, rxBufferProfile: .direct)
    let streams = SessionStreamSet(audioStreams: [], videoStreams: [])
    let endpoints = appSessionMediaEndpoints()
    let transport = SessionConfigurationTransport(
        peerMediaEndpoints: [
            appPeerEndpoints(peerID: "peer-a", basePort: 19_001, host: "192.0.2.10"),
            appPeerEndpoints(peerID: "peer-b", basePort: 19_011, host: "192.0.2.20")
        ],
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 1_000
    )
    return SessionConfiguration(
        identity: identity,
        profile: profile,
        streams: streams,
        endpoints: endpoints,
        transport: transport
    )
}

private func appSessionMediaEndpoints() -> SessionMediaEndpoints {
    SessionMediaEndpoints(
        control: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_001),
        audio: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_002),
        video: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_003),
        metrics: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_004)
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
