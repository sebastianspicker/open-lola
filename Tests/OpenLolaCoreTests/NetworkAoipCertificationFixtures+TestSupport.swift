import Foundation
import Testing
@testable import OpenLolaCore

func loadNetworkAoipCertificationFixture(named name: String) throws -> NetworkAoipCertificationReport {
    let url = try networkAoipCertificationFixtureURL(named: name)
    return try NetworkAoipCertificationReport.decode(from: Data(contentsOf: url))
}

func makeNetworkAoipCertificationPassCandidate() throws -> NetworkAoipCertificationReport {
    let routeReport = networkAoipRouteReport()
    let routeCertification = networkAoipRouteCertification(routeReport: routeReport)
    let driftReport = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: routeReport,
        configuration: DriftPlcRunConfiguration(
            routeReportPath: "docs/mac-port/reports/g04-direct-link-route.json",
            durationSeconds: 3_600,
            policy: .silence,
            artifactAssessmentCompleted: true,
            artifactNotes: "No audible artifacts during measured silence baseline.",
            outputPath: "docs/mac-port/reports/g05-direct-link-drift-plc.json"
        )
    )
    let driftCertification = DriftPlcFixedTargetCertificationReport(
        id: "g05-direct-link-fixed-target-certification",
        title: "G05 direct-link fixed-target drift PLC certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        routeCertificationReport: routeCertification,
        driftPlcReport: driftReport,
        sourceRealtimeEngineReport: try networkAoipRealtimeReport(routeCertification: routeCertification),
        lolaBaselineComparison: networkAoipLolaBaseline(route: routeReport.route),
        runArtifactPath: "docs/mac-port/reports/g05-direct-link-drift-plc.json",
        notTestedReason: nil,
        verdict: .pass,
        notes: "Measured G05 fixed-target certification for the accepted direct-link baseline."
    )

    return NetworkAoipCertificationReport(
        id: "g06-network-aoip-certification-measured",
        title: "G06 measured network AoIP certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        routeCertificationReport: routeCertification,
        driftPlcCertificationReport: driftCertification,
        aoipEvaluationReport: networkAoipEvaluationReport(routeReport: routeReport),
        ptpArtifactPath: "docs/mac-port/reports/ptp/g06-avb-ptp-lock.md",
        stressArtifactPath: "docs/mac-port/reports/stress/g06-avb-wcrt.md",
        profileArtifactPath: "docs/mac-port/reports/profiles/g06-avb-profile.md",
        notTestedReason: nil,
        verdict: .pass,
        notes: "Measured G06 network timing certification over the accepted direct-link baseline."
    )
}

private func networkAoipCertificationFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NetworkAoipCertificationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NetworkAoipCertificationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )
    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func networkAoipRouteCertification(routeReport: UdpPcmRouteReport) -> MacToMacRouteCertificationReport {
    MacToMacRouteCertificationReport(
        id: "g04-direct-link-certification-measured",
        title: "Measured G04 direct-link route certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        packetMode: networkAoipPacketMode(),
        sourceRealtimeEngineReportId: "g03-rme-engine-measured",
        routes: [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: routeReport,
                packetCaptureArtifact: "docs/mac-port/reports/captures/direct-link-en5-2026-05-02.pcapng",
                notTestedReason: nil,
                notes: "Measured direct-link route with receiver capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route was not part of this direct-link baseline.",
                notes: "Deferred until direct-link baseline is accepted."
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
        notes: "Measured direct-link certification for G06 baseline input."
    )
}

private func networkAoipRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        id: "m05-direct-link-measured-route",
        title: "Measured direct-link UDP PCM route",
        capturedAt: "2026-05-02T00:00:00Z",
        route: RouteIdentity(label: "direct-link-reference", topology: "mac-to-mac-direct-cable"),
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
        packetMode: networkAoipPacketMode(),
        measuredDurationSeconds: 2,
        network: UdpPcmNetworkProfile(
            linkRateMbps: 1_000,
            vlan: "untagged",
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

private func networkAoipEvaluationReport(routeReport: UdpPcmRouteReport) -> AoipEvaluationReport {
    AoipEvaluationReport(
        id: "m07-avb-measured-evaluation",
        title: "Measured M07 AVB network evaluation",
        capturedAt: "2026-05-02T00:00:00Z",
        mode: .avb,
        usage: .optionalFastestLocalMode,
        route: routeReport.route,
        ptp: AoipPtpProfile(
            version: "IEEE 1588-2008",
            profile: "802.1AS AVB media profile",
            domain: "0",
            masterClockId: "rme-avb-master-clock-001",
            lockState: "locked"
        ),
        switchProfile: AoipSwitchProfile(
            model: "Netgear M4250-10G2F-PoE",
            firmwareVersion: "13.0.4.13",
            linkRateMbps: 1_000,
            trafficClass: "SR class A",
            streamReservation: "enabled",
            schedule: "credit-based shaper"
        ),
        endpoint: AoipEndpointPair(
            sender: networkAoipEndpointProfile("sender"),
            receiver: networkAoipEndpointProfile("receiver")
        ),
        profileEvidence: AoipProfileEvidence(
            standardsRead: ["IEEE 802.1AS and 802.1Qav AVB profile notes"],
            vendorProfilesRead: ["RME AVB endpoint media profile"]
        ),
        baselineComparison: AoipBaselineComparison(
            directUdpPcmRouteReportId: routeReport.id,
            directUdpPcmVerdict: .pass,
            measuredOnSamePath: true,
            directUdpPcmP99Microseconds: 240,
            evaluatedModeP99Microseconds: 180,
            notes: "AVB endpoint p99 was measured on the same direct-link path."
        ),
        stress: AoipStressReport(
            measured: true,
            competingTrafficProfile: "iperf3 bidirectional 70 percent link load",
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 90,
                p95Microseconds: 140,
                p99Microseconds: 180,
                maxMicroseconds: 220
            ),
            packetLoss: 0,
            recoveryBehavior: "stream recovered within one packet period",
            notes: "Measured WCRT-style stress run retained audio timing."
        ),
        verdict: .pass,
        notes: "Measured AVB mode kept lower p99 than the direct UDP PCM baseline."
    )
}

private func networkAoipRealtimeReport(
    routeCertification: MacToMacRouteCertificationReport
) throws -> RealtimeAudioEngineReport {
    RealtimeAudioEngineReport(
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
        configuration: try networkAoipRealtimeConfiguration(),
        safety: RealtimeAudioCallbackSafetyChecklist(
            noAllocationInCallback: true,
            noLoggingInCallback: true,
            noFileIOInCallback: true,
            noLocksOrUnboundedWaitsInCallback: true,
            noNetworkSetupInCallback: true,
            noReportWritingInCallback: true,
            countersOnlyInCallback: true
        ),
        runtime: try networkAoipRealtimeRuntime(),
        sourceRmeFastestAudioReport: networkAoipRmeFastestReport(),
        sourceRouteCertificationReport: routeCertification,
        runArtifactPath: "docs/mac-port/reports/g03-rme-realtime-engine-measured.json",
        verdict: .pass,
        notes: "Measured RME MADI realtime engine source report for G06 tests."
    )
}

private func networkAoipRmeFastestReport() -> RmeFastestAudioPathReport {
    RmeFastestAudioPathReport(
        id: "g02-rme-fastest-pass-candidate",
        title: "Measured G02 RME fastest audio report",
        capturedAt: "2026-05-02T00:00:00Z",
        inventoryCapturedAt: "2026-05-02T00:00:00Z",
        inventoryHostName: "reference-mac",
        rmeDevice: networkAoipRmeDevice(),
        driverEvidence: RmeMadiDriverEvidence(
            driverPackage: "RME Thunderbolt Driver",
            driverVersion: "4.08",
            firmwareVersion: "230",
            driverMode: .driverKit,
            totalMixVersion: "1.94",
            totalMixSnapshot: "docs/mac-port/reports/totalmix/g02-rme-totalmix.tmx",
            clockSource: "internal clock with MADI loopback locked",
            sampleRateSource: "Core Audio nominal sample rate",
            sampleRateConversion: .absent,
            routingNotes: "Thunderbolt RME MADI output 1/2 looped to input 1/2"
        ),
        loopbackReport: networkAoipEndpointLoopbackReport(),
        verdict: .pass,
        notes: "Measured RME fastest-audio source report for G06 tests."
    )
}

private func networkAoipEndpointLoopbackReport() -> EndpointLoopbackReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return EndpointLoopbackReport(
        id: "m03-rme-loopback-pass-candidate",
        title: "Measured RME MADI loopback report",
        capturedAt: "2026-05-02T00:00:00Z",
        hardware: HardwareIdentity(
            referenceMac: "reference-mac",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            osVersion: "macOS 15.5 24F74",
            driverVersion: "RME Thunderbolt Driver 4.08"
        ),
        route: RouteIdentity(label: "rme-madi-loopback", topology: "single-mac-rme-madi-output-to-input"),
        device: EndpointLoopbackDevice(
            name: "RME Fireface UFX+ MADI Thunderbolt",
            uid: "rme-madi-uid",
            transportType: "thunderbolt",
            clockDomain: 1
        ),
        selectedMode: selectedMode,
        sampleRates: networkAoipLoopbackSampleRates(),
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
            notes: "Thirty minute fixed-target measured run."
        ),
        verdict: .pass,
        notes: "Measured RME loopback source report for G06 tests."
    )
}

private func networkAoipLoopbackSampleRates() -> [SampleRateLoopbackResult] {
    [
        SampleRateLoopbackResult(
            sampleRateHertz: 48_000,
            supported: true,
            unsupportedReason: nil,
            modeResults: [
                networkAoipRejectedMode(48_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                networkAoipAcceptedMode(48_000, 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1),
                networkAoipAcceptedMode(48_000, 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380),
                networkAoipAcceptedMode(48_000, 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320),
                networkAoipAcceptedMode(48_000, 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260),
            ]
        ),
        SampleRateLoopbackResult(
            sampleRateHertz: 96_000,
            supported: true,
            unsupportedReason: nil,
            modeResults: [
                networkAoipRejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                networkAoipRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
                networkAoipAcceptedMode(96_000, 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1),
                networkAoipAcceptedMode(96_000, 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340),
                networkAoipAcceptedMode(96_000, 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290),
            ]
        ),
        SampleRateLoopbackResult(
            sampleRateHertz: 192_000,
            supported: false,
            unsupportedReason: "measured device did not report 192 kHz support",
            modeResults: []
        ),
    ]
}

private func networkAoipAcceptedMode(
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
        underruns: underruns,
        unstableNotes: "accepted unstable measured row"
    )
}

private func networkAoipRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

private func networkAoipRealtimeRuntime() throws -> RealtimeAudioRuntimeEvidence {
    let rxPolicy = try networkAoipRxBufferPolicy()
    return RealtimeAudioRuntimeEvidence(
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
    )
}

private func networkAoipRealtimeConfiguration() throws -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
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
        rxBufferPolicy: try networkAoipRxBufferPolicy()
    )
}

private func networkAoipRxBufferPolicy() throws -> RxBufferPolicy {
    try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
}

private func networkAoipRmeDevice() -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: "rme-madi-uid",
        id: 42,
        transportType: "thunderbolt",
        outsideReportedRange: [],
        diagnosticNotes: ["measured RME MADI Thunderbolt source"]
    )
}

private func networkAoipLolaBaseline(route: RouteIdentity) -> LolaBaselineComparison {
    measuredFixtureLolaBaseline(route: route, packetMode: networkAoipPacketMode())
}

private func networkAoipEndpointProfile(_ suffix: String) -> AoipEndpointProfile {
    AoipEndpointProfile(
        vendor: "RME",
        model: "AVB Tool \(suffix)",
        firmwareVersion: "1.2.3",
        profileName: "AVB media endpoint",
        bufferFrames: 16
    )
}

private func networkAoipPacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}
