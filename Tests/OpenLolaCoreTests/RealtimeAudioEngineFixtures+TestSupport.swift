import Foundation
import Testing

@testable import OpenLolaCore

func realtimeAudioEnginePassCandidateReport() throws -> RealtimeAudioEngineReport {
    var report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")
    report.runMode = .measured
    report.hardwarePath = .rmeMadi
    report.hardware = HardwareIdentity(
        referenceMac: "reference-mac-mini-m2",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.5",
        driverVersion: "RME driver 4.16"
    )
    report.configuration.inputDeviceUID = "rme-madi-uid"
    report.configuration.outputDeviceUID = "rme-madi-uid"
    report.configuration.rxBufferPolicy = try .direct(
        framesPerPacket: report.configuration.framesPerBuffer,
        sampleRateHertz: report.configuration.sampleRateHertz,
        targetPackets: 1
    )
    report.runtime.callback = EndpointCallbackMetrics(
        p50Microseconds: 50,
        p95Microseconds: 90,
        p99Microseconds: 120,
        maxMicroseconds: 200,
        missedDeadlines: 0,
        underruns: 0,
        overruns: 0
    )
    report.runtime.callbackOwner = .audioDeviceIOProc
    report.runtime.handoff = RealtimeAudioHandoffMetrics(
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
        rxBuffer: RxBufferRuntimeSnapshot(policy: report.configuration.rxBufferPolicy!)
    )
    report.runtime.udpSocketsPreparedBeforeStart = true
    report.runtime.reportWrittenAfterStop = true
    report.sourceRmeFastestAudioReport = makeRealtimeAudioEngineRmeFastestAudioReport()
    report.sourceRouteCertificationReport = makeRealtimeAudioEngineRouteCertificationReport(
        sourceRealtimeEngineReportId: report.id
    )
    report.runArtifactPath = "private/reports/g03-rme-realtime-engine-measured.json"
    report.verdict = .pass
    report.notes = "Measured RME MADI realtime engine pass candidate."
    return report
}

func makeRealtimeAudioEngineRmeFastestAudioReport() -> RmeFastestAudioPathReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return RmeFastestAudioPathReport(
        id: "g02-rme-fastest-pass-candidate",
        title: "Measured G02 RME fastest audio report",
        capturedAt: "2026-05-03T00:00:00Z",
        inventoryCapturedAt: "2026-05-03T00:00:00Z",
        inventoryHostName: "reference-mac",
        rmeDevice: realtimeAudioEngineRmeMadiDevice(uid: "rme-madi-uid"),
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
        loopbackReport: realtimeAudioEngineRmeEndpointLoopbackReport(selectedMode: selectedMode),
        verdict: .pass,
        notes: "Measured RME fastest-audio source report for F02 validator tests."
    )
}

func realtimeAudioEngineRmeEndpointLoopbackReport(selectedMode: AudioMode) -> EndpointLoopbackReport {
    EndpointLoopbackReport(
        id: "m03-rme-loopback-pass-candidate",
        title: "Measured RME MADI loopback report",
        capturedAt: "2026-05-03T00:00:00Z",
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
                    realtimeAudioEngineRejectedMode(48_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    realtimeAudioEngineAcceptedMode(48_000, 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1),
                    realtimeAudioEngineAcceptedMode(48_000, 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380),
                    realtimeAudioEngineAcceptedMode(48_000, 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320),
                    realtimeAudioEngineAcceptedMode(48_000, 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260),
                ]
            ),
            SampleRateLoopbackResult(
                sampleRateHertz: 96_000,
                supported: true,
                unsupportedReason: nil,
                modeResults: [
                    realtimeAudioEngineRejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"),
                    realtimeAudioEngineRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
                    realtimeAudioEngineAcceptedMode(96_000, 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1),
                    realtimeAudioEngineAcceptedMode(96_000, 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340),
                    realtimeAudioEngineAcceptedMode(96_000, 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290),
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
        notes: "Measured RME loopback source report for F02 validator tests."
    )
}

func realtimeAudioEngineAcceptedMode(
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

func realtimeAudioEngineRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

func makeRealtimeAudioEngineRouteCertificationReport(
    sourceRealtimeEngineReportId: String
) -> MacToMacRouteCertificationReport {
    let routeReport = makeRealtimeAudioEngineRouteReport()
    return MacToMacRouteCertificationReport(
        id: "g04-direct-link-certification-measured",
        title: "Measured G04 direct-link route certification",
        capturedAt: "2026-05-03T00:00:00Z",
        runMode: .measured,
        packetMode: realtimeAudioEngineRoutePacketMode(),
        sourceRealtimeEngineReportId: sourceRealtimeEngineReportId,
        routes: [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: routeReport,
                packetCaptureArtifact: "private/reports/captures/direct-link-en5-2026-05-03.pcapng",
                notTestedReason: nil,
                notes: "Measured direct-link route with receiver capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route was not part of this F02 direct-link baseline.",
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
        notes: "Measured direct-link certification for F02 baseline input."
    )
}

func makeRealtimeAudioEngineRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        id: "m05-direct-link-measured-route",
        title: "Measured direct-link UDP PCM route",
        capturedAt: "2026-05-03T00:00:00Z",
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
        packetMode: realtimeAudioEngineRoutePacketMode(),
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
                maxMicroseconds: 320
            ),
            jitterP99Microseconds: 70,
            playoutTargetMicroseconds: 666,
            hiddenPlayoutGrowthDetected: false
        ),
        verdict: .pass,
        notes: "Measured direct-link route for F02 validator tests."
    )
}

func realtimeAudioEngineRoutePacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}

func realtimeAudioEngineRmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: uid,
        transportType: "thun",
        diagnosticNotes: ["test fixture"]
    )
}

func loadRealtimeAudioEngineFixture(named name: String) throws -> RealtimeAudioEngineReport {
    let url = try realtimeAudioEngineFixtureURL(named: name)
    return try RealtimeAudioEngineReport.decode(from: Data(contentsOf: url))
}

func realtimeAudioEngineFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RealtimeAudioEngineReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RealtimeAudioEngineReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
