// Builds fake CLI, Docker, and media-tool fixtures for deterministic parity-script tests.
import Foundation
import Testing

struct PairScriptFixture {
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

func makePairScriptFixture(
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

func writeExecutableScript(_ contents: String, to url: URL) throws {
    try contents.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private let fakeConnectorSessionRunShell = """
connector_command="${1:-}"
if [[ "$connector_command" == "external-connector-session-run" ]]; then
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
"""

func writeFakeJackTripOpenLola(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/bin/bash
        set -euo pipefail
        printf 'prefix=%s\\n' "${OPEN_LOLA_JACKTRIP_DOCKER_NAME_PREFIX:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        printf '%s\\n' "$*" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        \(fakeConnectorSessionRunShell)
        exit 0
        """,
        to: url
    )
}

func writeFakeJackTripDocker(to url: URL) throws {
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

func writeFakeUltraGridDockerOpenLola(to url: URL) throws {
    try writeExecutableScript(
        """
        #!/usr/bin/env bash
        set -euo pipefail
        printf 'prefix=%s\\n' "${OPEN_LOLA_ULTRAGRID_DOCKER_NAME_PREFIX:-}" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        printf '%s\\n' "$*" >>"$OPEN_LOLA_TEST_OPEN_LOLA_ARGS"
        \(fakeConnectorSessionRunShell)
        if [[ "$connector_command" == "external-connector-session-run" ]]; then
          sleep 0.2
        fi
        exit 0
        """,
        to: url
    )
}

func writeFakeUltraGridDocker(to url: URL) throws {
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

func writeFakeUltraGridNativeOpenLola(to url: URL, selectedExecutable: URL) throws {
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
      printf '%s%s\\n' \
        '{"verdict":"pass","probes":[{"detectedIdentity":"ultraGrid",' \
        '"executable":"__SELECTED_EXECUTABLE__","notes":"ok"}]}' \
        >"$output"
    else
      \(fakeConnectorSessionRunShell)
      if [[ "$connector_command" == "external-connector-session-run" ]]; then
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
    fi
    exit 0
    """.replacingOccurrences(of: "__SELECTED_EXECUTABLE__", with: selectedExecutable.path)
    try writeExecutableScript(script, to: url)
}

func writeFakeUltraGridStressBash(to url: URL) throws {
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

func loadJSON(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}
