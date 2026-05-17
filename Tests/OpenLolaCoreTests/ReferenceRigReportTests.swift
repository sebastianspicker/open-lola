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
        id: "m01-reference-rig-pass-candidate",
        title: "M01 reference rig pass candidate",
        capturedAt: "2026-05-02T00:00:00Z",
        referenceMacs: [
            ReferenceMacProfile(
                label: "source-mac",
                hostName: "lola-source.local",
                modelIdentifier: "Mac15,6",
                siliconGeneration: "Apple M3 Pro",
                ramGigabytes: 36,
                macOSProductVersion: "15.4.1",
                macOSBuild: "24E263",
                ethernetAdapterPath: "Thunderbolt 4 port 1 to Apple Thunderbolt Ethernet Adapter",
                wiredInterfaceBSDName: "en6",
                wiredInterfaceLinkSpeedMbps: 1_000,
                power: ReferenceMacPowerSettings(
                    powerSource: "AC power",
                    automaticSleep: "disabled",
                    displaySleep: "disabled during run",
                    lowPowerMode: "disabled",
                    appNapPolicy: "disabled for measurement process"
                )
            ),
            ReferenceMacProfile(
                label: "receiver-mac",
                hostName: "lola-receiver.local",
                modelIdentifier: "Mac15,6",
                siliconGeneration: "Apple M3 Pro",
                ramGigabytes: 36,
                macOSProductVersion: "15.4.1",
                macOSBuild: "24E263",
                ethernetAdapterPath: "Thunderbolt 4 port 1 to Apple Thunderbolt Ethernet Adapter",
                wiredInterfaceBSDName: "en6",
                wiredInterfaceLinkSpeedMbps: 1_000,
                power: ReferenceMacPowerSettings(
                    powerSource: "AC power",
                    automaticSleep: "disabled",
                    displaySleep: "disabled during run",
                    lowPowerMode: "disabled",
                    appNapPolicy: "disabled for measurement process"
                )
            ),
        ],
        audioPath: ReferenceAudioPath(
            interfaceModel: "RME Fireface UFX+ MADI Thunderbolt",
            connectionPath: "Thunderbolt 3 direct connection",
            driverPackage: "RME Thunderbolt Driver",
            driverVersion: "4.08",
            firmwareVersion: "230",
            driverMode: "RME DriverKit low-latency",
            totalMixVersion: "1.94",
            totalMixRouteSnapshot: "snapshots/m01-totalmix-source-receiver.tmx",
            clockSource: "internal source, receiver synced over MADI loop",
            sampleRateSource: "Core Audio nominal sample rate",
            sampleRateConversion: .absent,
            madiOpticalState: "optical input/output loop connected",
            madiCoaxState: "coax disabled",
            channelCount: 64,
            inputChannelLabels: ["MADI 1", "MADI 2"],
            outputChannelLabels: ["MADI 1", "MADI 2"],
            coreAudioInputUID: "rme-madi-input-uid",
            coreAudioOutputUID: "rme-madi-output-uid",
            cableLoopDescription: "MADI optical output pair looped to matching input pair",
            currentBufferFrameSize: 32,
            acceptedBufferFrameRange: ReferenceBufferFrameRange(minimum: 16, maximum: 128),
            inputLatencyFrames: 32,
            outputLatencyFrames: 32,
            inputSafetyOffsetFrames: 0,
            outputSafetyOffsetFrames: 0
        ),
        sampleRateMatrix: [
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
        ],
        networkProfiles: [
            ReferenceNetworkProfile(
                label: "single-host",
                topology: .singleHost,
                senderMacLabel: "source-mac",
                receiverMacLabel: "source-mac",
                routeDescription: "same-host loopback smoke only",
                vlanState: "none",
                senderInterfaceName: "lo0",
                receiverInterfaceName: "lo0",
                linkSpeedMbps: 0,
                mtu: 16_384,
                senderIPAddress: "127.0.0.1",
                receiverIPAddress: "127.0.0.1",
                packetCaptureHost: "lola-source.local",
                packetCaptureInterface: "lo0",
                packetCapturePoint: "loopback capture on source Mac",
                captureFilter: "udp port 5004",
                dscp: ReferenceDscpPolicy(
                    requestedValue: nil,
                    observedValue: nil,
                    classification: .notTested,
                    policy: "DSCP not evaluated on loopback smoke route.",
                    notTestedReason: "loopback smoke route is not a physical network path"
                )
            ),
            ReferenceNetworkProfile(
                label: "direct-wired",
                topology: .directWired,
                senderMacLabel: "source-mac",
                receiverMacLabel: "receiver-mac",
                routeDescription: "direct Thunderbolt Ethernet cable",
                vlanState: "untagged",
                senderInterfaceName: "en6",
                receiverInterfaceName: "en6",
                linkSpeedMbps: 1_000,
                mtu: 1_500,
                senderIPAddress: "192.0.2.10",
                receiverIPAddress: "192.0.2.11",
                packetCaptureHost: "receiver-mac",
                packetCaptureInterface: "en6",
                packetCapturePoint: "receiver en6 ingress capture",
                captureFilter: "udp port 5004",
                dscp: ReferenceDscpPolicy(
                    requestedValue: 46,
                    observedValue: 46,
                    classification: .honored,
                    policy: "request EF DSCP 46 on UDP PCM packets",
                    notTestedReason: nil
                )
            ),
            ReferenceNetworkProfile(
                label: "dedicated-switch",
                topology: .dedicatedSwitch,
                senderMacLabel: "source-mac",
                receiverMacLabel: "receiver-mac",
                routeDescription: "isolated one-switch test path",
                vlanState: "untagged",
                senderInterfaceName: "en6",
                receiverInterfaceName: "en6",
                linkSpeedMbps: 1_000,
                mtu: 1_500,
                senderIPAddress: "198.51.100.10",
                receiverIPAddress: "198.51.100.11",
                packetCaptureHost: "receiver-mac",
                packetCaptureInterface: "en6",
                packetCapturePoint: "receiver en6 ingress capture behind switch",
                captureFilter: "udp port 5004",
                dscp: ReferenceDscpPolicy(
                    requestedValue: 46,
                    observedValue: 46,
                    classification: .honored,
                    policy: "request EF DSCP 46 on UDP PCM packets",
                    notTestedReason: nil
                )
            ),
            ReferenceNetworkProfile(
                label: "campus",
                topology: .campus,
                senderMacLabel: "source-mac",
                receiverMacLabel: "receiver-mac",
                routeDescription: "managed campus test VLAN",
                vlanState: "test VLAN 300",
                senderInterfaceName: "en6",
                receiverInterfaceName: "en6",
                linkSpeedMbps: 1_000,
                mtu: 1_500,
                senderIPAddress: "203.0.113.10",
                receiverIPAddress: "203.0.113.11",
                packetCaptureHost: "receiver-mac",
                packetCaptureInterface: "en6",
                packetCapturePoint: "receiver en6 ingress capture on campus VLAN",
                captureFilter: "udp port 5004",
                dscp: ReferenceDscpPolicy(
                    requestedValue: 46,
                    observedValue: 46,
                    classification: .honored,
                    policy: "request EF DSCP 46 on UDP PCM packets",
                    notTestedReason: nil
                )
            ),
        ],
        thresholds: ReferenceRigThresholds(
            primaryStableBufferFrames: 32,
            stretchStableBufferFrames: 16,
            fallbackStableBufferFrames: 64,
            builtInDevicesAllowedForPass: false,
            callbackP99MaxMicroseconds: 400,
            callbackMaxMicroseconds: 666,
            allowedUnderruns: 0,
            packetAgeP99MaxMicroseconds: 400,
            packetAgeMaxMicroseconds: 666,
            packetLossMaxPackets: 0,
            allowedVerdicts: [.pass, .partial, .fail]
        ),
        verdict: .pass,
        notes: "Pass candidate for validator tests only."
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
