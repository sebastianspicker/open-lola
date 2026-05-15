import Foundation

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

public enum NativeAppShellOperatorCommandIntent: String, Codable, Equatable, Sendable {
    case idle
    case handoffRequested
    case startRequested
    case runRequested
    case stopRequested
}

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

public struct NativeAppShellSurfaceAction: Codable, Equatable, Sendable {
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

    public init(
        id: String,
        title: String,
        keyboardShortcut: String?,
        operatorCommandIntent: NativeAppShellOperatorCommandIntent = .idle,
        refreshesReportOnly: Bool,
        startsRealtimeAudio: Bool,
        startsRealtimeVideo: Bool,
        armsExecution: Bool = false,
        armsControlOutput: Bool,
        launchesExternalProcess: Bool = false,
        launchesExternalRealtimeProcess: Bool = false
    ) {
        self.id = id
        self.title = title
        self.keyboardShortcut = keyboardShortcut
        self.operatorCommandIntent = operatorCommandIntent
        self.refreshesReportOnly = refreshesReportOnly
        self.startsRealtimeAudio = startsRealtimeAudio
        self.startsRealtimeVideo = startsRealtimeVideo
        self.armsExecution = armsExecution
        self.armsControlOutput = armsControlOutput
        self.launchesExternalProcess = launchesExternalProcess
        self.launchesExternalRealtimeProcess = launchesExternalRealtimeProcess
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
            section(.settings, "Settings", "gearshape", readOnly: false),
        ],
        actions: releaseReadinessActions,
        launchProbePlan: NativeAppShellLaunchProbePlan(
            appTargetName: "open-lola-app",
            buildCommand: "./script/build_and_run.sh --verify",
            launchCommand: "./script/build_and_run.sh --verify",
            expectedSectionIDs: NativeAppShellSurfaceSectionID.allCases,
            requiresHumanVisibleWindow: true,
            recordsScreenshotOrLog: true,
            blocksFieldReadyPass: true
        )
    )
}

public enum NativeAppShellActionInventory {
    public static let menuActions: [NativeAppShellSurfaceAction] = [
            NativeAppShellSurfaceAction(
                id: "refresh-synthetic-metrics",
                title: "Refresh Synthetic Metrics",
                keyboardShortcut: "command-r",
                refreshesReportOnly: true,
                startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false
            ),
            NativeAppShellSurfaceAction(
                id: "refresh-local-media-inventory",
                title: "Refresh Local Media Inventory",
                keyboardShortcut: nil,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false
            ),
            NativeAppShellSurfaceAction(
                id: "arm-execution",
                title: "Arm Execution",
                keyboardShortcut: "command-shift-e",
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsExecution: true,
                armsControlOutput: false,
                launchesExternalProcess: false
            ),
            NativeAppShellSurfaceAction(
                id: "write-two-peer-plan",
                title: "Write Two-Peer Plan",
                keyboardShortcut: nil,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: false
            ),
            NativeAppShellSurfaceAction(
                id: "dry-run-supervisor",
                title: "Dry Run Supervisor",
                keyboardShortcut: nil,
                operatorCommandIntent: .handoffRequested,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: true
            ),
            NativeAppShellSurfaceAction(
                id: "set-handoff-intent",
                title: "Set Handoff Intent",
                keyboardShortcut: nil,
                operatorCommandIntent: .handoffRequested,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: false
            ),
            NativeAppShellSurfaceAction(
                id: "start-armed-supervisor",
                title: "Start Armed Supervisor",
                keyboardShortcut: nil,
                operatorCommandIntent: .runRequested,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: true,
                launchesExternalRealtimeProcess: true
            ),
            NativeAppShellSurfaceAction(
                id: "stop-supervisor-run",
                title: "Stop Supervisor Run",
                keyboardShortcut: nil,
                operatorCommandIntent: .stopRequested,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: false
            ),
            NativeAppShellSurfaceAction(
                id: "validate-supervisor-report",
                title: "Validate Supervisor Report",
                keyboardShortcut: nil,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false,
                launchesExternalProcess: true
            ),
            NativeAppShellSurfaceAction(
                id: "clear-command-intent",
                title: "Clear Command Intent",
                keyboardShortcut: nil,
                operatorCommandIntent: .idle,
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false
            ),
            NativeAppShellSurfaceAction(
                id: "open-local-preview-window",
                title: "Open Local Preview Window",
                keyboardShortcut: "command-shift-p",
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false
            ),
    ]
}

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
    case actionRunIntentWithoutExternalRealtimeMarker(String)
    case passWithoutLaunchedSurfaceEvidence
    case passWhileLaunchProbeBlocksFieldReady
}

public struct NativeAppShellSurfaceProbeReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let capturedAt: String
    public let sourceReportId: String
    public let appTargetName: String
    public let sections: [NativeAppShellSurfaceSection]
    public let actions: [NativeAppShellSurfaceAction]
    public let launchProbePlan: NativeAppShellLaunchProbePlan
    public var verdict: MeasurementVerdict
    public let notes: String

    public static func decode(from data: Data) throws -> NativeAppShellSurfaceProbeReport {
        try JSONDecoder().decode(NativeAppShellSurfaceProbeReport.self, from: data)
    }

    public func validate() throws {
        try requireNativeAppSurfaceNonEmpty(id, "id")
        try requireNativeAppSurfaceNonEmpty(title, "title")
        try requireNativeAppSurfaceNonEmpty(capturedAt, "capturedAt")
        try requireNativeAppSurfaceNonEmpty(sourceReportId, "sourceReportId")
        try requireNativeAppSurfaceNonEmpty(appTargetName, "appTargetName")
        try requireNativeAppSurfaceNonEmpty(notes, "notes")
        try validateSections()
        try validateActions()
        try validateLaunchProbePlan()
    }

    private func validateSections() throws {
        var seen = Set<NativeAppShellSurfaceSectionID>()
        for section in sections {
            try requireNativeAppSurfaceNonEmpty(section.title, "sections.title")
            try requireNativeAppSurfaceNonEmpty(section.systemImage, "sections.systemImage")
            guard seen.insert(section.id).inserted else {
                throw NativeAppShellSurfaceValidationError.duplicateSection(section.id)
            }
            if section.mutatesRealtimeConfiguration {
                throw NativeAppShellSurfaceValidationError.sectionMutatesRealtimeConfiguration(section.id)
            }
        }
        for requiredSection in NativeAppShellSurfaceSectionID.allCases where !seen.contains(requiredSection) {
            throw NativeAppShellSurfaceValidationError.missingRequiredSection(requiredSection)
        }
    }

    private func validateActions() throws {
        var seen = Set<String>()
        for action in actions {
            try requireNativeAppSurfaceNonEmpty(action.id, "actions.id")
            try requireNativeAppSurfaceNonEmpty(action.title, "actions.title")
            guard seen.insert(action.id).inserted else {
                throw NativeAppShellSurfaceValidationError.duplicateAction(action.id)
            }
            if action.startsRealtimeAudio || action.startsRealtimeVideo || action.armsControlOutput {
                throw NativeAppShellSurfaceValidationError.actionStartsRealtimePath(action.id)
            }
            if action.operatorCommandIntent == .runRequested,
               action.launchesExternalProcess,
               !action.launchesExternalRealtimeProcess {
                throw NativeAppShellSurfaceValidationError.actionRunIntentWithoutExternalRealtimeMarker(action.id)
            }
        }
    }

    private func validateLaunchProbePlan() throws {
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.appTargetName, "launchProbePlan.appTargetName")
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.buildCommand, "launchProbePlan.buildCommand")
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.launchCommand, "launchProbePlan.launchCommand")
        if verdict == .pass {
            guard launchProbePlan.recordsScreenshotOrLog else {
                throw NativeAppShellSurfaceValidationError.passWithoutLaunchedSurfaceEvidence
            }
            guard !launchProbePlan.blocksFieldReadyPass else {
                throw NativeAppShellSurfaceValidationError.passWhileLaunchProbeBlocksFieldReady
            }
        }
    }
}

public enum NativeAppShellSurfaceProbe {
    public static func run(
        sourceReport: NativeAppShellReport,
        capturedAt: String = ISO8601DateFormatter().string(from: Date()),
        contract: NativeAppShellSurfaceContract = .releaseReadiness
    ) -> NativeAppShellSurfaceProbeReport {
        NativeAppShellSurfaceProbeReport(
            id: "c11-native-app-shell-surface-probe",
            title: "C11 native app shell surface probe",
            capturedAt: capturedAt,
            sourceReportId: sourceReport.id,
            appTargetName: contract.launchProbePlan.appTargetName,
            sections: contract.sections,
            actions: contract.actions,
            launchProbePlan: contract.launchProbePlan,
            verdict: .partial,
            notes: "Source-level SwiftUI surface contract. Field-ready PASS remains blocked until a launched app window is observed and recorded."
        )
    }
}

private func section(
    _ id: NativeAppShellSurfaceSectionID,
    _ title: String,
    _ systemImage: String,
    readOnly: Bool = true
) -> NativeAppShellSurfaceSection {
    NativeAppShellSurfaceSection(
        id: id,
        title: title,
        systemImage: systemImage,
        readOnly: readOnly,
        mutatesRealtimeConfiguration: false
    )
}

func requireNativeAppSurfaceNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty { throw NativeAppShellSurfaceValidationError.emptyField(field) }
}
