// Defines audio loopback report and validation contracts, keeping evidence serialization separate from runner orchestration.
import CoreAudio
import Foundation

/// Reports `emptyField`, `completedRunMissingCallback`, `completedRunMissingHandoff`, and `completedRunMissingCleanup` failures that stop invalid CoreAudio loopback routing work before it reaches a live path.
public enum AudioLoopbackRunValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case completedRunMissingCallback
    case completedRunMissingHandoff
    case completedRunMissingCleanup
    case completedRunCleanupFailureMissingNote(String)
    case passVerdictNotAllowedForSingleRun
}

extension AudioLoopbackRunValidationError: ValidationEmptyFieldError {}

/// Records `operation` and `status` when a cleanup step cannot complete safely.
public struct AudioLoopbackRunCleanupFailure: Codable, Equatable, Sendable {
    public let operation: String
    public let status: OSStatus?

    public init(operation: String, status: OSStatus?) {
        self.operation = operation
        self.status = status
    }
}

/// Combines `failures` and `succeeded` into the outcome returned by a bounded loopback routing operation.
public struct AudioLoopbackRunCleanupResult: Codable, Equatable, Sendable {
    public let failures: [AudioLoopbackRunCleanupFailure]

    public init(failures: [AudioLoopbackRunCleanupFailure] = []) {
        self.failures = failures
    }

    public var succeeded: Bool { failures.isEmpty }
}

/// Records `id`, `capturedAt`, `hostName`, and `runnerKind` so CoreAudio loopback routing measurements and verdicts can be checked after a run.
public struct AudioLoopbackRunReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let capturedAt: String
        public let hostName: String
        public let runnerKind: AudioLoopbackRunnerKind

        public init(
            id: String,
            capturedAt: String,
            hostName: String,
            runnerKind: AudioLoopbackRunnerKind
        ) {
            self.id = id
            self.capturedAt = capturedAt
            self.hostName = hostName
            self.runnerKind = runnerKind
        }
    }

    public struct Execution: Sendable {
        public let state: AudioLoopbackRunState
        public let configuration: AudioLoopbackRunConfiguration
        public let preflight: AudioLoopbackPreflight
        public let safety: RealtimeAudioCallbackSafetyChecklist

        public init(
            state: AudioLoopbackRunState,
            configuration: AudioLoopbackRunConfiguration,
            preflight: AudioLoopbackPreflight,
            safety: RealtimeAudioCallbackSafetyChecklist = AudioLoopbackRunReport.callbackSafetyChecklist
        ) {
            self.state = state
            self.configuration = configuration
            self.preflight = preflight
            self.safety = safety
        }
    }

    public struct Runtime: Sendable {
        public let callback: EndpointCallbackMetrics?
        public let handoff: RealtimeAudioHandoffMetrics?
        public let cleanup: AudioLoopbackRunCleanupResult?

        public init(
            callback: EndpointCallbackMetrics?,
            handoff: RealtimeAudioHandoffMetrics? = nil,
            cleanup: AudioLoopbackRunCleanupResult? = nil
        ) {
            self.callback = callback
            self.handoff = handoff
            self.cleanup = cleanup
        }
    }

    public struct Outcome: Sendable {
        public let verdict: MeasurementVerdict
        public let notes: String

        public init(verdict: MeasurementVerdict, notes: String) {
            self.verdict = verdict
            self.notes = notes
        }
    }

    public let id: String
    public let capturedAt: String
    public let hostName: String
    public let runnerKind: AudioLoopbackRunnerKind
    public let state: AudioLoopbackRunState
    public let configuration: AudioLoopbackRunConfiguration
    public let preflight: AudioLoopbackPreflight
    public let safety: RealtimeAudioCallbackSafetyChecklist
    public let callback: EndpointCallbackMetrics?
    public let handoff: RealtimeAudioHandoffMetrics?
    public let cleanup: AudioLoopbackRunCleanupResult?
    public let verdict: MeasurementVerdict
    public let notes: String

    public init(
        identity: Identity,
        execution: Execution,
        runtime: Runtime,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.capturedAt = identity.capturedAt
        self.hostName = identity.hostName
        self.runnerKind = identity.runnerKind
        self.state = execution.state
        self.configuration = execution.configuration
        self.preflight = execution.preflight
        self.safety = execution.safety
        self.callback = runtime.callback
        self.handoff = runtime.handoff
        self.cleanup = runtime.cleanup
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

    public static let callbackSafetyChecklist = RealtimeAudioCallbackSafetyChecklist(
        noAllocationInCallback: false,
        noLoggingInCallback: false,
        noFileIOInCallback: false,
        noLocksOrUnboundedWaitsInCallback: false,
        noNetworkSetupInCallback: false,
        noReportWritingInCallback: false,
        countersOnlyInCallback: false
    )

    public static func decode(from data: Data) throws -> AudioLoopbackRunReport {
        try JSONDecoder().decode(AudioLoopbackRunReport.self, from: data)
    }

    public func validate() throws {
        try AudioLoopbackRunValidator.requireNonEmpty(id, "id")
        try AudioLoopbackRunValidator.requireNonEmpty(capturedAt, "capturedAt")
        try AudioLoopbackRunValidator.requireNonEmpty(hostName, "hostName")
        try AudioLoopbackRunValidator.requireNonEmpty(configuration.inputUID, "configuration.inputUID")
        try AudioLoopbackRunValidator.requireNonEmpty(configuration.outputUID, "configuration.outputUID")
        try AudioLoopbackRunValidator.requireNonEmpty(configuration.outputPath, "configuration.outputPath")
        if state == .completed, callback == nil {
            throw AudioLoopbackRunValidationError.completedRunMissingCallback
        }
        if state == .completed, handoff == nil {
            throw AudioLoopbackRunValidationError.completedRunMissingHandoff
        }
        if state == .completed, cleanup == nil {
            throw AudioLoopbackRunValidationError.completedRunMissingCleanup
        }
        if state == .completed,
           let cleanup,
           let failure = cleanup.failures.first,
           !notes.localizedCaseInsensitiveContains("cleanup") {
            throw AudioLoopbackRunValidationError.completedRunCleanupFailureMissingNote(failure.operation)
        }
        if verdict == .pass {
            throw AudioLoopbackRunValidationError.passVerdictNotAllowedForSingleRun
        }
    }
}
