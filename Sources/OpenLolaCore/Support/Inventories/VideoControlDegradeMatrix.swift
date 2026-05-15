import Foundation

public enum VideoControlSurfaceKind: String, Codable, Equatable, Sendable {
    case videoCapture
    case videoTransport
    case videoRenderOutput
    case multiVideoStreams
    case atemReadOnlyControl
    case oscCueControl
    case lightingFixtureGate
    case integratedAv
    case integratedProfile
}

public enum VideoControlEvidenceBoundary: String, Codable, Equatable, Sendable {
    case genericCaptureOnly
    case frameDropDegradeFirst
    case outputHardwareEvidence
    case streamPriorityDrop
    case readOnlyControl
    case cueTimingNoAudioImpact
    case isolatedFixtureGate
    case audioMasterIntegratedAv
    case fastestAudioProfile
}

public struct VideoControlDegradeMatrixEntry: Codable, Equatable, Sendable {
    public let surface: VideoControlSurfaceKind
    public let primarySourceFile: String
    public let relatedSourceFiles: [String]
    public let relatedTestFiles: [String]
    public let relatedDocs: [String]
    public let relatedCommands: [String]
    public let evidenceBoundary: VideoControlEvidenceBoundary
    public let audioProtected: Bool
    public let degradeBeforeAudioLatencyRequired: Bool
    public let audioBaselineRequiredForPass: Bool
    public let passEvidenceRequired: Bool
    public let destructiveControlArmedByDefault: Bool
    public let notes: String

    public init(
        surface: VideoControlSurfaceKind,
        primarySourceFile: String,
        relatedSourceFiles: [String],
        relatedTestFiles: [String],
        relatedDocs: [String],
        relatedCommands: [String],
        evidenceBoundary: VideoControlEvidenceBoundary,
        audioProtected: Bool,
        degradeBeforeAudioLatencyRequired: Bool,
        audioBaselineRequiredForPass: Bool,
        passEvidenceRequired: Bool,
        destructiveControlArmedByDefault: Bool,
        notes: String
    ) {
        self.surface = surface
        self.primarySourceFile = primarySourceFile
        self.relatedSourceFiles = relatedSourceFiles
        self.relatedTestFiles = relatedTestFiles
        self.relatedDocs = relatedDocs
        self.relatedCommands = relatedCommands
        self.evidenceBoundary = evidenceBoundary
        self.audioProtected = audioProtected
        self.degradeBeforeAudioLatencyRequired = degradeBeforeAudioLatencyRequired
        self.audioBaselineRequiredForPass = audioBaselineRequiredForPass
        self.passEvidenceRequired = passEvidenceRequired
        self.destructiveControlArmedByDefault = destructiveControlArmedByDefault
        self.notes = notes
    }
}

public struct VideoControlDegradeMatrixSummary: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let commandBackedCount: Int
    public let audioProtectedCount: Int
    public let degradeBeforeAudioLatencyRequiredCount: Int
    public let audioBaselineRequiredForPassCount: Int
    public let passEvidenceRequiredCount: Int
    public let readOnlyControlCount: Int
    public let armedByDefaultCount: Int
}

public struct VideoControlDegradeMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: VideoControlDegradeMatrixSummary
    public let entries: [VideoControlDegradeMatrixEntry]
    public let notes: String
}

public enum VideoControlDegradeMatrix {
    public static func report() -> VideoControlDegradeMatrixReport {
        VideoControlDegradeMatrixReport(
            id: "c07-video-control-degrade-matrix",
            title: "C07 video and control degrade-first matrix",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable C07 crosswalk. It proves source ownership and validation boundaries; real Blackmagic, ATEM, lighting, route, and benchmark evidence are still required for release PASS."
        )
    }

    public static func summary() -> VideoControlDegradeMatrixSummary {
        VideoControlDegradeMatrixSummary(
            entryCount: entries.count,
            commandBackedCount: entries.filter { !$0.relatedCommands.isEmpty }.count,
            audioProtectedCount: entries.filter(\.audioProtected).count,
            degradeBeforeAudioLatencyRequiredCount: entries
                .filter(\.degradeBeforeAudioLatencyRequired)
                .count,
            audioBaselineRequiredForPassCount: entries
                .filter(\.audioBaselineRequiredForPass)
                .count,
            passEvidenceRequiredCount: entries.filter(\.passEvidenceRequired).count,
            readOnlyControlCount: entries.filter { $0.evidenceBoundary == .readOnlyControl }.count,
            armedByDefaultCount: entries.filter(\.destructiveControlArmedByDefault).count
        )
    }

    public static let entries: [VideoControlDegradeMatrixEntry] = [
        entry(
            .videoCapture,
            "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
            [
                "Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift",
                "Sources/OpenLolaCore/Video/VideoCaptureProbe.swift",
                "Sources/OpenLolaCore/Video/VideoCaptureRunner.swift",
            ],
            ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"],
            [
                "docs/architecture/blackmagic-video-rx-tx.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-video-capture-report",
                "video-capture-synthetic-smoke",
                "video-capture-run",
            ],
            .genericCaptureOnly,
            true,
            false,
            true,
            "AVFoundation capture can describe local capture only. PASS requires production Blackmagic evidence and unchanged audio callback/playout metrics."
        ),
        entry(
            .videoTransport,
            "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
            [
                "Sources/OpenLolaCore/Video/VideoTransportProbe.swift",
                "Sources/OpenLolaCore/Video/VideoTransportRunner.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Video/VideoTransportReassembly.swift",
            ],
            [
                "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift",
            ],
            [
                "docs/architecture/blackmagic-video-rx-tx.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-video-transport-report",
                "video-transport-synthetic-smoke",
                "video-transport-run",
            ],
            .frameDropDegradeFirst,
            true,
            true,
            true,
            "Socket-backed UDP raw-fragment runtime exists, including staged multi-stream test-pattern probes. PASS requires frame drop or video disable before audio target, route verdict, callback, playout, or underrun impact."
        ),
        entry(
            .videoRenderOutput,
            "Sources/OpenLolaCore/Video/VideoOutputRenderer.swift",
            [
                "Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift",
                "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
            ],
            [
                "Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift",
            ],
            [
                "docs/architecture/video-blackmagic-atem.md",
                "docs/mac-port/README.md",
            ],
            ["validate-video-transport-report"],
            .outputHardwareEvidence,
            true,
            true,
            true,
            "Rendered-output PASS is owned by VideoTransportReport and requires Blackmagic physical output evidence with no output drops."
        ),
        entry(
            .multiVideoStreams,
            "Sources/OpenLolaCore/Video/MultiVideoStreams.swift",
            [
                "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Protocol/SessionProtocol.swift",
            ],
            [
                "Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift",
                "Tests/OpenLolaCoreTests/MultiVideoStreamNegotiationTests.swift",
            ],
            [
                "docs/architecture/multiple-video-streams.md",
                "docs/mac-port/README.md",
            ],
            ["validate-video-transport-report"],
            .streamPriorityDrop,
            true,
            true,
            true,
            "Multi-video selection and staged transport must drop lower-priority video streams and protect audio priority before adding buffer or route pressure."
        ),
        entry(
            .atemReadOnlyControl,
            "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift",
            ["Sources/OpenLolaCore/Control/AtemReadOnlyControlValidation.swift"],
            ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"],
            [
                "docs/architecture/lighting-control.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-atem-control-report",
                "atem-readonly-probe",
            ],
            .readOnlyControl,
            true,
            false,
            false,
            "ATEM control defaults to disarmed read-only polling. PASS rejects armed commands and placeholder hardware fields."
        ),
        entry(
            .oscCueControl,
            "Sources/OpenLolaCore/Control/OscCueProbe.swift",
            ["Sources/OpenLolaCore/Control/OscCueRunners.swift"],
            ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"],
            [
                "docs/architecture/lighting-control.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-osc-cue-report",
                "osc-cue-synthetic-smoke",
                "osc-cue-run",
                "osc-cue-external-run",
            ],
            .cueTimingNoAudioImpact,
            true,
            false,
            true,
            "OSC cue PASS requires live loopback, first external peer evidence, stable playout target, no underruns, and no hidden audio impact."
        ),
        entry(
            .lightingFixtureGate,
            "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
            [
                "Sources/OpenLolaCore/Control/LightingFixtureGate.swift",
                "Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift",
            ],
            ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"],
            [
                "docs/architecture/lighting-control.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-lighting-gate-report",
                "lighting-gate-synthetic-smoke",
                "lighting-gate-run",
            ],
            .isolatedFixtureGate,
            true,
            false,
            true,
            "Lighting PASS requires an isolated allowed universe, packet capture, fixture owner match, and unchanged audio callback/playout metrics."
        ),
        entry(
            .integratedAv,
            "Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift",
            [
                "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift",
                "Sources/OpenLolaCore/Integration/IntegratedAvRun.swift",
                "Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift",
            ],
            [
                "Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift",
                "Tests/OpenLolaCoreTests/IntegratedAvDegradeFirstTests.swift",
            ],
            [
                "docs/architecture/av-sync-and-timing.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-integrated-av-report",
                "integrated-av-synthetic-smoke",
                "integrated-av-run",
            ],
            .audioMasterIntegratedAv,
            true,
            true,
            true,
            "Integrated AV can aggregate a measured video-transport report, but PASS still requires audio master clock, audio-only baseline first, video degrade-before-impact evidence, ATEM read-only polling, and stable route/audio metrics."
        ),
        entry(
            .integratedProfile,
            "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift",
            [
                "Sources/OpenLolaCore/Integration/IntegratedProfileTypes.swift",
                "Sources/OpenLolaCore/Integration/IntegratedProfileRun.swift",
                "Sources/OpenLolaCore/Integration/IntegratedProfileRuntimeEvidence.swift",
            ],
            [
                "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift",
                "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift",
            ],
            [
                "docs/architecture/latency-first-architecture.md",
                "docs/mac-port/README.md",
            ],
            [
                "validate-integrated-profile-report",
                "integrated-profile-synthetic-smoke",
                "integrated-profile-run",
            ],
            .fastestAudioProfile,
            true,
            true,
            true,
            "Integrated profile can aggregate measured runtime reports while keeping fastest-audio as default; PASS still requires physical subordinate evidence and video degradation before audio latency can increase."
        ),
    ]
}

private func entry(
    _ surface: VideoControlSurfaceKind,
    _ primarySourceFile: String,
    _ relatedSourceFiles: [String],
    _ relatedTestFiles: [String],
    _ relatedDocs: [String],
    _ relatedCommands: [String],
    _ evidenceBoundary: VideoControlEvidenceBoundary,
    _ audioProtected: Bool,
    _ degradeBeforeAudioLatencyRequired: Bool,
    _ audioBaselineRequiredForPass: Bool,
    _ notes: String
) -> VideoControlDegradeMatrixEntry {
    VideoControlDegradeMatrixEntry(
        surface: surface,
        primarySourceFile: primarySourceFile,
        relatedSourceFiles: relatedSourceFiles,
        relatedTestFiles: relatedTestFiles,
        relatedDocs: relatedDocs,
        relatedCommands: relatedCommands,
        evidenceBoundary: evidenceBoundary,
        audioProtected: audioProtected,
        degradeBeforeAudioLatencyRequired: degradeBeforeAudioLatencyRequired,
        audioBaselineRequiredForPass: audioBaselineRequiredForPass,
        passEvidenceRequired: true,
        destructiveControlArmedByDefault: false,
        notes: notes
    )
}
