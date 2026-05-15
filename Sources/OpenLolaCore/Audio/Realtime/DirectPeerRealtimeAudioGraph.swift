import CoreAudio
import COpenLolaAtomics
import Darwin
import Foundation

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
    private var callbackOverrunBlocks = OpenLolaAtomicUInt64()
    private var ioProcRunning = OpenLolaAtomicUInt64()
    private var inputScratch: UnsafeMutableRawPointer
    private var outputScratch: UnsafeMutableRawPointer
    private let hostTimeNumerator: UInt64
    private let hostTimeDenominator: UInt64
    private let lifecycleLock = NSLock()
    let rxBufferAdaptationLock = NSLock()
    var rxBufferSnapshot: RxBufferRuntimeSnapshot? = nil
    var adaptiveRxBufferController: RxBufferAdaptiveController? = nil

    public init(configuration: DirectPeerRealtimeAudioGraphConfiguration) {
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
            if policy.profile == .adaptive { self.adaptiveRxBufferController = try? .runtimeController(policy: policy) }
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
        open_lola_atomic_u64_init(&callbackOverrunBlocks, 0)
        open_lola_atomic_u64_init(&ioProcRunning, 0)
    }

    deinit {
        stop()
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
            open_lola_atomic_u64_store(&ioProcRunning, 1)
            if inputDeviceID == outputDeviceID {
                inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioIOProc)
            } else {
                inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioInputIOProc)
                outputIOProcID = try makeAndStartIOProc(deviceID: outputDeviceID, ioProc: directPeerRealtimeAudioOutputIOProc)
            }
        } catch {
            stopUnlocked()
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
            callbackOverrunBlocks: Int(open_lola_atomic_u64_load(&callbackOverrunBlocks))
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
            _ = AudioDeviceDestroyIOProcID(deviceID, createdIOProcID)
            throw error
        }
        return createdIOProcID
    }

    public func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stopUnlocked()
    }

    private func stopUnlocked() {
        if let inputDeviceID, let inputIOProcID {
            _ = AudioDeviceStop(inputDeviceID, inputIOProcID)
            _ = AudioDeviceDestroyIOProcID(inputDeviceID, inputIOProcID)
        }
        if let outputDeviceID, let outputIOProcID {
            _ = AudioDeviceStop(outputDeviceID, outputIOProcID)
            _ = AudioDeviceDestroyIOProcID(outputDeviceID, outputIOProcID)
        }
        open_lola_atomic_u64_store(&ioProcRunning, 0)
        if let inputDeviceID, let originalInputSampleRate {
            try? setDoubleProperty(
                inputDeviceID,
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeGlobal,
                originalInputSampleRate
            )
        }
        if let inputDeviceID, let originalInputBufferFrameSize {
            try? setUInt32Property(
                inputDeviceID,
                kAudioDevicePropertyBufferFrameSize,
                kAudioObjectPropertyScopeGlobal,
                originalInputBufferFrameSize
            )
        }
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputSampleRate {
            try? setDoubleProperty(
                outputDeviceID,
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeGlobal,
                originalOutputSampleRate
            )
        }
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputBufferFrameSize {
            try? setUInt32Property(
                outputDeviceID,
                kAudioDevicePropertyBufferFrameSize,
                kAudioObjectPropertyScopeGlobal,
                originalOutputBufferFrameSize
            )
        }
        self.inputIOProcID = nil
        self.outputIOProcID = nil
        self.inputDeviceID = nil
        self.outputDeviceID = nil
        self.originalInputSampleRate = nil
        self.originalOutputSampleRate = nil
        self.originalInputBufferFrameSize = nil
        self.originalOutputBufferFrameSize = nil
    }

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
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
        renderPlayout(output: output)
    }

    func processInputIO(
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>
    ) {
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
    }

    func processOutputIO(output: UnsafeMutablePointer<AudioBufferList>) {
        renderPlayout(output: output)
    }

    func nanoseconds(fromHostTime hostTime: UInt64) -> UInt64? {
        precondition(hostTimeDenominator > 0, "mach timebase denominator must be positive")
        let (scaled, overflow) = hostTime.multipliedReportingOverflow(by: hostTimeNumerator)
        return overflow ? nil : scaled / hostTimeDenominator
    }

    private func copyInputToCaptureRing(
        input: UnsafePointer<AudioBufferList>,
        hostTimeNanoseconds: UInt64
    ) {
        let buffers = ReadOnlyAudioBufferListPointer(input)
        guard !buffers.isEmpty else {
            return
        }
        let startFrame = reserveInputStartFrame()
        let copyResult = copyMappedInput(from: buffers)
        guard copyResult == .copied else {
            increment(&droppedInputBlocks)
            return
        }
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
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        if buffers.count == 1 {
            guard let sourceBuffer = buffers[0], let source = sourceBuffer.mData else {
                return .inputBufferUnavailable
            }
            let sourceChannels = Int(sourceBuffer.mNumberChannels)
            guard sourceChannels > 0 else { return .invalidSourceChannelCount }
            for frame in 0..<configuration.framesPerBuffer {
                for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
                    guard outputChannel < configuration.channelCount else {
                        return .destinationChannelOutOfRange
                    }
                    guard inputChannel >= 0, inputChannel < sourceChannels else {
                        return .inputChannelOutOfRange
                    }
                    guard let sourceOffset = audioByteOffset(
                        frame: frame,
                        channel: inputChannel,
                        channelCount: sourceChannels,
                        bytesPerSample: bytesPerSample
                    ), let destinationOffset = audioByteOffset(
                        frame: frame,
                        channel: outputChannel,
                        channelCount: configuration.channelCount,
                        bytesPerSample: bytesPerSample
                    ) else {
                        return .invalidByteOffset
                    }
                    guard sourceOffset + bytesPerSample <= Int(sourceBuffer.mDataByteSize) else {
                        return .inputBufferTooSmall
                    }
                    guard destinationOffset + bytesPerSample <= configuration.payloadByteCount else {
                        return .destinationBufferTooSmall
                    }
                    memcpy(
                        inputScratch.advanced(by: destinationOffset),
                        source.advanced(by: sourceOffset),
                        bytesPerSample
                    )
                }
            }
            return .copied
        }
        for frame in 0..<configuration.framesPerBuffer {
            for (outputChannel, inputChannel) in configuration.inputChannelMap.enumerated() {
                guard outputChannel < configuration.channelCount else {
                    return .destinationChannelOutOfRange
                }
                guard inputChannel >= 0 else {
                    return .inputChannelOutOfRange
                }
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
                guard let sourceOffset = audioByteOffset(
                    frame: frame,
                    channel: sourceLocation.channelIndex,
                    channelCount: sourceLocation.channelCount,
                    bytesPerSample: bytesPerSample
                ), let destinationOffset = audioByteOffset(
                    frame: frame,
                    channel: outputChannel,
                    channelCount: configuration.channelCount,
                    bytesPerSample: bytesPerSample
                ) else {
                    return .invalidByteOffset
                }
                guard sourceOffset + bytesPerSample <= Int(sourceLocation.buffer.mDataByteSize) else {
                    return .inputBufferTooSmall
                }
                guard destinationOffset + bytesPerSample <= configuration.payloadByteCount else {
                    return .destinationBufferTooSmall
                }
                memcpy(
                    inputScratch.advanced(by: destinationOffset),
                    source.advanced(by: sourceOffset),
                    bytesPerSample
                )
            }
        }
        return .copied
    }

    private func clearOutput(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers where buffer.mData != nil {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
    }

    private func copyMappedOutput(to buffers: UnsafeMutableAudioBufferListPointer) -> Bool {
        let bytesPerSample = configuration.sampleFormat.bytesPerSample
        if buffers.count == 1, let destination = buffers[0].mData {
            let destinationChannels = Int(buffers[0].mNumberChannels)
            guard destinationChannels > 0 else { return false }
            for frame in 0..<configuration.framesPerBuffer {
                for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
                    guard inputChannel < configuration.channelCount,
                          outputChannel >= 0,
                          outputChannel < destinationChannels else {
                        return false
                    }
                    guard let sourceOffset = audioByteOffset(
                        frame: frame,
                        channel: inputChannel,
                        channelCount: configuration.channelCount,
                        bytesPerSample: bytesPerSample
                    ), let destinationOffset = audioByteOffset(
                        frame: frame,
                        channel: outputChannel,
                        channelCount: destinationChannels,
                        bytesPerSample: bytesPerSample
                    ) else {
                        return false
                    }
                    guard sourceOffset + bytesPerSample <= configuration.payloadByteCount,
                          destinationOffset + bytesPerSample <= Int(buffers[0].mDataByteSize) else {
                        return false
                    }
                    memcpy(
                        destination.advanced(by: destinationOffset),
                        outputScratch.advanced(by: sourceOffset),
                        bytesPerSample
                    )
                }
            }
            return true
        }
        for frame in 0..<configuration.framesPerBuffer {
            for (inputChannel, outputChannel) in configuration.outputChannelMap.enumerated() {
                guard inputChannel < configuration.channelCount,
                      outputChannel >= 0,
                      let destinationLocation = mutableBufferLocation(
                        forStableChannel: outputChannel,
                        in: buffers
                      ) else {
                    return false
                }
                guard let sourceOffset = audioByteOffset(
                    frame: frame,
                    channel: inputChannel,
                    channelCount: configuration.channelCount,
                    bytesPerSample: bytesPerSample
                ), let destinationOffset = audioByteOffset(
                    frame: frame,
                    channel: destinationLocation.channelIndex,
                    channelCount: destinationLocation.channelCount,
                    bytesPerSample: bytesPerSample
                ) else {
                    return false
                }
                guard sourceOffset + bytesPerSample <= configuration.payloadByteCount,
                      destinationOffset + bytesPerSample <= destinationLocation.byteCount else {
                    return false
                }
                memcpy(
                    destinationLocation.data.advanced(by: destinationOffset),
                    outputScratch.advanced(by: sourceOffset),
                    bytesPerSample
                )
            }
        }
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
}
