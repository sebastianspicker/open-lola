// Records deadline PLC events, drift corrections, telemetry, and acceptance metrics so clock recovery claims expose their full history.
import Foundation
/// States whether packet-loss concealment reuses a block at the same playout deadline.
public enum SameDeadlinePlcPolicy: String, Codable, Equatable, Sendable {
    case silence
    case repeatLastGoodBlock
    case boundedSubstitute
}
/// Defines `outsideCallback`, `branchBoundedInsideDueBlock`, and `unboundedInsideCallback` states used to make drift correction location decisions in timing and drift control.
public enum DriftCorrectionLocation: String, Codable, Equatable, Sendable {
    case outsideCallback
    case branchBoundedInsideDueBlock
    case unboundedInsideCallback
}
/// Records `sequenceNumber`, `senderFrameIndex`, `receiverPlayoutFrameIndex`, and `driftFrames` from one measurement used to evaluate timing control.
public struct DriftTelemetrySample: Codable, Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var senderFrameIndex: Int
    public var receiverPlayoutFrameIndex: Int
    public var driftFrames: Int
    public var packetAgeMicroseconds: Double
    public init(
        sequenceNumber: UInt64,
        senderFrameIndex: Int,
        receiverPlayoutFrameIndex: Int,
        driftFrames: Int,
        packetAgeMicroseconds: Double
    ) {
        self.sequenceNumber = sequenceNumber
        self.senderFrameIndex = senderFrameIndex
        self.receiverPlayoutFrameIndex = receiverPlayoutFrameIndex
        self.driftFrames = driftFrames
        self.packetAgeMicroseconds = packetAgeMicroseconds
    }
}
/// Records `dueFrameIndex`, `missingSequenceNumber`, `policy`, and `waitedForRetransmission` for one observable timing or recovery event in timing control.
public struct SameDeadlinePlcEvent: Codable, Equatable, Sendable {
    public var dueFrameIndex: Int
    public var missingSequenceNumber: UInt64
    public var policy: SameDeadlinePlcPolicy
    public var waitedForRetransmission: Bool
    public var playoutTargetFramesBefore: Int
    public var playoutTargetFramesAfter: Int
    public var branchBounded: Bool
    public var notes: String
    public init(
        dueFrameIndex: Int,
        missingSequenceNumber: UInt64,
        policy: SameDeadlinePlcPolicy,
        waitedForRetransmission: Bool,
        playoutTargetFramesBefore: Int,
        playoutTargetFramesAfter: Int,
        branchBounded: Bool,
        notes: String
    ) {
        self.dueFrameIndex = dueFrameIndex
        self.missingSequenceNumber = missingSequenceNumber
        self.policy = policy
        self.waitedForRetransmission = waitedForRetransmission
        self.playoutTargetFramesBefore = playoutTargetFramesBefore
        self.playoutTargetFramesAfter = playoutTargetFramesAfter
        self.branchBounded = branchBounded
        self.notes = notes
    }
}
/// Records `playoutFrameIndex`, `driftFramesBefore`, `driftFramesAfter`, and `location` for one observable timing or recovery event in timing control.
public struct DriftCorrectionEvent: Codable, Equatable, Sendable {
    public var playoutFrameIndex: Int
    public var driftFramesBefore: Int
    public var driftFramesAfter: Int
    public var location: DriftCorrectionLocation
    public var targetGrowthFrames: Int
    public var notes: String
    public init(
        playoutFrameIndex: Int,
        driftFramesBefore: Int,
        driftFramesAfter: Int,
        location: DriftCorrectionLocation,
        targetGrowthFrames: Int,
        notes: String
    ) {
        self.playoutFrameIndex = playoutFrameIndex
        self.driftFramesBefore = driftFramesBefore
        self.driftFramesAfter = driftFramesAfter
        self.location = location
        self.targetGrowthFrames = targetGrowthFrames
        self.notes = notes
    }
}

/// Tracks `durationSeconds`, `playoutTargetFrames`, `callbackP99Microseconds`, and `callbackMaxMicroseconds` to expose latency, pressure, and delivery outcomes in timing and drift control.
public struct DriftPlcMetrics: Codable, Equatable, Sendable {
    public static let minimumPassDurationSeconds = 3_600

    public var durationSeconds: Int
    public var playoutTargetFrames: Int
    public var callbackP99Microseconds: Double
    public var callbackMaxMicroseconds: Double
    public var underruns: Int
    public var correctionEvents: Int
    public var plcEvents: Int
    public var maxAbsoluteDriftFrames: Int
    public var driftSlopeFramesPerMinute: Double
    public var hiddenPlayoutGrowthDetected: Bool
    public var rxBuffer: RxBufferRuntimeSnapshot?

    public struct CallbackTiming: Equatable, Sendable {
        public var durationSeconds: Int
        public var playoutTargetFrames: Int
        public var callbackP99Microseconds: Double
        public var callbackMaxMicroseconds: Double

        public init(
            durationSeconds: Int,
            playoutTargetFrames: Int,
            callbackP99Microseconds: Double,
            callbackMaxMicroseconds: Double
        ) {
            self.durationSeconds = durationSeconds
            self.playoutTargetFrames = playoutTargetFrames
            self.callbackP99Microseconds = callbackP99Microseconds
            self.callbackMaxMicroseconds = callbackMaxMicroseconds
        }
    }

    public struct Recovery: Equatable, Sendable {
        public var underruns: Int
        public var correctionEvents: Int
        public var plcEvents: Int
        public var maxAbsoluteDriftFrames: Int
        public var driftSlopeFramesPerMinute: Double
        public var hiddenPlayoutGrowthDetected: Bool

        public init(
            underruns: Int,
            correctionEvents: Int,
            plcEvents: Int,
            maxAbsoluteDriftFrames: Int,
            driftSlopeFramesPerMinute: Double,
            hiddenPlayoutGrowthDetected: Bool
        ) {
            self.underruns = underruns
            self.correctionEvents = correctionEvents
            self.plcEvents = plcEvents
            self.maxAbsoluteDriftFrames = maxAbsoluteDriftFrames
            self.driftSlopeFramesPerMinute = driftSlopeFramesPerMinute
            self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
        }
    }

    public init(
        callbackTiming: CallbackTiming,
        recovery: Recovery,
        rxBuffer: RxBufferRuntimeSnapshot? = nil
    ) {
        self.durationSeconds = callbackTiming.durationSeconds
        self.playoutTargetFrames = callbackTiming.playoutTargetFrames
        self.callbackP99Microseconds = callbackTiming.callbackP99Microseconds
        self.callbackMaxMicroseconds = callbackTiming.callbackMaxMicroseconds
        self.underruns = recovery.underruns
        self.correctionEvents = recovery.correctionEvents
        self.plcEvents = recovery.plcEvents
        self.maxAbsoluteDriftFrames = recovery.maxAbsoluteDriftFrames
        self.driftSlopeFramesPerMinute = recovery.driftSlopeFramesPerMinute
        self.hiddenPlayoutGrowthDetected = recovery.hiddenPlayoutGrowthDetected
        self.rxBuffer = rxBuffer
    }
}

/// Reports `emptyField`, `nonPositiveField`, `negativeField`, and `nonFiniteField` failures that stop invalid timing and drift control work before it reaches a live path.
public enum DriftPlcValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedCallbackMetrics
    case missingTelemetry
    case nonMonotonicTelemetrySenderFrameIndex(previous: Int, current: Int)
    case telemetryDriftMismatch(sequenceNumber: UInt64, expected: Int, actual: Int)
    case maxDriftMismatch(expected: Int, actual: Int)
    case eventCountMismatch(field: String, expected: Int, actual: Int)
    case plcWaitedForRetransmission(missingSequenceNumber: UInt64)
    case plcChangedPlayoutTarget(dueFrameIndex: Int, before: Int, after: Int)
    case plcTargetMismatch(dueFrameIndex: Int, target: Int)
    case plcNotBranchBounded(missingSequenceNumber: UInt64)
    case invalidFixedPlayoutTarget(playoutTargetFrames: Int, framesPerPacket: Int)
    case correctionInsideUnboundedCallback(playoutFrameIndex: Int)
    case correctionGrewTarget(playoutFrameIndex: Int, targetGrowthFrames: Int)
    case hiddenPlayoutGrowthDetected
    case passRunTooShort(seconds: Int, minimumSeconds: Int)
    case passWithUnderruns(Int)
    case passWithoutArtifactAssessment
    case passCorrectionNotOutsideCallback(playoutFrameIndex: Int)
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
}

/// Records `id`, `title`, `capturedAt`, and `route` so timing and drift control measurements and verdicts can be checked after a run.
public struct DriftPlcReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var route: RouteIdentity
    public var packetMode: UdpPcmPacketMode
    public var telemetry: [DriftTelemetrySample]
    public var plcEvents: [SameDeadlinePlcEvent]
    public var correctionEvents: [DriftCorrectionEvent]
    public var metrics: DriftPlcMetrics
    public var artifactAssessmentCompleted: Bool
    public var artifactNotes: String
    public var verdict: MeasurementVerdict
    public var notes: String

    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var route: RouteIdentity
        public var packetMode: UdpPcmPacketMode

        public init(
            id: String,
            title: String,
            capturedAt: String,
            route: RouteIdentity,
            packetMode: UdpPcmPacketMode
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.route = route
            self.packetMode = packetMode
        }
    }

    public struct Measurements: Equatable, Sendable {
        public var telemetry: [DriftTelemetrySample]
        public var plcEvents: [SameDeadlinePlcEvent]
        public var correctionEvents: [DriftCorrectionEvent]
        public var metrics: DriftPlcMetrics

        public init(
            telemetry: [DriftTelemetrySample],
            plcEvents: [SameDeadlinePlcEvent],
            correctionEvents: [DriftCorrectionEvent],
            metrics: DriftPlcMetrics
        ) {
            self.telemetry = telemetry
            self.plcEvents = plcEvents
            self.correctionEvents = correctionEvents
            self.metrics = metrics
        }
    }

    public struct Assessment: Equatable, Sendable {
        public var artifactAssessmentCompleted: Bool
        public var artifactNotes: String
        public var verdict: MeasurementVerdict
        public var notes: String

        public init(
            artifactAssessmentCompleted: Bool,
            artifactNotes: String,
            verdict: MeasurementVerdict,
            notes: String
        ) {
            self.artifactAssessmentCompleted = artifactAssessmentCompleted
            self.artifactNotes = artifactNotes
            self.verdict = verdict
            self.notes = notes
        }
    }

    public init(
        identity: Identity,
        measurements: Measurements,
        assessment: Assessment
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.route = identity.route
        self.packetMode = identity.packetMode
        self.telemetry = measurements.telemetry
        self.plcEvents = measurements.plcEvents
        self.correctionEvents = measurements.correctionEvents
        self.metrics = measurements.metrics
        self.artifactAssessmentCompleted = assessment.artifactAssessmentCompleted
        self.artifactNotes = assessment.artifactNotes
        self.verdict = assessment.verdict
        self.notes = assessment.notes
    }

    public static func decode(from data: Data) throws -> DriftPlcReport {
        try JSONDecoder().decode(DriftPlcReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validatePacketMode()
        try validateMetrics()
        try validateTelemetry()
        try validatePlcEvents()
        try validateCorrectionEvents()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try DriftPlcValidator.requireNonEmpty(id, "id")
        try DriftPlcValidator.requireNonEmpty(title, "title")
        try DriftPlcValidator.requireNonEmpty(capturedAt, "capturedAt")
        try DriftPlcValidator.requireNonEmpty(route.label, "route.label")
        try DriftPlcValidator.requireNonEmpty(route.topology, "route.topology")
        try DriftPlcValidator.requireNonEmpty(artifactNotes, "artifactNotes")
        try DriftPlcValidator.requireNonEmpty(notes, "notes")
    }

    private func validatePacketMode() throws {
        try DriftPlcValidator.requirePositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try DriftPlcValidator.requirePositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try DriftPlcValidator.requirePositive(packetMode.channelCount, "packetMode.channelCount")
    }

    private func validateMetrics() throws {
        try DriftPlcValidator.requirePositive(metrics.durationSeconds, "metrics.durationSeconds")
        try DriftPlcValidator.requireNonNegative(metrics.playoutTargetFrames, "metrics.playoutTargetFrames")
        try DriftPlcValidator.requireNonNegative(metrics.callbackP99Microseconds, "metrics.callbackP99Microseconds")
        try DriftPlcValidator.requireNonNegative(metrics.callbackMaxMicroseconds, "metrics.callbackMaxMicroseconds")
        try DriftPlcValidator.requireNonNegative(metrics.underruns, "metrics.underruns")
        try DriftPlcValidator.requireNonNegative(metrics.correctionEvents, "metrics.correctionEvents")
        try DriftPlcValidator.requireNonNegative(metrics.plcEvents, "metrics.plcEvents")
        try DriftPlcValidator.requireNonNegative(metrics.maxAbsoluteDriftFrames, "metrics.maxAbsoluteDriftFrames")
        try DriftPlcValidator.requireFinite(metrics.driftSlopeFramesPerMinute, "metrics.driftSlopeFramesPerMinute")
        try metrics.rxBuffer?.validate()

        guard metrics.callbackP99Microseconds <= metrics.callbackMaxMicroseconds else {
            throw DriftPlcValidationError.unorderedCallbackMetrics
        }
        guard metrics.playoutTargetFrames == packetMode.framesPerPacket else {
            throw DriftPlcValidationError.invalidFixedPlayoutTarget(
                playoutTargetFrames: metrics.playoutTargetFrames,
                framesPerPacket: packetMode.framesPerPacket
            )
        }
        if metrics.hiddenPlayoutGrowthDetected {
            throw DriftPlcValidationError.hiddenPlayoutGrowthDetected
        }
        if metrics.rxBuffer?.hiddenGrowthDetected == true {
            throw DriftPlcValidationError.hiddenPlayoutGrowthDetected
        }
        if metrics.plcEvents != plcEvents.count {
            throw DriftPlcValidationError.eventCountMismatch(
                field: "metrics.plcEvents",
                expected: plcEvents.count,
                actual: metrics.plcEvents
            )
        }
        if metrics.correctionEvents != correctionEvents.count {
            throw DriftPlcValidationError.eventCountMismatch(
                field: "metrics.correctionEvents",
                expected: correctionEvents.count,
                actual: metrics.correctionEvents
            )
        }
    }

    private func validateTelemetry() throws {
        guard !telemetry.isEmpty else {
            throw DriftPlcValidationError.missingTelemetry
        }

        for sample in telemetry {
            try DriftPlcValidator.requireNonNegative(sample.senderFrameIndex, "telemetry.senderFrameIndex")
            try DriftPlcValidator.requireNonNegative(
sample.receiverPlayoutFrameIndex,
"telemetry.receiverPlayoutFrameIndex"
)
            try DriftPlcValidator.requireNonNegative(sample.packetAgeMicroseconds, "telemetry.packetAgeMicroseconds")

            let expected = sample.senderFrameIndex - sample.receiverPlayoutFrameIndex
            if sample.driftFrames != expected {
                throw DriftPlcValidationError.telemetryDriftMismatch(
                    sequenceNumber: sample.sequenceNumber,
                    expected: expected,
                    actual: sample.driftFrames
                )
            }
        }
        for (previous, current) in zip(telemetry, telemetry.dropFirst()) where
                current.senderFrameIndex < previous.senderFrameIndex {
            throw DriftPlcValidationError.nonMonotonicTelemetrySenderFrameIndex(
                previous: previous.senderFrameIndex,
                current: current.senderFrameIndex
            )
        }

        let expectedMaxDrift = telemetry.map { abs($0.driftFrames) }.max() ?? 0
        if metrics.maxAbsoluteDriftFrames != expectedMaxDrift {
            throw DriftPlcValidationError.maxDriftMismatch(
                expected: expectedMaxDrift,
                actual: metrics.maxAbsoluteDriftFrames
            )
        }
    }

    private func validatePlcEvents() throws {
        for event in plcEvents {
            try DriftPlcValidator.requireNonNegative(event.dueFrameIndex, "plcEvents.dueFrameIndex")
            try DriftPlcValidator.requireNonNegative(
event.playoutTargetFramesBefore,
"plcEvents.playoutTargetFramesBefore"
)
            try DriftPlcValidator.requireNonNegative(
event.playoutTargetFramesAfter,
"plcEvents.playoutTargetFramesAfter"
)
            try DriftPlcValidator.requireNonEmpty(event.notes, "plcEvents.notes")

            if event.waitedForRetransmission {
                throw DriftPlcValidationError.plcWaitedForRetransmission(
                    missingSequenceNumber: event.missingSequenceNumber
                )
            }
            if event.playoutTargetFramesBefore != event.playoutTargetFramesAfter {
                throw DriftPlcValidationError.plcChangedPlayoutTarget(
                    dueFrameIndex: event.dueFrameIndex,
                    before: event.playoutTargetFramesBefore,
                    after: event.playoutTargetFramesAfter
                )
            }
            if event.playoutTargetFramesBefore != metrics.playoutTargetFrames {
                throw DriftPlcValidationError.plcTargetMismatch(
                    dueFrameIndex: event.dueFrameIndex,
                    target: metrics.playoutTargetFrames
                )
            }
            if !event.branchBounded {
                throw DriftPlcValidationError.plcNotBranchBounded(
                    missingSequenceNumber: event.missingSequenceNumber
                )
            }
        }
    }

    private func validateCorrectionEvents() throws {
        for event in correctionEvents {
            try DriftPlcValidator.requireNonNegative(event.playoutFrameIndex, "correctionEvents.playoutFrameIndex")
            try DriftPlcValidator.requireNonEmpty(event.notes, "correctionEvents.notes")

            if event.location == .unboundedInsideCallback {
                throw DriftPlcValidationError.correctionInsideUnboundedCallback(
                    playoutFrameIndex: event.playoutFrameIndex
                )
            }
            if event.targetGrowthFrames != 0 {
                throw DriftPlcValidationError.correctionGrewTarget(
                    playoutFrameIndex: event.playoutFrameIndex,
                    targetGrowthFrames: event.targetGrowthFrames
                )
            }
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        if metrics.durationSeconds < DriftPlcMetrics.minimumPassDurationSeconds {
            throw DriftPlcValidationError.passRunTooShort(
                seconds: metrics.durationSeconds,
                minimumSeconds: DriftPlcMetrics.minimumPassDurationSeconds
            )
        }
        if metrics.underruns > 0 {
            throw DriftPlcValidationError.passWithUnderruns(metrics.underruns)
        }
        if !artifactAssessmentCompleted {
            throw DriftPlcValidationError.passWithoutArtifactAssessment
        }
        if let rxBuffer = metrics.rxBuffer,
           !rxBuffer.policy.fastestAudioPassEligible {
            throw DriftPlcValidationError.passWithFastestIneligibleRxBuffer(
                rxBuffer.policy.profile
            )
        }
        for event in correctionEvents where event.location != .outsideCallback {
            throw DriftPlcValidationError.passCorrectionNotOutsideCallback(
                playoutFrameIndex: event.playoutFrameIndex
            )
        }
    }
}
