// Verifies that build-and-run script stages app CLI permissions, signature, and debug launch.
import Darwin
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
func appExecutableWiresItsDelegateIntoTheOperatorScene() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let entryPoint = try String(
        contentsOf: root.appendingPathComponent("Sources/open-lola-app-main/OpenLolaAppMain.swift"),
        encoding: .utf8
    )

    #expect(entryPoint.contains(
        "@NSApplicationDelegateAdaptor(OpenLolaApplicationDelegate.self) private var appDelegate"
    ))
    #expect(entryPoint.contains("OpenLolaAppScene(appDelegate: appDelegate)"))
    #expect(!entryPoint.contains("OpenLolaAppScene()"))
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
func buildAndRunVerifyStagesOnlyInAnExplicitExternalDirectory() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    try harness.writeEntitlements()
    let requestedExternalDist = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-external-dist-\(UUID().uuidString)", isDirectory: true)
    let requestedExternalBuild = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-external-build-\(UUID().uuidString)", isDirectory: true)
    let externalDist = try canonicalExternalTestDirectory(requestedExternalDist)
    let externalBuild = try canonicalExternalTestDirectory(requestedExternalBuild)
    let externalAppBinary = externalDist
        .appendingPathComponent("OpenLoLa.app/Contents/MacOS/OpenLoLa")

    let result = try harness.runVerify(environment: [
        "OPEN_LOLA_APP_DIST_DIR": requestedExternalDist.path,
        "OPEN_LOLA_SWIFT_BUILD_PATH": requestedExternalBuild.path,
        "OPEN_LOLA_FAKE_APP_BINARY": externalAppBinary.path
    ])
    let swiftLog = try harness.swiftLog

    #expect(result.status == 0)
    #expect(FileManager.default.fileExists(atPath: externalAppBinary.path))
    #expect(!FileManager.default.fileExists(atPath: harness.appBundle("OpenLoLa").path))
    #expect(result.output.contains("native app launch evidence: \(externalDist.path)/app-launch-evidence"))
    #expect(swiftLog.contains(
        "build --disable-sandbox --scratch-path \(externalBuild.path) --product open-lola-app"
    ))
}

private func canonicalExternalTestDirectory(_ requestedDirectory: URL) throws -> URL {
    let parentPath = requestedDirectory.deletingLastPathComponent().path
    var resolvedPath = [CChar](repeating: 0, count: Int(PATH_MAX))
    guard realpath(parentPath, &resolvedPath) != nil else {
        throw CocoaError(.fileNoSuchFile)
    }
    let resolvedBytes = resolvedPath.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return URL(fileURLWithPath: String(decoding: resolvedBytes, as: UTF8.self), isDirectory: true)
        .appendingPathComponent(requestedDirectory.lastPathComponent, isDirectory: true)
}

@Test(arguments: ["relative-dist", "dist/../external-dist"])
func buildAndRunRejectsNonAbsoluteExternalStagingDirectories(_ directory: String) throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_DIST_DIR": directory
    ])

    #expect(result.status == 2)
    #expect(result.output.contains("OPEN_LOLA_APP_DIST_DIR must be an absolute directory outside the repository"))
}

@Test
func buildAndRunRejectsRepositoryExternalStagingDirectory() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_DIST_DIR": harness.root.appendingPathComponent("external-dist").path
    ])

    #expect(result.status == 2)
    #expect(result.output.contains("OPEN_LOLA_APP_DIST_DIR must be outside the repository"))
}

@Test
func buildAndRunRejectsExternalStagingSymlinkIntoTheRepository() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    let externalLink = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-external-dist-link-\(UUID().uuidString)")
    try FileManager.default.createSymbolicLink(
        at: externalLink,
        withDestinationURL: harness.root.appendingPathComponent("dist")
    )

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_DIST_DIR": externalLink.path
    ])

    #expect(result.status == 2)
    #expect(result.output.contains("OPEN_LOLA_APP_DIST_DIR must reference a directory that is not a symlink"))
}

@Test
func buildAndRunRejectsRepositoryEvidenceDirectoryBeforeMutation() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    let evidenceDirectory = harness.root.appendingPathComponent("evidence")
    let sentinel = evidenceDirectory.appendingPathComponent("sentinel.txt")
    try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
    try Data("keep".utf8).write(to: sentinel)

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR": evidenceDirectory.path
    ])
    let swiftLog = try harness.swiftLog

    #expect(result.status == 2)
    #expect(result.output.contains("OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR must be outside the repository"))
    #expect(FileManager.default.fileExists(atPath: sentinel.path))
    #expect(swiftLog.isEmpty)
}

@Test
func buildAndRunRejectsSymlinkEvidenceDirectoryBeforeMutation() throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    let evidenceDirectory = harness.root.appendingPathComponent("evidence")
    let sentinel = evidenceDirectory.appendingPathComponent("sentinel.txt")
    try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
    try Data("keep".utf8).write(to: sentinel)
    let evidenceLink = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-evidence-link-\(UUID().uuidString)")
    try FileManager.default.createSymbolicLink(at: evidenceLink, withDestinationURL: evidenceDirectory)

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR": evidenceLink.path
    ])
    let swiftLog = try harness.swiftLog

    #expect(result.status == 2)
    #expect(result.output.contains(
        "OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR must reference a directory that is not a symlink"
    ))
    #expect(FileManager.default.fileExists(atPath: sentinel.path))
    #expect(swiftLog.isEmpty)
}

@Test(arguments: ["\n", "\u{0001}"])
func buildAndRunRejectsControlCharactersInEvidenceDirectory(_ suffix: String) throws {
    let harness = try AppBundleScriptHarness(
        scriptName: "build_and_run.sh",
        products: ["open-lola-app", "open-lola"]
    )
    let requestedDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-evidence-\(UUID().uuidString)")

    let result = try harness.run("--debug", environment: [
        "OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR": requestedDirectory.path + suffix
    ])
    let swiftLog = try harness.swiftLog

    #expect(result.status == 2)
    #expect(result.output.contains("OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR must not contain control characters"))
    #expect(swiftLog.isEmpty)
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
