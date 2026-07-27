// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import CryptoKit
import Foundation

func packagedPermissionEntitlementSurface() -> MacPackagedPermissionEntitlementSurface {
    MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: "OpenLoLa.app/Contents/Info.plist",
        entitlementsRelativePath: "OpenLoLa.app/Contents/Resources/open-lola-app.entitlements",
        microphoneUsageDescription: "Open LoLa captures selected audio inputs for explicit Mac-to-Mac audio tests.",
        cameraUsageDescription: "Open LoLa captures selected camera frames for explicit Mac-to-Mac video tests.",
        localNetworkUsageDescription: "Open LoLa sends and receives local UDP media between configured Mac peers.",
        networkClientEntitlementKey: "com.apple.security.network.client",
        appSandboxDecision: "App sandbox disabled for direct Core Audio, camera, "
            + "and UDP device access in field prototypes."
    )
}

struct PackagingArtifactInput {
    let kind: MacPackageArtifactKind
    let relativePath: String
    let required: Bool
    let sourcePath: String?
    let generatedData: Data?
}

func packagingArtifactInputs(
    surface: MacPackagedPermissionEntitlementSurface
) -> [PackagingArtifactInput] {
    appBundlePackagingInputs(surface: surface)
        + cliPackagingInputs()
        + supportPackagingInputs(surface: surface)
}

func appBundlePackagingInputs(
    surface: MacPackagedPermissionEntitlementSurface
) -> [PackagingArtifactInput] {
    [
        PackagingArtifactInput(
            kind: .appBundle,
            relativePath: surface.infoPlistRelativePath,
            required: true,
            sourcePath: "Sources/open-lola-app/Info.plist",
            generatedData: Data(packagedInfoPlist(surface).utf8)
        ),
        PackagingArtifactInput(
            kind: .appBundle,
            relativePath: "OpenLoLa.app/Contents/MacOS/open-lola-app",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola-app",
                ".build/debug/open-lola-app"
            ]),
            generatedData: nil
        )
    ]
}

func cliPackagingInputs() -> [PackagingArtifactInput] {
    [
        PackagingArtifactInput(
            kind: .commandLineTool,
            relativePath: "bin/open-lola",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola",
                ".build/debug/open-lola"
            ]),
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .commandLineTool,
            relativePath: "bin/open-lola-app",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola-app",
                ".build/debug/open-lola-app"
            ]),
            generatedData: nil
        )
    ]
}

func supportPackagingInputs(
    surface: MacPackagedPermissionEntitlementSurface
) -> [PackagingArtifactInput] {
    [
        PackagingArtifactInput(
            kind: .documentation,
            relativePath: "Documentation/README.md",
            required: true,
            sourcePath: "README.md",
            generatedData: Data("Open LoLa packaging README source was not reachable.\n".utf8)
        ),
        PackagingArtifactInput(
            kind: .entitlements,
            relativePath: surface.entitlementsRelativePath,
            required: true,
            sourcePath: "Sources/open-lola-app/open-lola-app.entitlements",
            generatedData: Data(packagedEntitlementsPlist(surface).utf8)
        ),
        PackagingArtifactInput(
            kind: .entitlements,
            relativePath: "Entitlements/open-lola.entitlements",
            required: true,
            sourcePath: "Sources/open-lola/open-lola.entitlements",
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .manifest,
            relativePath: "manifest.json",
            required: true,
            sourcePath: nil,
            generatedData: Data(packagedManifestJSON().utf8)
        ),
        PackagingArtifactInput(
            kind: .reportTemplate,
            relativePath: "ReportTemplates/field-report.md",
            required: true,
            sourcePath: nil,
            generatedData: Data(packagedFieldReportTemplate().utf8)
        )
    ]
}

func materializePackagingArtifact(
    _ input: PackagingArtifactInput,
    outputDirectory: URL
) throws -> MacPackageArtifact {
    let destination = outputDirectory.appendingPathComponent(input.relativePath)
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let data: Data
    if let sourcePath = input.sourcePath,
       FileManager.default.fileExists(atPath: sourcePath) {
        data = try BoundedFileReader.data(atPath: sourcePath)
    } else if let generatedData = input.generatedData {
        data = generatedData
    } else {
        data = Data("open-lola package artifact unavailable: \(input.relativePath)\n".utf8)
    }
    try data.write(to: destination)
    return MacPackageArtifact(
        kind: input.kind,
        relativePath: input.relativePath,
        required: input.required,
        sha256: packagingSHA256(data)
    )
}

func packagedInfoPlist(_ surface: MacPackagedPermissionEntitlementSurface) -> String {
    [
        #"<?xml version="1.0" encoding="UTF-8"?>"#,
        plistDoctypeLine(),
        #"<plist version="1.0">"#,
        "<dict>",
        "  <key>CFBundleIdentifier</key>",
        "  <string>de.hfmt.open-lola.app</string>",
        "  <key>NSCameraUsageDescription</key>",
        "  <string>\(surface.cameraUsageDescription)</string>",
        "  <key>NSLocalNetworkUsageDescription</key>",
        "  <string>\(surface.localNetworkUsageDescription)</string>",
        "  <key>NSMicrophoneUsageDescription</key>",
        "  <string>\(surface.microphoneUsageDescription)</string>",
        "</dict>",
        "</plist>"
    ].joined(separator: "\n") + "\n"
}

func packagedEntitlementsPlist(_ surface: MacPackagedPermissionEntitlementSurface) -> String {
    [
        #"<?xml version="1.0" encoding="UTF-8"?>"#,
        plistDoctypeLine(),
        #"<plist version="1.0">"#,
        "<dict>",
        "  <key>\(surface.networkClientEntitlementKey)</key>",
        "  <true/>",
        "</dict>",
        "</plist>"
    ].joined(separator: "\n") + "\n"
}

func plistDoctypeLine() -> String {
    #"<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "#
        + #""http://www.apple.com/DTDs/PropertyList-1.0.dtd">"#
}

func packagedManifestJSON() -> String {
    """
    {
      "product": "Open LoLa",
      "packageKind": "ad-hoc-local-field-prototype",
      "requiredArtifacts": [
        "OpenLoLa.app/Contents/Info.plist",
        "OpenLoLa.app/Contents/MacOS/open-lola-app",
        "OpenLoLa.app/Contents/Resources/open-lola-app.entitlements",
        "bin/open-lola",
        "bin/open-lola-app"
      ]
    }
    """
}

func packagedFieldReportTemplate() -> String {
    """
    # Open LoLa Field Report

    - Endpoint evidence:
    - Network evidence:
    - Audio evidence:
    - Video evidence:
    - Control evidence:
    - Recording evidence:
    - Packaging evidence:
    - VERDICT:
    """
}

func firstReachablePackagingSource(_ paths: [String]) -> String? {
    paths.first { FileManager.default.fileExists(atPath: $0) }
}

func packagingBuildTriple() -> String {
    #if arch(arm64)
    "arm64-apple-macosx"
    #elseif arch(x86_64)
    "x86_64-apple-macosx"
    #else
    "unknown-apple-macosx"
    #endif
}

func packagingSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
