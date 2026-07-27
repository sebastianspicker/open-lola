// Shared shared measured fixture builders helpers keep related tests deterministic and focused on their contract.
import Foundation
@testable import OpenLolaCore

func measuredFixturePacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

struct MeasuredFixtureAcceptedMode {
    var sampleRate: Int
    var frames: Int
    var stable: Bool
    var oneWayMilliseconds: Double
    var p99: Double
    var max: Double
    var missed = 0
    var underruns = 0
    var unstableNotes = "accepted but unstable measured row"
}

func standardDirectPeerAudioGraphConfiguration(
    inputDeviceUID: String,
    outputDeviceUID: String
) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        devices: .init(
            audioDeviceUID: inputDeviceUID,
            inputDeviceUID: inputDeviceUID,
            outputDeviceUID: outputDeviceUID
        ),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            sampleFormat: .float32LittleEndian
        ),
        channelMaps: .init(input: [0, 1], output: [0, 1]),
        buffering: .init(ringCapacityBlocks: 8, rxBufferPolicy: nil)
    )
}

struct DirectPeerSyntheticAVFixture {
    var manual: DirectPeerSessionManualRunConfiguration
    var durationSeconds = 1
    var audioDeviceUID = "synthetic-a"
    var inputDeviceUID = "synthetic-a"
    var outputDeviceUID = "synthetic-a"
    var videoWidth = 16
    var videoHeight = 16
    var videoDeviceID = "synthetic-test-device"
    var avProfile: DirectPeerSessionAVProfile = .balanced
    var rxBufferProfile: RxBufferProfile? = .adaptive
    var preview: DirectPeerSessionPreviewMode = .off
    var mediaSourceMode: DirectPeerSessionAVMediaSourceMode = .syntheticFixture

    func configuration() -> DirectPeerSessionAVRunConfiguration {
        DirectPeerSessionAVRunConfiguration(
            manual: manual,
            durationSeconds: durationSeconds,
            devices: .init(
                audioDeviceUID: audioDeviceUID,
                inputDeviceUID: inputDeviceUID,
                outputDeviceUID: outputDeviceUID
            ),
            audio: .init(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                sampleFormat: .float32LittleEndian,
                inputChannels: [0, 1],
                outputChannels: [0, 1],
                transport: nil,
                compression: .raw
            ),
            video: .init(
                deviceID: videoDeviceID,
                width: videoWidth,
                height: videoHeight,
                pixelFormat: "bgra8",
                compression: .raw,
                frameRate: 30,
                streamID: 100
            ),
            quality: .init(
                profile: avProfile,
                rxBufferProfile: rxBufferProfile,
                preview: preview,
                mediaSourceMode: mediaSourceMode,
                policy: .requireUsefulMedia
            ),
            aoip: .init(sdpOutputPath: nil, sdpInputPath: nil)
        )
    }
}

struct DirectPeerManualTestFixture {
    var role: DirectPeerSessionManualRole = .initiator
    var localPeerID = "peer-a"
    var remotePeerID = "peer-b"
    var localHost = "127.0.0.1"
    var remoteHost = "127.0.0.1"
    var ports: [UInt16] = [57_000, 57_010, 57_001, 57_002, 57_003]
    var packetCount = 1
    var timeoutSeconds = 1

    func configuration() -> DirectPeerSessionManualRunConfiguration {
        DirectPeerSessionManualRunConfiguration(
            identity: .init(role: role, localPeerID: localPeerID, remotePeerID: remotePeerID),
            network: .init(
                localHost: localHost,
                remoteHost: remoteHost,
                ports: .init(
                    controlPort: ports[0],
                    remoteControlPort: ports[1],
                    audioPort: ports[2],
                    videoPort: ports[3],
                    metricsPort: ports[4]
                )
            ),
            tuning: .init(packetCount: packetCount, audioChannelCount: 2, timeoutSeconds: timeoutSeconds, dscp: nil)
        )
    }
}

func pairedDirectPeerManualConfigurations(
    ports: [UInt16],
    packetCount: Int
) -> (DirectPeerSessionManualRunConfiguration, DirectPeerSessionManualRunConfiguration) {
    var initiator = DirectPeerManualTestFixture()
    initiator.ports = [ports[0], ports[4], ports[1], ports[2], ports[3]]
    initiator.packetCount = packetCount
    initiator.timeoutSeconds = 10

    var responder = DirectPeerManualTestFixture()
    responder.role = .responder
    responder.localPeerID = "peer-b"
    responder.remotePeerID = "peer-a"
    responder.ports = [ports[4], ports[0], ports[5], ports[6], ports[7]]
    responder.packetCount = packetCount
    responder.timeoutSeconds = 10
    return (initiator.configuration(), responder.configuration())
}

func standardRealtimeAudioEngineConfiguration(
    playoutTargetFrames: Int = 32,
    preallocatedBlockCount: Int = 4,
    rxBufferPolicy: RxBufferPolicy? = nil,
    inputDeviceUID: String = "rme-madi-uid",
    outputDeviceUID: String = "rme-madi-uid"
) -> RealtimeAudioEngineConfiguration {
    let stereoChannelMap = [0, 1]
    return RealtimeAudioEngineConfiguration(
        devices: .init(inputDeviceUID: inputDeviceUID, outputDeviceUID: outputDeviceUID),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            packetFormat: .int16LittleEndian
        ),
        channelMaps: .init(input: stereoChannelMap, output: stereoChannelMap),
        buffering: .init(
            playoutTargetFrames: playoutTargetFrames,
            preallocatedBlockCount: preallocatedBlockCount,
            rxBufferPolicy: rxBufferPolicy
        )
    )
}

func standardRealtimeAudioHandoffMetrics(
    rxBufferPolicy: RxBufferPolicy
) -> RealtimeAudioHandoffMetrics {
    RealtimeAudioHandoffMetrics(
        counters: standardRealtimeHandoffCounters(),
        buffering: standardRealtimeHandoffBuffering(),
        observability: standardRealtimeHandoffObservability(),
        completion: standardRealtimeHandoffCompletion(rxBufferPolicy: rxBufferPolicy)
    )
}

private func standardRealtimeHandoffCounters() -> RealtimeAudioHandoffMetrics.Counters {
    .init(inputBlocks: 1_000, outputBlocks: 1_000, networkSendBlocks: 1_000, networkReceiveBlocks: 1_000, droppedInputBlocks: 0, droppedNetworkBlocks: 0, outputUnderrunBlocks: 0, callbackOverrunBlocks: 0)
}

private func standardRealtimeHandoffBuffering() -> RealtimeAudioHandoffMetrics.Buffering {
    .init(latePackets: 0, maximumBufferedBlocks: 2, ringCapacityBlocks: 4, fullCaptureRingBlocks: 0, invalidInputBlocks: 0, directInputBlocks: 1_000, remappedInputBlocks: 0, packetFragmentCount: 1_000)
}

private func standardRealtimeHandoffObservability() -> RealtimeAudioHandoffMetrics.Observability {
    .init(allocationWarnings: 0, maximumCaptureRingOccupancyBlocks: 2, maximumPlayoutQueueDepthBlocks: 2, packetizationDuration: .empty, depacketizationDuration: .empty)
}

private func standardRealtimeHandoffCompletion(rxBufferPolicy: RxBufferPolicy) -> RealtimeAudioHandoffMetrics.Completion {
    .init(hiddenPlayoutGrowthDetected: false, shutdownCompleted: true, rxBuffer: RxBufferRuntimeSnapshot(policy: rxBufferPolicy))
}

private func standardRealtimeCallbackMetrics() -> EndpointCallbackMetrics {
    EndpointCallbackMetrics(
        latency: .init(p50Microseconds: 50, p95Microseconds: 90, p99Microseconds: 120, maxMicroseconds: 200),
        events: .init(missedDeadlines: 0, underruns: 0, overruns: 0)
    )
}

func standardRealtimeAudioRuntimeEvidence(
    rxBufferPolicy: RxBufferPolicy
) -> RealtimeAudioRuntimeEvidence {
    RealtimeAudioRuntimeEvidence(
        callbackOwner: .audioDeviceIOProc,
        callback: standardRealtimeCallbackMetrics(),
        handoff: standardRealtimeAudioHandoffMetrics(rxBufferPolicy: rxBufferPolicy),
        udpSocketsPreparedBeforeStart: true,
        reportWrittenAfterStop: true,
        measuredDurationSeconds: 3_600
    )
}

func measuredFixtureEndpointStabilityRun(
    selectedMode: AudioMode,
    notes: String
) -> EndpointStabilityRun {
    EndpointStabilityRun(
        mode: selectedMode,
        durationSeconds: 1_800,
        callback: EndpointCallbackMetrics(
            latency: .init(p50Microseconds: 100, p95Microseconds: 185, p99Microseconds: 250, maxMicroseconds: 390),
            events: .init(missedDeadlines: 0, underruns: 0, overruns: 0)
        ),
        dropoutEvents: 0,
        hiddenBufferGrowthDetected: false,
        notes: notes
    )
}

func testSwiftSourceFiles(under root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var sourceFiles: [URL] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            sourceFiles.append(url)
        }
    }
    return sourceFiles
}

func standardMeasuredRouteMetrics() -> UdpPcmRouteMetrics {
    UdpPcmRouteMetrics(delivery: .init(packetsSent: 3_000, packetsReceived: 3_000, lostPackets: 0, latePackets: 0, reorderedPackets: 0, duplicatePackets: 0), timing: .init(packetAge: UdpPcmPacketAgeMetrics(p50Microseconds: 100, p95Microseconds: 180, p99Microseconds: 240, maxMicroseconds: 300), callbackP99Microseconds: 120, callbackMaxMicroseconds: 180, jitterP99Microseconds: 40, playoutTargetMicroseconds: 666), hiddenPlayoutGrowthDetected: false)
}

func latencyBenchmarkPhysicalValidationCandidate(
    id: String,
    title: String,
    category: LatencyBenchmarkCategory,
    rxBufferImpact: RxBufferBenchmarkImpact? = nil
) throws -> LatencyBenchmarkReport {
    var report = try LatencyBenchmarkSyntheticSmoke.run()
    report.id = id
    report.title = title
    report.category = category
    report.runMode = .measured
    report.evidenceKind = .physicalReferenceRig
    report.hardware = HardwareIdentity(
        referenceMac: "reference-mac-a",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.4",
        driverVersion: "RME 4.17"
    )
    report.route = RouteIdentity(label: "direct-wired-p2p", topology: "two-mac-direct-ethernet")
    report.timing = LatencyBenchmarkTimingMetrics(
        oneWayEstimateMicroseconds: 4_900,
        roundTripMicroseconds: 9_800,
        jitter: LatencyJitterMetrics(
            p50Microseconds: 60,
            p95Microseconds: 120,
            p99Microseconds: 180,
            maxMicroseconds: 240
        )
    )
    report.loss = LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 0, lossPercent: 0)
    report.faults = LatencyBenchmarkFaultMetrics(
        underruns: 0,
        overruns: 0,
        missedDeadlines: 0,
        droppedFrames: 0
    )
    report.resources.allocationWarnings = []
    report.resources.threadWarnings = []
    report.rxBufferImpact = rxBufferImpact
    report.notes = "Physical reference-rig candidate used only for validator behavior."
    report.verdict = .pass
    try report.validate()
    return report
}

func measuredFixtureAcceptedMode(_ fixture: MeasuredFixtureAcceptedMode) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: fixture.sampleRate,
            framesPerBuffer: fixture.frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: true,
        stable: fixture.stable,
        rejectionReason: nil,
        callback: EndpointCallbackMetrics(latency: .init(p50Microseconds: 100, p95Microseconds: 180, p99Microseconds: fixture.p99, maxMicroseconds: fixture.max), events: .init(missedDeadlines: fixture.missed, underruns: fixture.underruns, overruns: 0)),
        loopback: EndpointLoopbackMetrics(
            reportedInputLatencyFrames: 12,
            reportedOutputLatencyFrames: 12,
            inputSafetyOffsetFrames: 0,
            outputSafetyOffsetFrames: 0,
            measuredAnalogRoundTripMilliseconds: fixture.oneWayMilliseconds * 2,
            correctedOneWayMilliseconds: fixture.oneWayMilliseconds,
            hiddenBufferGrowthDetected: false
        ),
        notes: fixture.stable ? "stable measured row" : fixture.unstableNotes
    )
}

func measuredFixtureRejectedMode(
    _ sampleRate: Int,
    _ frames: Int,
    reason: String
) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: sampleRate,
            framesPerBuffer: frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: false,
        stable: false,
        rejectionReason: reason,
        callback: nil,
        loopback: nil,
        notes: "rejected measured row"
    )
}

func measuredFixtureRmeMadiDevice(
    uid: String,
    id: UInt32 = 100,
    transportType: String = "thun",
    outsideReportedRange: [Int] = [256],
    diagnosticNotes: [String] = ["test fixture"]
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
            identity: .init(id: id, name: "RME Fireface UFX+ MADI Thunderbolt", uid: uid, manufacturer: "RME", transportType: transportType, isAggregate: false),
            streams: .init(inputChannelCount: 64, outputChannelCount: 64, inputStreamCount: 1, outputStreamCount: 1, inputChannelLayout: nil, outputChannelLayout: nil),
            sampleRates: .init(nominalSampleRateHertz: 48_000, availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
        ]),
            buffering: .init(currentBufferFrameSize: 32, bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 8, maximum: 128), candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [8, 16, 32, 64, 128],
            outsideReportedRange: outsideReportedRange,
            note: outsideReportedRange.isEmpty ? "reported measured range" : "reported-range-only"
        )),
            timing: .init(inputLatencyFrames: 12, outputLatencyFrames: 12, inputSafetyOffsetFrames: 0, outputSafetyOffsetFrames: 0, clockDomain: 1),
            diagnosticNotes: diagnosticNotes
        )
}

func measuredFixtureLolaBaseline(
    route: RouteIdentity,
    packetMode: UdpPcmPacketMode
) -> LolaBaselineComparison {
    LolaBaselineComparison(
        setup: LolaBaselineComparison.Setup(
            availability: .measured,
            lolaVersion: "LoLa 2.0.0 Windows reference",
            lolaSettings: "48 kHz, 32-frame comparable low-latency audio path",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            route: route,
            packetMode: packetMode,
            measurementMethod: .roundTripAnalogLoopback
        ),
        measurements: LolaBaselineComparison.Measurements(
            latency: LolaBaselineLatencyMetrics(
                p50Milliseconds: 3.5,
                p95Milliseconds: 4.0,
                p99Milliseconds: 4.3,
                maxMilliseconds: 4.8
            ),
            lostPackets: 0,
            latePackets: 0,
            underruns: 0
        ),
        evidence: LolaBaselineComparison.Evidence(
            artifactNotes: "No audible LoLa baseline artifacts during the measured comparison.",
            measuredOnSameHardwareAndRoute: true
        ),
        outcome: LolaBaselineComparison.Outcome(result: .openLolaFaster, notTestedReason: nil)
    )
}
