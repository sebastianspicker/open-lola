// Verifies that build-and-run script stages app CLI permissions, signature, and debug launch.
import Foundation
import Testing

@Test
func appInfoPlistDeclaresOpenLoLaIconMetadata() throws {
    let infoPlistURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/open-lola-app/Info.plist")
    let data = try Data(contentsOf: infoPlistURL)
    let infoPlist = try #require(PropertyListSerialization.propertyList(
        from: data,
        format: nil
    ) as? [String: Any])

    #expect(infoPlist["CFBundleName"] as? String == "Open LoLa")
    #expect(infoPlist["CFBundleIconFile"] as? String == "OpenLoLa.icns")
}

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
    #expect(swiftLog.contains("build --disable-sandbox --product open-lola-app\n"))
    #expect(swiftLog.contains("build --disable-sandbox --product open-lola\n"))
    #expect(swiftLog.contains("build --disable-sandbox --product open-lola-app --show-bin-path\n"))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("OpenLoLa").path))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("open-lola").path))
    #expect(infoPlist["CFBundleExecutable"] as? String == "OpenLoLa")
    #expect(infoPlist["CFBundleInfoDictionaryVersion"] as? String == "6.0")
    #expect(infoPlist["CFBundleIconFile"] as? String == "OpenLoLa.icns")
    #expect(infoPlist["CFBundleName"] as? String == "Open LoLa")
    #expect(try Data(contentsOf: harness.stagedIcon) == Data(contentsOf: harness.iconSource))
    #expect(infoPlist["NSCameraUsageDescription"] is String)
    #expect(infoPlist["NSMicrophoneUsageDescription"] is String)
    #expect(infoPlist["NSLocalNetworkUsageDescription"] is String)
    #expect(codesignLog.contains("--sign - --entitlements"))
    #expect(codesignLog.contains("OpenLoLa.app"))
    #expect(lldbLog.contains("-- \(harness.appBinary("OpenLoLa").path)"))
    #expect(scriptText.contains("\"Refresh Local Media Inventory\""))
    #expect(scriptText.contains("\"Refresh Source/Synthetic Report\""))
    #expect(scriptText.contains("\"Evidence Summary\""))
    #expect(scriptText.contains("accessibility label capture failed; required UI labels were not verified"))
    #expect(scriptText.contains("tell application id \"$BUNDLE_ID\" to activate"))
    #expect(scriptText.contains("set frontmost to true"))
    #expect(scriptText.contains("missing accessibility app window (process="))
    #expect(scriptText.contains("displayedName="))
    #expect(scriptText.contains("bundleIdentifier="))
    #expect(scriptText.contains("frontmostBeforeActivation="))
    #expect(scriptText.contains("frontmostAfterActivation="))
    #expect(scriptText.contains("visible window evidence captured before accessibility failure:"))
    #expect(scriptText.contains("open.status.txt"))
    #expect(scriptText.contains("screencapture -x -l"))
    #expect(scriptText.contains("89504e470d0a1a0a"))
    #expect(!scriptText.contains(
        "accessibility label capture unavailable; visible-window and screenshot evidence captured"
    ))
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
    #expect(result.output.contains("accessibility capture stderr:"))
    #expect(result.output.contains("fake accessibility failure"))
    #expect(result.output.contains("visible window evidence captured before accessibility failure:"))
    #expect(result.output.contains("window_id=4242 pid=424242 owner=Open LoLa name=Open LoLa"))
    #expect(FileManager.default.fileExists(
        atPath: harness.launchEvidenceDirectory.appendingPathComponent("window-list.txt").path
    ))
    #expect(FileManager.default.fileExists(
        atPath: harness.launchEvidenceDirectory.appendingPathComponent("screenshot.png").path
    ))
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
    #expect(result.output.contains("window-scoped screenshot capture failed, was empty, or was not a PNG"))
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
    #expect(result.output.contains("window-scoped screenshot capture failed, was empty, or was not a PNG"))
    #expect(!result.output.contains("native app launch evidence:"))
}

@Test
func buildAndRunVerifyRejectsMissingRequiredLabel() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()

    let labelsMissingPackets = completeLaunchAccessibilityText()
        .replacingOccurrences(of: "Packets\n", with: "")
    let result = try harness.runVerify(osascriptOutput: labelsMissingPackets)

    #expect(result.status != 0)
    #expect(result.output.contains("missing launched app UI label in accessibility evidence: Packets"))
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
    #expect(try String(
        contentsOf: harness.launchEvidenceDirectory.appendingPathComponent("accessibility-ui.txt"),
        encoding: .utf8
    ).contains("Packets"))
    #expect(try Data(
        contentsOf: harness.launchEvidenceDirectory.appendingPathComponent("screenshot.png")
    ).isEmpty == false)
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
    #expect(swiftLog.contains("build --disable-sandbox --product open-lola\n"))
    #expect(swiftLog.contains("build --disable-sandbox --product open-lola --show-bin-path\n"))
    #expect(!swiftLog.contains("build --show-bin-path"))
    #expect(FileManager.default.fileExists(atPath: harness.appBinary("open-lola", bundleName: "OpenLoLaCLI").path))
    #expect(infoPlist["CFBundleExecutable"] as? String == "open-lola")
    #expect(infoPlist["CFBundleInfoDictionaryVersion"] as? String == "6.0")
    #expect(infoPlist["CFBundleName"] as? String == "OpenLoLaCLI")
    #expect(infoPlist["NSCameraUsageDescription"] is String)
    #expect(infoPlist["NSLocalNetworkUsageDescription"] is String)
    #expect(infoPlist["NSMicrophoneUsageDescription"] is String)
    #expect(codesignLog.contains("--sign -"))
    #expect(codesignLog.contains("OpenLoLaCLI.app"))
}
