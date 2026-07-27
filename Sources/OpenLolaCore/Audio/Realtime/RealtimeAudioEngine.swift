// Validates realtime engine configuration and report evidence, grouping callback-safety and handoff metrics under one hardware-path model.
import Foundation
import OpenLolaContracts

/// Identifies the measured or synthetic hardware path used by a real-time audio run.
public enum RealtimeAudioHardwarePath: String, Codable, Equatable, Sendable {
    case rmeMadi
    case builtIn
    case synthetic
    case unknown
}

/// Pairs input and output channel indices for a realtime audio engine configuration.
public struct RealtimeAudioChannelMaps: Equatable, Sendable {
    public var input: [Int]
    public var output: [Int]

    public init(input: [Int], output: [Int]) {
        self.input = input
        self.output = output
    }
}

/// Binds `inputDeviceUID`, `outputDeviceUID`, `sampleRateHertz`, and `framesPerBuffer` before the callback-driven audio path starts, preventing implicit runtime defaults.
public struct RealtimeAudioEngineConfiguration: Codable, Equatable, Sendable {
    public struct Devices: Equatable, Sendable {
        public var inputDeviceUID: String
        public var outputDeviceUID: String

        public init(inputDeviceUID: String, outputDeviceUID: String) {
            self.inputDeviceUID = inputDeviceUID
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var framesPerBuffer: Int
        public var channelCount: Int
        public var packetFormat: UdpPcmSampleFormat

        public init(
            sampleRateHertz: Int,
            framesPerBuffer: Int,
            channelCount: Int,
            packetFormat: UdpPcmSampleFormat
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.channelCount = channelCount
            self.packetFormat = packetFormat
        }
    }

    public typealias ChannelMaps = RealtimeAudioChannelMaps

    public struct Buffering: Equatable, Sendable {
        public var playoutTargetFrames: Int
        public var preallocatedBlockCount: Int
        public var rxBufferPolicy: RxBufferPolicy?

        public init(
            playoutTargetFrames: Int,
            preallocatedBlockCount: Int,
            rxBufferPolicy: RxBufferPolicy? = nil
        ) {
            self.playoutTargetFrames = playoutTargetFrames
            self.preallocatedBlockCount = preallocatedBlockCount
            self.rxBufferPolicy = rxBufferPolicy
        }
    }

 public var inputDeviceUID: String
 public var outputDeviceUID: String
 public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var channelCount: Int
    public var packetFormat: UdpPcmSampleFormat
    public var inputChannelMap: [Int]
    public var outputChannelMap: [Int]
    public var playoutTargetFrames: Int
    public var preallocatedBlockCount: Int
    public var rxBufferPolicy: RxBufferPolicy?

    public init(devices: Devices, format: Format, channelMaps: ChannelMaps, buffering: Buffering) {
        self.inputDeviceUID = devices.inputDeviceUID
        self.outputDeviceUID = devices.outputDeviceUID
        self.sampleRateHertz = format.sampleRateHertz
        self.framesPerBuffer = format.framesPerBuffer
        self.channelCount = format.channelCount
        self.packetFormat = format.packetFormat
        self.inputChannelMap = channelMaps.input
        self.outputChannelMap = channelMaps.output
        self.playoutTargetFrames = buffering.playoutTargetFrames
        self.preallocatedBlockCount = buffering.preallocatedBlockCount
        self.rxBufferPolicy = buffering.rxBufferPolicy
    }

    public var audioMode: AudioMode {
        AudioMode(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            sampleFormat: packetFormat.audioModeSampleFormat
        )
    }

    public func validateRealtimeBufferInputs() throws {
        let format = RealtimeAudioBufferValidationInput.Format(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            bytesPerSample: packetFormat.bytesPerSample
        )
        let channelMaps = RealtimeAudioBufferValidationInput.ChannelMaps(
            input: inputChannelMap,
            output: outputChannelMap
        )
        let buffering = RealtimeAudioBufferValidationInput.Buffering(
            capacityRequirement: .preallocatedBlockCount(preallocatedBlockCount),
            playoutTargetFrames: playoutTargetFrames,
            rxBufferPolicy: rxBufferPolicy
        )
        try validateRealtimeAudioBufferInput(
            RealtimeAudioBufferValidationInput(
                format: format,
                channelMaps: channelMaps,
                buffering: buffering
            )
        )
    }
}

/// Preserves `callbackOwner`, `callback`, `handoff`, and `udpSocketsPreparedBeforeStart` needed to distinguish measured the callback-driven audio path behavior from configuration claims.
public struct RealtimeAudioRuntimeEvidence: Codable, Equatable, Sendable {
    public var callbackOwner: RealtimeAudioCallbackOwner
    public var callback: EndpointCallbackMetrics
    public var handoff: RealtimeAudioHandoffMetrics
    public var udpSocketsPreparedBeforeStart: Bool
    public var reportWrittenAfterStop: Bool
    public var measuredDurationSeconds: Int

    public init(
        callbackOwner: RealtimeAudioCallbackOwner,
        callback: EndpointCallbackMetrics,
        handoff: RealtimeAudioHandoffMetrics,
        udpSocketsPreparedBeforeStart: Bool,
        reportWrittenAfterStop: Bool,
        measuredDurationSeconds: Int
    ) {
        self.callbackOwner = callbackOwner
        self.callback = callback
        self.handoff = handoff
        self.udpSocketsPreparedBeforeStart = udpSocketsPreparedBeforeStart
        self.reportWrittenAfterStop = reportWrittenAfterStop
        self.measuredDurationSeconds = measuredDurationSeconds
    }
}

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
