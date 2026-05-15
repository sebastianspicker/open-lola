import Foundation
import Testing

@Test
func buildAndRunScriptSourcePolicyStagesBundleCLIPrivacyAndAdHocSignature() throws {
    let script = try readAppBundleScriptPolicyText("script/build_and_run.sh")
    let infoPlist = try readAppBundleScriptPolicyText("Sources/open-lola-app/Info.plist")

    #expect(script.contains("set -euo pipefail"))
    #expect(script.contains("build_product \"$PRODUCT_NAME\""))
    #expect(script.contains("build_product \"$CLI_PRODUCT_NAME\""))
    #expect(script.contains("product_build_bin_path"))
    #expect(script.contains("APP_BINARY=\"$APP_MACOS/$APP_NAME\""))
    #expect(script.contains("APP_UI_NAME=\"Open LoLa\""))
    #expect(infoPlist.contains("<key>CFBundleExecutable</key>"))
    #expect(infoPlist.contains("<string>OpenLoLa</string>"))
    #expect(script.contains("CLI_BINARY=\"$APP_MACOS/$CLI_PRODUCT_NAME\""))
    #expect(script.contains("NSCameraUsageDescription"))
    #expect(script.contains("NSMicrophoneUsageDescription"))
    #expect(script.contains("NSLocalNetworkUsageDescription"))
    #expect(script.contains("codesign --force --sign - --entitlements"))
    #expect(script.contains("OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR"))
    #expect(script.contains("capture_visible_window_evidence"))
    #expect(script.contains("window-list.txt"))
    #expect(script.contains("CGWindowListCopyWindowInfo"))
    #expect(script.contains("capture_app_ui_evidence"))
    #expect(script.contains("screencapture -x"))
    #expect(script.contains("/usr/bin/open -n -F \"$APP_BUNDLE\""))
    #expect(script.contains("require_ui_label"))
    #expect(script.contains("Packet Monitor"))
    #expect(script.contains("validate_mode"))
    #expect(script.contains("staged_app_pids"))
    #expect(script.contains("terminate_staged_app_processes"))
    #expect(script.contains("ps -p \"$pid\" -o command="))
    #expect(script.contains("case \"$command\" in"))
    #expect(script.contains("\"$APP_BINARY\"*"))
    #expect(script.contains("app_pid=\"$(staged_app_pids | head -n 1)\""))
    #expect(script.contains("printf '%s\\n' \"$app_pid\" >\"$evidence_dir/process.pid\""))
    #expect(!script.contains("pkill -u \"$USER\" -x \"$APP_NAME\""))
    #expect(!script.contains("pkill -u \"$USER\" -x \"$PRODUCT_NAME\""))
    #expect(!script.contains("pkill -x \"$APP_NAME\""))
    #expect(!script.contains("pkill -x \"$PRODUCT_NAME\""))
}

@Test
func cliAppBundleScriptSourcePolicyUsesProductScopedBuildPath() throws {
    let script = try readAppBundleScriptPolicyText("script/build_cli_app_bundle.sh")

    #expect(script.contains("set -euo pipefail"))
    #expect(script.contains("swift build --product \"$PRODUCT_NAME\""))
    #expect(script.contains("swift build --product \"$PRODUCT_NAME\" --show-bin-path"))
    #expect(!script.contains("swift build --show-bin-path"))
    #expect(script.contains("codesign --force --sign - \"$APP_BUNDLE\""))
}

private func readAppBundleScriptPolicyText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
