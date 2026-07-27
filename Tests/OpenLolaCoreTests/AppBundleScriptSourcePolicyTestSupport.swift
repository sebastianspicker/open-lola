// Shared App bundle script source policy helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

private let fakeSwiftToolScript = """
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-" ]]; then
  cat >/dev/null
  printf '%s\\n' "${OPEN_LOLA_FAKE_WINDOW_OUTPUT:-pid=424242 owner=Open LoLa name=Open LoLa bounds={0,0,800,600}}"
  exit "${OPEN_LOLA_FAKE_WINDOW_STATUS:-0}"
fi
printf '%s\\n' "$*" >>"$OPEN_LOLA_FAKE_SWIFT_LOG"
product=""
args=("$@")
for ((index = 0; index < $#; index++)); do
  if [[ "${args[$index]}" == "--product" ]]; then
    product="${args[$((index + 1))]}"
  fi
done
mkdir -p "$OPEN_LOLA_FAKE_BUILD_DIR"
if [[ "$*" == *"--show-bin-path"* ]]; then
  printf '%s\\n' "$OPEN_LOLA_FAKE_BUILD_DIR"
  exit 0
fi
printf '#!/usr/bin/env sh\\nexit 0\\n' >"$OPEN_LOLA_FAKE_BUILD_DIR/$product"
chmod +x "$OPEN_LOLA_FAKE_BUILD_DIR/$product"
"""

private let fakeCodesignToolScript = """
#!/usr/bin/env bash
printf '%s\\n' "$*" >>"$OPEN_LOLA_FAKE_CODESIGN_LOG"
"""

private let fakeLldbToolScript = """
#!/usr/bin/env bash
printf '%s\\n' "$*" >>"$OPEN_LOLA_FAKE_LLDB_LOG"
"""

private let fakeOpenToolScript = """
#!/usr/bin/env bash
printf '%s\\n' "$*"
"""

private let fakeLogToolScript = """
#!/usr/bin/env bash
printf 'fake log\\n'
"""

private let fakeOsascriptToolScript = """
#!/usr/bin/env bash
cat >/dev/null
status="${OPEN_LOLA_FAKE_OSASCRIPT_STATUS:-0}"
if [[ "$status" != "0" ]]; then
  printf '%s\\n' "${OPEN_LOLA_FAKE_OSASCRIPT_ERROR:-fake accessibility failure}" >&2
  exit "$status"
fi
printf '%s\\n' "${OPEN_LOLA_FAKE_OSASCRIPT_OUTPUT:-}"
"""

private let fakeScreencaptureToolScript = """
#!/usr/bin/env bash
target="${@: -1}"
case "${OPEN_LOLA_FAKE_SCREENSHOT_MODE:-content}" in
  content)
    printf '\\211PNG\\r\\n\\032\\nfake screenshot\\n' >"$target"
    ;;
  blank)
    : >"$target"
    ;;
  missing)
    ;;
  fail)
    exit 1
    ;;
  *)
    printf '\\211PNG\\r\\n\\032\\nfake screenshot\\n' >"$target"
    ;;
esac
"""

private let fakePsToolScript = """
#!/usr/bin/env bash
if [[ -n "${OPEN_LOLA_FAKE_APP_BINARY:-}" ]]; then
  printf '%s\\n' "$OPEN_LOLA_FAKE_APP_BINARY"
  exit 0
fi
/bin/ps "$@"
"""

private let fakePgrepToolScript = """
#!/usr/bin/env bash
if [[ -n "${OPEN_LOLA_FAKE_APP_PID:-}" ]]; then
  printf '%s\\n' "$OPEN_LOLA_FAKE_APP_PID"
  exit 0
fi
exit 1
"""

struct AppBundleScriptHarness {
    let root: URL
    let script: URL
    let fakeBuildDirectory: URL

    init(scriptName: String, products: [String]) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lola-app-bundle-script-\(UUID().uuidString)")
        script = root
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("macos", isDirectory: true)
            .appendingPathComponent(scriptName)
        fakeBuildDirectory = root.appendingPathComponent("fake-build", isDirectory: true)

        try FileManager.default.createDirectory(
            at: script.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fakeBuildDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: repositoryRoot
                .appendingPathComponent("scripts", isDirectory: true)
                .appendingPathComponent("macos", isDirectory: true)
                .appendingPathComponent(scriptName),
            to: script
        )
        try makeExecutable(script)
        try writeFakeTools(products: products)
        try writeIcon()
    }

    func run(_ arguments: String...) throws -> AppBundleShellResult {
        try runShell(
            script.path,
            arguments,
            environment: runEnvironment()
        )
    }

    func runVerify(
        osascriptStatus: Int32 = 0,
        osascriptOutput: String = completeLaunchAccessibilityText(),
        screenshotMode: String = "content"
    ) throws -> AppBundleShellResult {
        try patchCopiedScriptForFakeLaunchTools()
        return try runShell(
            script.path,
            ["--verify"],
            environment: runEnvironment([
                "OPEN_LOLA_FAKE_APP_BINARY": appBinary("OpenLoLa").path,
                "OPEN_LOLA_FAKE_APP_PID": "424242",
                "OPEN_LOLA_FAKE_OSASCRIPT_STATUS": "\(osascriptStatus)",
                "OPEN_LOLA_FAKE_OSASCRIPT_OUTPUT": osascriptOutput,
                "OPEN_LOLA_FAKE_SCREENSHOT_MODE": screenshotMode,
                "OPEN_LOLA_FAKE_WINDOW_OUTPUT": "window_id=4242 pid=424242 owner=Open LoLa name=Open LoLa bounds={0,0,800,600}"
            ])
        )
    }

    func writeEntitlements() throws {
        let entitlements = root
            .appendingPathComponent("Sources/open-lola-app", isDirectory: true)
            .appendingPathComponent("open-lola-app.entitlements")
        try FileManager.default.createDirectory(
            at: entitlements.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict></dict></plist>
        """.utf8).write(to: entitlements)
    }

    func appBundle(_ bundleName: String) -> URL {
        root.appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("\(bundleName).app", isDirectory: true)
    }

    func appBinary(_ binaryName: String, bundleName: String = "OpenLoLa") -> URL {
        appBundle(bundleName)
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(binaryName)
    }

    var iconSource: URL {
        root.appendingPathComponent(".github/assets/OpenLoLa.icns")
    }

    var stagedIcon: URL {
        appBundle("OpenLoLa")
            .appendingPathComponent("Contents/Resources/OpenLoLa.icns")
    }

    var launchEvidenceDirectory: URL {
        root.appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("app-launch-evidence", isDirectory: true)
    }

    func infoPlist() throws -> [String: Any] {
        try infoPlist(bundleName: "OpenLoLa")
    }

    func infoPlist(bundleName: String) throws -> [String: Any] {
        let data = try Data(contentsOf: appBundle(bundleName)
            .appendingPathComponent("Contents/Info.plist"))
        return try #require(PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any])
    }

    var swiftLog: String {
        get throws { try readLog(swiftLogURL) }
    }

    var codesignLog: String {
        get throws { try readLog(codesignLogURL) }
    }

    var lldbLog: String {
        get throws { try readLog(lldbLogURL) }
    }

    private var swiftLogURL: URL { root.appendingPathComponent("swift.log") }
    private var codesignLogURL: URL { root.appendingPathComponent("codesign.log") }
    private var lldbLogURL: URL { root.appendingPathComponent("lldb.log") }

    private func fakeTool(_ name: String) -> URL {
        root.appendingPathComponent("bin", isDirectory: true).appendingPathComponent(name)
    }

    private func runEnvironment(_ extra: [String: String] = [:]) -> [String: String] {
        [
            "OPEN_LOLA_FAKE_BUILD_DIR": fakeBuildDirectory.path,
            "OPEN_LOLA_FAKE_SWIFT_LOG": swiftLogURL.path,
            "OPEN_LOLA_FAKE_CODESIGN_LOG": codesignLogURL.path,
            "OPEN_LOLA_FAKE_LLDB_LOG": lldbLogURL.path,
            "PATH": root.appendingPathComponent("bin").path
                + ":"
                + ProcessInfo.processInfo.environment["PATH", default: ""]
        ].merging(extra) { _, new in new }
    }

    private func patchCopiedScriptForFakeLaunchTools() throws {
        var text = try String(contentsOf: script, encoding: .utf8)
        let replacements = [
            "/usr/bin/open": fakeTool("open").path,
            "/usr/bin/log": fakeTool("log").path,
            "/usr/bin/osascript": fakeTool("osascript").path,
            "/usr/bin/swift": fakeTool("swift").path,
            "/usr/sbin/screencapture": fakeTool("screencapture").path
        ]
        for (source, replacement) in replacements {
            text = text.replacingOccurrences(of: source, with: replacement)
        }
        try Data(text.utf8).write(to: script)
    }

    private func writeFakeTools(products: [String]) throws {
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutable(bin.appendingPathComponent("swift"), fakeSwiftToolScript)
        try writeExecutable(bin.appendingPathComponent("codesign"), fakeCodesignToolScript)
        try writeExecutable(bin.appendingPathComponent("lldb"), fakeLldbToolScript)
        try writeExecutable(bin.appendingPathComponent("open"), fakeOpenToolScript)
        try writeExecutable(bin.appendingPathComponent("log"), fakeLogToolScript)
        try writeExecutable(bin.appendingPathComponent("osascript"), fakeOsascriptToolScript)
        try writeExecutable(bin.appendingPathComponent("screencapture"), fakeScreencaptureToolScript)
        try writeExecutable(bin.appendingPathComponent("ps"), fakePsToolScript)
        try writeExecutable(bin.appendingPathComponent("pgrep"), fakePgrepToolScript)
        for product in products {
            try Data().write(to: fakeBuildDirectory.appendingPathComponent(product))
        }
    }

    private func writeIcon() throws {
        try FileManager.default.createDirectory(
            at: iconSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("open-lola-test-icon".utf8).write(to: iconSource)
    }
}

struct AppBundleShellResult {
    let status: Int32
    let output: String
}

private func runShell(
    _ script: String,
    _ arguments: [String] = [],
    environment: [String: String]
) throws -> AppBundleShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script] + arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    let result = try runTestProcessCapturingCombinedOutput(process)
    return AppBundleShellResult(
        status: result.status,
        output: result.output
    )
}

private func writeExecutable(_ url: URL, _ text: String) throws {
    try Data(text.utf8).write(to: url)
    try makeExecutable(url)
}

private func makeExecutable(_ url: URL) throws {
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: url.path
    )
}

private func readLog(_ url: URL) throws -> String {
    guard FileManager.default.fileExists(atPath: url.path) else {
        return ""
    }
    return try String(contentsOf: url, encoding: .utf8)
}

private let requiredLaunchAccessibilityLabels = [
    "Session",
    "Connection",
    "Routing",
    "Media",
    "Packets",
    "Review",
    "Diagnostics",
    "Settings",
    "Refresh Local Media Inventory",
    "Refresh Source/Synthetic Report",
    "Arm Execution",
    "Dry Run Supervisor",
    "Start Armed Supervisor",
    "Stop Supervisor Run",
    "Validate Supervisor Report",
    "Evidence Summary",
    "Packet evidence",
    "Not measured"
]

func completeLaunchAccessibilityText() -> String {
    (["windows: Open LoLa", "menu:"] + requiredLaunchAccessibilityLabels)
        .joined(separator: "\n")
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
