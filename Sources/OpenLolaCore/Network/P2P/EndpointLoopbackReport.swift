import Foundation

public struct EndpointLoopbackDevice: Codable, Equatable, Sendable {
    public var name: String
    public var uid: String
    public var transportType: String
    public var clockDomain: UInt32?

    public init(
        name: String,
        uid: String,
        transportType: String,
        clockDomain: UInt32?
    ) {
        self.name = name
        self.uid = uid
        self.transportType = transportType
        self.clockDomain = clockDomain
    }
}

public struct EndpointCallbackMetrics: Codable, Equatable, Sendable {
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var missedDeadlines: Int
    public var underruns: Int
    public var overruns: Int
    public var recordedIntervalSamples: Int
    public var droppedIntervalSamples: Int
    public var hostTimeConversionFailures: Int

    public init(
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double,
        missedDeadlines: Int,
        underruns: Int,
        overruns: Int,
        recordedIntervalSamples: Int = 0,
        droppedIntervalSamples: Int = 0,
        hostTimeConversionFailures: Int = 0
    ) {
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
        self.missedDeadlines = missedDeadlines
        self.underruns = underruns
        self.overruns = overruns
        self.recordedIntervalSamples = recordedIntervalSamples
        self.droppedIntervalSamples = droppedIntervalSamples
        self.hostTimeConversionFailures = hostTimeConversionFailures
    }

    private enum CodingKeys: String, CodingKey {
        case p50Microseconds
        case p95Microseconds
        case p99Microseconds
        case maxMicroseconds
        case missedDeadlines
        case underruns
        case overruns
        case recordedIntervalSamples
        case droppedIntervalSamples
        case hostTimeConversionFailures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.p50Microseconds = try container.decode(Double.self, forKey: .p50Microseconds)
        self.p95Microseconds = try container.decode(Double.self, forKey: .p95Microseconds)
        self.p99Microseconds = try container.decode(Double.self, forKey: .p99Microseconds)
        self.maxMicroseconds = try container.decode(Double.self, forKey: .maxMicroseconds)
        self.missedDeadlines = try container.decode(Int.self, forKey: .missedDeadlines)
        self.underruns = try container.decode(Int.self, forKey: .underruns)
        self.overruns = try container.decode(Int.self, forKey: .overruns)
        self.recordedIntervalSamples = try container.decodeIfPresent(
            Int.self,
            forKey: .recordedIntervalSamples
        ) ?? 0
        self.droppedIntervalSamples = try container.decodeIfPresent(
            Int.self,
            forKey: .droppedIntervalSamples
        ) ?? 0
        self.hostTimeConversionFailures = try container.decodeIfPresent(
            Int.self,
            forKey: .hostTimeConversionFailures
        ) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p50Microseconds, forKey: .p50Microseconds)
        try container.encode(p95Microseconds, forKey: .p95Microseconds)
        try container.encode(p99Microseconds, forKey: .p99Microseconds)
        try container.encode(maxMicroseconds, forKey: .maxMicroseconds)
        try container.encode(missedDeadlines, forKey: .missedDeadlines)
        try container.encode(underruns, forKey: .underruns)
        try container.encode(overruns, forKey: .overruns)
        try container.encode(recordedIntervalSamples, forKey: .recordedIntervalSamples)
        try container.encode(droppedIntervalSamples, forKey: .droppedIntervalSamples)
        try container.encode(hostTimeConversionFailures, forKey: .hostTimeConversionFailures)
    }
}

public struct EndpointLoopbackMetrics: Codable, Equatable, Sendable {
    public var reportedInputLatencyFrames: Int
    public var reportedOutputLatencyFrames: Int
    public var inputSafetyOffsetFrames: Int
    public var outputSafetyOffsetFrames: Int
    public var measuredAnalogRoundTripMilliseconds: Double
    public var correctedOneWayMilliseconds: Double
    public var hiddenBufferGrowthDetected: Bool

    public init(
        reportedInputLatencyFrames: Int,
        reportedOutputLatencyFrames: Int,
        inputSafetyOffsetFrames: Int,
        outputSafetyOffsetFrames: Int,
        measuredAnalogRoundTripMilliseconds: Double,
        correctedOneWayMilliseconds: Double,
        hiddenBufferGrowthDetected: Bool
    ) {
        self.reportedInputLatencyFrames = reportedInputLatencyFrames
        self.reportedOutputLatencyFrames = reportedOutputLatencyFrames
        self.inputSafetyOffsetFrames = inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = outputSafetyOffsetFrames
        self.measuredAnalogRoundTripMilliseconds = measuredAnalogRoundTripMilliseconds
        self.correctedOneWayMilliseconds = correctedOneWayMilliseconds
        self.hiddenBufferGrowthDetected = hiddenBufferGrowthDetected
    }
}

public struct EndpointModeResult: Codable, Equatable, Sendable {
    public var mode: AudioMode
    public var accepted: Bool
    public var stable: Bool
    public var rejectionReason: String?
    public var callback: EndpointCallbackMetrics?
    public var loopback: EndpointLoopbackMetrics?
    public var notes: String

    public init(
        mode: AudioMode,
        accepted: Bool,
        stable: Bool,
        rejectionReason: String?,
        callback: EndpointCallbackMetrics?,
        loopback: EndpointLoopbackMetrics?,
        notes: String
    ) {
        self.mode = mode
        self.accepted = accepted
        self.stable = stable
        self.rejectionReason = rejectionReason
        self.callback = callback
        self.loopback = loopback
        self.notes = notes
    }
}

public struct SampleRateLoopbackResult: Codable, Equatable, Sendable {
    public var sampleRateHertz: Int
    public var supported: Bool
    public var unsupportedReason: String?
    public var modeResults: [EndpointModeResult]

    public init(
        sampleRateHertz: Int,
        supported: Bool,
        unsupportedReason: String?,
        modeResults: [EndpointModeResult]
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.supported = supported
        self.unsupportedReason = unsupportedReason
        self.modeResults = modeResults
    }
}

public struct EndpointStabilityRun: Codable, Equatable, Sendable {
    public var mode: AudioMode
    public var durationSeconds: Int
    public var callback: EndpointCallbackMetrics
    public var dropoutEvents: Int
    public var hiddenBufferGrowthDetected: Bool
    public var notes: String

    public init(
        mode: AudioMode,
        durationSeconds: Int,
        callback: EndpointCallbackMetrics,
        dropoutEvents: Int,
        hiddenBufferGrowthDetected: Bool,
        notes: String
    ) {
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.callback = callback
        self.dropoutEvents = dropoutEvents
        self.hiddenBufferGrowthDetected = hiddenBufferGrowthDetected
        self.notes = notes
    }
}

public enum EndpointLoopbackValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case unorderedCallbackMetrics
    case missingRequiredSampleRate(Int)
    case duplicateSampleRate(Int)
    case unsupportedSampleRateMissingReason(Int)
    case supportedSampleRateMissingModes(Int)
    case modeSampleRateMismatch(expected: Int, actual: Int)
    case duplicateFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case missingRequiredFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case acceptedModeMissingCallbackMetrics(sampleRateHertz: Int, framesPerBuffer: Int)
    case acceptedModeMissingLoopbackMetrics(sampleRateHertz: Int, framesPerBuffer: Int)
    case rejectedModeMissingReason(sampleRateHertz: Int, framesPerBuffer: Int)
    case rejectedModeMarkedStable(sampleRateHertz: Int, framesPerBuffer: Int)
    case selectedModeNotAccepted
    case selectedModeNotStable
    case stabilityModeMismatch
    case stabilityRunTooShort(seconds: Int)
    case eightFrameStabilityRunTooShort(seconds: Int, minimumSeconds: Int)
    case dropoutEventsDetected(Int)
    case hiddenBufferGrowthDetected
}

public struct EndpointLoopbackReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public static let requiredSampleRates = [48_000, 96_000, 192_000]
    public static let requiredFrameSizes = [8, 16, 32, 64, 128]
    public static let minimumStabilityDurationSeconds = 1_800
    public static let minimumExtremeLowLatencyDurationSeconds = 7_200

    public var id: String
    public var title: String
    public var capturedAt: String
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var device: EndpointLoopbackDevice
    public var selectedMode: AudioMode
    public var sampleRates: [SampleRateLoopbackResult]
    public var stabilityRun: EndpointStabilityRun
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        hardware: HardwareIdentity,
        route: RouteIdentity,
        device: EndpointLoopbackDevice,
        selectedMode: AudioMode,
        sampleRates: [SampleRateLoopbackResult],
        stabilityRun: EndpointStabilityRun,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.hardware = hardware
        self.route = route
        self.device = device
        self.selectedMode = selectedMode
        self.sampleRates = sampleRates
        self.stabilityRun = stabilityRun
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> EndpointLoopbackReport {
        try JSONDecoder().decode(EndpointLoopbackReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateRequiredSampleRates()
        try validateSelectedMode()
        try validateStabilityRun()
    }

    private func validateIdentity() throws {
        try requireNonEmpty(id, "id")
        try requireNonEmpty(title, "title")
        try requireNonEmpty(capturedAt, "capturedAt")
        try requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try requireNonEmpty(route.label, "route.label")
        try requireNonEmpty(route.topology, "route.topology")
        try requireNonEmpty(device.name, "device.name")
        try requireNonEmpty(device.uid, "device.uid")
        try requireNonEmpty(device.transportType, "device.transportType")
        try validateMode(selectedMode)
    }

    private func validateRequiredSampleRates() throws {
        var sampleRateMap: [Int: SampleRateLoopbackResult] = [:]
        for sampleRate in sampleRates {
            if sampleRateMap[sampleRate.sampleRateHertz] != nil {
                throw EndpointLoopbackValidationError.duplicateSampleRate(
                    sampleRate.sampleRateHertz
                )
            }
            sampleRateMap[sampleRate.sampleRateHertz] = sampleRate
        }

        for requiredSampleRate in Self.requiredSampleRates {
            guard let sampleRate = sampleRateMap[requiredSampleRate] else {
                throw EndpointLoopbackValidationError.missingRequiredSampleRate(requiredSampleRate)
            }
            try validateSampleRate(sampleRate)
        }
    }

    private func validateSampleRate(_ sampleRate: SampleRateLoopbackResult) throws {
        try requirePositive(sampleRate.sampleRateHertz, "sampleRateHertz")

        if !sampleRate.supported {
            try validateUnsupportedSampleRate(sampleRate)
            return
        }

        try validateSupportedSampleRateModes(sampleRate)
        let modeMap = try modeResultsByFrameSize(for: sampleRate)
        try validateRequiredFrameSizes(modeMap, sampleRateHertz: sampleRate.sampleRateHertz)

        for result in sampleRate.modeResults {
            try validateModeResult(result, sampleRateHertz: sampleRate.sampleRateHertz)
        }
    }

    private func validateUnsupportedSampleRate(_ sampleRate: SampleRateLoopbackResult) throws {
        if sampleRate.unsupportedReason == nil || sampleRate.unsupportedReason?.isEmpty == true {
            throw EndpointLoopbackValidationError.unsupportedSampleRateMissingReason(
                sampleRate.sampleRateHertz
            )
        }
    }

    private func validateSupportedSampleRateModes(_ sampleRate: SampleRateLoopbackResult) throws {
        if sampleRate.modeResults.isEmpty {
            throw EndpointLoopbackValidationError.supportedSampleRateMissingModes(
                sampleRate.sampleRateHertz
            )
        }
    }

    private func modeResultsByFrameSize(
        for sampleRate: SampleRateLoopbackResult
    ) throws -> [Int: EndpointModeResult] {
        var modeMap: [Int: EndpointModeResult] = [:]
        for modeResult in sampleRate.modeResults {
            let framesPerBuffer = modeResult.mode.framesPerBuffer
            if modeMap[framesPerBuffer] != nil {
                throw EndpointLoopbackValidationError.duplicateFrameSize(
                    sampleRateHertz: sampleRate.sampleRateHertz,
                    framesPerBuffer: framesPerBuffer
                )
            }
            modeMap[framesPerBuffer] = modeResult
        }
        return modeMap
    }

    private func validateRequiredFrameSizes(
        _ modeMap: [Int: EndpointModeResult],
        sampleRateHertz: Int
    ) throws {
        for requiredFrameSize in Self.requiredFrameSizes {
            guard modeMap[requiredFrameSize] != nil else {
                throw EndpointLoopbackValidationError.missingRequiredFrameSize(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: requiredFrameSize
                )
            }
        }
    }

    private func validateModeResult(
        _ result: EndpointModeResult,
        sampleRateHertz: Int
    ) throws {
        try validateMode(result.mode)
        if result.mode.sampleRateHertz != sampleRateHertz {
            throw EndpointLoopbackValidationError.modeSampleRateMismatch(
                expected: sampleRateHertz,
                actual: result.mode.sampleRateHertz
            )
        }

        if result.accepted {
            guard let callback = result.callback else {
                throw EndpointLoopbackValidationError.acceptedModeMissingCallbackMetrics(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            guard let loopback = result.loopback else {
                throw EndpointLoopbackValidationError.acceptedModeMissingLoopbackMetrics(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            try validateCallback(callback)
            try validateLoopback(loopback)
        } else {
            if result.rejectionReason?.isEmpty != false {
                throw EndpointLoopbackValidationError.rejectedModeMissingReason(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            if result.stable {
                throw EndpointLoopbackValidationError.rejectedModeMarkedStable(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
        }
    }

    private func validateSelectedMode() throws {
        let selectedResult = sampleRates
            .flatMap(\.modeResults)
            .first { $0.mode == selectedMode }

        guard let selectedResult, selectedResult.accepted else {
            throw EndpointLoopbackValidationError.selectedModeNotAccepted
        }
        if !selectedResult.stable {
            throw EndpointLoopbackValidationError.selectedModeNotStable
        }
    }

    private func validateStabilityRun() throws {
        if stabilityRun.mode != selectedMode {
            throw EndpointLoopbackValidationError.stabilityModeMismatch
        }
        if stabilityRun.durationSeconds < Self.minimumStabilityDurationSeconds {
            throw EndpointLoopbackValidationError.stabilityRunTooShort(
                seconds: stabilityRun.durationSeconds
            )
        }
        if selectedMode.framesPerBuffer == 8,
           stabilityRun.durationSeconds < Self.minimumExtremeLowLatencyDurationSeconds {
            throw EndpointLoopbackValidationError.eightFrameStabilityRunTooShort(
                seconds: stabilityRun.durationSeconds,
                minimumSeconds: Self.minimumExtremeLowLatencyDurationSeconds
            )
        }
        try validateCallback(stabilityRun.callback)
        try requireNonNegative(stabilityRun.dropoutEvents, "stabilityRun.dropoutEvents")
        if stabilityRun.dropoutEvents > 0 {
            throw EndpointLoopbackValidationError.dropoutEventsDetected(
                stabilityRun.dropoutEvents
            )
        }
        if stabilityRun.hiddenBufferGrowthDetected {
            throw EndpointLoopbackValidationError.hiddenBufferGrowthDetected
        }
    }
}

private func validateMode(_ mode: AudioMode) throws {
    try requirePositive(mode.sampleRateHertz, "mode.sampleRateHertz")
    try requirePositive(mode.framesPerBuffer, "mode.framesPerBuffer")
    try requirePositive(mode.channelCount, "mode.channelCount")
    try requireNonEmpty(mode.sampleFormat, "mode.sampleFormat")
}

private func validateCallback(_ callback: EndpointCallbackMetrics) throws {
    try requireNonNegative(callback.p50Microseconds, "callback.p50Microseconds")
    try requireNonNegative(callback.p95Microseconds, "callback.p95Microseconds")
    try requireNonNegative(callback.p99Microseconds, "callback.p99Microseconds")
    try requireNonNegative(callback.maxMicroseconds, "callback.maxMicroseconds")
    try requireNonNegative(callback.missedDeadlines, "callback.missedDeadlines")
    try requireNonNegative(callback.underruns, "callback.underruns")
    try requireNonNegative(callback.overruns, "callback.overruns")
    try requireNonNegative(callback.recordedIntervalSamples, "callback.recordedIntervalSamples")
    try requireNonNegative(callback.droppedIntervalSamples, "callback.droppedIntervalSamples")
    try requireNonNegative(callback.hostTimeConversionFailures, "callback.hostTimeConversionFailures")

    guard callback.p50Microseconds <= callback.p95Microseconds,
          callback.p95Microseconds <= callback.p99Microseconds,
          callback.p99Microseconds <= callback.maxMicroseconds else {
        throw EndpointLoopbackValidationError.unorderedCallbackMetrics
    }
}

private func validateLoopback(_ loopback: EndpointLoopbackMetrics) throws {
    try requireNonNegative(
        loopback.reportedInputLatencyFrames,
        "loopback.reportedInputLatencyFrames"
    )
    try requireNonNegative(
        loopback.reportedOutputLatencyFrames,
        "loopback.reportedOutputLatencyFrames"
    )
    try requireNonNegative(loopback.inputSafetyOffsetFrames, "loopback.inputSafetyOffsetFrames")
    try requireNonNegative(loopback.outputSafetyOffsetFrames, "loopback.outputSafetyOffsetFrames")
    try requireNonNegative(
        loopback.measuredAnalogRoundTripMilliseconds,
        "loopback.measuredAnalogRoundTripMilliseconds"
    )
    try requireNonNegative(
        loopback.correctedOneWayMilliseconds,
        "loopback.correctedOneWayMilliseconds"
    )
    if loopback.hiddenBufferGrowthDetected {
        throw EndpointLoopbackValidationError.hiddenBufferGrowthDetected
    }
}

private func requireNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw EndpointLoopbackValidationError.emptyField(field)
    }
}

private func requirePositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw EndpointLoopbackValidationError.nonPositiveField(field)
    }
}

private func requireNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw EndpointLoopbackValidationError.negativeField(field)
    }
}

private func requireNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw EndpointLoopbackValidationError.negativeField(field)
    }
}
