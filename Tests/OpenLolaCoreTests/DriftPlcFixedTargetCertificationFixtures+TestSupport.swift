import Foundation
import Testing

@testable import OpenLolaCore

func makeDriftPlcFixedTargetCertificationPassCandidate() throws
    -> DriftPlcFixedTargetCertificationReport {
    let routeReport = makeCertificationRouteReport()
    let routeCertification = MacToMacRouteCertificationReport(
        id: "g04-direct-link-certification-measured",
        title: "Measured G04 direct-link route certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        packetMode: driftCertificationRoutePacketMode(),
        sourceRealtimeEngineReportId: "g03-rme-engine-measured",
        routes: [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: routeReport,
                packetCaptureArtifact: "private/reports/captures/direct-link-en5-2026-05-02.pcapng",
                notTestedReason: nil,
                notes: "Measured direct-link route with receiver capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route was not part of this G05 direct-link baseline.",
                notes: "Deferred until direct-link G05 baseline is accepted."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .campusPath,
                label: "campus-path-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Campus path awaits approved capture point.",
                notes: "Deferred by the campus capture question."
            ),
        ],
        verdict: .pass,
        notes: "Measured direct-link certification for G05 baseline input."
    )
    let driftReport = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: routeReport,
        configuration: DriftPlcRunConfiguration(
            routeReportPath: "private/reports/g04-direct-link-route.json",
            durationSeconds: 3_600,
            policy: .silence,
            artifactAssessmentCompleted: true,
            artifactNotes: "No audible artifacts during the measured silence baseline.",
            outputPath: "private/reports/g05-direct-link-drift-plc.json"
        )
    )

    return DriftPlcFixedTargetCertificationReport(
        id: "g05-direct-link-fixed-target-certification",
        title: "G05 direct-link fixed-target drift PLC certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        routeCertificationReport: routeCertification,
        driftPlcReport: driftReport,
        sourceRealtimeEngineReport: try makeRealtimeEngineReport(routeCertification: routeCertification),
        lolaBaselineComparison: makeLolaBaselineComparison(route: routeReport.route),
        runArtifactPath: "private/reports/g05-direct-link-drift-plc.json",
        notTestedReason: nil,
        verdict: .pass,
        notes: "Measured G05 fixed-target certification for the accepted direct-link baseline."
    )
}

func makeCertificationRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        id: "m05-direct-link-measured-route",
        title: "Measured direct-link UDP PCM route",
        capturedAt: "2026-05-02T00:00:00Z",
        route: RouteIdentity(
            label: "direct-link-reference",
            topology: "mac-to-mac-direct-cable"
        ),
        routeKind: .directLink,
        sender: UdpPcmRouteEndpoint(
            label: "sender-mac",
            hostName: "sender-mini-a",
            interfaceName: "en5",
            ipAddress: "10.10.20.10"
        ),
        receiver: UdpPcmRouteEndpoint(
            label: "receiver-mac",
            hostName: "receiver-mini-b",
            interfaceName: "en5",
            ipAddress: "10.10.20.11"
        ),
        packetMode: driftCertificationRoutePacketMode(),
        measuredDurationSeconds: 2,
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
                point: "receiver en5 tcpdump capture",
                receiverCorrelation: true,
                notes: "Receiver capture matched expected packet count and timestamp window."
            )
        ),
        metrics: UdpPcmRouteMetrics(
            packetsSent: 3_000,
            packetsReceived: 3_000,
            lostPackets: 0,
            latePackets: 0,
            reorderedPackets: 0,
            duplicatePackets: 0,
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 100,
                p95Microseconds: 180,
                p99Microseconds: 240,
                maxMicroseconds: 300
            ),
            callbackP99Microseconds: 120,
            callbackMaxMicroseconds: 180,
            jitterP99Microseconds: 40,
            playoutTargetMicroseconds: 666,
            hiddenPlayoutGrowthDetected: false
        ),
        verdict: .pass,
        notes: "Measured route report with fixed playout target and capture correlation."
    )
}

func makeRealtimeEngineReport(
    routeCertification: MacToMacRouteCertificationReport
) throws -> RealtimeAudioEngineReport {
    let rxPolicy = try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
    return RealtimeAudioEngineReport(
        id: "g03-rme-engine-measured",
        title: "Measured G03 RME realtime engine",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        hardwarePath: .rmeMadi,
        hardware: HardwareIdentity(
            referenceMac: "reference-mac-mini-m2",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            osVersion: "macOS 15.5 24F74",
            driverVersion: "RME Thunderbolt Driver 4.08"
        ),
        configuration: RealtimeAudioEngineConfiguration(
            inputDeviceUID: "rme-madi-uid",
            outputDeviceUID: "rme-madi-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            packetFormat: .int16LittleEndian,
            inputChannelMap: [0, 1],
            outputChannelMap: [0, 1],
            playoutTargetFrames: 32,
            preallocatedBlockCount: 4,
            rxBufferPolicy: rxPolicy
        ),
        safety: RealtimeAudioCallbackSafetyChecklist(
            noAllocationInCallback: true,
            noLoggingInCallback: true,
            noFileIOInCallback: true,
            noLocksOrUnboundedWaitsInCallback: true,
            noNetworkSetupInCallback: true,
            noReportWritingInCallback: true,
            countersOnlyInCallback: true
        ),
        runtime: RealtimeAudioRuntimeEvidence(
            callbackOwner: .audioDeviceIOProc,
            callback: EndpointCallbackMetrics(
                p50Microseconds: 50,
                p95Microseconds: 90,
                p99Microseconds: 120,
                maxMicroseconds: 200,
                missedDeadlines: 0,
                underruns: 0,
                overruns: 0
            ),
            handoff: RealtimeAudioHandoffMetrics(
                inputBlocks: 1_000,
                outputBlocks: 1_000,
                networkSendBlocks: 1_000,
                networkReceiveBlocks: 1_000,
                droppedInputBlocks: 0,
                droppedNetworkBlocks: 0,
                outputUnderrunBlocks: 0,
                callbackOverrunBlocks: 0,
                latePackets: 0,
                maximumBufferedBlocks: 2,
                ringCapacityBlocks: 4,
                fullCaptureRingBlocks: 0,
                invalidInputBlocks: 0,
                directInputBlocks: 1_000,
                remappedInputBlocks: 0,
                packetFragmentCount: 1_000,
                allocationWarnings: 0,
                maximumCaptureRingOccupancyBlocks: 2,
                maximumPlayoutQueueDepthBlocks: 2,
                packetizationDuration: .empty,
                depacketizationDuration: .empty,
                hiddenPlayoutGrowthDetected: false,
                shutdownCompleted: true,
                rxBuffer: RxBufferRuntimeSnapshot(policy: rxPolicy)
            ),
            udpSocketsPreparedBeforeStart: true,
            reportWrittenAfterStop: true,
            measuredDurationSeconds: 3_600
        ),
        sourceRmeFastestAudioReport: makeDriftCertificationRmeFastestAudioReport(),
        sourceRouteCertificationReport: routeCertification,
        runArtifactPath: "private/reports/g03-rme-realtime-engine-measured.json",
        verdict: .pass,
        notes: "Measured F02 realtime engine source report for F04 validator tests."
    )
}

func makeLolaBaselineComparison(route: RouteIdentity) -> LolaBaselineComparison {
    measuredFixtureLolaBaseline(route: route, packetMode: driftCertificationRoutePacketMode())
}

func makeDriftCertificationRmeFastestAudioReport() -> RmeFastestAudioPathReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return RmeFastestAudioPathReport(
        id: "g02-rme-fastest-pass-candidate",
        title: "Measured G02 RME fastest audio report",
        capturedAt: "2026-05-02T00:00:00Z",
        inventoryCapturedAt: "2026-05-02T00:00:00Z",
        inventoryHostName: "reference-mac",
        rmeDevice: driftCertificationRmeMadiDevice(uid: "rme-madi-uid"),
        driverEvidence: RmeMadiDriverEvidence(
            driverPackage: "RME Thunderbolt Driver",
            driverVersion: "4.08",
            firmwareVersion: "230",
            driverMode: .driverKit,
            totalMixVersion: "1.94",
            totalMixSnapshot: "private/reports/totalmix/g02-rme-totalmix.tmx",
            clockSource: "internal clock with MADI loopback locked",
            sampleRateSource: "Core Audio nominal sample rate",
            sampleRateConversion: .absent,
            routingNotes: "Thunderbolt RME MADI output 1/2 looped to input 1/2"
        ),
        loopbackReport: driftCertificationRmeEndpointLoopbackReport(selectedMode: selectedMode),
        verdict: .pass,
        notes: "Measured RME fastest-audio source report for F04 validator tests."
    )
}

func driftCertificationRmeEndpointLoopbackReport(selectedMode: AudioMode) -> EndpointLoopbackReport {
    EndpointLoopbackReport(
        id: "m03-rme-loopback-pass-candidate",
        title: "Measured RME MADI loopback report",
        capturedAt: "2026-05-02T00:00:00Z",
        hardware: HardwareIdentity(
            referenceMac: "reference-mac",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            osVersion: "macOS 15.5 24F74",
            driverVersion: "RME Thunderbolt Driver 4.08"
        ),
        route: RouteIdentity(
            label: "rme-madi-loopback",
            topology: "single-mac-rme-madi-output-to-input"
        ),
        device: EndpointLoopbackDevice(
            name: "RME Fireface UFX+ MADI Thunderbolt",
            uid: "rme-madi-uid",
            transportType: "thun",
            clockDomain: 1
        ),
        selectedMode: selectedMode,
        sampleRates: [
            SampleRateLoopbackResult(
                sampleRateHertz: 48_000,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    driftCertificationRejectedMode(48_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    driftCertificationAcceptedMode(48_000, 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1),
                    driftCertificationAcceptedMode(48_000, 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380),
                    driftCertificationAcceptedMode(48_000, 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320),
                    driftCertificationAcceptedMode(48_000, 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260),
                ]
            ),
            SampleRateLoopbackResult(
                sampleRateHertz: 96_000,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    driftCertificationRejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    driftCertificationRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
                    driftCertificationAcceptedMode(96_000, 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1),
                    driftCertificationAcceptedMode(96_000, 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340),
                    driftCertificationAcceptedMode(96_000, 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290),
                ]
            ),
            SampleRateLoopbackResult(
                sampleRateHertz: 192_000,
                supported: false,
                unsupportedReason: "device did not report 192 kHz support",
                modeResults: []
            ),
        ],
        stabilityRun: EndpointStabilityRun(
            mode: selectedMode,
            durationSeconds: 1_800,
            callback: EndpointCallbackMetrics(
                p50Microseconds: 100,
                p95Microseconds: 185,
                p99Microseconds: 250,
                maxMicroseconds: 390,
                missedDeadlines: 0,
                underruns: 0,
                overruns: 0
            ),
            dropoutEvents: 0,
            hiddenBufferGrowthDetected: false,
            notes: "30-minute fixed-target run"
        ),
        verdict: .pass,
        notes: "Measured RME loopback source report for F04 validator tests."
    )
}

func driftCertificationAcceptedMode(
    _ sampleRate: Int,
    _ frames: Int,
    stable: Bool,
    oneWayMilliseconds: Double,
    p99: Double,
    max: Double,
    missed: Int = 0,
    underruns: Int = 0
) -> EndpointModeResult {
    measuredFixtureAcceptedMode(
        sampleRate,
        frames,
        stable: stable,
        oneWayMilliseconds: oneWayMilliseconds,
        p99: p99,
        max: max,
        missed: missed,
        underruns: underruns
    )
}

func driftCertificationRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

func driftCertificationRmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: uid,
        transportType: "thun",
        diagnosticNotes: ["measured RME MADI Thunderbolt path"]
    )
}

func driftCertificationRoutePacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}

func loadDriftPlcFixedTargetCertificationFixture(
    named name: String
) throws -> DriftPlcFixedTargetCertificationReport {
    let url = try driftPlcFixedTargetCertificationFixtureURL(named: name)
    return try DriftPlcFixedTargetCertificationReport.decode(from: Data(contentsOf: url))
}

func driftPlcFixedTargetCertificationFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcFixedTargetCertificationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcFixedTargetCertificationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
