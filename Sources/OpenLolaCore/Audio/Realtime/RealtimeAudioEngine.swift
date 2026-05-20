import Foundation
import OpenLolaContracts

public enum RealtimeAudioHardwarePath: String, Codable, Equatable, Sendable {
    case rmeMadi
    case builtIn
    case synthetic
    case unknown
}

public enum RealtimeAudioCallbackOwner: String, Codable, Equatable, Sendable {
    case audioDeviceIOProc
    case auhalRenderCallback
    case synthetic
}

public struct RealtimeAudioEngineConfiguration: Codable, Equatable, Sendable {
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

    public init(
        inputDeviceUID: String,
        outputDeviceUID: String,
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        channelCount: Int,
        packetFormat: UdpPcmSampleFormat,
        inputChannelMap: [Int],
        outputChannelMap: [Int],
        playoutTargetFrames: Int,
        preallocatedBlockCount: Int,
        rxBufferPolicy: RxBufferPolicy? = nil
    ) {
        self.inputDeviceUID = inputDeviceUID
        self.outputDeviceUID = outputDeviceUID
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.packetFormat = packetFormat
        self.inputChannelMap = inputChannelMap
        self.outputChannelMap = outputChannelMap
        self.playoutTargetFrames = playoutTargetFrames
        self.preallocatedBlockCount = preallocatedBlockCount
        self.rxBufferPolicy = rxBufferPolicy
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
        try validatePositive(sampleRateHertz, "sampleRateHertz")
        try validatePositive(framesPerBuffer, "framesPerBuffer")
        try validatePositive(channelCount, "channelCount")
        try validateNonNegative(playoutTargetFrames, "playoutTargetFrames")
        try validatePositive(preallocatedBlockCount, "preallocatedBlockCount")
        try validateChannelMap(inputChannelMap, channelCount: channelCount, field: "inputChannelMap")
        try validateChannelMap(outputChannelMap, channelCount: channelCount, field: "outputChannelMap")
        _ = try validatedRealtimeAudioPayloadByteCount(
            frameCount: framesPerBuffer,
            channelCount: channelCount,
            bytesPerSample: packetFormat.bytesPerSample
        )
        if let rxBufferPolicy {
            try rxBufferPolicy.validate()
            guard rxBufferPolicy.framesPerPacket == framesPerBuffer else {
                throw RealtimeAudioBufferConfigurationError.mismatchedField(
                    field: "rxBufferPolicy.framesPerPacket",
                    expected: framesPerBuffer,
                    actual: rxBufferPolicy.framesPerPacket
                )
            }
            guard rxBufferPolicy.sampleRateHertz == sampleRateHertz else {
                throw RealtimeAudioBufferConfigurationError.mismatchedField(
                    field: "rxBufferPolicy.sampleRateHertz",
                    expected: sampleRateHertz,
                    actual: rxBufferPolicy.sampleRateHertz
                )
            }
        }
    }
}

func normalizedRealtimeAudioChannelMap(_ channelMap: [Int]?, channelCount: Int) -> [Int] {
    let resolved: [Int]
    if let channelMap, !channelMap.isEmpty {
        resolved = channelMap
    } else {
        resolved = Array(0..<channelCount)
    }
    precondition(resolved.count == channelCount, "channel map must match channel count")
    precondition(resolved.allSatisfy { $0 >= 0 }, "channel map indices must be non-negative")
    return resolved
}

public enum RealtimeAudioBufferConfigurationError: Error, Equatable, Sendable {
    case nonPositiveField(String)
    case negativeField(String)
    case invalidChannelMap(field: String, expected: Int, actual: Int)
    case negativeChannelMapIndex(String)
    case payloadByteCountOverflow
    case mismatchedField(field: String, expected: Int, actual: Int)
}

func validatePositive(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw RealtimeAudioBufferConfigurationError.nonPositiveField(field)
    }
}

func validateNonNegative(_ value: Int, _ field: String) throws {
    guard value >= 0 else {
        throw RealtimeAudioBufferConfigurationError.negativeField(field)
    }
}

func validateChannelMap(_ channelMap: [Int], channelCount: Int, field: String) throws {
    guard !channelMap.isEmpty else { return }
    guard channelMap.count == channelCount else {
        throw RealtimeAudioBufferConfigurationError.invalidChannelMap(
            field: field,
            expected: channelCount,
            actual: channelMap.count
        )
    }
    guard channelMap.allSatisfy({ $0 >= 0 }) else {
        throw RealtimeAudioBufferConfigurationError.negativeChannelMapIndex(field)
    }
}

private extension UdpPcmSampleFormat {
    var audioModeSampleFormat: String {
        switch self {
        case .int16LittleEndian:
            "int16-le"
        case .float32LittleEndian:
            "float32-le"
        }
    }
}

/// Self-attestation checklist. Fields are set by the developer writing the report,
/// not by runtime instrumentation. This is a documentation aid, not a measured check.
/// A violation is only detectable if the developer explicitly sets a field to false.
public struct RealtimeAudioCallbackSafetyChecklist: Codable, Equatable, Sendable {
    public var noAllocationInCallback: Bool
    public var noLoggingInCallback: Bool
    public var noFileIOInCallback: Bool
    public var noLocksOrUnboundedWaitsInCallback: Bool
    public var noNetworkSetupInCallback: Bool
    public var noReportWritingInCallback: Bool
    public var countersOnlyInCallback: Bool

    public init(
        noAllocationInCallback: Bool,
        noLoggingInCallback: Bool,
        noFileIOInCallback: Bool,
        noLocksOrUnboundedWaitsInCallback: Bool,
        noNetworkSetupInCallback: Bool,
        noReportWritingInCallback: Bool,
        countersOnlyInCallback: Bool
    ) {
        self.noAllocationInCallback = noAllocationInCallback
        self.noLoggingInCallback = noLoggingInCallback
        self.noFileIOInCallback = noFileIOInCallback
        self.noLocksOrUnboundedWaitsInCallback = noLocksOrUnboundedWaitsInCallback
        self.noNetworkSetupInCallback = noNetworkSetupInCallback
        self.noReportWritingInCallback = noReportWritingInCallback
        self.countersOnlyInCallback = countersOnlyInCallback
    }

    public var firstViolation: String? {
        if !noAllocationInCallback { return "noAllocationInCallback" }
        if !noLoggingInCallback { return "noLoggingInCallback" }
        if !noFileIOInCallback { return "noFileIOInCallback" }
        if !noLocksOrUnboundedWaitsInCallback { return "noLocksOrUnboundedWaitsInCallback" }
        if !noNetworkSetupInCallback { return "noNetworkSetupInCallback" }
        if !noReportWritingInCallback { return "noReportWritingInCallback" }
        if !countersOnlyInCallback { return "countersOnlyInCallback" }
        return nil
    }
}

public struct RealtimeAudioHandoffMetrics: Codable, Equatable, Sendable {
    public var inputBlocks: Int
    public var outputBlocks: Int
    public var networkSendBlocks: Int
    public var networkReceiveBlocks: Int
    public var droppedInputBlocks: Int
    public var droppedNetworkBlocks: Int
    public var outputUnderrunBlocks: Int
    public var callbackOverrunBlocks: Int
    public var latePackets: Int
    public var maximumBufferedBlocks: Int
    public var ringCapacityBlocks: Int
    public var fullCaptureRingBlocks: Int
    public var invalidInputBlocks: Int
    public var directInputBlocks: Int
    public var remappedInputBlocks: Int
    public var packetFragmentCount: Int
    public var allocationWarnings: Int
    public var maximumCaptureRingOccupancyBlocks: Int
    public var maximumPlayoutQueueDepthBlocks: Int
    public var packetizationDuration: PerformanceCounterSummary
    public var depacketizationDuration: PerformanceCounterSummary
    public var hiddenPlayoutGrowthDetected: Bool
    public var shutdownCompleted: Bool
    public var rxBuffer: RxBufferRuntimeSnapshot?

    public init(
        inputBlocks: Int,
        outputBlocks: Int,
        networkSendBlocks: Int,
        networkReceiveBlocks: Int,
        droppedInputBlocks: Int,
        droppedNetworkBlocks: Int,
        outputUnderrunBlocks: Int,
        callbackOverrunBlocks: Int,
        latePackets: Int,
        maximumBufferedBlocks: Int,
        ringCapacityBlocks: Int,
        fullCaptureRingBlocks: Int,
        invalidInputBlocks: Int,
        directInputBlocks: Int,
        remappedInputBlocks: Int,
        packetFragmentCount: Int,
        allocationWarnings: Int,
        maximumCaptureRingOccupancyBlocks: Int,
        maximumPlayoutQueueDepthBlocks: Int,
        packetizationDuration: PerformanceCounterSummary,
        depacketizationDuration: PerformanceCounterSummary,
        hiddenPlayoutGrowthDetected: Bool,
        shutdownCompleted: Bool,
        rxBuffer: RxBufferRuntimeSnapshot?
    ) {
        self.inputBlocks = inputBlocks
        self.outputBlocks = outputBlocks
        self.networkSendBlocks = networkSendBlocks
        self.networkReceiveBlocks = networkReceiveBlocks
        self.droppedInputBlocks = droppedInputBlocks
        self.droppedNetworkBlocks = droppedNetworkBlocks
        self.outputUnderrunBlocks = outputUnderrunBlocks
        self.callbackOverrunBlocks = callbackOverrunBlocks
        self.latePackets = latePackets
        self.maximumBufferedBlocks = maximumBufferedBlocks
        self.ringCapacityBlocks = ringCapacityBlocks
        self.fullCaptureRingBlocks = fullCaptureRingBlocks
        self.invalidInputBlocks = invalidInputBlocks
        self.directInputBlocks = directInputBlocks
        self.remappedInputBlocks = remappedInputBlocks
        self.packetFragmentCount = packetFragmentCount
        self.allocationWarnings = allocationWarnings
        self.maximumCaptureRingOccupancyBlocks = maximumCaptureRingOccupancyBlocks
        self.maximumPlayoutQueueDepthBlocks = maximumPlayoutQueueDepthBlocks
        self.packetizationDuration = packetizationDuration
        self.depacketizationDuration = depacketizationDuration
        self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
        self.shutdownCompleted = shutdownCompleted
        self.rxBuffer = rxBuffer
    }

}

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

public struct RealtimeAudioEngineReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
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
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.hardwarePath = hardwarePath
        self.hardware = hardware
        self.configuration = configuration
        self.safety = safety
        self.runtime = runtime
        self.sourceRmeFastestAudioReport = sourceRmeFastestAudioReport
        self.sourceRouteCertificationReport = sourceRouteCertificationReport
        self.runArtifactPath = runArtifactPath
        self.verdict = verdict
        self.notes = notes
    }
}
