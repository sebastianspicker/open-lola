import Foundation
import Testing

@Test
func releaseReadinessScriptDefinesLocalVerificationMatrix() throws {
    let script = try readText("scripts/verify-release-readiness.sh")

    #expect(script.contains("set -euo pipefail"))
    #expect(script.contains("bash scripts/verify-docs.sh"))
    #expect(script.contains("shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh"))
    #expect(script.contains("ruff check linux_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(script.contains("python -m pytest -p no:cacheprovider linux_connector"))
    #expect(script.contains("python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(script.contains("swift build"))
    #expect(script.contains("swift test"))
    #expect(script.contains("SWIFT_BUILD_TIMEOUT_SECONDS=\"${SWIFT_BUILD_TIMEOUT_SECONDS:-600}\""))
    #expect(script.contains("SWIFT_TEST_TIMEOUT_SECONDS=\"${SWIFT_TEST_TIMEOUT_SECONDS:-1800}\""))
    #expect(script.contains("run_timed_step \"$SWIFT_BUILD_TIMEOUT_SECONDS\" swift build"))
    #expect(script.contains("run_timed_step \"$SWIFT_TEST_TIMEOUT_SECONDS\" swift test --no-parallel"))
    #expect(script.contains("kill_process_tree"))
    #expect(script.contains(": >\"$log_file\" || fail \"timed step log file is not writable: $log_file\""))
    #expect(script.contains("[[ -w \"$log_file\" ]] || fail \"timed step log file is not writable: $log_file\""))
    #expect(script.contains("local cli_binary=\".build/debug/open-lola\""))
    #expect(script.contains("[[ -x \"$cli_binary\" ]] || fail \"binary not found at $cli_binary\""))
    #expect(script.contains("\"$cli_binary\" \"$command_name\" >\"$output_file\""))
    #expect(script.contains("run_cli_probe command-inventory PARTIAL"))
    #expect(script.contains("run_cli_probe source-ownership-inventory PARTIAL"))
    #expect(script.contains("run_cli_probe fixture-smoke-matrix PARTIAL"))
    #expect(script.contains("run_cli_probe report-schema-inventory PARTIAL"))
    #expect(script.contains("run_goal_report_probe()"))
    #expect(script.contains("\"$run_command\" --output \"$report_path\""))
    #expect(script.contains("goal-codewise-closure-run"))
    #expect(script.contains("validate-goal-codewise-closure-report"))
    #expect(script.contains("goal-runtime-evidence-template-run"))
    #expect(script.contains("validate-goal-runtime-evidence-template-report"))
    #expect(script.contains("goal-runtime-preflight-run"))
    #expect(script.contains("validate-goal-runtime-preflight-report"))
    #expect(script.contains("goal-completion-audit-run"))
    #expect(script.contains("validate-goal-completion-audit-report"))
    #expect(script.contains("run_open_source_release_readiness_probe"))
    #expect(script.contains("open-source-release-readiness-run --output"))
    #expect(script.contains("validate-open-source-release-readiness-report"))
    #expect(script.contains("blockers: 6"))
    #expect(script.contains("real-world-verdict: partial"))
    #expect(script.contains("run_cli_probe realtime-audio-path-inventory PARTIAL"))
    #expect(script.contains("run_cli_probe network-route-command-matrix PARTIAL"))
    #expect(script.contains("run_cli_probe video-control-degrade-matrix PARTIAL"))
    #expect(script.contains("run_cli_probe native-app-shell-surface-probe PARTIAL"))
    #expect(script.contains("source-gate-verdict: pass"))
    #expect(script.contains("product-runtime-verdict: partial"))
    #expect(script.contains("echo \"VERDICT: PARTIAL\""))
    #expect(!script.contains("echo \"VERDICT: PASS\""))
}

@Test
func releaseReadinessScriptKeepsReleaseBoundaryExplicit() throws {
    let script = try readText("scripts/verify-release-readiness.sh")

    for forbiddenPath in [".build/", "win-compiled/", "private/", "reverse-engineering/", "archive/"] {
        #expect(script.contains(forbiddenPath))
    }
    #expect(script.contains("manual_hardware_signing_gate"))
    #expect(script.contains("Developer ID, notarization, Gatekeeper, clean-Mac, hardware, benchmark"))
}

@Test
func ciWorkflowRunsSameReleaseReadinessScriptWithoutPublishingArtifacts() throws {
    let workflow = try readText(".github/workflows/release-readiness.yml")

    #expect(workflow.contains("bash scripts/verify-release-readiness.sh"))
    #expect(workflow.contains("actions/checkout"))
    #expect(workflow.contains("actions/setup-python"))
    #expect(workflow.contains("tomllib.load"))
    #expect(workflow.contains("[\"project\"][\"optional-dependencies\"][\"dev\"]"))
    #expect(workflow.contains("contents: read"))
    #expect(!workflow.contains("upload-artifact"))
    #expect(!workflow.contains("upload-pages-artifact"))
    #expect(!workflow.contains("gh release"))
    #expect(!workflow.contains("action-gh-release"))
}

@Test
func verificationMatrixDocumentPointsToLocalAndCIContracts() throws {
    let matrix = try readText("docs/testing/README.md")

    #expect(matrix.contains("bash scripts/verify-release-readiness.sh"))
    #expect(matrix.contains(".github/workflows/release-readiness.yml"))
    #expect(matrix.contains("ruff check linux_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(matrix.contains("python -m pytest -p no:cacheprovider linux_connector"))
    #expect(matrix.contains("python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py"))
    #expect(matrix.contains("shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh"))
    #expect(matrix.contains("manual"))
    #expect(matrix.contains("VERDICT: PARTIAL"))
}

@Test
func localUltraGridDockerProbeIsDocumentedAndScripted() throws {
    let scriptsReadme = try readText("scripts/README.md")
    let matrix = try readText("docs/testing/README.md")
    let serverScript = try readText("scripts/start-local-ultragrid-docker.sh")
    let clientScript = try readText("scripts/open-lola-ultragrid-docker-client.sh")
    let dockerfile = try readText("scripts/ultragrid-docker/Dockerfile")
    let linuxConnectorDockerfile = try readText("linux_connector/env/Dockerfile")
    let linuxConnectorCompose = try readText("linux_connector/env/compose.yaml")
    let linuxConnectorEnvReadme = try readText("linux_connector/env/README.md")

    #expect(scriptsReadme.contains("Local UltraGrid Docker helpers"))
    #expect(matrix.contains("Connector and Docker helper procedures live"))
    #expect(matrix.contains("../../scripts/README.md"))
    #expect(serverScript.contains("OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE"))
    #expect(serverScript.contains("open-lola-ultragrid-local"))
    #expect(clientScript.contains("OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE"))
    #expect(clientScript.contains("host.docker.internal:host-gateway"))
    #expect(dockerfile.contains("UltraGrid/archive/v${ULTRAGRID_VERSION}.tar.gz"))
    #expect(dockerfile.contains("ULTRAGRID_SOURCE_SHA256"))
    #expect(dockerfile.contains("sha256sum -c -"))
    #expect(dockerfile.contains("--enable-all=no"))
    #expect(dockerfile.contains("USER openlola"))
    #expect(linuxConnectorDockerfile.contains("python:3.12-slim@sha256:"))
    #expect(linuxConnectorDockerfile.contains("USER openlola"))
    #expect(linuxConnectorCompose.contains("profiles: [\"host-network-lab\"]"))
    #expect(linuxConnectorEnvReadme.contains("host-network-lab"))
}

@Test
func nativeAppBundleHelperLaneIsDocumented() throws {
    let scriptsReadme = try readText("scripts/README.md")
    let surface = try readText("Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift")
    let helper = try readText("script/build_and_run.sh")
    let readiness = try readText("scripts/verify-release-readiness.sh")

    #expect(scriptsReadme.contains("Native macOS app bundle helper"))
    #expect(scriptsReadme.contains("../script/build_and_run.sh"))
    #expect(surface.contains("./script/build_and_run.sh --verify"))
    #expect(helper.contains("set -euo pipefail"))
    #expect(helper.contains("OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR"))
    #expect(helper.contains("capture_app_ui_evidence"))
    #expect(helper.contains("screenshot.png"))
    #expect(readiness.contains("run_native_app_launch_probe"))
    #expect(readiness.contains("OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR"))
}

@Test
func localConnectorDockerRxTxProbesAreDocumentedAndScripted() throws {
    let scriptsReadme = try readText("scripts/README.md")
    let matrix = try readText("docs/testing/README.md")
    let runtime = try readText("Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift")
    let jackTripPair = try readText("scripts/run-local-jacktrip-rxtx-docker.sh")
    let ultraGridPair = try readText("scripts/run-local-ultragrid-rxtx-docker.sh")
    let ultraGridNativePair = try readText("scripts/run-local-ultragrid-rxtx-native.sh")
    let ultraGridNativeComparator = try readText("scripts/compare-local-ultragrid-parity-native.sh")
    let ultraGridParityMetricsWriter = try readText("scripts/lib/write-ultragrid-parity-metrics.py")
    let ultraGridNativeStress = try readText("scripts/stress-local-ultragrid-parity-native.sh")
    let ultraGridStress = try readText("scripts/stress-local-ultragrid-parity-docker.sh")
    let jackTripWrapper = try readText("scripts/open-lola-jacktrip-docker-client.sh")
    let ultraGridWrapper = try readText("scripts/open-lola-ultragrid-docker-client.sh")
    let ultraGridNativeWrapper = try readText("scripts/open-lola-ultragrid-native-client.sh")

    #expect(scriptsReadme.contains("Legacy paired Open LoLa RX/TX Docker probes"))
    #expect(scriptsReadme.contains("connector contract is explicit simultaneous `tx-rx`"))
    #expect(scriptsReadme.contains("ultragrid-parity-metrics.json"))
    #expect(scriptsReadme.contains("OPEN_LOLA_ULTRAGRID_MAX_MANAGED_CONNECTION_DELTA_MS"))
    #expect(scriptsReadme.contains("OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS"))
    #expect(scriptsReadme.contains("OPEN_LOLA_ULTRAGRID_MAX_MANAGED_DISPLAY_FPS_DELTA"))
    #expect(scriptsReadme.contains("OPEN_LOLA_ULTRAGRID_MANAGED_RX_DURATION_SECONDS"))
    #expect(scriptsReadme.contains("default is\n`250`"))
    #expect(scriptsReadme.contains("default is `0.5`"))
    #expect(scriptsReadme.contains("run-local-ultragrid-rxtx-native.sh"))
    #expect(scriptsReadme.contains("compare-local-ultragrid-parity-native.sh"))
    #expect(scriptsReadme.contains("stress-local-ultragrid-parity-native.sh"))
    #expect(scriptsReadme.contains("ultragrid-native-preflight.json"))
    #expect(scriptsReadme.contains("ultragrid-native-parity-metrics.json"))
    #expect(scriptsReadme.contains("ultragrid-native-parity-stability-summary.json"))
    #expect(scriptsReadme.contains("ultragrid-parity-stability-summary.json"))
    #expect(matrix.contains("Connector and Docker helper procedures live"))
    #expect(matrix.contains("paired with physical route and media measurements"))
    #expect(jackTripPair.contains("--role rx"))
    #expect(jackTripPair.contains("--role tx"))
    #expect(jackTripPair.contains("startup_seconds=\"${OPEN_LOLA_JACKTRIP_STARTUP_SECONDS:-4}\""))
    #expect(jackTripPair.contains("sleep \"$startup_seconds\""))
    #expect(!jackTripPair.contains("sleep 4"))
    #expect(ultraGridPair.contains("--role rx"))
    #expect(ultraGridPair.contains("--role tx"))
    #expect(ultraGridPair.contains("ultragrid-connection-metrics.json"))
    #expect(ultraGridPair.contains("wait_for_managed_connection"))
    #expect(ultraGridPair.contains("wait_for_managed_rx_ready"))
    #expect(ultraGridPair.contains("connection_poll_seconds"))
    #expect(ultraGridNativePair.contains("external-connector-executable-preflight-run"))
    #expect(ultraGridNativePair.contains("ultragrid-native-preflight.json"))
    #expect(ultraGridNativePair.contains("scripts/lib/extract-preflight-executable.py"))
    #expect(ultraGridNativePair.contains("scripts/lib/write-connection-metrics.py"))
    #expect(!ultraGridNativePair.contains("python3 - \"$preflight_report\""))
    #expect(!ultraGridNativePair.contains("python3 - \"$connection_metrics\""))
    #expect(ultraGridNativePair.contains("OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE"))
    #expect(ultraGridNativePair.contains("OPEN_LOLA_ULTRAGRID_NATIVE_LOG"))
    #expect(ultraGridNativePair.contains("exit 77"))
    #expect(ultraGridNativeComparator.contains("run-local-ultragrid-rxtx-native.sh"))
    #expect(ultraGridNativeComparator.contains("open-lola-ultragrid-native-parity-metrics-v1"))
    #expect(ultraGridNativeComparator.contains("scripts/lib/write-ultragrid-parity-metrics.py"))
    #expect(ultraGridParityMetricsWriter.contains("managedDisplayFpsWithinDelta"))
    #expect(ultraGridParityMetricsWriter.contains("endpointHealth"))
    #expect(ultraGridNativeComparator.contains("exit 77"))
    #expect(ultraGridNativeStress.contains("OPEN_LOLA_ULTRAGRID_PARITY_TRIALS"))
    #expect(ultraGridNativeStress.contains("ultragrid-native-parity-stability-summary.json"))
    #expect(ultraGridNativeStress.contains("\"hostReady\""))
    #expect(ultraGridNativeStress.contains("allDirectBaselinesClean"))
    #expect(ultraGridNativeStress.contains("sys.exit(77)"))
    let ultraGridComparator = try readText("scripts/compare-local-ultragrid-parity-docker.sh")
    #expect(ultraGridComparator.contains("scripts/lib/write-ultragrid-parity-metrics.py"))
    #expect(ultraGridParityMetricsWriter.contains("managedDisplayFpsWithinDelta"))
    #expect(ultraGridComparator.contains("max_managed_display_fps_delta"))
    #expect(ultraGridParityMetricsWriter.contains("\"min\": min(display_fps_values)"))
    #expect(ultraGridParityMetricsWriter.contains("float(metrics[\"displayFps\"][\"min\"])"))
    #expect(ultraGridParityMetricsWriter.contains("\"endpointHealth\""))
    #expect(ultraGridParityMetricsWriter.contains("directBaselineClean"))
    #expect(ultraGridComparator.contains("OPEN_LOLA_ULTRAGRID_MANAGED_RX_DURATION_SECONDS"))
    #expect(ultraGridStress.contains("OPEN_LOLA_ULTRAGRID_PARITY_TRIALS"))
    #expect(ultraGridStress.contains("allTrialsPassed"))
    #expect(ultraGridStress.contains("allDirectBaselinesClean"))
    #expect(ultraGridStress.contains("allManagedEndpointsClean"))
    #expect(jackTripWrapper.contains("-p \"$audio_port:$audio_port/udp\""))
    #expect(runtime.contains("OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE"))
    #expect(runtime.contains("invocation.role.rawValue"))
    #expect(ultraGridWrapper.contains("OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE"))
    #expect(ultraGridWrapper.contains("--server"))
    #expect(ultraGridWrapper.contains("--client"))
    #expect(ultraGridNativeWrapper.contains("OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE"))
    #expect(ultraGridNativeWrapper.contains("Refusing to launch Python uv"))
    #expect(ultraGridNativeWrapper.contains("--server"))
    #expect(ultraGridNativeWrapper.contains("--client"))
}

@Test
func jackTripDockerHelpersRejectMutablePrivilegedDefaults() throws {
    let scriptsReadme = try readText("scripts/README.md")
    let policy = try readText("scripts/open-lola-jacktrip-docker-policy.sh")
    let client = try readText("scripts/open-lola-jacktrip-docker-client.sh")
    let server = try readText("scripts/start-local-jacktrip-docker.sh")
    let comparator = try readText("scripts/compare-local-jacktrip-parity-docker.sh")

    #expect(policy.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE must be set"))
    #expect(policy.contains("must not use the mutable latest tag"))
    #expect(client.contains("open_lola_required_jacktrip_docker_image"))
    #expect(server.contains("open_lola_required_jacktrip_docker_image"))
    #expect(comparator.contains("open_lola_required_jacktrip_docker_image"))
    #expect(!client.contains("jacktrip/jacktrip:latest"))
    #expect(!server.contains("jacktrip/jacktrip:latest"))
    #expect(!comparator.contains("jacktrip/jacktrip:latest"))
    #expect(!client.contains("--privileged"))
    #expect(!server.contains("--privileged"))
    #expect(!comparator.contains("--privileged"))
    #expect(scriptsReadme.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE"))
    #expect(!scriptsReadme.contains("jacktrip/jacktrip:latest"))
}

@Test
func parityJackTripDelayParserRejectsMalformedTimestamps() throws {
    let parity = try readText("scripts/lib/parity.sh")

    #expect(parity.contains("function timestamp_seconds(raw, parts)"))
    #expect(parity.contains("raw !~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\\.[0-9]+)?$/"))
    #expect(parity.contains("parts[1] > 23 || parts[2] > 59 || parts[3] > 59"))
    #expect(parity.contains("start == \"\" || stop == \"\" || start < 0 || stop < 0"))
    #expect(!parity.contains("split($3, timestamp, \":\")"))
}

@Test
func wslLoLaNetworkHelperUsesStrictDryRunAndScopedFirewallControls() throws {
    let script = try readText("linux_connector/env/enable_wsl_lola_network.ps1")

    #expect(script.contains("[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = \"High\")]"))
    #expect(script.contains("Set-StrictMode -Version Latest"))
    #expect(script.contains("$ErrorActionPreference = \"Stop\""))
    #expect(script.contains("Merge-WslConfigText"))
    #expect(script.contains("Backup-WslConfig"))
    #expect(script.contains("$PSCmdlet.ShouldProcess"))
    #expect(script.contains("-Profile $Profile"))
    #expect(script.contains("-InterfaceAlias $Alias"))
    #expect(script.contains("-LocalPort $Ports"))
    #expect(script.contains("-LocalPorts $PortString"))
    #expect(script.contains("[switch]$SkipWslShutdown"))
    #expect(script.contains("wsl --shutdown"))
    #expect(!script.contains("$ErrorActionPreference = \"Continue\""))
    #expect(!script.contains("-Profile Any"))
    #expect(!script.contains("-RemoteAddresses Any"))
    #expect(!script.contains("-LocalAddresses Any"))
    #expect(!script.contains("-DefaultInboundAction Allow"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}
