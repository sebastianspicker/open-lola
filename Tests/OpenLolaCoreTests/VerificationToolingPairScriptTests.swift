import Foundation
import Testing


@Test
func dockerParityPreflightReportsBlockedForUnresponsiveDaemon() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-docker-preflight-\(UUID().uuidString)")
    let fakeBin = temporaryRoot.appendingPathComponent("bin")
    try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let fakeDocker = fakeBin.appendingPathComponent("docker")
    try """
    #!/usr/bin/env bash
    sleep 5
    """.write(to: fakeDocker, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeDocker.path)

    let result = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS=0.2 /bin/bash -c 'source scripts/lib/parity.sh; parity_require_docker_daemon \"Docker parity test\"'",
        fakeBin.path
    )

    #expect(result.status == 77)
    #expect(result.output.contains("Docker parity test blocked"))
    #expect(result.output.contains("Docker daemon did not respond within 0.2s to docker ps"))
    #expect(result.output.contains("Start Docker Desktop or the Docker daemon"))
}

@Test
func parityOutputDirPreservesExplicitEnvironmentAndTemporaryFallbacks() throws {
    let explicit = try runShell(
        "OPEN_LOLA_OUTPUT_DIR=\"$2\"; TMPDIR=\"$3\"; source scripts/lib/parity.sh; parity_output_dir \"sample\" \"$1\"",
        "/explicit/out",
        "/env/out",
        "/tmp/open-lola-test"
    )
    #expect(explicit.status == 0)
    #expect(explicit.output.trimmingCharacters(in: .whitespacesAndNewlines) == "/explicit/out")

    let environment = try runShell(
        "OPEN_LOLA_OUTPUT_DIR=\"$2\"; TMPDIR=\"$3\"; source scripts/lib/parity.sh; parity_output_dir \"sample\" \"$1\"",
        "",
        "/env/out",
        "/tmp/open-lola-test"
    )
    #expect(environment.status == 0)
    #expect(environment.output.trimmingCharacters(in: .whitespacesAndNewlines) == "/env/out")

    let temporary = try runShell(
        "unset OPEN_LOLA_OUTPUT_DIR; TMPDIR=\"$1\"; source scripts/lib/parity.sh; parity_output_dir \"sample\"",
        "/tmp/open-lola-test"
    )
    #expect(temporary.status == 0)
    #expect(temporary.output.contains("/tmp/open-lola-test/open-lola-sample-"))
}

@Test
func parityStopsDockerContainersByNamePrefix() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-docker-stop-prefix-\(UUID().uuidString)")
    let fakeBin = temporaryRoot.appendingPathComponent("bin")
    let dockerLog = temporaryRoot.appendingPathComponent("docker-log.txt")
    try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let fakeDocker = fakeBin.appendingPathComponent("docker")
    try """
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
    """.write(to: fakeDocker, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeDocker.path)

    let result = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_TEST_DOCKER_LOG=\"$2\" /bin/bash -c 'source scripts/lib/parity.sh; parity_stop_docker_containers_by_name_prefix \"open-lola-test\"'",
        fakeBin.path,
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

    let result = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" OPEN_LOLA_JACKTRIP_STARTUP_SECONDS=0 OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 OPEN_LOLA_JACKTRIP_TX_DURATION_SECONDS=1 bash scripts/run-local-jacktrip-rxtx-docker.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    try expectManagedJackTripDockerResult(result, fixture: fixture)
}

private func expectManagedJackTripDockerResult(_ result: ShellResult, fixture: PairScriptFixture) throws {
    #expect(result.status == 0)
    #expect(result.output.contains("VERDICT: PARTIAL"))
    let openLolaArgs = try String(contentsOf: fixture.openLolaLog, encoding: .utf8)
    #expect(openLolaArgs.contains("prefix=open-lola-jacktrip-rxtx-rx"))
    #expect(openLolaArgs.contains("prefix=open-lola-jacktrip-rxtx-tx"))
    #expect(openLolaArgs.contains("--role rx"))
    #expect(openLolaArgs.contains("--role tx"))
    #expect(openLolaArgs.contains("validate-external-connector-session-report"))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("jacktrip-rx.json").path))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("jacktrip-tx.json").path))
}

@Test
func ultraGridDockerRxTxScriptRunsManagedRxTxAndConnectionMetrics() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-ultragrid-rxtx-script")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    try writeFakeUltraGridDockerOpenLola(to: fixture.openLola)
    try writeFakeUltraGridDocker(to: fixture.docker)

    let result = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE=reviewed/ultragrid:1.10 OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS=1 OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS=1 OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS=1 OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 bash scripts/run-local-ultragrid-rxtx-docker.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    try expectManagedUltraGridDockerResult(result, fixture: fixture)
}

private func expectManagedUltraGridDockerResult(_ result: ShellResult, fixture: PairScriptFixture) throws {
    #expect(result.status == 0)
    #expect(result.output.contains("VERDICT: PARTIAL"))
    let openLolaArgs = try String(contentsOf: fixture.openLolaLog, encoding: .utf8)
    #expect(openLolaArgs.contains("prefix=open-lola-ultragrid-rxtx-rx"))
    #expect(openLolaArgs.contains("prefix=open-lola-ultragrid-rxtx-tx"))
    #expect(openLolaArgs.contains("--role rx"))
    #expect(openLolaArgs.contains("--role tx"))
    #expect(openLolaArgs.contains("validate-external-connector-session-report"))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-rx.json").path))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-tx.json").path))
    #expect(FileManager.default.fileExists(
        atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-connection-metrics.json").path
    ))
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

    let result = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_BIN=\"$1/open-lola\" OPEN_LOLA_TEST_OPEN_LOLA_ARGS=\"$2\" OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE=/usr/local/bin/uvg OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS=1 OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS=1 OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS=1 OPEN_LOLA_CONNECTOR_DURATION_SECONDS=1 bash scripts/run-local-ultragrid-rxtx-native.sh \"$3\"",
        fixture.fakeBin.path,
        fixture.openLolaLog.path,
        fixture.outputDirectory.path
    )

    try expectManagedUltraGridNativeResult(result, fixture: fixture, selectedExecutable: selectedExecutable)
}

private func expectManagedUltraGridNativeResult(
    _ result: ShellResult,
    fixture: PairScriptFixture,
    selectedExecutable: URL
) throws {
    #expect(result.status == 0)
    #expect(result.output.contains("Native UltraGrid preflight report:"))
    #expect(result.output.contains("Native UltraGrid connection metrics:"))
    #expect(result.output.contains("VERDICT: PARTIAL"))
    let openLolaArgs = try String(contentsOf: fixture.openLolaLog, encoding: .utf8)
    #expect(openLolaArgs.contains("external-connector-executable-preflight-run"))
    #expect(openLolaArgs.contains("--ultragrid-executable /usr/local/bin/uvg"))
    #expect(openLolaArgs.contains("native-executable=\(selectedExecutable.path)"))
    #expect(openLolaArgs.contains("--role rx"))
    #expect(openLolaArgs.contains("--role tx"))
    #expect(openLolaArgs.contains("validate-external-connector-session-report"))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-native-preflight.json").path))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-rx.json").path))
    #expect(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-tx.json").path))
    #expect(FileManager.default.fileExists(
        atPath: fixture.outputDirectory.appendingPathComponent("ultragrid-connection-metrics.json").path
    ))
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
    let docker = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_ULTRAGRID_PARITY_TRIALS=2 /bin/bash scripts/stress-local-ultragrid-parity-docker.sh \"$2\"",
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
    let native = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_ULTRAGRID_PARITY_TRIALS=3 /bin/bash scripts/stress-local-ultragrid-parity-native.sh \"$2\"",
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

private struct PairScriptFixture {
    var root: URL
    var fakeBin: URL
    var outputDirectory: URL
    var openLolaLog: URL
    var selectedExecutable: URL?

    var openLola: URL {
        fakeBin.appendingPathComponent("open-lola")
    }

    var docker: URL {
        fakeBin.appendingPathComponent("docker")
    }

    var bash: URL {
        fakeBin.appendingPathComponent("bash")
    }
}

private func makePairScriptFixture(
    slug: String,
    selectedExecutableName: String? = nil
) throws -> PairScriptFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(slug)-\(UUID().uuidString)")
    let fakeBin = root.appendingPathComponent("bin")
    let selectedExecutable = selectedExecutableName.map { root.appendingPathComponent($0) }
    try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
    if let selectedExecutable {
        try Data().write(to: selectedExecutable)
    }
    return PairScriptFixture(
        root: root,
        fakeBin: fakeBin,
        outputDirectory: root.appendingPathComponent("out"),
        openLolaLog: root.appendingPathComponent("open-lola-args.txt"),
        selectedExecutable: selectedExecutable
    )
}

private func writeExecutableScript(_ contents: String, to url: URL) throws {
    try contents.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func writeFakeJackTripOpenLola(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/bin/bash
        set -euo pipefail
        printf 'prefix=%s\\n' "${OPEN_LOLA_JACKTRIP_DOCKER_NAME_PREFIX:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        printf '%s\\n' "$*" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        if [[ "${1:-}" == "external-connector-session-run" ]]; then
          output=""
          role=""
          while (($#)); do
            case "$1" in
              --output) shift; output="$1" ;;
              --role) shift; role="$1" ;;
            esac
            shift || true
          done
          if [[ -n "$output" ]]; then
            mkdir -p "$(dirname "$output")"
            printf '{"role":"%s"}\\n' "$role" >"$output"
          fi
        fi
        exit 0
        """,
        to: url
    )
}

private func writeFakeJackTripDocker(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/usr/bin/env bash
        case "${1:-}" in
          ps) printf 'container-rx\\n' ;;
          logs) printf 'fake docker log\\n' ;;
          exec) printf 'Received Connection from Peer!\\n' ;;
          stop) exit 0 ;;
        esac
        exit 0
        """,
        to: url
    )
}

private func writeFakeUltraGridDockerOpenLola(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/usr/bin/env bash
        set -euo pipefail
        printf 'prefix=%s\\n' "${OPEN_LOLA_ULTRAGRID_DOCKER_NAME_PREFIX:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        printf '%s\\n' "$*" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        if [[ "${1:-}" == "external-connector-session-run" ]]; then
          output=""
          role=""
          while (($#)); do
            case "$1" in
              --output) shift; output="$1" ;;
              --role) shift; role="$1" ;;
            esac
            shift || true
          done
          if [[ -n "$output" ]]; then
            mkdir -p "$(dirname "$output")"
            printf '{"role":"%s"}\\n' "$role" >"$output"
          fi
          sleep 0.2
        fi
        exit 0
        """,
        to: url
    )
}

private func writeFakeUltraGridDocker(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/usr/bin/env bash
        case "${1:-}" in
          image) exit 0 ;;
          ps) printf 'container-rx\\n' ;;
          logs)
            printf 'Audio sending started.\\n'
            printf 'Audio receiving started.\\n'
            printf 'Control socket listening\\n'
            printf 'New incoming audio format detected\\n'
            printf 'New incoming video format detected\\n'
            ;;
          stop) exit 0 ;;
        esac
        exit 0
        """,
        to: url
    )
}

private func writeFakeUltraGridNativeOpenLola(to url: URL, selectedExecutable: URL) throws {
    let script = """
    #!/usr/bin/env bash
    set -euo pipefail
    printf 'native-executable=%s\\n' "${OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
    printf 'native-log=%s\\n' "${OPEN_LOLA_ULTRAGRID_NATIVE_LOG:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
    printf '%s\\n' "$*" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
    if [[ "${1:-}" == "external-connector-executable-preflight-run" ]]; then
      output=""
      while (($#)); do
        if [[ "$1" == "--output" ]]; then shift; output="$1"; fi
        shift || true
      done
      mkdir -p "$(dirname "$output")"
      printf '%s\\n' '{"verdict":"pass","probes":[{"detectedIdentity":"ultraGrid","executable":"__SELECTED_EXECUTABLE__","notes":"ok"}]}' >"$output"
    elif [[ "${1:-}" == "external-connector-session-run" ]]; then
      output=""
      role=""
      while (($#)); do
        case "$1" in
          --output) shift; output="$1" ;;
          --role) shift; role="$1" ;;
        esac
        shift || true
      done
      if [[ -n "$output" ]]; then
        mkdir -p "$(dirname "$output")"
        printf '{"role":"%s"}\\n' "$role" >"$output"
      fi
      if [[ "$role" == "rx" && -n "${OPEN_LOLA_ULTRAGRID_NATIVE_LOG:-}" ]]; then
        mkdir -p "$(dirname "$OPEN_LOLA_ULTRAGRID_NATIVE_LOG")"
        {
          printf 'Audio sending started.\\n'
          printf 'Audio receiving started.\\n'
          printf 'Control socket listening\\n'
          printf 'New incoming audio format detected\\n'
          printf 'New incoming video format detected\\n'
        } >"$OPEN_LOLA_ULTRAGRID_NATIVE_LOG"
      fi
      sleep 0.2
    fi
    exit 0
    """.replacingOccurrences(of: "__SELECTED_EXECUTABLE__", with: selectedExecutable.path)
    try writeExecutableScript(script, to: url)
}

private func writeFakeUltraGridStressBash(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/bin/bash
        set -euo pipefail
        script="${1:-}"
        trial_dir="${2:-}"
        mkdir -p "$trial_dir"
        case "$script" in
          scripts/compare-local-ultragrid-parity-docker.sh)
            cat >"$trial_dir/ultragrid-parity-metrics.json" <<'JSON'
        {
          "comparisons": {
            "managedConnectionSetupWithinDelta": true,
            "managedDisplayFpsWithinDelta": true,
            "managedPacketReceiptNoWorseThanDirect": true
          },
          "connectionSetup": {"managedAudioVideoConnectionMs": 90},
          "displaySmoothness": {"managedMinDisplayFps": 10.0},
          "endpointHealth": {
            "directBaselineClean": true,
            "managedEndpointClean": true
          },
          "errors": []
        }
        JSON
            exit 0
            ;;
          scripts/compare-local-ultragrid-parity-native.sh)
            cat >"$trial_dir/ultragrid-native-preflight.json" <<'JSON'
        {"verdict":"fail","probes":[{"notes":"native UltraGrid missing"}]}
        JSON
            exit 77
            ;;
          *)
            exec /bin/bash "$@"
            ;;
        esac
        """,
        to: url
    )
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct ShellResult {
    let status: Int32
    let output: String
}

private func loadJSON(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func runShell(_ command: String, _ arguments: String...) throws -> ShellResult {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = repositoryRoot
    process.arguments = ["-lc", command, "open-lola-test"] + arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    var combinedOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
    combinedOutput.append(errorOutput)
    return ShellResult(
        status: process.terminationStatus,
        output: String(decoding: combinedOutput, as: UTF8.self)
    )
}
