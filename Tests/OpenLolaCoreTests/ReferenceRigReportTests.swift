import Foundation
import Testing

@testable import OpenLolaCore

@Test
func referenceRigReportRejectsInvalidPassEvidence() throws {
    try expectReferenceRigError(.missingReferenceMacs(minimum: 2, actual: 1)) {
        $0.referenceMacs = [$0.referenceMacs[0]]
    }
    try expectReferenceRigError(.passWithPlaceholderField("referenceMacs[0].hostName")) {
        $0.referenceMacs[0].hostName = "TODO(human): source Mac host name"
    }
    try expectReferenceRigError(.passWithPlaceholderField("referenceMacs[0].hostName")) {
        $0.referenceMacs[0].hostName = "FIXME source Mac host name"
    }
    try expectReferenceRigError(.passWithPlaceholderField("audioPath.driverVersion")) {
        $0.audioPath.driverVersion = "unimplemented driver version"
    }
    try expectReferenceRigError(.passWithPlaceholderField("audioPath.firmwareVersion")) {
        $0.audioPath.firmwareVersion = "XXX"
    }
    try expectReferenceRigError(.passWithPlaceholderField("audioPath.driverVersion")) {
        $0.audioPath.driverVersion = "not-supplied"
    }
    try expectReferenceRigError(.passWithoutRmeMadiPath) {
        $0.audioPath.interfaceModel = "Built-in Output"
    }
    try expectReferenceRigError(.passWithoutThunderboltRmePath) {
        $0.audioPath.connectionPath = "USB 3.0 direct connection"
    }
    try expectReferenceRigError(.passWithoutDedicatedRmeDriver) {
        $0.audioPath.driverMode = "class-compliant fallback"
    }
    try expectReferenceRigError(.passWithSampleRateConversion(.present)) {
        $0.audioPath.sampleRateConversion = .present
    }
    try expectReferenceRigError(.missingRequiredNetworkTopology(.directWired)) {
        $0.networkProfiles = $0.networkProfiles.filter { profile in
            profile.topology == .singleHost
        }
    }
    try expectReferenceRigError(.passWithoutDscpClassification("direct-wired")) {
        $0.networkProfiles[1].dscp.classification = .notTested
        $0.networkProfiles[1].dscp.observedValue = nil
        $0.networkProfiles[1].dscp.notTestedReason = "capture pending"
    }
    try expectReferenceRigError(.passAllowsBuiltInDevices) {
        $0.thresholds.builtInDevicesAllowedForPass = true
    }
}

@Test
func referenceRigReportRejectsNilDscpNotTestedReason() throws {
    var report = makePassCandidate()
    report.verdict = .partial
    report.networkProfiles[1].dscp.classification = .notTested
    report.networkProfiles[1].dscp.observedValue = nil
    report.networkProfiles[1].dscp.notTestedReason = nil

    #expect(throws: ReferenceRigValidationError.missingDscpNotTestedReason("direct-wired")) {
        try report.validate()
    }
}

@Test
func referenceRigPassCandidateValidates() throws {
    let report = makePassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.thresholds.primaryStableBufferFrames == 32)
}

@Test
func referenceRigPassThresholdTargetsAreEnforced() throws {
    let report = makePassCandidate()
    #expect(report.thresholds.primaryStableBufferFrames == 32)
    #expect(report.thresholds.stretchStableBufferFrames == 16)
    #expect(report.thresholds.fallbackStableBufferFrames == 64)

    var invalidPrimary = report
    invalidPrimary.thresholds.primaryStableBufferFrames = 64
    #expect(throws: ReferenceRigValidationError.invalidThresholdTarget("thresholds.primaryStableBufferFrames")) {
        try invalidPrimary.validate()
    }

    var invalidStretch = report
    invalidStretch.thresholds.stretchStableBufferFrames = 32
    #expect(throws: ReferenceRigValidationError.invalidThresholdTarget("thresholds.stretchStableBufferFrames")) {
        try invalidStretch.validate()
    }

    var invalidFallback = report
    invalidFallback.thresholds.fallbackStableBufferFrames = 128
    #expect(throws: ReferenceRigValidationError.invalidThresholdTarget("thresholds.fallbackStableBufferFrames")) {
        try invalidFallback.validate()
    }
}

private func expectReferenceRigError(
    _ expected: ReferenceRigValidationError,
    mutate: (inout ReferenceRigReport) throws -> Void
) throws {
    var report = makePassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func makePassCandidate() -> ReferenceRigReport {
    ReferenceRigReport(
        metadata: ReferenceRigReportMetadata(
            id: "m01-reference-rig-pass-candidate",
            title: "M01 reference rig pass candidate",
            capturedAt: "2026-05-02T00:00:00Z",
            notes: "Pass candidate for validator tests only."
        ),
        evidence: ReferenceRigReportEvidence(
            referenceMacs: [
                referenceMac(label: "source-mac", hostName: "lola-source.local"),
                referenceMac(label: "receiver-mac", hostName: "lola-receiver.local"),
            ],
            audioPath: referenceAudioPath(),
            sampleRateMatrix: referenceSampleRateMatrix(),
            networkProfiles: referenceNetworkProfiles(),
            thresholds: referenceThresholds()
        ),
        verdict: .pass
    )
}

private func referenceMac(label: String, hostName: String) -> ReferenceMacProfile {
    ReferenceMacProfile(
        identity: ReferenceMacIdentity(
            label: label,
            hostName: hostName,
            modelIdentifier: "Mac15,6",
            siliconGeneration: "Apple M3 Pro",
            ramGigabytes: 36
        ),
        operatingSystem: ReferenceMacOperatingSystem(productVersion: "15.4.1", build: "24E263"),
        wiredInterface: ReferenceMacWiredInterface(
            adapterPath: "Thunderbolt 4 port 1 to Apple Thunderbolt Ethernet Adapter",
            bsdName: "en6",
            linkSpeedMbps: 1_000
        ),
        power: ReferenceMacPowerSettings(
            powerSource: "AC power",
            automaticSleep: "disabled",
            displaySleep: "disabled during run",
            lowPowerMode: "disabled",
            appNapPolicy: "disabled for measurement process"
        )
    )
}

private func referenceAudioPath() -> ReferenceAudioPath {
    ReferenceAudioPath(
        interfaceDescription: ReferenceAudioInterfaceDescription(
            interfaceModel: "RME Fireface UFX+ MADI Thunderbolt",
            connectionPath: "Thunderbolt 3 direct connection",
            driverPackage: "RME Thunderbolt Driver",
            driverVersion: "4.08",
            firmwareVersion: "230",
            driverMode: "RME DriverKit low-latency",
            totalMixVersion: "1.94",
            totalMixRouteSnapshot: "snapshots/m01-totalmix-source-receiver.tmx"
        ),
        clocking: ReferenceAudioClocking(
            clockSource: "internal source, receiver synced over MADI loop",
            sampleRateSource: "Core Audio nominal sample rate",
            sampleRateConversion: .absent,
            madiOpticalState: "optical input/output loop connected",
            madiCoaxState: "coax disabled"
        ),
        channels: ReferenceAudioChannels(
            channelCount: 64,
            inputChannelLabels: ["MADI 1", "MADI 2"],
            outputChannelLabels: ["MADI 1", "MADI 2"]
        ),
        coreAudio: ReferenceCoreAudioDeviceIDs(
            inputUID: "rme-madi-input-uid",
            outputUID: "rme-madi-output-uid"
        ),
        buffering: ReferenceAudioBuffering(
            cableLoopDescription: "MADI optical output pair looped to matching input pair",
            currentBufferFrameSize: 32,
            acceptedBufferFrameRange: ReferenceBufferFrameRange(minimum: 16, maximum: 128),
            inputLatencyFrames: 32,
            outputLatencyFrames: 32,
            inputSafetyOffsetFrames: 0,
            outputSafetyOffsetFrames: 0
        )
    )
}

private func referenceSampleRateMatrix() -> [ReferenceSampleRateDisposition] {
    [
        ReferenceSampleRateDisposition(
            sampleRateHertz: 48_000,
            disposition: .accepted,
            requestedBufferFrameSizes: [16, 32, 64, 128],
            acceptedBufferFrameSizes: [32, 64, 128],
            notes: "32-frame stable target accepted."
        ),
        ReferenceSampleRateDisposition(
            sampleRateHertz: 96_000,
            disposition: .accepted,
            requestedBufferFrameSizes: [16, 32, 64, 128],
            acceptedBufferFrameSizes: [32, 64, 128],
            notes: "96 kHz accepted for comparison."
        ),
        ReferenceSampleRateDisposition(
            sampleRateHertz: 192_000,
            disposition: .rejected,
            requestedBufferFrameSizes: [16, 32, 64, 128],
            acceptedBufferFrameSizes: [],
            notes: "Rejected for this reference path after measurement."
        ),
    ]
}

private func referenceNetworkProfiles() -> [ReferenceNetworkProfile] {
    [
        referenceNetworkProfile(
            ReferenceNetworkFixture(
                label: "single-host",
                topology: .singleHost,
                receiverMacLabel: "source-mac",
                routeDescription: "same-host loopback smoke only",
                vlanState: "none",
                interfaces: ("lo0", "lo0"),
                linkSpeedMbps: 0,
                mtu: 16_384,
                addresses: ("127.0.0.1", "127.0.0.1"),
                capture: ("lola-source.local", "lo0", "loopback capture on source Mac"),
                dscp: loopbackDscpPolicy()
            )
        ),
        referenceNetworkProfile(
            ReferenceNetworkFixture(
                label: "direct-wired",
                topology: .directWired,
                routeDescription: "direct Thunderbolt Ethernet cable",
                vlanState: "untagged",
                addresses: ("192.0.2.10", "192.0.2.11"),
                capture: ("receiver-mac", "en6", "receiver en6 ingress capture")
            )
        ),
        referenceNetworkProfile(
            ReferenceNetworkFixture(
                label: "dedicated-switch",
                topology: .dedicatedSwitch,
                routeDescription: "isolated one-switch test path",
                vlanState: "untagged",
                addresses: ("198.51.100.10", "198.51.100.11"),
                capture: ("receiver-mac", "en6", "receiver en6 ingress capture behind switch")
            )
        ),
        referenceNetworkProfile(
            ReferenceNetworkFixture(
                label: "campus",
                topology: .campus,
                routeDescription: "managed campus test VLAN",
                vlanState: "test VLAN 300",
                addresses: ("203.0.113.10", "203.0.113.11"),
                capture: ("receiver-mac", "en6", "receiver en6 ingress capture on campus VLAN")
            )
        ),
    ]
}

private struct ReferenceNetworkFixture {
    var label: String
    var topology: ReferenceNetworkTopology
    var receiverMacLabel = "receiver-mac"
    var routeDescription: String
    var vlanState: String
    var interfaces: (sender: String, receiver: String) = ("en6", "en6")
    var linkSpeedMbps = 1_000
    var mtu = 1_500
    var addresses: (sender: String, receiver: String)
    var capture: (host: String, interface: String, point: String)
    var dscp = honoredDscpPolicy()
}

private func referenceNetworkProfile(_ fixture: ReferenceNetworkFixture) -> ReferenceNetworkProfile {
    ReferenceNetworkProfile(
        route: ReferenceNetworkRouteDetails(
            label: fixture.label,
            topology: fixture.topology,
            routeDescription: fixture.routeDescription,
            vlanState: fixture.vlanState,
            linkSpeedMbps: fixture.linkSpeedMbps,
            mtu: fixture.mtu
        ),
        endpoints: ReferenceNetworkEndpoints(
            senderMacLabel: "source-mac",
            receiverMacLabel: fixture.receiverMacLabel,
            senderInterfaceName: fixture.interfaces.sender,
            receiverInterfaceName: fixture.interfaces.receiver,
            senderIPAddress: fixture.addresses.sender,
            receiverIPAddress: fixture.addresses.receiver
        ),
        packetCapture: ReferencePacketCaptureProfile(
            host: fixture.capture.host,
            interface: fixture.capture.interface,
            point: fixture.capture.point,
            filter: "udp port 5004"
        ),
        dscp: fixture.dscp
    )
}

private func loopbackDscpPolicy() -> ReferenceDscpPolicy {
    ReferenceDscpPolicy(
        requestedValue: nil,
        observedValue: nil,
        classification: .notTested,
        policy: "DSCP not evaluated on loopback smoke route.",
        notTestedReason: "loopback smoke route is not a physical network path"
    )
}

private func honoredDscpPolicy() -> ReferenceDscpPolicy {
    ReferenceDscpPolicy(
        requestedValue: 46,
        observedValue: 46,
        classification: .honored,
        policy: "request EF DSCP 46 on UDP PCM packets",
        notTestedReason: nil
    )
}

private func referenceThresholds() -> ReferenceRigThresholds {
    ReferenceRigThresholds(
        buffers: ReferenceRigBufferThresholds(
            primaryStableBufferFrames: 32,
            stretchStableBufferFrames: 16,
            fallbackStableBufferFrames: 64
        ),
        builtInDevicesAllowedForPass: false,
        callback: ReferenceRigCallbackThresholds(
            p99MaxMicroseconds: 400,
            maxMicroseconds: 666,
            allowedUnderruns: 0
        ),
        packet: ReferenceRigPacketThresholds(
            ageP99MaxMicroseconds: 400,
            ageMaxMicroseconds: 666,
            lossMaxPackets: 0
        ),
        allowedVerdicts: [.pass, .partial, .fail]
    )
}

private func loadReferenceRigFixture(named name: String) throws -> ReferenceRigReport {
    let url = try referenceRigFixtureURL(named: name)
    return try ReferenceRigReport.decode(from: Data(contentsOf: url))
}

private func referenceRigFixtureURL(named name: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "ReferenceRigReports/valid"
    )

    return try #require(
        nestedURL ?? Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: nil
        )
    )
}
