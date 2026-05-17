import Foundation
import Testing

@testable import OpenLolaCore

@Test
func syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass() throws {
    let smokeCases: [(name: String, validate: () throws -> Void)] = [
        ("video capture", {
            let report = VideoCaptureSyntheticSmoke.run()
            try report.validate()
            #expect(report.source.kind == .testPattern)
            #expect(report.verdict == .partial)
            #expect(report.queue.policy == .latestFrame)
        }),
        ("native app shell", {
            let report = NativeAppShellSyntheticSmoke.run()
            try report.validate()
            #expect(report.runMode == .synthetic)
            #expect(report.verdict == .partial)
            #expect(report.metricsObserver.readOnly)
            #expect(report.smokeProbe.runtimeSmokeProbed == false)
        }),
        ("mac-to-mac route certification", {
            let report = MacToMacRouteCertificationSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.routes.map(\.routeKind) == [.directLink, .dedicatedSwitch, .campusPath])
        }),
        ("aoip evaluation", {
            let report = AoipSyntheticSmoke.run()
            try report.validate()
            #expect(report.mode == .avb)
            #expect(report.verdict == .partial)
            #expect(report.usage == .deferred)
        }),
        ("performance audit", {
            let report = try PerformanceAuditSyntheticSmoke.run()
            try report.validate()
            #expect(report.id == "m12-apple-silicon-performance-synthetic-smoke")
            #expect(report.verdict == .partial)
            #expect(report.counters.callbackDuration.sampleCount > 0)
            #expect(report.counters.packetizationDuration.sampleCount > 0)
            #expect(report.counters.depacketizationDuration.sampleCount > 0)
            #expect(report.counters.videoFrameAge.p99Microseconds > 0)
            #expect(report.counters.ringDropCount >= 0)
            #expect(report.hotPaths.first { $0.surface == .audioCallback }?.allocationWarnings == 0)
            #expect(report.appleSiliconPolicy.nativeArm64Process)
            #expect(!report.appleSiliconPolicy.rosettaTranslated)
            #expect(report.appleSiliconPolicy.usesQoSInsteadOfCorePinning)
            #expect(report.appleSiliconPolicy.usesUnifiedMemoryLowCopyVideoPath)
            #expect(Set(report.profileReports.map(\.settingsTier)) == Set(PerformanceSettingsTier.allCases))
        }),
        ("packaging field test", {
            let report = PackagingFieldTestSyntheticSmoke.run()
            try report.validate()
            #expect(report.distributionMethod == .developerID)
            #expect(report.verdict == .partial)
            #expect(report.cleanMac.cleanMacTested == false)
            #expect(report.permissionEntitlementSurface?.networkClientEntitlementKey == "com.apple.security.network.client")
        }),
        ("external connector", {
            let report = ExternalConnectorSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.sourceLevelVerdict == .pass)
            #expect(report.realWorldVerdict == .partial)
            #expect(report.connectors.map(\.connector) == ExternalConnectorKind.allCases)
            #expect(report.connectors.first { $0.connector == .lola }?.sourceContractImplemented == true)
            #expect(report.connectors.first { $0.connector == .lola }?.supportedHandshake == .protocolAwareTxRx)
            #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("docs/reverse-engineering-boundary.md") == true)
            #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("private/") == false)
            #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("archive/") == false)
            #expect(report.assumptions.first?.contains("video prelude packets") == true)
            #expect(report.assumptions.contains { $0.contains("early process exits") })
            #expect(report.assumptions.contains { $0.contains("connector-scoped") })
            #expect(report.connectors.first { $0.connector == .lola }?.notes.contains("post-control UDP socket media TX/RX") == true)
            #expect(report.connectors.filter { $0.connector != .lola }.allSatisfy { $0.sourceContractImplemented })
            #expect(report.connectors.allSatisfy { !$0.realWorldInteroperabilityClaimed })
            #expect(report.connectors.allSatisfy { $0.preservesDefaultAudioFirstPath })
        }),
        ("hardware validation", {
            let report = HardwareValidationSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.fieldRun.syntheticEvidenceUsedForPass == false)
            #expect(report.fieldRun.machineReadableVerdict)
        }),
        ("video transport", {
            let report = try VideoTransportSyntheticSmoke.run()
            try report.validate()
            #expect(report.transport.mode == .raw)
            #expect(report.receiver.queuePolicy == .latestFrame)
            #expect(report.verdict == .partial)
        }),
        ("drift plc fixed-target certification", {
            let report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.runMode == .synthetic)
        }),
        ("lighting fixture gate", {
            let report = try LightingFixtureGateSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.runMode == .synthetic)
            #expect(report.policy.explicitlyArmed == false)
            #expect(report.probe.packetCapture.captured == false)
        }),
        ("field-ready runtime", {
            let report = FieldReadyRuntimeSyntheticSmoke.run()
            try report.validate()
            #expect(report.runMode == .synthetic)
            #expect(report.verdict == .partial)
            #expect(report.runtime.cliAuthoritative)
            #expect(report.recording.writesOutsideRealtimePaths)
        }),
        ("network aoip certification", {
            let report = NetworkAoipCertificationSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.runMode == .synthetic)
        }),
        ("recording session", {
            let report = RecordingSessionSyntheticSmoke.run()
            try report.validate()
            #expect(report.runMode == .synthetic)
            #expect(report.verdict == .partial)
            #expect(report.sideLane.fileIOAllowedInRealtimeCallback == false)
            #expect(report.writerPressure.gapMarkerCount == report.writerPressure.droppedChunkCount)
        }),
        ("latency tuning", {
            let report = LatencyTuningSyntheticSmoke.run()
            try report.validate()
            #expect(report.id == "m07-latency-tuning-synthetic-smoke")
            #expect(report.verdict == .partial)
            #expect(report.candidates.count == 3)
            #expect(report.tuningChanges.count == 1)
        }),
        ("integrated profile", {
            let report = IntegratedProfileSyntheticSmoke.run()
            try report.validate()
            #expect(report.id == "m12-integrated-profile-synthetic-smoke")
            #expect(report.defaultProfile == .fastestAudio)
            #expect(report.verdict == .partial)
            #expect(report.aggregateSubordinateVerdict == .partial)
            #expect(report.profileOptions.first { $0.label == .fastestAudio }?.defaultProfile == true)
            #expect(report.profileOptions.filter(\.defaultProfile).count == 1)
        }),
        ("integrated headless av", {
            let report = IntegratedHeadlessAvSyntheticSmoke.run()
            try report.validate()
            #expect(report.runMode == .synthetic)
            #expect(report.headless.uiOwnsRealtimePaths == false)
            #expect(report.sync.masterClock == .audio)
            #expect(report.video.frameTiming.nonMonotonicTimestampCount == 0)
            #expect(report.video.frameTiming.duplicateFrameIdentityCount == 0)
            #expect(report.video.renderSync.staleFramesRendered == 0)
            #expect(report.video.receiverDroppedFrames == 2)
            #expect(report.proof?.closureGate == .p04IntegratedAvProof)
            #expect(report.proof?.rmeAudioDeviceVisible == false)
            #expect(report.verdict == .partial)
        }),
        ("latency benchmark", {
            let report = try LatencyBenchmarkSyntheticSmoke.run()
            try report.validate()
            #expect(report.id == "m02-latency-benchmark-synthetic-smoke")
            #expect(report.verdict == .partial)
            #expect(report.resources.allocationWarnings.count == 1)
            #expect(report.resources.threadWarnings.count == 1)
        }),
        ("e2e benchmark", {
            let report = try E2EBenchmarkSyntheticSmoke.run()
            try report.validate()
            #expect(report.id == "m13-e2e-integrated-benchmark-synthetic-smoke")
            #expect(report.runMode == .synthetic)
            #expect(report.evidenceKind == .synthetic)
            #expect(report.verdict == .partial)
            #expect(Set(report.profiles.map(\.profile)) == Set(E2EBenchmarkProfile.allCases))
            #expect(Set(report.impairments.map(\.profile)) == Set(E2EBenchmarkImpairmentProfile.allCases))
            #expect(report.recovery.reconnectEvents > 0)
            #expect(report.recovery.cleanShutdownObserved)
        }),
        ("release hardening", {
            let report = ReleaseHardeningSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.claims.map(\.evidenceKind).contains(.publicDocumentation))
            #expect(report.verificationGates.map(\.kind).contains(.swiftTest))
            #expect(report.benchmarkComparison.m12ReportId.contains("apple-silicon-performance"))
            #expect(report.benchmarkComparison.m13ReportId.contains("e2e-integrated-benchmark"))
        }),
        ("faster-than-lola closure", {
            let report = FasterThanLoLaClosureSyntheticSmoke.run()
            try report.validate()
            #expect(report.claimScope == .fieldReady)
            #expect(report.verdict == .partial)
            #expect(report.evidence.map(\.lane).contains(.f01RmeMadiHardwareBaseline))
            #expect(report.evidence.map(\.lane).contains(.f09FieldReadiness))
            #expect(report.comparison.result == .unavailable)
            #expect(report.fastestPathBlockedByParity == false)
        }),
        ("realtime audio engine", {
            let report = try RealtimeAudioEngineSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.runMode == .synthetic)
            #expect(report.runtime.handoff.outputUnderrunBlocks == 1)
            #expect(report.runtime.handoff.maximumBufferedBlocks <= report.runtime.handoff.ringCapacityBlocks)
        }),
        ("drift plc", {
            let report = try DriftPlcSyntheticSmoke.run()
            try report.validate()
            #expect(report.verdict == .partial)
            #expect(report.metrics.playoutTargetFrames == 32)
            #expect(report.metrics.hiddenPlayoutGrowthDetected == false)
            #expect(report.plcEvents.allSatisfy { !$0.waitedForRetransmission })
        }),
    ]

    #expect(smokeCases.count == 23)
    for smokeCase in smokeCases {
        #expect(!smokeCase.name.isEmpty)
        try smokeCase.validate()
    }
}

@Test
func syntheticSmokeReportsRejectFalsePassMutations() throws {
    let falsePassCases: [(name: String, validateFalsePass: () throws -> Void)] = [
        ("video capture", {
            var report = VideoCaptureSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("native app shell", {
            var report = NativeAppShellSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("mac-to-mac route certification", {
            var report = MacToMacRouteCertificationSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("aoip evaluation", {
            var report = AoipSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("performance audit", {
            var report = try PerformanceAuditSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("packaging field test", {
            var report = PackagingFieldTestSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("external connector", {
            var report = ExternalConnectorSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("hardware validation", {
            var report = HardwareValidationSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("video transport", {
            var report = try VideoTransportSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("drift plc fixed-target certification", {
            var report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("lighting fixture gate", {
            var report = try LightingFixtureGateSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("field-ready runtime", {
            var report = FieldReadyRuntimeSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("network aoip certification", {
            var report = NetworkAoipCertificationSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("recording session", {
            var report = RecordingSessionSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("latency tuning", {
            var report = LatencyTuningSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("integrated profile", {
            var report = IntegratedProfileSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("integrated headless av", {
            var report = IntegratedHeadlessAvSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("latency benchmark", {
            var report = try LatencyBenchmarkSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("e2e benchmark", {
            var report = try E2EBenchmarkSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("release hardening", {
            var report = ReleaseHardeningSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("faster-than-lola closure", {
            var report = FasterThanLoLaClosureSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("realtime audio engine", {
            var report = try RealtimeAudioEngineSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
        ("drift plc", {
            var report = try DriftPlcSyntheticSmoke.run()
            report.verdict = .pass
            try report.validate()
        }),
    ]

    #expect(falsePassCases.count == 23)
    for falsePassCase in falsePassCases {
        expectSyntheticFalsePassRejected(falsePassCase.name, falsePassCase.validateFalsePass)
    }
}

private func expectSyntheticFalsePassRejected(
    _ name: String,
    _ validateFalsePass: () throws -> Void
) {
    do {
        try validateFalsePass()
        Issue.record("Synthetic false-PASS mutation accepted: \(name)")
    } catch {
        #expect(!String(describing: error).isEmpty)
    }
}
