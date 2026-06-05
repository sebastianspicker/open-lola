import CoreAudio
import COpenLolaAtomics
import Darwin
import Foundation
import os

let directPeerRealtimeAudioBufferAlignment = max(16, MemoryLayout<Float>.alignment)

private enum DirectPeerInputCopyResult: Equatable {
    case copied
    case invalidSourceChannelCount
    case destinationChannelOutOfRange
    case inputChannelOutOfRange
    case inputBufferUnavailable
    case invalidByteOffset
    case inputBufferTooSmall
    case destinationBufferTooSmall
}

private struct DirectPeerReadOnlyAudioBufferLocation {
    var buffer: AudioBuffer
    var channelIndex: Int
    var channelCount: Int
}

private struct DirectPeerMutableAudioBufferLocation {
    var data: UnsafeMutableRawPointer
    var byteCount: Int
    var channelIndex: Int
    var channelCount: Int
}

private struct DirectPeerIOProcCleanupTarget {
    var role: String
    var deviceID: AudioObjectID
    var ioProcID: AudioDeviceIOProcID
}

public final class DirectPeerRealtimeAudioGraph: @unchecked Sendable {
    public let configuration: DirectPeerRealtimeAudioGraphConfiguration
    public let captureRing: DirectPeerAudioPayloadRing
    public let playoutRing: DirectPeerAudioPayloadRing

    private var nextInputFrame = OpenLolaAtomicUInt64()
    private var nextOutputFrame = OpenLolaAtomicUInt64()
    private var inputDeviceID: AudioObjectID?
    private var outputDeviceID: AudioObjectID?
    private var inputIOProcID: AudioDeviceIOProcID?
    private var outputIOProcID: AudioDeviceIOProcID?
    private var originalInputSampleRate: Double?
    private var originalOutputSampleRate: Double?
    private var originalInputBufferFrameSize: UInt32?
    private var originalOutputBufferFrameSize: UInt32?
    private var capturedInputBlocks = OpenLolaAtomicUInt64()
    private var droppedInputBlocks = OpenLolaAtomicUInt64()
    private var inputOverrunBlocks = OpenLolaAtomicUInt64()
    private var outputBlocks = OpenLolaAtomicUInt64()
    private var droppedOutputBlocks = OpenLolaAtomicUInt64()
    private var outputUnderrunBlocks = OpenLolaAtomicUInt64()
    var callbackInvocationBlocks = OpenLolaAtomicUInt64()
    private var callbackMaxMicroseconds = OpenLolaAtomicUInt64()
    private var callbackDeadlineMisses = OpenLolaAtomicUInt64()
    private var callbackOverrunBlocks = OpenLolaAtomicUInt64()
    private var hostTimeConversionFailures = OpenLolaAtomicUInt64()
    var ioProcRunning = OpenLolaAtomicUInt64()
    var activeIOProcCallbacks = OpenLolaAtomicUInt64()
    private var latestCleanupResult = DirectPeerRealtimeAudioGraphCleanupResult()
    private var inputScratch: UnsafeMutableRawPointer
    private var outputScratch: UnsafeMutableRawPointer
    private let hostTimeNumerator: UInt64
    private let hostTimeDenominator: UInt64
    private let lifecycleLock = NSLock()
    let rxBufferAdaptationLock = NSLock()
    var rxBufferSnapshot: RxBufferRuntimeSnapshot? = nil
    var adaptiveRxBufferController: RxBufferAdaptiveController? = nil
    #if DEBUG
    var stopDeviceForTesting: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = AudioDeviceStop
    var destroyIOProcForTesting: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = AudioDeviceDestroyIOProcID
    var setDoublePropertyForTesting: (AudioObjectID, AudioObjectPropertySelector, AudioObjectPropertyScope, Double) throws -> Void = setDoubleProperty
    var setUInt32PropertyForTesting: (AudioObjectID, AudioObjectPropertySelector, AudioObjectPropertyScope, UInt32) throws -> Void = setUInt32Property
    var hostTimeConversionForTesting: ((UInt64) -> UInt64?)?
    var callbackTimingTickForTesting: (() -> UInt64)?
    #endif

    public init(configuration: DirectPeerRealtimeAudioGraphConfiguration) throws {
        try configuration.validateRealtimeBufferInputs()
        self.configuration = configuration
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        self.hostTimeNumerator = UInt64(timebase.numer)
        self.hostTimeDenominator = UInt64(timebase.denom)
        precondition(self.hostTimeDenominator > 0, "mach timebase denominator must be positive")
        self.captureRing = DirectPeerAudioPayloadRing(
            capacity: configuration.ringCapacityBlocks,
            payloadByteCount: configuration.payloadByteCount,
            frameCount: configuration.framesPerBuffer
        )
        self.playoutRing = DirectPeerAudioPayloadRing(
            capacity: configuration.ringCapacityBlocks,
            payloadByteCount: configuration.payloadByteCount,
            frameCount: configuration.framesPerBuffer
        )
        self.inputScratch = UnsafeMutableRawPointer.allocate(
            byteCount: configuration.payloadByteCount,
            alignment: directPeerRealtimeAudioBufferAlignment
        )
        self.outputScratch = UnsafeMutableRawPointer.allocate(
            byteCount: configuration.payloadByteCount,
            alignment: directPeerRealtimeAudioBufferAlignment
        )
        if let policy = configuration.rxBufferPolicy {
            self.rxBufferSnapshot = RxBufferRuntimeSnapshot(policy: policy)
            if policy.profile == .adaptive { self.adaptiveRxBufferController = try .runtimeController(policy: policy) }
        }
        memset(self.inputScratch, 0, configuration.payloadByteCount)
        memset(self.outputScratch, 0, configuration.payloadByteCount)
        open_lola_atomic_u64_init(&nextInputFrame, 0)
        open_lola_atomic_u64_init(&nextOutputFrame, 0)
        open_lola_atomic_u64_init(&capturedInputBlocks, 0)
        open_lola_atomic_u64_init(&droppedInputBlocks, 0)
        open_lola_atomic_u64_init(&inputOverrunBlocks, 0)
        open_lola_atomic_u64_init(&outputBlocks, 0)
        open_lola_atomic_u64_init(&droppedOutputBlocks, 0)
        open_lola_atomic_u64_init(&outputUnderrunBlocks, 0)
        open_lola_atomic_u64_init(&callbackInvocationBlocks, 0)
        open_lola_atomic_u64_init(&callbackMaxMicroseconds, 0)
        open_lola_atomic_u64_init(&callbackDeadlineMisses, 0)
        open_lola_atomic_u64_init(&callbackOverrunBlocks, 0)
        open_lola_atomic_u64_init(&hostTimeConversionFailures, 0)
        open_lola_atomic_u64_init(&ioProcRunning, 0)
        open_lola_atomic_u64_init(&activeIOProcCallbacks, 0)
    }

    deinit {
        _ = stopUnlocked()
        inputScratch.deallocate()
        outputScratch.deallocate()
    }

    public static func preflight(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        inventory: CoreAudioInventoryReport
    ) throws -> DirectPeerRealtimeAudioGraphPreflight {
        let preflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        )
        guard let device = preflight.device else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.inputDeviceUID)
        }
        guard let outputDevice = preflight.outputDevice else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
        }
        guard preflight.fullDuplexSupported else {
            throw DirectPeerAudioGraphError.deviceNotFullDuplex(
                configuration.inputDeviceUID == configuration.outputDeviceUID ? device.uid : outputDevice.uid
            )
        }
        guard preflight.sampleRateSupported else {
            throw DirectPeerAudioGraphError.unsupportedSampleRate(
                uid: device.uid,
                sampleRateHertz: configuration.sampleRateHertz
            )
        }
        guard preflight.frameSizeSupported else {
            throw DirectPeerAudioGraphError.unsupportedFrameSize(
                uid: device.uid,
                framesPerBuffer: configuration.framesPerBuffer
            )
        }
        try validateChannelMap(
            configuration.inputChannelMap,
            scope: .input,
            available: device.inputChannelCount,
            expectedCount: configuration.channelCount
        )
        try validateChannelMap(
            configuration.outputChannelMap,
            scope: .output,
            available: outputDevice.outputChannelCount,
            expectedCount: configuration.channelCount
        )
        return preflight
    }

    public func start(deviceID: AudioObjectID) throws {
        try start(inputDeviceID: deviceID, outputDeviceID: deviceID)
    }

    public func start(inputDeviceID: AudioObjectID, outputDeviceID: AudioObjectID) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard inputIOProcID == nil,
              outputIOProcID == nil,
              open_lola_atomic_u64_load(&ioProcRunning) == 0 else {
            throw DirectPeerAudioGraphError.graphAlreadyStarted
        }
        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID
        originalInputSampleRate = doubleProperty(inputDeviceID, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal)
        originalInputBufferFrameSize = uint32Property(inputDeviceID, kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal)
        originalOutputSampleRate = inputDeviceID == outputDeviceID
            ? originalInputSampleRate
            : doubleProperty(outputDeviceID, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal)
        originalOutputBufferFrameSize = inputDeviceID == outputDeviceID
            ? originalInputBufferFrameSize
            : uint32Property(outputDeviceID, kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal)
        do {
            try configureDevice(inputDeviceID)
            if inputDeviceID != outputDeviceID {
                try configureDevice(outputDeviceID)
            }
            open_lola_atomic_u64_store(&activeIOProcCallbacks, 0)
            open_lola_atomic_u64_store(&ioProcRunning, 1)
            if inputDeviceID == outputDeviceID {
                inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioIOProc)
            } else {
                inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioInputIOProc)
                outputIOProcID = try makeAndStartIOProc(deviceID: outputDeviceID, ioProc: directPeerRealtimeAudioOutputIOProc)
            }
        } catch {
            let cleanupResult = stopUnlocked()
            if !cleanupResult.succeeded {
                os_log(
                    .fault,
                    "Audio graph cleanup during start failure also failed: %{public}@",
                    directPeerRealtimeAudioCleanupFailureSummary(cleanupResult)
                )
            }
            throw error
        }
    }

    public func runtimeCounters() -> DirectPeerRealtimeAudioGraphRuntimeCounters {
        DirectPeerRealtimeAudioGraphRuntimeCounters(
            capturedInputBlocks: Int(open_lola_atomic_u64_load(&capturedInputBlocks)),
            droppedInputBlocks: Int(open_lola_atomic_u64_load(&droppedInputBlocks)),
            inputOverrunBlocks: Int(open_lola_atomic_u64_load(&inputOverrunBlocks)),
            outputBlocks: Int(open_lola_atomic_u64_load(&outputBlocks)),
            droppedOutputBlocks: Int(open_lola_atomic_u64_load(&droppedOutputBlocks)),
            outputUnderrunBlocks: Int(open_lola_atomic_u64_load(&outputUnderrunBlocks)),
            callbackInvocationBlocks: Int(open_lola_atomic_u64_load(&callbackInvocationBlocks)),
            callbackMaxMicroseconds: Int(open_lola_atomic_u64_load(&callbackMaxMicroseconds)),
            callbackDeadlineMisses: Int(open_lola_atomic_u64_load(&callbackDeadlineMisses)),
            callbackOverrunBlocks: Int(open_lola_atomic_u64_load(&callbackOverrunBlocks)),
            hostTimeConversionFailures: Int(open_lola_atomic_u64_load(&hostTimeConversionFailures))
        )
    }

    private func configureDevice(_ deviceID: AudioObjectID) throws {
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
    }

    private func makeAndStartIOProc(deviceID: AudioObjectID, ioProc: AudioDeviceIOProc) throws -> AudioDeviceIOProcID {
        let clientData = Unmanaged.passUnretained(self).toOpaque()
        var createdIOProcID: AudioDeviceIOProcID?
        var status = AudioDeviceCreateIOProcID(
            deviceID,
            ioProc,
            clientData,
            &createdIOProcID
        )
        try throwDirectPeerAudioStatusIfNeeded(status, "create AudioDeviceIOProcID")
        guard let createdIOProcID else { throw DirectPeerAudioGraphError.graphNotStarted }
        status = AudioDeviceStart(deviceID, createdIOProcID)
        do {
            try throwDirectPeerAudioStatusIfNeeded(status, "start AudioDeviceIOProc")
        } catch {
            let cleanupStatus = destroyIOProc(deviceID, createdIOProcID)
            if cleanupStatus != noErr {
                os_log(
                    .error,
                    "AudioDeviceDestroyIOProcID failed after start failure with status %{public}d",
                    cleanupStatus
                )
            }
            throw error
        }
        return createdIOProcID
    }

    @discardableResult
    public func stop() -> DirectPeerRealtimeAudioGraphCleanupResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return stopUnlocked()
    }

    public func lastCleanupResult() -> DirectPeerRealtimeAudioGraphCleanupResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return latestCleanupResult
    }

    private func stopUnlocked() -> DirectPeerRealtimeAudioGraphCleanupResult {
        var result = DirectPeerRealtimeAudioGraphCleanupResult()
        let ioProcsToDestroy = stopActiveIOProcs(result: &result)
        clearRunningFlagIfNeeded(hasStoppedIOProcs: !ioProcsToDestroy.isEmpty)
        destroyStoppedIOProcs(ioProcsToDestroy, result: &result)
        restoreDeviceSettings(result: &result)
        latestCleanupResult = result
        guard result.succeeded else {
            return result
        }
        clearStoppedGraphState()
        return result
    }

    private func stopActiveIOProcs(
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) -> [DirectPeerIOProcCleanupTarget] {
        var ioProcsToDestroy: [DirectPeerIOProcCleanupTarget] = []
        if let inputDeviceID, let inputIOProcID {
            stopActiveIOProc(
                role: "input",
                deviceID: inputDeviceID,
                ioProcID: inputIOProcID,
                result: &result,
                targets: &ioProcsToDestroy
            )
        }
        if let outputDeviceID, let outputIOProcID {
            stopActiveIOProc(
                role: "output",
                deviceID: outputDeviceID,
                ioProcID: outputIOProcID,
                result: &result,
                targets: &ioProcsToDestroy
            )
        }
        return ioProcsToDestroy
    }

    private func stopActiveIOProc(
        role: String,
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult,
        targets: inout [DirectPeerIOProcCleanupTarget]
    ) {
        let status = stopDevice(deviceID, ioProcID)
        recordCleanupStatus(status, operation: "stop \(role) AudioDeviceIOProc", result: &result)
        targets.append(.init(role: role, deviceID: deviceID, ioProcID: ioProcID))
    }

    private func clearRunningFlagIfNeeded(hasStoppedIOProcs: Bool) {
        if hasStoppedIOProcs || open_lola_atomic_u64_load(&ioProcRunning) != 0 {
            open_lola_atomic_u64_store(&ioProcRunning, 0)
        }
    }

    private func destroyStoppedIOProcs(
        _ targets: [DirectPeerIOProcCleanupTarget],
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        guard !targets.isEmpty else { return }
        guard waitForIOProcQuiescence() else {
            recordQuiescenceFailures(for: targets, result: &result)
            return
        }
        for target in targets {
            destroyStoppedIOProc(target, result: &result)
        }
    }

    private func destroyStoppedIOProc(
        _ target: DirectPeerIOProcCleanupTarget,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        let status = destroyIOProc(target.deviceID, target.ioProcID)
        recordCleanupStatus(
            status,
            operation: "destroy \(target.role) AudioDeviceIOProc",
            result: &result
        )
        guard status == noErr else { return }
        if target.role == "input" {
            self.inputIOProcID = nil
        } else {
            self.outputIOProcID = nil
        }
    }

    private func recordQuiescenceFailures(
        for targets: [DirectPeerIOProcCleanupTarget],
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        for target in targets {
            result.failures.append(.init(
                operation: "wait for \(target.role) AudioDeviceIOProc quiescence",
                status: nil
            ))
        }
    }

    private func restoreDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        restoreInputDeviceSettings(result: &result)
        restoreOutputDeviceSettings(result: &result)
    }

    private func restoreInputDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        if let inputDeviceID, let originalInputSampleRate {
            recordCleanupRestore(
                operation: "restore input sample rate",
                result: &result
            ) {
                try setDoublePropertyForGraph(
                    inputDeviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalInputSampleRate
                )
            }
        }
        if let inputDeviceID, let originalInputBufferFrameSize {
            recordCleanupRestore(
                operation: "restore input buffer frame size",
                result: &result
            ) {
                try setUInt32PropertyForGraph(
                    inputDeviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalInputBufferFrameSize
                )
            }
        }
    }

    private func restoreOutputDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputSampleRate {
            recordCleanupRestore(
                operation: "restore output sample rate",
                result: &result
            ) {
                try setDoublePropertyForGraph(
                    outputDeviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalOutputSampleRate
                )
            }
        }
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputBufferFrameSize {
            recordCleanupRestore(
                operation: "restore output buffer frame size",
                result: &result
            ) {
                try setUInt32PropertyForGraph(
                    outputDeviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalOutputBufferFrameSize
                )
            }
        }
    }

    private func clearStoppedGraphState() {
        open_lola_atomic_u64_store(&ioProcRunning, 0)
        self.inputIOProcID = nil
        self.outputIOProcID = nil
        self.inputDeviceID = nil
        self.outputDeviceID = nil
        self.originalInputSampleRate = nil
        self.originalOutputSampleRate = nil
        self.originalInputBufferFrameSize = nil
        self.originalOutputBufferFrameSize = nil
    }

    #if DEBUG
    func setCleanupStateForTesting(
        inputDeviceID: AudioObjectID?,
        inputIOProcID: AudioDeviceIOProcID?,
        outputDeviceID: AudioObjectID?,
        outputIOProcID: AudioDeviceIOProcID?,
        originalInputSampleRate: Double?,
        originalInputBufferFrameSize: UInt32?,
        originalOutputSampleRate: Double?,
        originalOutputBufferFrameSize: UInt32?
    ) {
        self.inputDeviceID = inputDeviceID
        self.inputIOProcID = inputIOProcID
        self.outputDeviceID = outputDeviceID
        self.outputIOProcID = outputIOProcID
        self.originalInputSampleRate = originalInputSampleRate
        self.originalInputBufferFrameSize = originalInputBufferFrameSize
        self.originalOutputSampleRate = originalOutputSampleRate
        self.originalOutputBufferFrameSize = originalOutputBufferFrameSize
    }

    func setCleanupOperationOverridesForTesting(
        stop: @escaping (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { _, _ in noErr },
        destroy: @escaping (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { _, _ in noErr },
        setDouble: @escaping (AudioObjectID, AudioObjectPropertySelector, AudioObjectPropertyScope, Double) throws -> Void = { _, _, _, _ in },
        setUInt32: @escaping (AudioObjectID, AudioObjectPropertySelector, AudioObjectPropertyScope, UInt32) throws -> Void = { _, _, _, _ in }
    ) {
        stopDeviceForTesting = stop
        destroyIOProcForTesting = destroy
        setDoublePropertyForTesting = setDouble
        setUInt32PropertyForTesting = setUInt32
    }

    func setHostTimeConversionForTesting(_ conversion: ((UInt64) -> UInt64?)?) {
        hostTimeConversionForTesting = conversion
    }

    func setCallbackTimingTickForTesting(_ tick: (() -> UInt64)?) {
        callbackTimingTickForTesting = tick
    }

    func lifecycleLockForTesting() -> NSLock {
        lifecycleLock
    }
    #endif

    /// Injects a synthetic capture payload only while the realtime IOProc is stopped.
    public func captureInjectedPayload(_ payload: Data, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard open_lola_atomic_u64_load(&ioProcRunning) == 0 else {
            recordCaptureResult(.invalid)
            return .invalid
        }
        let startFrame = reserveInputStartFrame()
        let result = payload.withUnsafeBytes { bytes in
            captureRing.push(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceBytes: bytes
            )
        }
        recordCaptureResult(result)
        return result
    }

    public func withCapturedPayload<Result>(
        _ body: (RealtimeAudioFrameBlock, UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result? {
        try captureRing.withPoppedPayload(body)
    }

    public func queuePlayoutPayload(_ payload: Data, startFrame: UInt64, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        let playoutStartFrameResult = startFrame.addingReportingOverflow(UInt64(currentPlayoutTargetFrames()))
        guard !playoutStartFrameResult.overflow else {
            increment(&droppedOutputBlocks)
            observeAdaptiveRxBuffer(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                pressure: true
            )
            return .invalid
        }
        let playoutStartFrame = playoutStartFrameResult.partialValue
        let result = payload.withUnsafeBytes { bytes in
            playoutRing.push(
                startFrame: playoutStartFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceBytes: bytes
            )
        }
        if result == .full {
            increment(&droppedOutputBlocks)
        }
        observeAdaptiveRxBuffer(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            pressure: result != .stored
        )
        return result
    }

    func captureInputForTesting(input: UnsafePointer<AudioBufferList>, hostTimeNanoseconds: UInt64) {
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
    }

    func renderPlayoutForTesting(output: UnsafeMutablePointer<AudioBufferList>) {
        renderPlayout(output: output)
    }

    #if DEBUG
    func setIOProcRunningForTesting(_ running: Bool) {
        open_lola_atomic_u64_store(&ioProcRunning, running ? 1 : 0)
    }
    #endif

    func processIO(
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>
    ) {
        let start = callbackTimingTick()
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
        renderPlayout(output: output)
        recordCallbackDuration(startTicks: start)
    }

    func processInputIO(
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>
    ) {
        let start = callbackTimingTick()
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
        recordCallbackDuration(startTicks: start)
    }

    func processOutputIO(output: UnsafeMutablePointer<AudioBufferList>) {
        let start = callbackTimingTick()
        renderPlayout(output: output)
        recordCallbackDuration(startTicks: start)
    }

    func nanoseconds(fromHostTime hostTime: UInt64) -> UInt64? {
        #if DEBUG
        if let hostTimeConversionForTesting {
            return hostTimeConversionForTesting(hostTime)
        }
        #endif
        precondition(hostTimeDenominator > 0, "mach timebase denominator must be positive")
        return nanosecondsFromHostTime(hostTime, numerator: hostTimeNumerator, denominator: hostTimeDenominator)
    }

    func recordHostTimeConversionFailure() {
        increment(&hostTimeConversionFailures)
    }

    private func copyInputToCaptureRing(
        input: UnsafePointer<AudioBufferList>,
        hostTimeNanoseconds: UInt64
    ) {
        let buffers = ReadOnlyAudioBufferListPointer(input)
        guard !buffers.isEmpty else {
            return
        }
        let copyResult = copyMappedInput(from: buffers)
        guard copyResult == .copied else {
            increment(&droppedInputBlocks)
            return
        }
        let startFrame = reserveInputStartFrame()
        let result = captureRing.push(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            sourceBytes: UnsafeRawBufferPointer(start: inputScratch, count: configuration.payloadByteCount)
        )
        recordCaptureResult(result)
    }

    private func renderPlayout(output: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        guard !buffers.isEmpty else {
            return
        }
        let dueFrame = open_lola_atomic_u64_load(&nextOutputFrame)
        let stalePayloads = playoutRing.dropPayloads(before: dueFrame)
        for _ in 0..<stalePayloads {
            increment(&droppedOutputBlocks)
        }
        let copied = playoutRing.copyPayload(
            startFrame: dueFrame,
            to: outputScratch,
            byteCount: configuration.payloadByteCount
        )
        clearOutput(buffers)
        if copied {
            if !copyMappedOutput(to: buffers) {
                increment(&droppedOutputBlocks)
            }
        } else {
            increment(&outputUnderrunBlocks)
        }
        increment(&outputBlocks)
        reserveOutputStartFrame()
    }

    private func copyMappedInput(from buffers: ReadOnlyAudioBufferListPointer) -> DirectPeerInputCopyResult {
        memset(inputScratch, 0, configuration.payloadByteCount)
        if buffers.count == 1 {
            return copyMappedInputFromSingleBuffer(buffers)
        }
        return copyMappedInputFromSplitBuffers(buffers)
    }

    private func copyMappedInputFromSingleBuffer(
        _ buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerInputCopyResult {
        guard let sourceBuffer = buffers[0], let source = sourceBuffer.mData else {
            return .inputBufferUnavailable
        }
        let sourceChannels = Int(sourceBuffer.mNumberChannels)
        guard sourceChannels > 0 else { return .invalidSourceChannelCount }
        for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
            guard outputChannel < configuration.channelCount else {
                return .destinationChannelOutOfRange
            }
            guard inputChannel >= 0, inputChannel < sourceChannels else {
                return .inputChannelOutOfRange
            }
            let result = copyMappedInputChannel(
                source: UnsafeRawPointer(source),
                sourceChannel: inputChannel,
                sourceChannelCount: sourceChannels,
                sourceByteCount: Int(sourceBuffer.mDataByteSize),
                destinationChannel: outputChannel
            )
            guard result == .copied else { return result }
        }
        return .copied
    }

    private func copyMappedInputFromSplitBuffers(
        _ buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerInputCopyResult {
        for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
            guard outputChannel < configuration.channelCount else {
                return .destinationChannelOutOfRange
            }
            guard inputChannel >= 0 else { return .inputChannelOutOfRange }
            guard let sourceLocation = readOnlyBufferLocation(
                forStableChannel: inputChannel,
                in: buffers
            ) else {
                return totalChannelCount(in: buffers) > 0
                    ? .inputChannelOutOfRange
                    : .invalidSourceChannelCount
            }
            guard let source = sourceLocation.buffer.mData else {
                return .inputBufferUnavailable
            }
            let result = copyMappedInputChannel(
                source: UnsafeRawPointer(source),
                sourceChannel: sourceLocation.channelIndex,
                sourceChannelCount: sourceLocation.channelCount,
                sourceByteCount: Int(sourceLocation.buffer.mDataByteSize),
                destinationChannel: outputChannel
            )
            guard result == .copied else { return result }
        }
        return .copied
    }

    private func copyMappedInputChannel(
        source: UnsafeRawPointer,
        sourceChannel: Int,
        sourceChannelCount: Int,
        sourceByteCount: Int,
        destinationChannel: Int
    ) -> DirectPeerInputCopyResult {
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        switch audioChannelCopyPlan(
            request: DirectPeerAudioChannelCopyPlanRequest(
                source: DirectPeerAudioChannelCopyEndpoint(
                    channel: sourceChannel,
                    channelCount: sourceChannelCount,
                    byteCount: sourceByteCount
                ),
                destination: DirectPeerAudioChannelCopyEndpoint(
                    channel: destinationChannel,
                    channelCount: configuration.channelCount,
                    byteCount: configuration.payloadByteCount
                ),
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
        ) {
        case let .valid(plan):
            copyAudioChannelBytes(
                source: source,
                destination: inputScratch,
                plan: plan,
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
            return .copied
        case .invalidByteOffset:
            return .invalidByteOffset
        case .sourceBufferTooSmall:
            return .inputBufferTooSmall
        case .destinationBufferTooSmall:
            return .destinationBufferTooSmall
        }
    }

    private func clearOutput(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers where buffer.mData != nil {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
    }

    private func copyMappedOutput(to buffers: UnsafeMutableAudioBufferListPointer) -> Bool {
        if buffers.count == 1, let destination = buffers[0].mData {
            return copyMappedOutputToSingleBuffer(destination, buffer: buffers[0])
        }
        return copyMappedOutputToSplitBuffers(buffers)
    }

    private func copyMappedOutputToSingleBuffer(
        _ destination: UnsafeMutableRawPointer,
        buffer: AudioBuffer
    ) -> Bool {
        let destinationChannels = Int(buffer.mNumberChannels)
        guard destinationChannels > 0 else { return false }
        for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
            guard inputChannel < configuration.channelCount,
                  outputChannel >= 0,
                  outputChannel < destinationChannels else {
                return false
            }
            guard copyMappedOutputChannel(
                destination: destination,
                destinationChannel: outputChannel,
                destinationChannelCount: destinationChannels,
                destinationByteCount: Int(buffer.mDataByteSize),
                inputChannel: inputChannel
            ) else {
                return false
            }
        }
        return true
    }

    private func copyMappedOutputToSplitBuffers(
        _ buffers: UnsafeMutableAudioBufferListPointer
    ) -> Bool {
        for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
            guard inputChannel < configuration.channelCount,
                  outputChannel >= 0,
                  let destinationLocation = mutableBufferLocation(
                    forStableChannel: outputChannel,
                    in: buffers
                  ) else {
                return false
            }
            guard copyMappedOutputChannel(
                destination: destinationLocation.data,
                destinationChannel: destinationLocation.channelIndex,
                destinationChannelCount: destinationLocation.channelCount,
                destinationByteCount: destinationLocation.byteCount,
                inputChannel: inputChannel
            ) else {
                return false
            }
        }
        return true
    }

    private func copyMappedOutputChannel(
        destination: UnsafeMutableRawPointer,
        destinationChannel: Int,
        destinationChannelCount: Int,
        destinationByteCount: Int,
        inputChannel: Int
    ) -> Bool {
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        guard case let .valid(plan) = audioChannelCopyPlan(
            request: DirectPeerAudioChannelCopyPlanRequest(
                source: DirectPeerAudioChannelCopyEndpoint(
                    channel: inputChannel,
                    channelCount: configuration.channelCount,
                    byteCount: configuration.payloadByteCount
                ),
                destination: DirectPeerAudioChannelCopyEndpoint(
                    channel: destinationChannel,
                    channelCount: destinationChannelCount,
                    byteCount: destinationByteCount
                ),
                bytesPerSample: bytesPerSample,
                frameCount: configuration.framesPerBuffer
            )
        ) else {
            return false
        }
        copyAudioChannelBytes(
            source: UnsafeRawPointer(outputScratch),
            destination: destination,
            plan: plan,
            bytesPerSample: bytesPerSample,
            frameCount: configuration.framesPerBuffer
        )
        return true
    }

    private func readOnlyBufferLocation(
        forStableChannel stableChannel: Int,
        in buffers: ReadOnlyAudioBufferListPointer
    ) -> DirectPeerReadOnlyAudioBufferLocation? {
        var baseChannel = 0
        for bufferIndex in 0..<buffers.count {
            guard let buffer = buffers[bufferIndex] else {
                continue
            }
            let channelCount = Int(buffer.mNumberChannels)
            guard channelCount > 0 else {
                continue
            }
            let upperBound = baseChannel + channelCount
            if stableChannel < upperBound {
                return DirectPeerReadOnlyAudioBufferLocation(
                    buffer: buffer,
                    channelIndex: stableChannel - baseChannel,
                    channelCount: channelCount
                )
            }
            baseChannel = upperBound
        }
        return nil
    }

    private func mutableBufferLocation(
        forStableChannel stableChannel: Int,
        in buffers: UnsafeMutableAudioBufferListPointer
    ) -> DirectPeerMutableAudioBufferLocation? {
        var baseChannel = 0
        for bufferIndex in 0..<buffers.count {
            let buffer = buffers[bufferIndex]
            let channelCount = Int(buffer.mNumberChannels)
            guard channelCount > 0 else {
                continue
            }
            let upperBound = baseChannel + channelCount
            if stableChannel < upperBound {
                guard let data = buffer.mData else {
                    return nil
                }
                return DirectPeerMutableAudioBufferLocation(
                    data: data,
                    byteCount: Int(buffer.mDataByteSize),
                    channelIndex: stableChannel - baseChannel,
                    channelCount: channelCount
                )
            }
            baseChannel = upperBound
        }
        return nil
    }

    private func totalChannelCount(in buffers: ReadOnlyAudioBufferListPointer) -> Int {
        var total = 0
        for bufferIndex in 0..<buffers.count {
            guard let buffer = buffers[bufferIndex] else {
                continue
            }
            total += max(0, Int(buffer.mNumberChannels))
        }
        return total
    }

    private func recordCaptureResult(_ result: SPSCAtomicRingResult) {
        if result == .stored {
            increment(&capturedInputBlocks)
        } else if result == .invalid {
            increment(&droppedInputBlocks)
        } else if result == .full {
            increment(&droppedInputBlocks)
            increment(&inputOverrunBlocks)
            increment(&callbackOverrunBlocks)
        }
    }

    private func callbackTimingTick() -> UInt64 {
        #if DEBUG
        if let callbackTimingTickForTesting {
            return callbackTimingTickForTesting()
        }
        #endif
        return mach_absolute_time()
    }

    private func recordCallbackDuration(startTicks: UInt64) {
        let elapsedMicroseconds = callbackElapsedMicroseconds(
            startTicks: startTicks,
            endTicks: callbackTimingTick()
        )
        increment(&callbackInvocationBlocks)
        observeMax(&callbackMaxMicroseconds, elapsedMicroseconds)
        if elapsedMicroseconds > callbackPeriodMicroseconds() {
            increment(&callbackDeadlineMisses)
        }
    }

    private func callbackElapsedMicroseconds(startTicks: UInt64, endTicks: UInt64) -> UInt64 {
        guard endTicks >= startTicks else {
            return 0
        }
        let elapsedTicks = endTicks - startTicks
        let (elapsedNanoseconds, overflow) = elapsedTicks.multipliedReportingOverflow(by: hostTimeNumerator)
        guard !overflow else {
            return UInt64.max
        }
        return (elapsedNanoseconds / hostTimeDenominator) / 1_000
    }

    private func callbackPeriodMicroseconds() -> UInt64 {
        max(1, UInt64(configuration.framesPerBuffer) * 1_000_000 / UInt64(configuration.sampleRateHertz))
    }

    private func reserveInputStartFrame() -> UInt64 {
        open_lola_atomic_u64_fetch_add(&nextInputFrame, UInt64(configuration.framesPerBuffer))
    }

    private func reserveOutputStartFrame() {
        _ = open_lola_atomic_u64_fetch_add(&nextOutputFrame, UInt64(configuration.framesPerBuffer))
    }

    private func increment(_ counter: inout OpenLolaAtomicUInt64) {
        // Only the side effect matters for monotonic counters; the previous value is intentionally unused.
        _ = open_lola_atomic_u64_fetch_add(&counter, 1)
    }

    private func observeMax(_ counter: inout OpenLolaAtomicUInt64, _ value: UInt64) {
        var current = open_lola_atomic_u64_load(&counter)
        while value > current {
            var expected = current
            if open_lola_atomic_u64_compare_exchange(&counter, &expected, value) {
                return
            }
            current = expected
        }
    }
}
