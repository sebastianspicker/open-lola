// Shared verification tooling script helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

func expectReleaseReadinessExternalGates(in output: String) {
    let requiredExternalGates = [
        "RUN_STEP:env PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh",
        "RUN_STEP:env PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify_source_documentation.py",
        "RUN_STEP:shellcheck -x scripts/build-local-ultragrid-docker.sh",
        "scripts/verify-release-readiness.sh",
        "scripts/lib/common.sh",
        "scripts/lib/parity.sh",
        "scripts/macos/build_and_run.sh scripts/macos/build_cli_app_bundle.sh",
        "linux_connector/deployment/wsl/probe_windows_lola.sh linux_connector/deployment/wsl/wsl_setup.sh",
        "ruff check linux_connector scripts/verify_docs scripts/lib/extract-preflight-executable.py",
        "python -m pytest -p no:cacheprovider linux_connector",
        "python -m mypy --strict linux_connector/lola_connector scripts/verify_docs "
            + "scripts/lib/extract-preflight-executable.py",
        "RUN_STEP:bash scripts/verify-release-hygiene.sh",
        "RUN_TIMED_STEP:600:swift build",
        "RUN_TIMED_STEP:1800:swift test --disable-sandbox --no-parallel --scratch-path",
        "MANUAL_GATE",
        "NATIVE_APP_LAUNCH",
        "OPEN_SOURCE_RELEASE_READINESS"
    ]
    for gate in requiredExternalGates {
        #expect(output.contains(gate))
    }
}

func expectReleaseReadinessProbeMatrix(in output: String) {
    for command in [
        "CLI:command-inventory:PARTIAL",
        "CLI:source-ownership-inventory:PARTIAL",
        "CLI:fixture-smoke-matrix:PARTIAL",
        "CLI:report-schema-inventory:PARTIAL",
        "CLI:realtime-audio-path-inventory:PARTIAL",
        "CLI:network-route-command-matrix:PARTIAL",
        "CLI:video-control-degrade-matrix:PARTIAL",
        "CLI:native-app-shell-surface-probe:PARTIAL",
        "GOAL:goal-codewise-closure:PASS",
        "GOAL:goal-runtime-evidence-template:PARTIAL",
        "GOAL:goal-runtime-preflight:PARTIAL",
        "GOAL:goal-completion-audit:PARTIAL"
    ] {
        #expect(output.contains(command))
    }
}

func expectJackTripDockerScriptsRejectUnsafeImages() throws {
    for script in jackTripDockerScripts {
        try expectJackTripDockerScriptRejectsMissingImage(script)
        try expectJackTripDockerScriptRejectsLatestImage(script)
    }
}

private func expectJackTripDockerScriptRejectsMissingImage(_ script: String) throws {
    let missing = try runVerificationToolingShell(
        "env -u OPEN_LOLA_JACKTRIP_DOCKER_IMAGE bash \"$1\" --version",
        script
    )
    #expect(missing.status == 64)
    #expect(missing.output.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE must be set"))
    #expect(missing.output.contains("Refusing the former unsafe default jacktrip/jacktrip:latest"))
}

private func expectJackTripDockerScriptRejectsLatestImage(_ script: String) throws {
    let latest = try runVerificationToolingShell(
        "OPEN_LOLA_JACKTRIP_DOCKER_IMAGE=jacktrip/jacktrip:latest bash \"$1\" --version",
        script
    )
    #expect(latest.status == 64)
    #expect(latest.output.contains("must not use the mutable latest tag"))
}

func expectJackTripDockerClientUsesPinnedUnprivilegedContainer() throws {
    let fixture = try makePairScriptFixture(slug: "open-lola-jacktrip-docker")
    let dockerLog = fixture.root.appendingPathComponent("docker-args.txt")
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }
    try writeExecutableScript("""
    #!/usr/bin/env bash
    printf '%s\\n' "$*" >> "$OPEN_LOLA_TEST_DOCKER_ARGS"
    exit 0
    """, to: fixture.docker)

    let client = try runVerificationToolingShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_TEST_DOCKER_ARGS=\"$2\" "
            + "OPEN_LOLA_JACKTRIP_DOCKER_IMAGE=reviewed/jacktrip:1.0 "
            + "bash scripts/open-lola-jacktrip-docker-client.sh -s -B 4464",
        fixture.fakeBin.path,
        dockerLog.path
    )
    #expect(client.status == 0)
    let dockerArgs = try String(contentsOf: dockerLog, encoding: .utf8)
    #expect(dockerArgs.contains("reviewed/jacktrip:1.0"))
    #expect(dockerArgs.contains("-p 4464:4464/tcp"))
    #expect(dockerArgs.contains("-p 4464:4464/udp"))
    #expect(!dockerArgs.contains("--privileged"))
    #expect(!dockerArgs.contains("jacktrip/jacktrip:latest"))
}

private let jackTripDockerScripts = [
    "scripts/open-lola-jacktrip-docker-client.sh",
    "scripts/start-local-jacktrip-docker.sh",
    "scripts/compare-local-jacktrip-parity-docker.sh"
]

private func writeUltraGridRuntimeLog(
    in directory: URL,
    name: String,
    displayFps: Double
) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try """
    New incoming audio format detected: PCM 48000 Hz
    New incoming video format detected: RGB 640x360
    [Pbuf] [audio] 10/10 packets received (100.0%), 0 lost
    [Pbuf] [video] 10/10 packets received (100.0%), 0 lost
    Audio dec stats (cumulative): 480 played / 480 total audio frames
    Video dec stats (cumulative): 12 total / 12 disp / 0 drop / 0 corr / 0 miss
    [dummy] 10 frames in 1.0 seconds = \(displayFps) FPS

    """.write(to: url, atomically: true, encoding: .utf8)
    return url
}

var verificationToolingRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func verificationToolingReadText(_ relativePath: String) throws -> String {
    let url = verificationToolingRepositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

struct VerificationToolingShellResult {
    let status: Int32
    let output: String
}

func runVerificationToolingShell(
    _ command: String,
    _ arguments: String...
) throws -> VerificationToolingShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = verificationToolingRepositoryRoot
    process.arguments = ["-lc", command, "open-lola-test"] + arguments
    let result = try runTestProcessCapturingCombinedOutput(process)

    return VerificationToolingShellResult(
        status: result.status,
        output: result.output
    )
}
