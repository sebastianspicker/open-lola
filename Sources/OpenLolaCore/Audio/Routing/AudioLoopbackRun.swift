import COpenLolaAtomics
import CoreAudio
import Darwin
import Foundation

public enum AudioLoopbackRunnerKind: String, Codable, Equatable, Sendable {
    case audioDeviceIOProc
    case auhal
}

public enum AudioLoopbackRunState: String, Codable, Equatable, Sendable {
    case blockedPreflight
    case completed
}

public struct AudioLoopbackPreflight: Codable, Equatable, Sendable {
    public let inputDevice: CoreAudioDeviceInventory?
    public let outputDevice: CoreAudioDeviceInventory?
    public let rmeMadiVisible: Bool
    public let sampleRateSupported: Bool
    public let frameSizeInReportedRange: Bool
    public let canStartIOProc: Bool
    public let blockers: [String]

    public init(
        inputDevice: CoreAudioDeviceInventory?,
        outputDevice: CoreAudioDeviceInventory?,
        rmeMadiVisible: Bool,
        sampleRateSupported: Bool,
        frameSizeInReportedRange: Bool,
        canStartIOProc: Bool,
        blockers: [String]
    ) {
        self.inputDevice = inputDevice
        self.outputDevice = outputDevice
        self.rmeMadiVisible = rmeMadiVisible
        self.sampleRateSupported = sampleRateSupported
        self.frameSizeInReportedRange = frameSizeInReportedRange
        self.canStartIOProc = canStartIOProc
        self.blockers = blockers
    }

    public static func evaluate(
        configuration: AudioLoopbackRunConfiguration,
        inventory: CoreAudioInventoryReport
    ) -> AudioLoopbackPreflight {
        let inputDevice = inventory.devices.first { $0.uid == configuration.inputUID }
        let outputDevice = inventory.devices.first { $0.uid == configuration.outputUID }
        let rmeMadiVisible = inventory.devices.contains { isAudioLoopbackRmeMadiDevice($0) }
        let sampleRateSupported = inputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true && outputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true
        let frameSizeInReportedRange = inputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true && outputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true
        var blockers: [String] = []

        if inputDevice == nil {
            blockers.append("input UID not found")
        }
        if outputDevice == nil {
            blockers.append("output UID not found")
        }
        if configuration.inputUID != configuration.outputUID {
            blockers.append("separate input/output devices require a same-device full-duplex RME path")
        }
        if inputDevice?.inputChannelCount ?? 0 <= 0 {
            blockers.append("input device has no input channels")
        }
        if outputDevice?.outputChannelCount ?? 0 <= 0 {
            blockers.append("output device has no output channels")
        }
        if let inputDevice,
           !channelMapFits(configuration.inputChannelMap, available: inputDevice.inputChannelCount) {
            blockers.append("requested input channel map exceeds input device channels")
        }
        if let outputDevice,
           !channelMapFits(configuration.outputChannelMap, available: outputDevice.outputChannelCount) {
            blockers.append("requested output channel map exceeds output device channels")
        }
        if !rmeMadiVisible {
            blockers.append("RME MADI device is not visible")
        }
        if let inputDevice, !isAudioLoopbackRmeMadiDevice(inputDevice) {
            blockers.append("input device is not RME MADI")
        }
        if let outputDevice, !isAudioLoopbackRmeMadiDevice(outputDevice) {
            blockers.append("output device is not RME MADI")
        }
        if inputDevice != nil, !(inputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true) {
            blockers.append("requested sample rate is outside reported input range")
        }
        if outputDevice != nil, !(outputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true) {
            blockers.append("requested sample rate is outside reported output range")
        }
        if inputDevice != nil, !(inputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true) {
            blockers.append("requested frame size is outside reported input range")
        }
        if outputDevice != nil, !(outputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true) {
            blockers.append("requested frame size is outside reported output range")
        }
        if configuration.latencyProfile == .extremeLowLatency8,
           !configuration.experimentalEightFrameOptIn {
            blockers.append("8-frame experimental profile requires explicit opt-in")
        }

        return AudioLoopbackPreflight(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            rmeMadiVisible: rmeMadiVisible,
            sampleRateSupported: sampleRateSupported,
            frameSizeInReportedRange: frameSizeInReportedRange,
            canStartIOProc: blockers.isEmpty,
            blockers: blockers
        )
    }
}

public enum AudioLoopbackRunValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case completedRunMissingCallback
    case completedRunMissingHandoff
    case completedRunMissingCleanup
    case completedRunCleanupFailureMissingNote(String)
    case passVerdictNotAllowedForSingleRun
}

extension AudioLoopbackRunValidationError: ValidationEmptyFieldError {}

enum AudioLoopbackRunValidator: ReportValidationProtocol {
    typealias ValidationError = AudioLoopbackRunValidationError
}

public struct AudioLoopbackRunCleanupFailure: Codable, Equatable, Sendable {
    public let operation: String
    public let status: OSStatus?

    public init(operation: String, status: OSStatus?) {
        self.operation = operation
        self.status = status
    }
}

public struct AudioLoopbackRunCleanupResult: Codable, Equatable, Sendable {
    public let failures: [AudioLoopbackRunCleanupFailure]

    public init(failures: [AudioLoopbackRunCleanupFailure] = []) {
        self.failures = failures
    }

    public var succeeded: Bool { failures.isEmpty }
}

public struct AudioLoopbackRunReport: PrettyJSONCodable, Equatable, Sendable {
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
        id: String,
        capturedAt: String,
        hostName: String,
        runnerKind: AudioLoopbackRunnerKind,
        state: AudioLoopbackRunState,
        configuration: AudioLoopbackRunConfiguration,
        preflight: AudioLoopbackPreflight,
        safety: RealtimeAudioCallbackSafetyChecklist = AudioLoopbackRunReport.callbackSafetyChecklist,
        callback: EndpointCallbackMetrics?,
        handoff: RealtimeAudioHandoffMetrics? = nil,
        cleanup: AudioLoopbackRunCleanupResult? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.hostName = hostName
        self.runnerKind = runnerKind
        self.state = state
        self.configuration = configuration
        self.preflight = preflight
        self.safety = safety
        self.callback = callback
        self.handoff = handoff
        self.cleanup = cleanup
        self.verdict = verdict
        self.notes = notes
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

public enum AudioLoopbackRunError: Error, Equatable, Sendable {
    case coreAudioStatus(OSStatus, String)
    case deviceNotRunnable
    case callbackIntervalBufferAllocationFailed(Int)
}

public struct CoreAudioLoopbackRunner: Sendable {
    private let destroyIOProc: @Sendable (AudioObjectID, AudioDeviceIOProcID) -> OSStatus
    private let restoreDoubleProperty: @Sendable (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        Double
    ) throws -> Void
    private let restoreUInt32Property: @Sendable (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        UInt32
    ) throws -> Void

    public init() {
        self.init(
            destroyIOProc: AudioDeviceDestroyIOProcID,
            restoreDoubleProperty: setDoubleProperty,
            restoreUInt32Property: setUInt32Property
        )
    }

    init(
        destroyIOProc: @escaping @Sendable (AudioObjectID, AudioDeviceIOProcID) -> OSStatus,
        restoreDoubleProperty: @escaping @Sendable (
            AudioObjectID,
            AudioObjectPropertySelector,
            AudioObjectPropertyScope,
            Double
        ) throws -> Void,
        restoreUInt32Property: @escaping @Sendable (
            AudioObjectID,
            AudioObjectPropertySelector,
            AudioObjectPropertyScope,
            UInt32
        ) throws -> Void
    ) {
        self.destroyIOProc = destroyIOProc
        self.restoreDoubleProperty = restoreDoubleProperty
        self.restoreUInt32Property = restoreUInt32Property
    }

    public func run(configuration: AudioLoopbackRunConfiguration) throws -> AudioLoopbackRunReport {
        let inventory = try CoreAudioInventoryReader().capture()
        let preflight = AudioLoopbackPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        )

        guard preflight.canStartIOProc, let deviceID = preflight.inputDevice?.id else {
            return makeRunReport(
                configuration: configuration,
                inventory: inventory,
                preflight: preflight,
                state: .blockedPreflight,
                callback: nil,
                notes: "Core Audio IOProc was not started because preflight blocked the run."
            )
        }

        let result = try runIOProc(
            deviceID: AudioObjectID(deviceID),
            configuration: configuration
        )
        return makeRunReport(
            configuration: configuration,
            inventory: inventory,
            preflight: preflight,
            state: .completed,
            callback: result.callback,
            handoff: result.handoff,
            cleanup: result.cleanup,
            notes: audioLoopbackCompletionNotes(
                base: "Single Core Audio IOProc run completed. This is not an M03 PASS report until analog loopback and the full 16/32/64/128 matrix are measured.",
                cleanup: result.cleanup
            )
        )
    }

    private func runIOProc(
        deviceID: AudioObjectID,
        configuration: AudioLoopbackRunConfiguration
    ) throws -> AudioLoopbackIOProcResult {
        let originalSampleRate = doubleProperty(
            deviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal
        )
        let originalFrames = uint32Property(
            deviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal
        )
        var ioProcID: AudioDeviceIOProcID?
        var cleanupPerformed = false
        defer {
            if !cleanupPerformed {
                _ = cleanupIOProc(
                    deviceID: deviceID,
                    ioProcID: ioProcID,
                    originalSampleRate: originalSampleRate,
                    originalFrames: originalFrames
                )
            }
        }

        try setDoubleProperty(
            deviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            Double(configuration.sampleRateHertz)
        )
        try setUInt32Property(
            deviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal,
            UInt32(configuration.framesPerBuffer)
        )

        let state = try AudioLoopbackIOProcState(configuration: configuration)
        let clientData = Unmanaged.passUnretained(state).toOpaque()
        var status = AudioDeviceCreateIOProcID(
            deviceID,
            audioLoopbackIOProc,
            clientData,
            &ioProcID
        )
        try throwLoopbackIfNeeded(status, "create AudioDeviceIOProcID")

        guard let ioProcID else {
            throw AudioLoopbackRunError.deviceNotRunnable
        }
        status = AudioDeviceStart(deviceID, ioProcID)
        try throwLoopbackIfNeeded(status, "start AudioDeviceIOProc")
        _ = DispatchSemaphore(value: 0).wait(
            timeout: .now() + .seconds(configuration.durationSeconds)
        )
        status = AudioDeviceStop(deviceID, ioProcID)
        try throwLoopbackIfNeeded(status, "stop AudioDeviceIOProc")
        state.markStopped()
        let cleanup = cleanupIOProc(
            deviceID: deviceID,
            ioProcID: ioProcID,
            originalSampleRate: originalSampleRate,
            originalFrames: originalFrames
        )
        cleanupPerformed = true

        return AudioLoopbackIOProcResult(
            callback: state.callbackMetrics(),
            handoff: state.handoffMetrics(),
            cleanup: cleanup
        )
    }

    func cleanupIOProc(
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID?,
        originalSampleRate: Double?,
        originalFrames: UInt32?
    ) -> AudioLoopbackRunCleanupResult {
        var failures: [AudioLoopbackRunCleanupFailure] = []
        if let ioProcID {
            let destroyStatus = destroyIOProc(deviceID, ioProcID)
            if destroyStatus != noErr {
                failures.append(.init(
                    operation: "destroy AudioDeviceIOProcID",
                    status: destroyStatus
                ))
            }
        }
        if let originalSampleRate {
            do {
                try restoreDoubleProperty(
                    deviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalSampleRate
                )
            } catch {
                failures.append(.init(
                    operation: "restore sample rate",
                    status: audioLoopbackStatus(from: error)
                ))
            }
        } else {
            failures.append(.init(operation: "restore sample rate", status: nil))
        }
        if let originalFrames {
            do {
                try restoreUInt32Property(
                    deviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalFrames
                )
            } catch {
                failures.append(.init(
                    operation: "restore buffer frame size",
                    status: audioLoopbackStatus(from: error)
                ))
            }
        } else {
            failures.append(.init(operation: "restore buffer frame size", status: nil))
        }
        return AudioLoopbackRunCleanupResult(failures: failures)
    }
}

private final class AudioLoopbackIOProcState {
    private static let maximumRecordedCallbackIntervals = 100_000
    private static let microsecondsPerSecond = 1_000_000.0

    private let intervalStorage: UnsafeMutablePointer<Double>
    private let intervals: UnsafeMutableBufferPointer<Double>
    private let timebaseNumerator: UInt64
    private let timebaseDenominator: UInt64
    private let expectedIntervalMicroseconds: Double
    private var lastHostTimeNanoseconds: UInt64 = 0
    private var intervalCount = 0
    private var missedDeadlines = 0
    private var underruns = 0
    private var overruns = 0
    private var droppedIntervalSamples = 0
    private var hostTimeConversionFailures = 0
    private var stopped = false
    private var nextFrame = OpenLolaAtomicUInt64()
    private var handoff: RealtimeAudioPacketHandoff
    private let framesPerBuffer: Int

    init(configuration: AudioLoopbackRunConfiguration) throws {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        self.timebaseNumerator = UInt64(info.numer)
        self.timebaseDenominator = UInt64(info.denom)
        self.expectedIntervalMicroseconds = (
            Double(configuration.framesPerBuffer) / Double(configuration.sampleRateHertz)
        ) * Self.microsecondsPerSecond
        self.framesPerBuffer = configuration.framesPerBuffer
        let expectedCallbackProduct = configuration.durationSeconds.multipliedReportingOverflow(
            by: configuration.sampleRateHertz
        )
        let uncappedExpectedCallbacks = expectedCallbackProduct.overflow
            ? Self.maximumRecordedCallbackIntervals
            : max(1, expectedCallbackProduct.partialValue / configuration.framesPerBuffer)
        let recordedCallbackCapacity = min(
            uncappedExpectedCallbacks,
            Self.maximumRecordedCallbackIntervals
        )
        let intervalCapacity = recordedCallbackCapacity + 16
        guard let rawIntervals = calloc(intervalCapacity, MemoryLayout<Double>.stride) else {
            throw AudioLoopbackRunError.callbackIntervalBufferAllocationFailed(intervalCapacity)
        }
        self.intervalStorage = rawIntervals.assumingMemoryBound(to: Double.self)
        self.intervals = UnsafeMutableBufferPointer(start: intervalStorage, count: intervalCapacity)
        self.handoff = try RealtimeAudioPacketHandoff(
            configuration: try audioLoopbackRealtimeConfiguration(for: configuration)
        )
        open_lola_atomic_u64_init(&nextFrame, 0)
    }

    deinit {
        free(UnsafeMutableRawPointer(intervalStorage))
    }

    func record(hostTime: UInt64, input: UnsafePointer<AudioBufferList>) {
        guard let hostTimeNanoseconds = audioLoopbackHostTimeNanoseconds(
            hostTime: hostTime,
            timebaseNumerator: timebaseNumerator,
            timebaseDenominator: timebaseDenominator
        ) else {
            hostTimeConversionFailures += 1
            return
        }
        let startFrame = open_lola_atomic_u64_fetch_add(&nextFrame, UInt64(framesPerBuffer))
        let captureResult = handoff.captureAudioBufferListCallback(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            input: input
        )
        if captureResult == .droppedFull {
            overruns += 1
        }
        let renderResult = handoff.renderCallback()
        if case .silence = renderResult {
            underruns += 1
        }

        guard lastHostTimeNanoseconds > 0 else {
            lastHostTimeNanoseconds = hostTimeNanoseconds
            return
        }

        guard hostTimeNanoseconds > lastHostTimeNanoseconds else {
            droppedIntervalSamples += 1
            return
        }
        let deltaNanoseconds = hostTimeNanoseconds - lastHostTimeNanoseconds
        lastHostTimeNanoseconds = hostTimeNanoseconds
        let deltaMicroseconds = Double(deltaNanoseconds) / 1_000
        if intervalCount < intervals.count {
            intervals[intervalCount] = deltaMicroseconds
            intervalCount += 1
        } else {
            droppedIntervalSamples += 1
        }
        if deltaMicroseconds > expectedIntervalMicroseconds * 1.5 {
            missedDeadlines += 1
        }
    }

    func callbackMetrics() -> EndpointCallbackMetrics {
        precondition(stopped, "AudioLoopbackIOProcState metrics must be read after AudioDeviceStop")
        var values = Array(intervals.prefix(intervalCount))
        values.sort()
        return EndpointCallbackMetrics(
            p50Microseconds: percentile(values, 0.50),
            p95Microseconds: percentile(values, 0.95),
            p99Microseconds: percentile(values, 0.99),
            maxMicroseconds: values.last ?? 0,
            missedDeadlines: missedDeadlines,
            underruns: underruns,
            overruns: overruns,
            recordedIntervalSamples: intervalCount,
            droppedIntervalSamples: droppedIntervalSamples,
            hostTimeConversionFailures: hostTimeConversionFailures
        )
    }

    func handoffMetrics() -> RealtimeAudioHandoffMetrics {
        precondition(stopped, "AudioLoopbackIOProcState handoff metrics must be read after AudioDeviceStop")
        var metrics = handoff.metrics
        metrics.shutdownCompleted = true
        return metrics
    }

    func markStopped() {
        stopped = true
    }
}

func audioLoopbackHostTimeNanoseconds(
    hostTime: UInt64,
    timebaseNumerator: UInt64,
    timebaseDenominator: UInt64
) -> UInt64? {
    guard timebaseDenominator > 0 else {
        return nil
    }
    let (scaledHostTime, overflow) = hostTime.multipliedReportingOverflow(
        by: timebaseNumerator
    )
    guard !overflow else {
        return nil
    }
    return scaledHostTime / timebaseDenominator
}

func audioLoopbackRealtimeConfiguration(
    for configuration: AudioLoopbackRunConfiguration
) throws -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        inputDeviceUID: configuration.inputUID,
        outputDeviceUID: configuration.outputUID,
        sampleRateHertz: configuration.sampleRateHertz,
        framesPerBuffer: configuration.framesPerBuffer,
        channelCount: configuration.channelCount,
        packetFormat: configuration.sampleFormat,
        inputChannelMap: configuration.inputChannelMap,
        outputChannelMap: configuration.outputChannelMap,
        playoutTargetFrames: configuration.framesPerBuffer,
        preallocatedBlockCount: configuration.preallocatedBlockCount,
        rxBufferPolicy: try configuration.rxBufferProfile.policy(
            framesPerPacket: configuration.framesPerBuffer,
            sampleRateHertz: configuration.sampleRateHertz
        )
    )
}

private func audioLoopbackIOProc(
    _: AudioObjectID,
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    if let inClientData {
        let state = Unmanaged<AudioLoopbackIOProcState>
            .fromOpaque(inClientData)
            .takeUnretainedValue()
        state.record(hostTime: inNow.pointee.mHostTime, input: inInputData)
    }
    return copyInputToOutput(input: inInputData, output: outOutputData)
        ? noErr
        : kAudioHardwareBadPropertySizeError
}

private func copyInputToOutput(
    input: UnsafePointer<AudioBufferList>,
    output: UnsafeMutablePointer<AudioBufferList>
) -> Bool {
    let inputBuffers = UnsafeMutableAudioBufferListPointer(
        UnsafeMutablePointer(mutating: input)
    )
    let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
    guard inputBuffers.count == outputBuffers.count else {
        zeroOutputBuffers(outputBuffers)
        return false
    }

    for index in 0..<outputBuffers.count {
        guard let inputData = inputBuffers[index].mData,
              let outputData = outputBuffers[index].mData else {
            if let outputData = outputBuffers[index].mData {
                memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
            }
            continue
        }
        guard inputBuffers[index].mDataByteSize == outputBuffers[index].mDataByteSize else {
            memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
            return false
        }
        memcpy(
            outputData,
            inputData,
            Int(outputBuffers[index].mDataByteSize)
        )
    }
    return true
}

private func zeroOutputBuffers(_ outputBuffers: UnsafeMutableAudioBufferListPointer) {
    for index in 0..<outputBuffers.count {
        if let outputData = outputBuffers[index].mData {
            memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
        }
    }
}
