// Defines native-shell sections, actions, launch probes, and validation rules for the operator surface.
import Foundation

/// Defines the supported choices for native app shell surface section id.
public enum NativeAppShellSurfaceSectionID: String, CaseIterable, Codable, Sendable {
    case overview
    case session
    case streams
    case routing
    case devices
    case diagnostics
    case validation
    case packetMonitor
    case settings
}

/// Defines the supported choices for native app shell operator command intent.
public enum NativeAppShellOperatorCommandIntent: String, Codable, Equatable, Sendable {
    case idle
    case handoffRequested
    case startRequested
    case runRequested
    case stopRequested
}

/// Defines the validated fields for native app shell surface section.
public struct NativeAppShellSurfaceSection: Codable, Equatable, Sendable {
    public let id: NativeAppShellSurfaceSectionID
    public let title: String
    public let systemImage: String
    public let readOnly: Bool
    public let mutatesRealtimeConfiguration: Bool

    public init(
        id: NativeAppShellSurfaceSectionID,
        title: String,
        systemImage: String,
        readOnly: Bool,
        mutatesRealtimeConfiguration: Bool
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.readOnly = readOnly
        self.mutatesRealtimeConfiguration = mutatesRealtimeConfiguration
    }
}

/// Defines the validated fields for native app shell surface action.
public struct NativeAppShellSurfaceAction: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public let id: String
        public let title: String
        public let keyboardShortcut: String?
        public let operatorCommandIntent: NativeAppShellOperatorCommandIntent

        public init(
            id: String,
            title: String,
            keyboardShortcut: String?,
            operatorCommandIntent: NativeAppShellOperatorCommandIntent = .idle
        ) {
            self.id = id
            self.title = title
            self.keyboardShortcut = keyboardShortcut
            self.operatorCommandIntent = operatorCommandIntent
        }
    }

    public struct Effects: Equatable, Sendable {
        public let refreshesReportOnly: Bool
        public let startsRealtimeAudio: Bool
        public let startsRealtimeVideo: Bool
        public let armsExecution: Bool
        public let armsControlOutput: Bool

        public init(
            refreshesReportOnly: Bool,
            startsRealtimeAudio: Bool,
            startsRealtimeVideo: Bool,
            armsExecution: Bool = false,
            armsControlOutput: Bool
        ) {
            self.refreshesReportOnly = refreshesReportOnly
            self.startsRealtimeAudio = startsRealtimeAudio
            self.startsRealtimeVideo = startsRealtimeVideo
            self.armsExecution = armsExecution
            self.armsControlOutput = armsControlOutput
        }
    }

    public struct Execution: Equatable, Sendable {
        public let launchesExternalProcess: Bool
        public let launchesExternalRealtimeProcess: Bool

        public init(launchesExternalProcess: Bool = false, launchesExternalRealtimeProcess: Bool = false) {
            self.launchesExternalProcess = launchesExternalProcess
            self.launchesExternalRealtimeProcess = launchesExternalRealtimeProcess
        }
    }

    public let id: String
    public let title: String
    public let keyboardShortcut: String?
    public let operatorCommandIntent: NativeAppShellOperatorCommandIntent
    public let refreshesReportOnly: Bool
    public let startsRealtimeAudio: Bool
    public let startsRealtimeVideo: Bool
    public let armsExecution: Bool
    public let armsControlOutput: Bool
    public let launchesExternalProcess: Bool
    public let launchesExternalRealtimeProcess: Bool

    public init(identity: Identity, effects: Effects, execution: Execution = .init()) {
        id = identity.id
        title = identity.title
        keyboardShortcut = identity.keyboardShortcut
        operatorCommandIntent = identity.operatorCommandIntent
        refreshesReportOnly = effects.refreshesReportOnly
        startsRealtimeAudio = effects.startsRealtimeAudio
        startsRealtimeVideo = effects.startsRealtimeVideo
        armsExecution = effects.armsExecution
        armsControlOutput = effects.armsControlOutput
        launchesExternalProcess = execution.launchesExternalProcess
        launchesExternalRealtimeProcess = execution.launchesExternalRealtimeProcess
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case keyboardShortcut
        case operatorCommandIntent
        case refreshesReportOnly
        case startsRealtimeAudio
        case startsRealtimeVideo
        case armsExecution
        case armsControlOutput
        case launchesExternalProcess
        case launchesExternalRealtimeProcess
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        keyboardShortcut = try container.decodeIfPresent(String.self, forKey: .keyboardShortcut)
        operatorCommandIntent = try container.decodeIfPresent(
            NativeAppShellOperatorCommandIntent.self,
            forKey: .operatorCommandIntent
        ) ?? .idle
        refreshesReportOnly = try container.decode(Bool.self, forKey: .refreshesReportOnly)
        startsRealtimeAudio = try container.decode(Bool.self, forKey: .startsRealtimeAudio)
        startsRealtimeVideo = try container.decode(Bool.self, forKey: .startsRealtimeVideo)
        armsExecution = try container.decodeIfPresent(Bool.self, forKey: .armsExecution) ?? false
        armsControlOutput = try container.decode(Bool.self, forKey: .armsControlOutput)
        launchesExternalProcess = try container.decodeIfPresent(Bool.self, forKey: .launchesExternalProcess) ?? false
        launchesExternalRealtimeProcess = try container.decodeIfPresent(
            Bool.self,
            forKey: .launchesExternalRealtimeProcess
        ) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(keyboardShortcut, forKey: .keyboardShortcut)
        try container.encode(operatorCommandIntent, forKey: .operatorCommandIntent)
        try container.encode(refreshesReportOnly, forKey: .refreshesReportOnly)
        try container.encode(startsRealtimeAudio, forKey: .startsRealtimeAudio)
        try container.encode(startsRealtimeVideo, forKey: .startsRealtimeVideo)
        try container.encode(armsExecution, forKey: .armsExecution)
        try container.encode(armsControlOutput, forKey: .armsControlOutput)
        try container.encode(launchesExternalProcess, forKey: .launchesExternalProcess)
        try container.encode(launchesExternalRealtimeProcess, forKey: .launchesExternalRealtimeProcess)
    }
}

/// Defines the validated fields for native app shell launch probe plan.
public struct NativeAppShellLaunchProbePlan: Codable, Equatable, Sendable {
    public let appTargetName: String
    public let buildCommand: String
    public let launchCommand: String
    public let expectedSectionIDs: [NativeAppShellSurfaceSectionID]
    public let requiresHumanVisibleWindow: Bool
    public let recordsScreenshotOrLog: Bool
    public let blocksFieldReadyPass: Bool

    public init(
        appTargetName: String,
        buildCommand: String,
        launchCommand: String,
        expectedSectionIDs: [NativeAppShellSurfaceSectionID],
        requiresHumanVisibleWindow: Bool,
        recordsScreenshotOrLog: Bool,
        blocksFieldReadyPass: Bool
    ) {
        self.appTargetName = appTargetName
        self.buildCommand = buildCommand
        self.launchCommand = launchCommand
        self.expectedSectionIDs = expectedSectionIDs
        self.requiresHumanVisibleWindow = requiresHumanVisibleWindow
        self.recordsScreenshotOrLog = recordsScreenshotOrLog
        self.blocksFieldReadyPass = blocksFieldReadyPass
    }
}

/// Defines the validated fields for native app shell surface contract.
public struct NativeAppShellSurfaceContract: Codable, Equatable, Sendable {
    public let sections: [NativeAppShellSurfaceSection]
    public let actions: [NativeAppShellSurfaceAction]
    public let launchProbePlan: NativeAppShellLaunchProbePlan

    public init(
        sections: [NativeAppShellSurfaceSection],
        actions: [NativeAppShellSurfaceAction],
        launchProbePlan: NativeAppShellLaunchProbePlan
    ) {
        self.sections = sections
        self.actions = actions
        self.launchProbePlan = launchProbePlan
    }

    public static let releaseReadinessActions = NativeAppShellActionInventory.menuActions

    public static let releaseReadiness = NativeAppShellSurfaceContract(
        sections: [
            section(.overview, "Overview", "speedometer", readOnly: true),
            section(.session, "Session", "point.3.connected.trianglepath.dotted", readOnly: false),
            section(.streams, "Streams", "waveform.path.ecg", readOnly: false),
            section(.routing, "Routing", "arrow.triangle.branch"),
            section(.devices, "Devices", "slider.horizontal.below.rectangle", readOnly: false),
            section(.diagnostics, "Diagnostics", "stethoscope"),
            section(.validation, "Validation", "checklist.checked"),
            section(.packetMonitor, "Packet Monitor", "tablecells"),
            section(.settings, "Settings", "gearshape", readOnly: true)
        ],
        actions: releaseReadinessActions,
        launchProbePlan: NativeAppShellLaunchProbePlan(
            appTargetName: "open-lola-app",
            buildCommand: "./scripts/macos/build_and_run.sh --verify",
            launchCommand: "./scripts/macos/build_and_run.sh --verify",
            expectedSectionIDs: NativeAppShellSurfaceSectionID.allCases,
            requiresHumanVisibleWindow: true,
            recordsScreenshotOrLog: true,
            blocksFieldReadyPass: true
        )
    )
}

/// Builds the complete native-shell action inventory and validates required operator intents.
public enum NativeAppShellActionInventory {
    public static let menuActions: [NativeAppShellSurfaceAction] = [
        action("refresh-synthetic-metrics", "Refresh Source/Synthetic Report", "command-r", effects: .init(refreshesReportOnly: true, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("refresh-local-media-inventory", "Refresh Local Media Inventory", nil, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("arm-execution", "Arm Execution", "command-shift-e", effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsExecution: true, armsControlOutput: false)),
        action("write-two-peer-plan", "Write Two-Peer Plan", "command-option-w", effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("dry-run-supervisor", "Dry Run Supervisor", "command-option-d", intent: .handoffRequested, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false), execution: .init(launchesExternalProcess: true)),
        action("set-handoff-intent", "Set Handoff Intent", nil, intent: .handoffRequested, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("start-armed-supervisor", "Start Armed Supervisor", nil, intent: .runRequested, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false), execution: .init(launchesExternalProcess: true, launchesExternalRealtimeProcess: true)),
        action("stop-supervisor-run", "Stop Supervisor Run", nil, intent: .stopRequested, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("validate-supervisor-report", "Validate Supervisor Report", "command-shift-v", effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false), execution: .init(launchesExternalProcess: true)),
        action("clear-command-intent", "Clear Command Intent", nil, effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)),
        action("open-local-preview-window", "Open Local Preview Window", "command-shift-p", effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false))
    ]

    private static func action(
        _ id: String,
        _ title: String,
        _ keyboardShortcut: String?,
        intent: NativeAppShellOperatorCommandIntent = .idle,
        effects: NativeAppShellSurfaceAction.Effects,
        execution: NativeAppShellSurfaceAction.Execution = .init()
    ) -> NativeAppShellSurfaceAction {
        let identity = NativeAppShellSurfaceAction.Identity(
            id: id,
            title: title,
            keyboardShortcut: keyboardShortcut,
            operatorCommandIntent: intent
        )
        return NativeAppShellSurfaceAction(
            identity: identity,
            effects: effects,
            execution: execution
        )
    }
}

/// Defines failures reported when native app shell surface validation error cannot continue.
public enum NativeAppShellSurfaceValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case duplicateSection(NativeAppShellSurfaceSectionID)
    case duplicateAction(String)
    case missingRequiredSection(NativeAppShellSurfaceSectionID)
    case sectionMutatesRealtimeConfiguration(NativeAppShellSurfaceSectionID)
    case actionStartsRealtimePath(String)
    case emptyList(String)
    case selectedAudioInputUnavailable(String)
    case selectedAudioOutputUnavailable(String)
    case selectedVideoDeviceUnavailable(String)
    case selectedRemoteAudioInputUnavailable(String)
    case selectedRemoteAudioOutputUnavailable(String)
    case selectedRemoteVideoDeviceUnavailable(String)
    case missingLocalCommandSelection(String)
    case missingRemoteCommandSelection(String)
    case invalidCommandField(String)
    case duplicateCommandPort(String)
    case operatorEnablesRemoteOrchestration
    case operatorStartsLongRunningProcess
    // swiftlint:disable:next identifier_name
    case actionRunIntentWithoutExternalRealtimeMarker(String)
    case passWithoutLaunchedSurfaceEvidence
    case passWhileLaunchProbeBlocksFieldReady
}
