// Shared verification tooling pmr proof bundle helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

func expectWeakPmrReportFixturesAreRejected(_ fixture: PmrProofBundleTestFixture) throws {
    let lolaReport = fixture.bundle.appendingPathComponent("pmr-23/lola-media-session.json")
    try weakPmr23LoLaMediaSessionJson.write(to: lolaReport, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-23/lola-media-session.json peer must be a live non-loopback peer"
    )

    try validPmr23LoLaMediaSessionJson.write(to: lolaReport, atomically: true, encoding: .utf8)
    let audioLoopbackReport = fixture.bundle.appendingPathComponent("pmr-23/audio-loopback-run.json")
    try weakPmr23AudioLoopbackRunJson.write(to: audioLoopbackReport, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-23/audio-loopback-run.json callback.recordedIntervalSamples must be > 0"
    )

    try validPmr23AudioLoopbackRunJson.write(to: audioLoopbackReport, atomically: true, encoding: .utf8)
    try expectWeakPmr16HardwareNotesAreRejected(fixture)
    try expectWeakPmr16TrafficIsRejected(fixture)
    try expectWeakPmr14TrafficIsRejected(fixture)
    try expectWeakPmr04RuntimeAndSanitizerAreRejected(fixture)
}

private func expectWeakPmr16HardwareNotesAreRejected(_ fixture: PmrProofBundleTestFixture) throws {
    let hardwareNotes = fixture.bundle.appendingPathComponent("pmr-16/hardware-notes.md")
    try """
    input UID: shared-rme-madi-test-uid
    output UID: shared-rme-madi-test-uid
    RME MADI
    peer readiness: exchanged
    teardown: completed
    packet capture: private/captures/pmr-16-test.pcapng

    """.write(to: hardwareNotes, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-16/hardware-notes.md input UID and output UID must be distinct"
    )
    try validPmr16HardwareNotes.write(to: hardwareNotes, atomically: true, encoding: .utf8)
}

private func expectWeakPmr16TrafficIsRejected(_ fixture: PmrProofBundleTestFixture) throws {
    let madiReport = fixture.bundle.appendingPathComponent("pmr-16/madi-full-duplex.json")
    try weakPmr16MadiFullDuplexJson.write(to: madiReport, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-16/madi-full-duplex.json metrics.completedReceiveBlocks must be > 0"
    )
    try validPmr16MadiFullDuplexJson.write(to: madiReport, atomically: true, encoding: .utf8)
}

private func expectWeakPmr14TrafficIsRejected(_ fixture: PmrProofBundleTestFixture) throws {
    let directP2PReport = fixture.bundle.appendingPathComponent("pmr-14/direct-p2p-session.json")
    try weakPmr14DirectP2PSessionJson.write(to: directP2PReport, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout must be > 0"
    )
    try validPmr14DirectP2PSessionJson.write(to: directP2PReport, atomically: true, encoding: .utf8)
}

private func expectWeakPmr04RuntimeAndSanitizerAreRejected(_ fixture: PmrProofBundleTestFixture) throws {
    let realtimeReport = fixture.bundle.appendingPathComponent("pmr-04/realtime-audio-engine.json")
    try weakPmr04RealtimeAudioEngineJson.write(to: realtimeReport, atomically: true, encoding: .utf8)
    try expectCurrentPmrFixtureFails(
        fixture,
        expected: "pmr-04/realtime-audio-engine.json runtime.callbackOwner must be audioDeviceIOProc"
    )

    try validPmr04RealtimeAudioEngineJson.write(to: realtimeReport, atomically: true, encoding: .utf8)
    try "VERDICT: PASS\n".write(
        to: fixture.bundle.appendingPathComponent("pmr-04/sanitizer-result.txt"),
        atomically: true,
        encoding: .utf8
    )
    try expectCurrentPmrFixtureFails(fixture, expected: "must contain: ASAN: PASS")
}

func expectWeakPmrMode(_ fixture: PmrProofBundleTestFixture, mode: String, expected: String) throws {
    let result = try runVerificationToolingShell(
        "OPEN_LOLA_CLI=\"$1\" OPEN_LOLA_FAKE_PMR_MODE=\"$2\" bash scripts/verify-pmr-external-proof-bundle.sh \"$3\"",
        fixture.fakeCLI.path,
        mode,
        fixture.bundle.path
    )
    #expect(result.status != 0)
    #expect(result.output.contains(expected))
    #expect(!result.output.contains("PMR external proof bundle verified"))
}

private func expectCurrentPmrFixtureFails(_ fixture: PmrProofBundleTestFixture, expected: String) throws {
    let result = try runVerificationToolingShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fixture.fakeCLI.path,
        fixture.bundle.path
    )
    #expect(result.status != 0)
    #expect(result.output.contains(expected))
    #expect(!result.output.contains("PMR external proof bundle verified"))
}

struct PmrProofBundleTestFixture {
    var root: URL
    var bundle: URL
    var fakeCLI: URL
}

func makeTemporaryPmrProofBundleFixture() throws -> PmrProofBundleTestFixture {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-pmr-proof-bundle-\(UUID().uuidString)")
    let bundle = temporaryRoot.appendingPathComponent("bundle")
    let fakeCLI = temporaryRoot.appendingPathComponent("open-lola")
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    try createPmrProofBundleFixture(at: bundle)
    try writeFakePmrProofBundleCLI(to: fakeCLI)
    return PmrProofBundleTestFixture(root: temporaryRoot, bundle: bundle, fakeCLI: fakeCLI)
}

func expectPmrReportValidationCommands(in script: String) {
    let requiredReportValidations = [
        """
        validate_report "PMR-04" "pmr-04/realtime-audio-engine.json" "validate-realtime-audio-engine-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/rx-buffer-benchmark.json" "validate-rx-buffer-benchmark-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/drift-plc-certification.json" "validate-drift-plc-certification-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/direct-p2p-session.json" "validate-direct-p2p-session-report" "PASS"
        """,
        """
        validate_report "PMR-16" "pmr-16/madi-full-duplex.json" "validate-madi-full-duplex-report" "PASS"
        """,
        """
        validate_report "PMR-23" "pmr-23/recording-session.json" "validate-recording-session-report" "PASS"
        """
    ]
    for validation in requiredReportValidations {
        #expect(script.contains(validation))
    }
}

func expectPmr04AndPmr14RuntimeContracts(in script: String) {
    for required in [
        "validate_pmr04_runtime_contract",
        "pmr-04/realtime-audio-engine.json runtime.callbackOwner must be audioDeviceIOProc",
        "pmr-04/realtime-audio-engine.json runtime.handoff.shutdownCompleted must be true",
        "require_file_contains \"$sanitizer_result\" \"ASAN: PASS\"",
        "require_file_contains \"$sanitizer_result\" \"TSAN: PASS\"",
        "verify-direct-p2p-session-evidence-bundle",
        "expect_last_verdict \"pmr-14 direct P2P evidence bundle\" \"$output_file\" \"PASS\"",
        "validate_pmr14_runtime_contract",
        "pmr-14/rx-buffer-benchmark.json evidenceKind must be physicalReferenceRig",
        "pmr-14/rx-buffer-benchmark.json direct row fastestPassEligible must be true",
        "pmr-14/drift-plc-certification.json lolaBaselineComparison.result must be openLolaFaster "
            + "or openLolaEquivalent",
        "pmr-14/direct-p2p-session.json measuredEvidence.packetCapture",
        "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsSent",
        "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout",
        "\"audioPlayoutUnderruns\","
    ] {
        #expect(script.contains(required))
    }
}

func expectPmr16HardwareContracts(in script: String) {
    for required in [
        "require_file_contains \"$notes_path\" \"input UID:\"",
        "require_file_contains \"$notes_path\" \"output UID:\"",
        "require_file_contains \"$notes_path\" \"RME MADI\"",
        "require_file_contains \"$notes_path\" \"peer readiness: exchanged\"",
        "require_file_contains \"$notes_path\" \"teardown: completed\"",
        "require_file_contains \"$notes_path\" \"packet capture:\"",
        "pmr-16/hardware-notes.md input UID and output UID must be distinct",
        "validate_pmr16_runtime_contract",
        "\"completedReceiveBlocks\",",
        "\"renderedReceiveBlocks\",",
        "f\"pmr-16/madi-full-duplex.json metrics.{field}\""
    ] {
        #expect(script.contains(required))
    }
}

func expectPmr23RuntimeContracts(in script: String) {
    for predicate in [
        "^role: tx-rx$",
        "^real-link-transmitted: true$",
        "^frames: [1-9][0-9]*$",
        "^state: completed$",
        "^can-start-ioproc: true$",
        "^blockers: 0$"
    ] {
        #expect(script.contains(predicate))
    }
    for required in [
        "validate_pmr23_runtime_contract",
        "pmr-23/lola-media-session.json peer must be a live non-loopback peer"
    ] {
        #expect(script.contains(required))
    }
    #expect(script.contains("pmr-23/audio-loopback-run.json callback.recordedIntervalSamples"))
    #expect(script.contains("pmr-23/audio-loopback-run.json handoff.shutdownCompleted"))
    #expect(script.contains("echo \"VERDICT: PASS\""))
}

private func writeFakePmrProofBundleCLI(to url: URL) throws {
    try """
    #!/usr/bin/env bash
    set -euo pipefail

    command="${1:-}"
    mode="${OPEN_LOLA_FAKE_PMR_MODE:-pass}"

    case "$command" in
      validate-lola-media-session-report)
        echo "role: tx-rx"
        if [[ "$mode" == "weak-lola" ]]; then
          echo "real-link-transmitted: false"
          echo "frames: 0"
        else
          echo "real-link-transmitted: true"
          echo "frames: 480"
        fi
        echo "VERDICT: PARTIAL"
        ;;
      validate-audio-loopback-run-report)
        if [[ "$mode" == "weak-coreaudio" ]]; then
          echo "state: blockedPreflight"
          echo "can-start-ioproc: false"
          echo "blockers: 2"
        else
          echo "state: completed"
          echo "can-start-ioproc: true"
          echo "blockers: 0"
        fi
        echo "VERDICT: PARTIAL"
        ;;
      verify-direct-p2p-session-evidence-bundle)
        echo "bundle: verified"
        echo "VERDICT: PASS"
        ;;
      validate-*)
        echo "VERDICT: PASS"
        ;;
      *)
        echo "unexpected fake open-lola command: $command" >&2
        exit 64
        ;;
    esac

    """.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
