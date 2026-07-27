// Collects control-plane evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation
/// Defines the finite classification values recorded by video/control degradation matrix artifacts for deterministic validation and report interpretation.
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
/// Defines the finite evidence provenance values recorded by video/control degradation matrix artifacts for deterministic validation and report interpretation.
public enum VideoControlEvidenceBoundary: String, Codable, Equatable, Sendable {
    case genericCaptureOnly
    case frameDropDegradeFirst
    case outputHardwareEvidence
    case streamPriorityDrop
    case readOnlyControl
    case cueTimingNoAudioImpact
    case isolatedFixtureGate
    // swiftlint:disable:next inclusive_language
    case audioMasterIntegratedAv
    case fastestAudioProfile
}
/// Captures inventory entry required to validate, interpret, and reproduce a video/control degradation matrix result.
public struct VideoControlDegradeMatrixEntry: Codable, Equatable, Sendable {
    public struct Surface: Equatable, Sendable {
        public var kind: VideoControlSurfaceKind
        public var primarySourceFile: String
        public var evidenceBoundary: VideoControlEvidenceBoundary

        public init(
            kind: VideoControlSurfaceKind,
            primarySourceFile: String,
            evidenceBoundary: VideoControlEvidenceBoundary
        ) {
            self.kind = kind
            self.primarySourceFile = primarySourceFile
            self.evidenceBoundary = evidenceBoundary
        }
    }

    public struct References: Equatable, Sendable {
        public var sourceFiles: [String]
        public var testFiles: [String]
        public var docs: [String]
        public var commands: [String]

        public init(
            sourceFiles: [String],
            testFiles: [String],
            docs: [String],
            commands: [String]
        ) {
            self.sourceFiles = sourceFiles
            self.testFiles = testFiles
            self.docs = docs
            self.commands = commands
        }
    }

    public struct Protections: Equatable, Sendable {
        public var audioProtected: Bool
        public var degradeBeforeAudioLatencyRequired: Bool
        public var audioBaselineRequiredForPass: Bool
        public var passEvidenceRequired: Bool
        public var destructiveControlArmedByDefault: Bool

        public init(
            audioProtected: Bool,
            degradeBeforeAudioLatencyRequired: Bool,
            audioBaselineRequiredForPass: Bool,
            passEvidenceRequired: Bool,
            destructiveControlArmedByDefault: Bool
        ) {
            self.audioProtected = audioProtected
            self.degradeBeforeAudioLatencyRequired = degradeBeforeAudioLatencyRequired
            self.audioBaselineRequiredForPass = audioBaselineRequiredForPass
            self.passEvidenceRequired = passEvidenceRequired
            self.destructiveControlArmedByDefault = destructiveControlArmedByDefault
        }
    }

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
        surface: Surface,
        references: References,
        protections: Protections,
        notes: String
    ) {
        self.surface = surface.kind
        primarySourceFile = surface.primarySourceFile
        evidenceBoundary = surface.evidenceBoundary
        relatedSourceFiles = references.sourceFiles
        relatedTestFiles = references.testFiles
        relatedDocs = references.docs
        relatedCommands = references.commands
        audioProtected = protections.audioProtected
        degradeBeforeAudioLatencyRequired = protections.degradeBeforeAudioLatencyRequired
        audioBaselineRequiredForPass = protections.audioBaselineRequiredForPass
        passEvidenceRequired = protections.passEvidenceRequired
        destructiveControlArmedByDefault = protections.destructiveControlArmedByDefault
        self.notes = notes
    }
}
/// Captures summary statistics required to validate, interpret, and reproduce a video/control degradation matrix result.
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

/// Captures report contents required to validate, interpret, and reproduce a video/control degradation matrix result.
public struct VideoControlDegradeMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: VideoControlDegradeMatrixSummary
    public let entries: [VideoControlDegradeMatrixEntry]
    public let notes: String
}

/// Builds the video/control degradation matrix from source-backed entries so ownership and operational boundaries remain reviewable.
public enum VideoControlDegradeMatrix {
    public static func report() -> VideoControlDegradeMatrixReport {
        VideoControlDegradeMatrixReport(
            id: "c07-video-control-degrade-matrix",
            title: "C07 video and control degrade-first matrix",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable C07 crosswalk. It proves source ownership and validation boundaries; real "
                + "Blackmagic, ATEM, lighting, route, and benchmark evidence are still required for "
                + "release PASS."
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
    videoCaptureEntry,
    videoTransportEntry,
    videoRenderOutputEntry,
    multiVideoStreamsEntry,
    atemReadOnlyControlEntry,
    oscCueControlEntry,
    lightingFixtureGateEntry,
    integratedAvEntry,
    integratedProfileEntry
  ]

  private static let videoCaptureEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .videoCapture,
            primarySourceFile: "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift",
                "Sources/OpenLolaCore/Video/VideoCaptureProbe.swift",
                "Sources/OpenLolaCore/Video/VideoCaptureRunner.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"],
            relatedDocs: [
                "docs/video-blackmagic-atem.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-video-capture-report",
                "video-capture-synthetic-smoke",
                "video-capture-run"
            ],
            evidenceBoundary: .genericCaptureOnly,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: false,
            audioBaselineRequiredForPass: true,
            notes: "AVFoundation capture can describe local capture only. "
                + "PASS requires production Blackmagic evidence and unchanged audio callback/playout metrics."
    ))

  private static let videoTransportEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .videoTransport,
            primarySourceFile: "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Video/VideoTransportProbe.swift",
                "Sources/OpenLolaCore/Video/VideoTransportRunner.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Video/VideoTransportReassembly.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/VideoTransportReportPolicyTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"
            ],
            relatedDocs: [
                "docs/video-blackmagic-atem.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-video-transport-report",
                "video-transport-synthetic-smoke",
                "video-transport-run"
            ],
            evidenceBoundary: .frameDropDegradeFirst,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: true,
            audioBaselineRequiredForPass: true,
            notes: "Socket-backed UDP raw-fragment runtime exists, including staged multi-stream "
                + "test-pattern probes. PASS requires frame drop or video disable before audio target, "
                + "route verdict, callback, playout, or underrun impact."
    ))

  private static let videoRenderOutputEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .videoRenderOutput,
            primarySourceFile: "Sources/OpenLolaCore/Video/VideoOutputRenderer.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift",
                "Sources/OpenLolaCore/Video/VideoTransportReport.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"
            ],
            relatedDocs: [
                "docs/video-blackmagic-atem.md",
                "docs/current-state.md"
            ],
            relatedCommands: ["validate-video-transport-report"],
            evidenceBoundary: .outputHardwareEvidence,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: true,
            audioBaselineRequiredForPass: true,
            notes: "Rendered-output PASS is owned by VideoTransportReport and requires Blackmagic "
                + "physical output evidence with no output drops."
    ))

  private static let multiVideoStreamsEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .multiVideoStreams,
            primarySourceFile: "Sources/OpenLolaCore/Video/MultiVideoStreams.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Protocol/SessionProtocol.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift",
                "Tests/OpenLolaCoreTests/MultiVideoStreamNegotiationTests.swift"
            ],
            relatedDocs: [
                "docs/multiple-video-streams.md",
                "docs/current-state.md"
            ],
            relatedCommands: ["validate-video-transport-report"],
            evidenceBoundary: .streamPriorityDrop,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: true,
            audioBaselineRequiredForPass: true,
            notes: "Multi-video selection and staged transport must drop lower-priority video streams and "
                + "protect audio priority before adding buffer or route pressure."
    ))

  private static let atemReadOnlyControlEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .atemReadOnlyControl,
            primarySourceFile: "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift",
            relatedSourceFiles: ["Sources/OpenLolaCore/Control/AtemReadOnlyControlValidation.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"],
            relatedDocs: [
                "docs/lighting-control.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-atem-control-report",
                "atem-readonly-probe"
            ],
            evidenceBoundary: .readOnlyControl,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: false,
            audioBaselineRequiredForPass: false,
            notes: "ATEM control defaults to disarmed read-only polling. "
                + "PASS rejects armed commands and placeholder hardware fields."
    ))

  private static let oscCueControlEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .oscCueControl,
            primarySourceFile: "Sources/OpenLolaCore/Control/OscCueProbe.swift",
            relatedSourceFiles: ["Sources/OpenLolaCore/Control/OscCueRunners.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"],
            relatedDocs: [
                "docs/lighting-control.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-osc-cue-report",
                "osc-cue-synthetic-smoke",
                "osc-cue-run",
                "osc-cue-external-run"
            ],
            evidenceBoundary: .cueTimingNoAudioImpact,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: false,
            audioBaselineRequiredForPass: true,
            notes: "OSC cue PASS requires live loopback, first external peer evidence, stable playout "
                + "target, no underruns, and no hidden audio impact."
    ))

  private static let lightingFixtureGateEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .lightingFixtureGate,
            primarySourceFile: "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Control/LightingFixtureGate.swift",
                "Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"],
            relatedDocs: [
                "docs/lighting-control.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-lighting-gate-report",
                "lighting-gate-synthetic-smoke",
                "lighting-gate-run"
            ],
            evidenceBoundary: .isolatedFixtureGate,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: false,
            audioBaselineRequiredForPass: true,
            notes: "Lighting PASS requires an isolated allowed universe, packet capture, fixture owner "
                + "match, and unchanged audio callback/playout metrics."
    ))

  private static let integratedAvEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .integratedAv,
            primarySourceFile: "Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift",
                "Sources/OpenLolaCore/Integration/IntegratedAvRun.swift",
                "Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift",
                "Tests/OpenLolaCoreTests/IntegratedAvDegradeFirstTests.swift"
            ],
            relatedDocs: [
                "docs/av-sync-and-timing.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-integrated-av-report",
                "integrated-av-synthetic-smoke",
                "integrated-av-run"
            ],
            evidenceBoundary: .audioMasterIntegratedAv,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: true,
            audioBaselineRequiredForPass: true,
            notes: "Integrated AV can aggregate a measured video-transport report, but PASS still "
                + "requires audio master clock, audio-only baseline first, video degrade-before-impact "
                + "evidence, ATEM read-only polling, and stable route/audio metrics."
    ))

  private static let integratedProfileEntry = entry(VideoControlDegradeMatrixEntryDraft(
            surface: .integratedProfile,
            primarySourceFile: "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Integration/IntegratedProfileTypes.swift",
                "Sources/OpenLolaCore/Integration/IntegratedProfileRun.swift",
                "Sources/OpenLolaCore/Integration/IntegratedProfileRuntimeEvidence.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift",
                "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift"
            ],
            relatedDocs: [
                "docs/latency-first-architecture.md",
                "docs/current-state.md"
            ],
            relatedCommands: [
                "validate-integrated-profile-report",
                "integrated-profile-synthetic-smoke",
                "integrated-profile-run"
            ],
            evidenceBoundary: .fastestAudioProfile,
            audioProtected: true,
            degradeBeforeAudioLatencyRequired: true,
            audioBaselineRequiredForPass: true,
            notes: "Integrated profile can aggregate measured runtime reports while keeping fastest-audio "
                + "as default; PASS still requires physical subordinate evidence and video degradation "
                + "before audio latency can increase."
    ))
}

private struct VideoControlDegradeMatrixEntryDraft {
    var surface: VideoControlSurfaceKind
    var primarySourceFile: String
    var relatedSourceFiles: [String]
    var relatedTestFiles: [String]
    var relatedDocs: [String]
    var relatedCommands: [String]
    var evidenceBoundary: VideoControlEvidenceBoundary
    var audioProtected: Bool
    var degradeBeforeAudioLatencyRequired: Bool
    var audioBaselineRequiredForPass: Bool
    var notes: String
}

private func entry(_ draft: VideoControlDegradeMatrixEntryDraft) -> VideoControlDegradeMatrixEntry {
    VideoControlDegradeMatrixEntry(
        surface: VideoControlDegradeMatrixEntry.Surface(
            kind: draft.surface,
            primarySourceFile: draft.primarySourceFile,
            evidenceBoundary: draft.evidenceBoundary
        ),
        references: VideoControlDegradeMatrixEntry.References(
            sourceFiles: draft.relatedSourceFiles,
            testFiles: draft.relatedTestFiles,
            docs: draft.relatedDocs,
            commands: draft.relatedCommands
        ),
        protections: VideoControlDegradeMatrixEntry.Protections(
            audioProtected: draft.audioProtected,
            degradeBeforeAudioLatencyRequired: draft.degradeBeforeAudioLatencyRequired,
            audioBaselineRequiredForPass: draft.audioBaselineRequiredForPass,
            passEvidenceRequired: true,
            destructiveControlArmedByDefault: false
        ),
        notes: draft.notes
    )
}
