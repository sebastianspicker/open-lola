// Verifies that Docker parity preflight reports blocked for unresponsive daemon.
import Foundation
import Testing

@Test
func dockerParityPreflightReportsBlockedForUnresponsiveDaemon() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-docker-preflight")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    try writeExecutableScript("""
    #!/usr/bin/env bash
    sleep 5
    """, to: fixture.docker)

    let result = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS=0.2 " +
            "/bin/bash -c 'source scripts/lib/parity.sh; " +
            "parity_require_docker_daemon \"Docker parity test\"'",
        fixture.fakeBin.path
    )

    #expect(result.status == 77)
    #expect(result.output.contains("Docker parity test blocked"))
    #expect(result.output.contains("Docker daemon did not respond within 0.2s to docker ps"))
    #expect(result.output.contains("Start Docker Desktop or the Docker daemon"))
}
@Test
func parityOutputDirPreservesExplicitEnvironmentAndTemporaryFallbacks() throws {
    let explicit = try runVerificationToolingShell(
        "OPEN_LOLA_OUTPUT_DIR=\"$2\"; TMPDIR=\"$3\"; source scripts/lib/parity.sh; parity_output_dir \"sample\" \"$1\"",
        "/explicit/out",
        "/env/out",
        "/tmp/open-lola-test"
    )
    #expect(explicit.status == 0)
    #expect(explicit.output.trimmingCharacters(in: .whitespacesAndNewlines) == "/explicit/out")

    let environment = try runVerificationToolingShell(
        "OPEN_LOLA_OUTPUT_DIR=\"$2\"; TMPDIR=\"$3\"; source scripts/lib/parity.sh; parity_output_dir \"sample\" \"$1\"",
        "",
        "/env/out",
        "/tmp/open-lola-test"
    )
    #expect(environment.status == 0)
    #expect(environment.output.trimmingCharacters(in: .whitespacesAndNewlines) == "/env/out")

    let temporary = try runVerificationToolingShell(
        "unset OPEN_LOLA_OUTPUT_DIR; TMPDIR=\"$1\"; source scripts/lib/parity.sh; parity_output_dir \"sample\"",
        "/tmp/open-lola-test"
    )
    #expect(temporary.status == 0)
    #expect(temporary.output.contains("/tmp/open-lola-test/open-lola-sample-"))
}

@Test
func parityMonotonicClockAdvancesAcrossPythonProcesses() throws {
    let result = try runVerificationToolingShell(
        "PATH=/usr/bin:/bin; source scripts/lib/parity.sh; " +
            "first=$(parity_monotonic_ms); sleep 0.2; second=$(parity_monotonic_ms); " +
            "printf '%s %s\\n' \"$first\" \"$second\""
    )
    let values = result.output.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
    let first = try #require(values.first)
    let second = try #require(values.last)

    #expect(result.status == 0)
    #expect(values.count == 2)
    #expect(second - first >= 100)
}

@Test
func parityStopsDockerContainersByNamePrefix() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-docker-stop-prefix")
    let dockerLog = fixture.root.appendingPathComponent("docker-log.txt")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    try writeExecutableScript("""
    #!/usr/bin/env bash
    set -euo pipefail
    case "${1:-}" in
      ps)
        printf 'container-a\\ncontainer-b\\n'
        ;;
      stop)
        printf 'stop:%s\\n' "${2:-}" >>"$OPEN_LOLA_TEST_DOCKER_LOG"
        ;;
    esac
    exit 0
    """, to: fixture.docker)

    let result = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_TEST_DOCKER_LOG=\"$2\" " +
            "/bin/bash -c 'source scripts/lib/parity.sh; " +
            "parity_stop_docker_containers_by_name_prefix \"open-lola-test\"'",
        fixture.fakeBin.path,
        dockerLog.path
    )

    #expect(result.status == 0)
    let log = try String(contentsOf: dockerLog, encoding: .utf8)
    #expect(log.contains("stop:container-a"))
    #expect(log.contains("stop:container-b"))
}

@Test
func jackTripDockerRxTxScriptRunsManagedRxTxAndValidation() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-jacktrip-rxtx-script")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    try writeFakeJackTripOpenLola(to: fixture.openLola)
    try writeFakeJackTripDocker(to: fixture.docker)

    let result = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" " +
            "OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" OPEN_LOLA_JACKTRIP_STARTUP_SECONDS=0 " +
            "OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 OPEN_LOLA_JACKTRIP_TX_DURATION_SECONDS=1 " +
            "bash scripts/run-local-jacktrip-rxtx-docker.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    try expectManagedConnectorResult(
        result,
        fixture: fixture,
        containerPrefix: "open-lola-jacktrip-rxtx",
        artifactNames: ["jacktrip-rx.json", "jacktrip-tx.json"]
    )
}

@Test
func ultraGridDockerRxTxScriptRunsManagedRxTxAndConnectionMetrics() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-ultragrid-rxtx-script")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    try writeFakeUltraGridDockerOpenLola(to: fixture.openLola)
    try writeFakeUltraGridDocker(to: fixture.docker)

    let result = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" " +
            "OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" " +
            "OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE=reviewed/ultragrid:1.10 " +
            "OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS=1 " +
            "OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS=1 " +
            "OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS=1 OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 " +
            "bash scripts/run-local-ultragrid-rxtx-docker.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    try expectManagedConnectorResult(
        result,
        fixture: fixture,
        containerPrefix: "open-lola-ultragrid-rxtx",
        artifactNames: [
            "ultragrid-rx.json",
            "ultragrid-tx.json",
            "ultragrid-connection-metrics.json"
        ]
    )
}

private func expectManagedConnectorResult(
    _ result: VerificationToolingShellResult,
    fixture: PairScriptFixture,
    containerPrefix: String?,
    artifactNames: [String]
) throws {
    #expect(result.status == 0)
    #expect(result.output.contains("VERDICT: PARTIAL"))
    let openLolaArgs = try String(contentsOf: fixture.openLolaLog, encoding: .utf8)
    if let containerPrefix {
        #expect(openLolaArgs.contains("prefix=\(containerPrefix)-rx"))
        #expect(openLolaArgs.contains("prefix=\(containerPrefix)-tx"))
    }
    #expect(openLolaArgs.contains("--role rx"))
    #expect(openLolaArgs.contains("--role tx"))
    #expect(openLolaArgs.contains("validate-external-connector-session-report"))
    for artifactName in artifactNames {
        #expect(FileManager.default.fileExists(
            atPath: fixture.outputDirectory.appendingPathComponent(artifactName).path
        ))
    }
}

@Test
func ultraGridNativeRxTxScriptRunsPreflightManagedRxTxAndConnectionMetrics() throws {
    let fixture = try makePairScriptFixture(
        slug: "open-lola-ultragrid-native-rxtx-script",
        selectedExecutableName: "uvg"
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    let selectedExecutable = try #require(fixture.selectedExecutable)
    try writeFakeUltraGridNativeOpenLola(to: fixture.openLola, selectedExecutable: selectedExecutable)

    let result = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" " +
            "OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" " +
            "OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE=/usr/local/bin/uvg " +
            "OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS=1 " +
            "OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS=1 " +
            "OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS=1 OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 " +
            "bash scripts/run-local-ultragrid-rxtx-native.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    #expect(result.status == 0)
    #expect(result.output.contains("Native UltraGrid preflight report:"))
    #expect(result.output.contains("Native UltraGrid connection metrics:"))
    let openLolaArgs = try String(contentsOf: fixture.openLolaLog, encoding: .utf8)
    #expect(openLolaArgs.contains("external-connector-executable-preflight-run"))
    #expect(openLolaArgs.contains("--ultragrid-executable /usr/local/bin/uvg"))
    #expect(openLolaArgs.contains("native-executable=\(selectedExecutable.path)"))
    try expectManagedConnectorResult(
        result,
        fixture: fixture,
        containerPrefix: nil,
        artifactNames: [
            "ultragrid-native-preflight.json",
            "ultragrid-rx.json",
            "ultragrid-tx.json",
            "ultragrid-connection-metrics.json"
        ]
    )
}

@Test
func ultraGridStressScriptsSummarizeTrialHealthAndNativePreflightFailure() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-ultragrid-stress-script")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    try writeFakeUltraGridStressBash(to: fixture.bash)

    try expectUltraGridDockerStressSummary(fixture)
    try expectUltraGridNativeStressPreflightFailure(fixture)
}

private func expectUltraGridDockerStressSummary(_ fixture: PairScriptFixture) throws {
    let dockerOutput = fixture.root.appendingPathComponent("docker-out")
    let docker = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_ULTRAGRID_PARITY_TRIALS=2 " +
            "/bin/bash scripts/stress-local-ultragrid-parity-docker.sh \"$2\"",
        fixture.fakeBin.path,
        dockerOutput.path
    )
    #expect(docker.status == 0)
    #expect(docker.output.contains("UltraGrid parity stability summary:"))
    #expect(docker.output.contains("VERDICT: PARTIAL"))
    let dockerSummary = try loadJSON(
        dockerOutput.appendingPathComponent("ultragrid-parity-stability-summary.json")
    )
    #expect(dockerSummary["schema"] as? String == "open-lola-ultragrid-local-parity-stability-summary-v1")
    #expect(dockerSummary["requestedTrials"] as? Int == 2)
    #expect(dockerSummary["completedTrials"] as? Int == 2)
    #expect(dockerSummary["allTrialsPassed"] as? Bool == true)
    #expect(dockerSummary["allDirectBaselinesClean"] as? Bool == true)
    #expect(dockerSummary["allManagedEndpointsClean"] as? Bool == true)
}

private func expectUltraGridNativeStressPreflightFailure(_ fixture: PairScriptFixture) throws {
    let nativeOutput = fixture.root.appendingPathComponent("native-out")
    let native = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_ULTRAGRID_PARITY_TRIALS=3 " +
            "/bin/bash scripts/stress-local-ultragrid-parity-native.sh \"$2\"",
        fixture.fakeBin.path,
        nativeOutput.path
    )
    #expect(native.status == 77)
    let nativeSummary = try loadJSON(
        nativeOutput.appendingPathComponent("ultragrid-native-parity-stability-summary.json")
    )
    #expect(nativeSummary["schema"] as? String == "open-lola-ultragrid-native-parity-stability-summary-v1")
    #expect(nativeSummary["requestedTrials"] as? Int == 3)
    #expect(nativeSummary["completedTrials"] as? Int == 1)
    #expect(nativeSummary["hostReady"] as? Bool == false)
    #expect(nativeSummary["allTrialsPassed"] as? Bool == false)
    let trials = try #require(nativeSummary["trials"] as? [[String: Any]])
    #expect(trials.first?["exitStatus"] as? Int == 77)
    #expect((trials.first?["errors"] as? [String])?.contains(
        "native UltraGrid executable preflight did not pass"
    ) == true)
}
