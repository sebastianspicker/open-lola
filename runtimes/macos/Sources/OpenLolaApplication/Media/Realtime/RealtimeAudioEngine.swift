import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Validates realtime engine configuration and report evidence, grouping callback-safety and handoff metrics under one hardware-path model.
import Foundation
import OpenLolaContracts
import OpenLolaEvidenceModels
import OpenLolaMediaPlatform
/// Reports malformed runtime evidence before an audio-engine result is treated as trustworthy.
public enum RealtimeAudioEngineValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedCallbackMetrics
    case unorderedPerformanceCounter(String)
    case emptyChannelMap(String)
    case channelMapCountMismatch(field: String, expected: Int, actual: Int)
    case passWithoutMeasuredRun
    case passWithoutRmeMadiPath
    case passWithMismatchedInputOutputUID
    case passWithPlaceholderField(String)
    case passWithoutAcceptedRmeFastestAudioReport
    case passWithoutAcceptedRouteCertification
    case passWithRmeModeMismatch
    case passWithRouteModeMismatch
    case passWithRouteSourceMismatch(expected: String, actual: String)
    case passWithBufferedPlayoutTarget(playoutTargetFrames: Int, framesPerBuffer: Int)
    case passWithRingCapacityMismatch(configured: Int, actual: Int)
    case passWithPacketHandoffMismatch
    case passWithoutRunArtifactPath
    case passWithSyntheticCallbackOwner
    case passWithCallbackSafetyViolation(String)
    case passWithCallbackDeadlineMisses
    case passWithHandoffDropsOrUnderruns
    case passWithUnboundedHandoff
    case passWithHiddenPlayoutGrowth
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
    case passWithoutRuntimeRxBufferSnapshot(RxBufferProfile)
    case passWithRxBufferDegradation(String)
    case rxBufferRuntimePolicyMismatch(configured: RxBufferProfile, observed: RxBufferProfile)
    case rxBufferPlayoutTargetMismatch(policyFrames: Int, configurationFrames: Int)
    case passWithoutShutdown
    case passWithoutUdpPreparedBeforeStart
    case passWithReportWritingBeforeStop
    case passWithoutPacketHandoff
    case passCallbackExceededPeriod(maxMicroseconds: Double, periodMicroseconds: Double)
}

/// Records `id`, `title`, `capturedAt`, and `runMode` so the callback-driven audio path measurements and verdicts can be checked after a run.
public struct RealtimeAudioEngineReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
 public struct Fields: Codable, Equatable, Sendable {
 public var id: String
 public var title: String
 public var capturedAt: String
 public var runMode: ReportRunMode
 public var hardwarePath: RealtimeAudioHardwarePath
 public var hardware: HardwareIdentity
 public var configuration: RealtimeAudioEngineConfiguration
 public var safety: RealtimeAudioCallbackSafetyChecklist
 public var runtime: RealtimeAudioRuntimeEvidence
 public var sourceRmeFastestAudioReport: RmeFastestAudioPathReport?
 public var sourceRouteCertificationReport: MacToMacRouteCertificationReport?
 public var runArtifactPath: String?
 public var verdict: MeasurementVerdict
 public var notes: String

 public struct Metadata: Equatable, Sendable {
     public var id: String
     public var title: String
     public var capturedAt: String
     public var runMode: ReportRunMode
     public var hardwarePath: RealtimeAudioHardwarePath

     public init(
         id: String,
         title: String,
         capturedAt: String,
         runMode: ReportRunMode,
         hardwarePath: RealtimeAudioHardwarePath
     ) {
         self.id = id
         self.title = title
         self.capturedAt = capturedAt
         self.runMode = runMode
         self.hardwarePath = hardwarePath
     }
 }

 public struct Runtime: Equatable, Sendable {
     public var hardware: HardwareIdentity
     public var configuration: RealtimeAudioEngineConfiguration
     public var safety: RealtimeAudioCallbackSafetyChecklist
     public var runtime: RealtimeAudioRuntimeEvidence
     public var sourceRmeFastestAudioReport: RmeFastestAudioPathReport?
     public var sourceRouteCertificationReport: MacToMacRouteCertificationReport?

     public init(
         hardware: HardwareIdentity,
         configuration: RealtimeAudioEngineConfiguration,
         safety: RealtimeAudioCallbackSafetyChecklist,
         runtime: RealtimeAudioRuntimeEvidence,
         sourceRmeFastestAudioReport: RmeFastestAudioPathReport? = nil,
         sourceRouteCertificationReport: MacToMacRouteCertificationReport? = nil
     ) {
         self.hardware = hardware
         self.configuration = configuration
         self.safety = safety
         self.runtime = runtime
         self.sourceRmeFastestAudioReport = sourceRmeFastestAudioReport
         self.sourceRouteCertificationReport = sourceRouteCertificationReport
     }
 }

 public struct Outcome: Equatable, Sendable {
     public var runArtifactPath: String?
     public var verdict: MeasurementVerdict
     public var notes: String

     public init(
         runArtifactPath: String? = nil,
         verdict: MeasurementVerdict,
         notes: String
     ) {
         self.runArtifactPath = runArtifactPath
         self.verdict = verdict
         self.notes = notes
     }
 }

 public init(metadata: Metadata, runtime: Runtime, outcome: Outcome) {
     id = metadata.id
     title = metadata.title
     capturedAt = metadata.capturedAt
     runMode = metadata.runMode
     hardwarePath = metadata.hardwarePath
     hardware = runtime.hardware
     configuration = runtime.configuration
     safety = runtime.safety
     self.runtime = runtime.runtime
     sourceRmeFastestAudioReport = runtime.sourceRmeFastestAudioReport
     sourceRouteCertificationReport = runtime.sourceRouteCertificationReport
     runArtifactPath = outcome.runArtifactPath
     verdict = outcome.verdict
     notes = outcome.notes
 }
 }

 public typealias Init = Fields
 private var fields: Fields

 public var id: String {
     get { fields.id }
     set { fields.id = newValue }
 }

 public var title: String {
     get { fields.title }
     set { fields.title = newValue }
 }

 public var capturedAt: String {
     get { fields.capturedAt }
     set { fields.capturedAt = newValue }
 }

 public var runMode: ReportRunMode {
     get { fields.runMode }
     set { fields.runMode = newValue }
 }

 public var hardwarePath: RealtimeAudioHardwarePath {
     get { fields.hardwarePath }
     set { fields.hardwarePath = newValue }
 }

 public var hardware: HardwareIdentity {
     get { fields.hardware }
     set { fields.hardware = newValue }
 }

 public var configuration: RealtimeAudioEngineConfiguration {
     get { fields.configuration }
     set { fields.configuration = newValue }
 }

 public var safety: RealtimeAudioCallbackSafetyChecklist {
     get { fields.safety }
     set { fields.safety = newValue }
 }

 public var runtime: RealtimeAudioRuntimeEvidence {
     get { fields.runtime }
     set { fields.runtime = newValue }
 }

 public var sourceRmeFastestAudioReport: RmeFastestAudioPathReport? {
     get { fields.sourceRmeFastestAudioReport }
     set { fields.sourceRmeFastestAudioReport = newValue }
 }

 public var sourceRouteCertificationReport: MacToMacRouteCertificationReport? {
     get { fields.sourceRouteCertificationReport }
     set { fields.sourceRouteCertificationReport = newValue }
 }

 public var runArtifactPath: String? {
     get { fields.runArtifactPath }
     set { fields.runArtifactPath = newValue }
 }

 public var verdict: MeasurementVerdict {
     get { fields.verdict }
     set { fields.verdict = newValue }
 }

 public var notes: String {
     get { fields.notes }
     set { fields.notes = newValue }
 }

 public init(_ input: Init) {
 self.fields = input
 }

 public init(from decoder: Decoder) throws {
     self.fields = try Fields(from: decoder)
 }

 public func encode(to encoder: Encoder) throws {
     try fields.encode(to: encoder)
 }

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: ReportRunMode,
        hardwarePath: RealtimeAudioHardwarePath,
        hardware: HardwareIdentity,
        configuration: RealtimeAudioEngineConfiguration,
        safety: RealtimeAudioCallbackSafetyChecklist,
        runtime: RealtimeAudioRuntimeEvidence,
        sourceRmeFastestAudioReport: RmeFastestAudioPathReport? = nil,
        sourceRouteCertificationReport: MacToMacRouteCertificationReport? = nil,
        runArtifactPath: String? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.init(.init(
            metadata: .init(
                id: id,
                title: title,
                capturedAt: capturedAt,
                runMode: runMode,
                hardwarePath: hardwarePath
            ),
            runtime: .init(
                hardware: hardware,
                configuration: configuration,
                safety: safety,
                runtime: runtime,
                sourceRmeFastestAudioReport: sourceRmeFastestAudioReport,
                sourceRouteCertificationReport: sourceRouteCertificationReport
            ),
            outcome: .init(
                runArtifactPath: runArtifactPath,
                verdict: verdict,
                notes: notes
            )
        ))
    }
}
