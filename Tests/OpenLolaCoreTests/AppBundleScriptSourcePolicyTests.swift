import Foundation
import Testing

@Test
func buildAndRunScriptStagesAppCliPermissionsSignatureAndDebugLaunch() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let result = try harness.run("--debug")
    let swiftLog = try harness.swiftLog
    let infoPlist = try harness.infoPlist()
    let codesignLog = try harness.codesignLog
    let lldbLog = try harness.lldbLog
    let scriptText = try String(contentsOf: harness.script, encoding: .utf8)

    #expect(result.status == 0)
    #expect(swiftLog.contains("build --product open-lola-app\n"))
    #expect(swiftLog.contains("build --product open-lola\n"))
    #expect(swiftLog.contains("build --product open-lola-app --show-bin-path\n"))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("OpenLoLa").path))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("open-lola").path))
    #expect(infoPlist["CFBundleExecutable"] as? String == "OpenLoLa")
    #expect(infoPlist["CFBundleName"] as? String == "Open LoLa")
    #expect(infoPlist["NSCameraUsageDescription"] as? String != nil)
    #expect(infoPlist["NSMicrophoneUsageDescription"] as? String != nil)
    #expect(infoPlist["NSLocalNetworkUsageDescription"] as? String != nil)
    #expect(codesignLog.contains("--sign - --entitlements"))
    #expect(codesignLog.contains("OpenLoLa.app"))
    #expect(lldbLog.contains("-- \(harness.appBinary("OpenLoLa").path)"))
    #expect(scriptText.contains("require_any_ui_label"))
    #expect(scriptText.contains("\"Remote unavailable\""))
    #expect(scriptText.contains("\"LoLa not measured\""))
    #expect(scriptText.contains("accessibility label capture failed; required UI labels were not verified"))
    #expect(!scriptText.contains("accessibility label capture unavailable; visible-window and screenshot evidence captured"))
}

@Test
func buildAndRunVerifyRequiresAccessibilityLabelsEvenWithWindowAndScreenshot() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let result = try harness.runVerify(osascriptStatus: 1)

    #expect(result.status != 0)
    #expect(result.output.contains("accessibility label capture failed; required UI labels were not verified"))
    #expect(FileManager.default.fileExists(atPath: harness.launchEvidenceDirectory.appendingPathComponent("window-list.txt").path))
    #expect(FileManager.default.fileExists(atPath: harness.launchEvidenceDirectory.appendingPathComponent("screenshot.png").path))
    #expect(!result.output.contains("native app launch evidence:"))
}

@Test
func buildAndRunVerifyRejectsMissingScreenshot() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let result = try harness.runVerify(screenshotMode: "missing")

    #expect(result.status != 0)
    #expect(result.output.contains("screenshot capture failed or produced an empty artifact"))
    #expect(!FileManager.default.fileExists(atPath: harness.launchEvidenceDirectory.appendingPathComponent("accessibility-ui.txt").path))
    #expect(!result.output.contains("native app launch evidence:"))
}

@Test
func buildAndRunVerifyRejectsBlankScreenshot() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let result = try harness.runVerify(screenshotMode: "blank")

    #expect(result.status != 0)
    #expect(result.output.contains("screenshot capture failed or produced an empty artifact"))
    #expect(!result.output.contains("native app launch evidence:"))
}

@Test
func buildAndRunVerifyRejectsMissingRequiredLabel() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let labelsMissingPacketMonitor = completeLaunchAccessibilityText()
        .replacingOccurrences(of: "Packet Monitor\n", with: "")
    let result = try harness.runVerify(osascriptOutput: labelsMissingPacketMonitor)

    #expect(result.status != 0)
    #expect(result.output.contains("missing launched app UI label in accessibility evidence: Packet Monitor"))
    #expect(!result.output.contains("native app launch evidence:"))
}

@Test
func buildAndRunVerifyPassesWhenAllRequiredLabelsAndScreenshotAreCaptured() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let result = try harness.runVerify()

    #expect(result.status == 0)
    #expect(result.output.contains("native app launch evidence: \(harness.launchEvidenceDirectory.path)"))
    #expect(try String(contentsOf: harness.launchEvidenceDirectory.appendingPathComponent("accessibility-ui.txt"), encoding: .utf8).contains("Packet Monitor"))
    #expect(try Data(contentsOf: harness.launchEvidenceDirectory.appendingPathComponent("screenshot.png")).isEmpty == false)
}

@Test
func cliAppBundleScriptBuildsProductScopedBundle() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_cli_app_bundle.sh",
        products: ["open-lola"]
    )

    let result = try harness.run()
    let swiftLog = try harness.swiftLog
    let infoPlist = try harness.infoPlist(bundleName: "OpenLoLaCLI")
    let codesignLog = try harness.codesignLog

    #expect(result.status == 0)
    #expect(result.output.contains(harness.appBundle("OpenLoLaCLI").path))
    #expect(swiftLog.contains("build --product open-lola\n"))
    #expect(swiftLog.contains("build --product open-lola --show-bin-path\n"))
    #expect(!swiftLog.contains("build --show-bin-path"))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("open-lola", bundleName: "OpenLoLaCLI").path))
    #expect(infoPlist["CFBundleExecutable"] as? String == "open-lola")
    #expect(infoPlist["CFBundleName"] as? String == "OpenLoLaCLI")
    #expect(infoPlist["NSCameraUsageDescription"] as? String != nil)
    #expect(codesignLog.contains("--sign -"))
    #expect(codesignLog.contains("OpenLoLaCLI.app"))
}

private struct AppBundleScriptHarness {
    let root: URL
    let script: URL
    let fakeBuildDirectory: URL

    init(scriptName: String, products: [String]) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lola-app-bundle-script-\(UUID().uuidString)")
        script = root
            .appendingPathComponent("script", isDirectory: true)
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
                .appendingPathComponent("script", isDirectory: true)
                .appendingPathComponent(scriptName),
            to: script
        )
        try makeExecutable(script)
        try writeFakeTools(products: products)
    }

    func run(_ arguments: String...) throws -> ShellResult {
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
    ) throws -> ShellResult {
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
                "OPEN_LOLA_FAKE_WINDOW_OUTPUT": "pid=424242 owner=Open LoLa name=Open LoLa bounds={0,0,800,600}",
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
            "PATH": root.appendingPathComponent("bin").path + ":" + ProcessInfo.processInfo.environment["PATH", default: ""],
        ].merging(extra) { _, new in new }
    }

    private func patchCopiedScriptForFakeLaunchTools() throws {
        var text = try String(contentsOf: script, encoding: .utf8)
        let replacements = [
            "/usr/bin/open": fakeTool("open").path,
            "/usr/bin/log": fakeTool("log").path,
            "/usr/bin/osascript": fakeTool("osascript").path,
            "/usr/bin/swift": fakeTool("swift").path,
            "/usr/sbin/screencapture": fakeTool("screencapture").path,
        ]
        for (source, replacement) in replacements {
            text = text.replacingOccurrences(of: source, with: replacement)
        }
        try Data(text.utf8).write(to: script)
    }

    private func writeFakeTools(products: [String]) throws {
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutable(
            bin.appendingPathComponent("swift"),
            """
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
        )
        try writeExecutable(
            bin.appendingPathComponent("codesign"),
            """
            #!/usr/bin/env bash
            printf '%s\\n' "$*" >>"$OPEN_LOLA_FAKE_CODESIGN_LOG"
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("lldb"),
            """
            #!/usr/bin/env bash
            printf '%s\\n' "$*" >>"$OPEN_LOLA_FAKE_LLDB_LOG"
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("open"),
            """
            #!/usr/bin/env bash
            printf '%s\\n' "$*"
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("log"),
            """
            #!/usr/bin/env bash
            printf 'fake log\\n'
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("osascript"),
            """
            #!/usr/bin/env bash
            cat >/dev/null
            status="${OPEN_LOLA_FAKE_OSASCRIPT_STATUS:-0}"
            if [[ "$status" != "0" ]]; then
              printf '%s\\n' "${OPEN_LOLA_FAKE_OSASCRIPT_ERROR:-fake accessibility failure}" >&2
              exit "$status"
            fi
            printf '%s\\n' "${OPEN_LOLA_FAKE_OSASCRIPT_OUTPUT:-}"
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("screencapture"),
            """
            #!/usr/bin/env bash
            target="${@: -1}"
            case "${OPEN_LOLA_FAKE_SCREENSHOT_MODE:-content}" in
              content)
                printf 'fake screenshot\\n' >"$target"
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
                printf 'fake screenshot\\n' >"$target"
                ;;
            esac
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("ps"),
            """
            #!/usr/bin/env bash
            if [[ -n "${OPEN_LOLA_FAKE_APP_BINARY:-}" ]]; then
              printf '%s\\n' "$OPEN_LOLA_FAKE_APP_BINARY"
              exit 0
            fi
            /bin/ps "$@"
            """
        )
        try writeExecutable(
            bin.appendingPathComponent("pgrep"),
            """
            #!/usr/bin/env bash
            if [[ -n "${OPEN_LOLA_FAKE_APP_PID:-}" ]]; then
              printf '%s\\n' "$OPEN_LOLA_FAKE_APP_PID"
              exit 0
            fi
            exit 1
            """
        )
        for product in products {
            try Data().write(to: fakeBuildDirectory.appendingPathComponent(product))
        }
    }
}

private struct ShellResult {
    let status: Int32
    let output: String
}

private func runShell(
    _ script: String,
    _ arguments: [String] = [],
    environment: [String: String]
) throws -> ShellResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script] + arguments
    process.standardOutput = output
    process.standardError = output
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    try process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return ShellResult(
        status: process.terminationStatus,
        output: String(data: data, encoding: .utf8) ?? ""
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
    "Overview",
    "Session",
    "Streams",
    "Routing",
    "Devices",
    "Diagnostics",
    "Validation",
    "Packet Monitor",
    "Settings",
    "Refresh Synthetic Metrics",
    "Refresh Local Media Inventory",
    "Arm Execution",
    "Write Two-Peer Plan",
    "Dry Run Supervisor",
    "Set Handoff Intent",
    "Start Armed Supervisor",
    "Stop Supervisor Run",
    "Validate Supervisor Report",
    "Clear Command Intent",
    "Open Local Preview Window",
    "Operator Plan",
    "PARTIAL",
    "Idle.",
    "Setup required",
    "Packet monitor unavailable",
]

private func completeLaunchAccessibilityText() -> String {
    (["windows: Open LoLa", "menu:"] + requiredLaunchAccessibilityLabels + ["Remote unavailable"])
        .joined(separator: "\n")
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
