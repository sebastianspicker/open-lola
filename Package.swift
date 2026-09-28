// swift-tools-version: 6.0
// Declares OpenLola package products and target wiring, keeping build boundaries explicit for local and release builds.

import PackageDescription

#if os(Linux)
// The Swift package is macOS-only because OpenLolaCore links AppKit,
// AVFoundation, and CoreAudio. The Linux compatibility connector is packaged
// independently from the Windows and Linux runtime under runtimes/rust-station/.
#endif

func executableInfoPlistLinkerSettings(_ path: String) -> [LinkerSetting] {
    [
        .unsafeFlags([
            "-Xlinker", "-sectcreate",
            "-Xlinker", "__TEXT",
            "-Xlinker", "__info_plist",
            "-Xlinker", path
        ])
    ]
}

let package = Package(
    name: "open-lola",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenLolaCore",
            targets: ["OpenLolaCore", "COpenLolaAtomics"]
        ),
        .library(
            name: "OpenLolaContracts",
            targets: ["OpenLolaContracts"]
        ),
        .library(
            name: "OpenLolaAppSupport",
            targets: ["OpenLolaAppSupport"]
        ),
        .executable(
            name: "open-lola",
            targets: ["open-lola"]
        ),
        .executable(
            name: "open-lola-app",
            targets: ["open-lola-app"]
        )
    ],
    targets: [
        .target(
            name: "OpenLolaContracts",
            path: "runtimes/macos/Sources/OpenLolaContracts"
        ),
        .target(
            name: "OpenLolaCore",
            dependencies: ["OpenLolaApplication", "OpenLolaContracts", "OpenLolaSessionDomain", "OpenLolaTransport", "OpenLolaMediaPlatform", "OpenLolaEvidenceModels", "OpenLolaIntegrations"],
            path: "runtimes/macos/Sources/OpenLolaCore"
        ),
        .target(
            name: "OpenLolaSessionDomain",
            dependencies: ["OpenLolaContracts"],
            path: "runtimes/macos/Sources/OpenLolaSessionDomain"
        ),
        .target(
            name: "OpenLolaTransport",
            dependencies: ["OpenLolaContracts", "OpenLolaSessionDomain", "OpenLolaEvidenceModels"],
            path: "runtimes/macos/Sources/OpenLolaTransport"
        ),
        .target(
            name: "OpenLolaMediaPlatform",
            dependencies: [
                "OpenLolaContracts",
                "OpenLolaSessionDomain",
                "OpenLolaEvidenceModels",
                "OpenLolaTransport",
                "COpenLolaAtomics"
            ],
            path: "runtimes/macos/Sources/OpenLolaMediaPlatform"
        ),
        .target(
            name: "OpenLolaEvidenceModels",
            dependencies: ["OpenLolaContracts"],
            path: "runtimes/macos/Sources/OpenLolaEvidenceModels"
        ),
        // External-integration connectors and controls are deliberately downstream of the
        // reusable runtime and upstream of Application, keeping third-party protocol bridges
        // isolated from CLI/session policy while still reusable by it.
        .target(
            name: "OpenLolaIntegrations",
            dependencies: [
                "OpenLolaContracts",
                "OpenLolaSessionDomain",
                "OpenLolaEvidenceModels",
                "OpenLolaTransport",
                "OpenLolaMediaPlatform"
            ],
            path: "runtimes/macos/Sources/OpenLolaIntegrations",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        // Application policy is deliberately downstream of the reusable runtime.
        // Keeping this as a distinct module prevents Session from reaching up
        // into CLI defaults and makes executable policy an explicit dependency.
        .target(
            name: "OpenLolaApplication",
            dependencies: [
                "OpenLolaContracts",
                "OpenLolaSessionDomain",
                "OpenLolaTransport",
                "OpenLolaMediaPlatform",
                "OpenLolaEvidenceModels",
                "OpenLolaIntegrations",
                "COpenLolaAtomics"
            ],
            path: "runtimes/macos/Sources/OpenLolaApplication",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .target(
            name: "OpenLolaAppSupport",
            dependencies: ["OpenLolaCore", "COpenLolaAtomics"],
            path: "runtimes/macos/Sources/OpenLolaAppSupport"
        ),
        .target(
            name: "COpenLolaAtomics",
            path: "runtimes/macos/Sources/COpenLolaAtomics",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "open-lola",
            dependencies: ["OpenLolaCore", "OpenLolaApplication", "OpenLolaEvidenceModels"],
            path: "runtimes/macos/Sources/open-lola",
            exclude: ["Info.plist", "open-lola.entitlements"],
            linkerSettings: executableInfoPlistLinkerSettings("runtimes/macos/Sources/open-lola/Info.plist")
        ),
        .executableTarget(
            name: "open-lola-app",
            dependencies: ["OpenLolaAppSupport"],
            path: "runtimes/macos/Sources/open-lola-app",
            exclude: ["Info.plist", "open-lola-app.entitlements"],
            linkerSettings: executableInfoPlistLinkerSettings("runtimes/macos/Sources/open-lola-app/Info.plist")
        )
    ]
)
