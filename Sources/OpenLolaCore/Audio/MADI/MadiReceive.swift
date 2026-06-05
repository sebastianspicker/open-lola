import Foundation

private struct MadiReceiveInitializationState {
    var rxBufferPolicy: RxBufferPolicy
    var mixStore: ReceiverMixSnapshotStore
    var outputChannelCount: Int
}

private struct MadiReceivePacketTiming {
    var playoutFrame: UInt64
    var packetAgeMicroseconds: Double?
}

private enum MadiReceivePacketReception {
    case proceed(MadiReceivePacketTiming)
    case finished(MadiReceivePacketResult)

    var timing: MadiReceivePacketTiming? {
        if case .proceed(let timing) = self {
            return timing
        }
        return nil
    }

    var result: MadiReceivePacketResult? {
        if case .finished(let result) = self {
            return result
        }
        return nil
    }
}

private enum MadiReceivePendingPacketState {
    case waiting(MadiReceivePacketResult)
    case complete(MadiReceiveCompletedPendingPacket)
}

private struct MadiReceiveCompletedPendingPacket {
    var reassembled: UdpPcmV2ReassemblyResult
    var receivedFragmentCount: Int
    var expectedFragmentCount: Int
}

private struct MadiReceiveSampleMixContext {
    var frame: Int
    var mode: AudioTransportMode
    var outputChannelCount: Int
}

private struct MadiReceiveSampleMixRequest {
    var sourceChannelIndex: Int
    var destinationChannelIndex: Int
    var gain: Double
    var context: MadiReceiveSampleMixContext
}

public struct MadiReceiveEngine: Sendable {
    public static let maxPendingDeadlines = 8

    private let mode: AudioTransportMode
    private let rxBufferPolicy: RxBufferPolicy
    private var currentTargetFrames: Int
    private var adaptiveRxBufferController: RxBufferAdaptiveController?
    private let mixStore: ReceiverMixSnapshotStore
    private let outputChannelCount: Int
    private let allMissingFragmentIndices: [UInt16]
    private let overrunPolicy: MadiReceiveOverrunPolicy
    private var pendingDeadlines: MadiReceivePendingDeadlineSlots
    private var readyBlocks: MadiReceiveReadyBlockRing
    private var receiverMixScratch: [UInt8]
    private var missingFragmentScratch: [UInt16]
    private var nextDueFrame: UInt64 = 0
    private var highestReceivedSequenceNumber: UInt64?
    private var warmupComplete = false

    public private(set) var metrics: MadiReceiveMetrics

    public init(configuration: MadiReceiveConfiguration) throws {
        let state = try Self.initializationState(configuration: configuration)

        self.mode = configuration.mode
        self.rxBufferPolicy = state.rxBufferPolicy
        self.currentTargetFrames = state.rxBufferPolicy.targetFrames
        self.adaptiveRxBufferController = state.rxBufferPolicy.profile == .adaptive
            ? try RxBufferAdaptiveController.runtimeController(policy: state.rxBufferPolicy)
            : nil
        self.mixStore = state.mixStore
        self.outputChannelCount = state.outputChannelCount
        self.allMissingFragmentIndices = (0..<configuration.mode.fragments.count).map { UInt16($0) }
        self.overrunPolicy = configuration.overrunPolicy
        self.pendingDeadlines = try MadiReceivePendingDeadlineSlots(capacity: Self.maxPendingDeadlines)
        self.readyBlocks = try MadiReceiveReadyBlockRing(
            capacity: configuration.preallocatedBlockCount,
            framesPerBlock: configuration.mode.framesPerPacket
        )
        self.receiverMixScratch = Array(
            repeating: 0,
            count: Self.outputPayloadByteCount(
                mode: configuration.mode,
                outputChannelCount: state.outputChannelCount
            )
        )
        self.missingFragmentScratch = []
        self.missingFragmentScratch.reserveCapacity(configuration.mode.fragments.count)
        self.metrics = MadiReceiveMetrics(
            preallocatedBlockPoolCapacity: configuration.preallocatedBlockCount,
            rxBuffer: RxBufferRuntimeSnapshot(policy: state.rxBufferPolicy)
        )
    }

    public mutating func receive(
        _ packet: UdpPcmV2Packet,
        receivedAtHostTimeNanoseconds: UInt64 = 0
    ) throws -> MadiReceivePacketResult {
        try validate(packet)
        metrics.networkReceiveFragments += 1
        let packetState = try packetReception(
            packet,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
        if let result = packetState.result {
            return result
        }
        guard let timing = packetState.timing else {
            return .droppedLate
        }
        recordPacketOrdering(packet)
        guard !readyBlocks.contains(playoutFrame: timing.playoutFrame) else {
            recordDuplicate()
            return .droppedDuplicate
        }
        let completed: MadiReceiveCompletedPendingPacket
        switch try pendingPacketState(for: packet) {
        case .waiting(let result):
            return result
        case .complete(let completePacket):
            completed = completePacket
        }
        guard let payload = completed.reassembled.payload else {
            return missingPayloadResult(completed)
        }
        let mixedPayload = try applyReceiverMix(payload)
        let block = playoutBlock(
            packet: packet,
            playoutFrame: timing.playoutFrame,
            mixedPayload: mixedPayload
        )
        if let result = storeReadyBlock(
            block,
            sequenceNumber: packet.header.sequenceNumber,
            packetAgeMicroseconds: timing.packetAgeMicroseconds
        ) {
            return result
        }
        return completeQueuedPacket(packet, timing: timing)
    }

    private static func initializationState(
        configuration: MadiReceiveConfiguration
    ) throws -> MadiReceiveInitializationState {
        guard configuration.mode.protocolVersion == .udpPcmV2 else {
            throw MadiReceiveError.invalidTransportMode
        }
        guard configuration.preallocatedBlockCount > 0 else {
            throw MadiReceiveError.nonPositiveField("preallocatedBlockCount")
        }
        let rxBufferPolicy = try resolvedRxBufferPolicy(configuration: configuration)
        let outputChannelCount = try resolvedOutputChannelCount(configuration: configuration)
        let mixStore = try resolvedReceiverMixStore(
            configuration: configuration,
            outputChannelCount: outputChannelCount
        )
        return MadiReceiveInitializationState(
            rxBufferPolicy: rxBufferPolicy,
            mixStore: mixStore,
            outputChannelCount: outputChannelCount
        )
    }

    private static func resolvedRxBufferPolicy(
        configuration: MadiReceiveConfiguration
    ) throws -> RxBufferPolicy {
        let rxBufferPolicy = try configuration.rxBufferPolicy
            ?? MadiReceiveEngine.defaultRxBufferPolicy(for: configuration.mode)
        guard rxBufferPolicy.framesPerPacket == configuration.mode.framesPerPacket else {
            throw MadiReceiveError.transportModeMismatch("framesPerPacket")
        }
        guard rxBufferPolicy.sampleRateHertz == configuration.mode.sampleRateHertz else {
            throw MadiReceiveError.transportModeMismatch("sampleRateHertz")
        }
        return rxBufferPolicy
    }

    private static func resolvedOutputChannelCount(
        configuration: MadiReceiveConfiguration
    ) throws -> Int {
        let outputChannelCount = configuration.outputChannelCount ?? configuration.mode.channelCount
        guard outputChannelCount > 0 else {
            throw MadiReceiveError.nonPositiveField("outputChannelCount")
        }
        return outputChannelCount
    }

    private static func resolvedReceiverMixStore(
        configuration: MadiReceiveConfiguration,
        outputChannelCount: Int
    ) throws -> ReceiverMixSnapshotStore {
        let receiverMix = configuration.receiverMix
            ?? ReceiverMixSnapshot.identity(
                inputChannels: AudioChannelSet.defaultInput(count: configuration.mode.channelCount),
                outputChannels: AudioChannelSet.defaultOutput(count: outputChannelCount)
            )
        do {
            return try ReceiverMixSnapshotStore(
                initial: receiverMix,
                inputChannelCount: configuration.mode.channelCount,
                outputChannelCount: outputChannelCount
            )
        } catch let error as ReceiverMixSnapshotError {
            throw MadiReceiveError.receiverMix(error)
        }
    }

    private mutating func packetReception(
        _ packet: UdpPcmV2Packet,
        receivedAtHostTimeNanoseconds: UInt64
    ) throws -> MadiReceivePacketReception {
        let playoutFrame = try Self.targetPlayoutFrame(
            senderFrameIndex: packet.header.senderFrameIndex,
            targetFrames: currentTargetFrames
        )
        let packetAge = recordPacketAge(
            senderHostTimeNanoseconds: packet.header.senderHostTimeNanoseconds,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
        guard playoutFrame >= nextDueFrame else {
            recordLateDrop()
            observeAdaptiveRxBuffer(
                sequenceNumber: packet.header.sequenceNumber,
                packetAgeMicroseconds: packetAge,
                pressure: true
            )
            return .finished(.droppedLate)
        }
        return .proceed(
            MadiReceivePacketTiming(playoutFrame: playoutFrame, packetAgeMicroseconds: packetAge)
        )
    }

    private mutating func recordPacketOrdering(_ packet: UdpPcmV2Packet) {
        if let highest = highestReceivedSequenceNumber,
           packet.header.sequenceNumber < highest {
            metrics.reorderedPackets += 1
            metrics.rxBuffer.reorderedPackets += 1
        }
        highestReceivedSequenceNumber = max(
            highestReceivedSequenceNumber ?? packet.header.sequenceNumber,
            packet.header.sequenceNumber
        )
    }

    private mutating func pendingPacketState(
        for packet: UdpPcmV2Packet
    ) throws -> MadiReceivePendingPacketState {
        let key = MadiReceiveDeadlineKey(
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber
        )
        var pending = pendingDeadlines.pending(for: key)
            ?? MadiReceivePendingDeadline(reference: packet.header)
        let insertResult: MadiReceivePendingInsertResult
        do {
            insertResult = try pending.insert(packet)
        } catch let error as UdpPcmV2FragmentReassemblyError {
            throw MadiReceiveError.reassembly(error)
        }
        switch insertResult {
        case .duplicate:
            recordDuplicate()
            return .waiting(.droppedDuplicate)
        case .stored:
            break
        }
        guard pending.isComplete else {
            return try storePendingPacket(pending, for: key)
        }
        _ = pendingDeadlines.remove(for: key)
        do {
            return .complete(
                MadiReceiveCompletedPendingPacket(
                    reassembled: try pending.reassemble(),
                    receivedFragmentCount: pending.receivedFragmentCount,
                    expectedFragmentCount: pending.expectedFragmentCount
                )
            )
        } catch let error as UdpPcmV2FragmentReassemblyError {
            throw MadiReceiveError.reassembly(error)
        }
    }

    private mutating func storePendingPacket(
        _ pending: MadiReceivePendingDeadline,
        for key: MadiReceiveDeadlineKey
    ) throws -> MadiReceivePendingPacketState {
        guard pendingDeadlines.store(pending, for: key) else {
            metrics.allocationWarnings += 1
            throw MadiReceiveError.pendingDeadlineLimitExceeded(Self.maxPendingDeadlines)
        }
        return .waiting(
            .waitingForFragments(
                receivedFragmentCount: pending.receivedFragmentCount,
                expectedFragmentCount: pending.expectedFragmentCount
            )
        )
    }

    private func playoutBlock(
        packet: UdpPcmV2Packet,
        playoutFrame: UInt64,
        mixedPayload: Data
    ) -> MadiReceivePlayoutBlock {
        MadiReceivePlayoutBlock(
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber,
            startFrame: playoutFrame,
            senderFrameIndex: packet.header.senderFrameIndex,
            frameCount: Int(packet.header.framesPerPacket),
            inputChannelCount: Int(packet.header.totalChannelCount),
            outputChannelCount: outputChannelCount,
            sampleFormat: packet.header.sampleFormat,
            payload: mixedPayload,
            mixRevision: mixStore.revision,
            latency: currentLatency()
        )
    }

    private mutating func storeReadyBlock(
        _ block: MadiReceivePlayoutBlock,
        sequenceNumber: UInt64,
        packetAgeMicroseconds: Double?
    ) -> MadiReceivePacketResult? {
        switch readyBlocks.store(block, nextDueFrame: nextDueFrame, overrunPolicy: overrunPolicy) {
        case .stored:
            return nil
        case .droppedNewest:
            recordOverrun()
            observeAdaptiveRxBuffer(
                sequenceNumber: sequenceNumber,
                packetAgeMicroseconds: packetAgeMicroseconds,
                pressure: true
            )
            return .droppedFull
        case .droppedOldest(let droppedBlock):
            _ = droppedBlock.sequenceNumber
            recordOverrun()
            return nil
        case .droppedFuture:
            recordFutureDrop()
            observeAdaptiveRxBuffer(
                sequenceNumber: sequenceNumber,
                packetAgeMicroseconds: packetAgeMicroseconds,
                pressure: true
            )
            return .droppedFull
        }
    }

    private mutating func completeQueuedPacket(
        _ packet: UdpPcmV2Packet,
        timing: MadiReceivePacketTiming
    ) -> MadiReceivePacketResult {
        metrics.completedBlocks += 1
        updateMaximumBufferedBlocks()
        observeAdaptiveRxBuffer(
            sequenceNumber: packet.header.sequenceNumber,
            packetAgeMicroseconds: timing.packetAgeMicroseconds,
            pressure: false
        )
        return .queued
    }

    private mutating func missingPayloadResult(
        _ completed: MadiReceiveCompletedPendingPacket
    ) -> MadiReceivePacketResult {
        recordFragmentLoss()
        return .waitingForFragments(
            receivedFragmentCount: completed.receivedFragmentCount,
            expectedFragmentCount: completed.expectedFragmentCount
        )
    }

    public mutating func renderCallback() -> MadiReceiveRenderResult {
        let dueFrame = nextDueFrame
        nextDueFrame &+= UInt64(mode.framesPerPacket)

        guard dueFrame >= UInt64(currentTargetFrames) else {
            return .silence(startFrame: dueFrame, frameCount: mode.framesPerPacket)
        }
        warmupComplete = true

        if let block = readyBlocks.remove(playoutFrame: dueFrame) {
            metrics.renderedBlocks += 1
            updateMaximumBufferedBlocks()
            return .played(block)
        }

        if let pending = removePendingDeadline(playoutFrame: dueFrame) {
            pending.appendMissingFragmentIndices(to: &missingFragmentScratch)
            let missing = missingFragmentScratch
            recordFragmentLoss()
            return .sameDeadlineRecovery(
                recoveryBlock(
                    sequenceNumber: pending.reference.sequenceNumber,
                    startFrame: dueFrame,
                    missingFragmentIndices: missing
                )
            )
        }

        recordUnderrun()
        recordSameDeadlineRecovery()
        return .sameDeadlineRecovery(
            recoveryBlock(
                sequenceNumber: missingSequenceNumber(dueFrame: dueFrame),
                startFrame: dueFrame,
                missingFragmentIndices: allMissingFragmentIndices
            )
        )
    }

    private static func defaultRxBufferPolicy(for mode: AudioTransportMode) throws -> RxBufferPolicy {
        switch mode.rxBufferProfile {
        case .direct:
            try RxBufferPolicy.direct(
                framesPerPacket: mode.framesPerPacket,
                sampleRateHertz: mode.sampleRateHertz
            )
        case .small:
            try RxBufferPolicy.small(
                framesPerPacket: mode.framesPerPacket,
                sampleRateHertz: mode.sampleRateHertz
            )
        case .adaptive:
            try RxBufferPolicy.adaptive(
                framesPerPacket: mode.framesPerPacket,
                sampleRateHertz: mode.sampleRateHertz
            )
        case .stableWan:
            try RxBufferPolicy.stableWan(
                framesPerPacket: mode.framesPerPacket,
                sampleRateHertz: mode.sampleRateHertz
            )
        }
    }

    private func validate(_ packet: UdpPcmV2Packet) throws {
        try validateTimingHeader(packet)
        try validateFormatHeader(packet)
        try validateFragmentPlan(packet)
    }

    private func validateTimingHeader(_ packet: UdpPcmV2Packet) throws {
        guard packet.header.streamID == UInt32(mode.fragments.first?.streamID ?? 0) else {
            throw MadiReceiveError.transportModeMismatch("streamID")
        }
        guard packet.header.sampleRateHertz == UInt32(mode.sampleRateHertz) else {
            throw MadiReceiveError.transportModeMismatch("sampleRateHertz")
        }
        guard packet.header.framesPerPacket == UInt32(mode.framesPerPacket) else {
            throw MadiReceiveError.transportModeMismatch("framesPerPacket")
        }
    }

    private func validateFormatHeader(_ packet: UdpPcmV2Packet) throws {
        guard packet.header.totalChannelCount == UInt16(mode.channelCount) else {
            throw MadiReceiveError.transportModeMismatch("totalChannelCount")
        }
        guard packet.header.sampleFormat == mode.sampleFormat else {
            throw MadiReceiveError.transportModeMismatch("sampleFormat")
        }
        guard packet.header.fragmentCount == UInt16(mode.fragments.count) else {
            throw MadiReceiveError.transportModeMismatch("fragmentCount")
        }
        guard packet.header.metadataRevision == UInt32(mode.fragments.first?.metadataRevision ?? 0) else {
            throw MadiReceiveError.transportModeMismatch("metadataRevision")
        }
        guard packet.header.packingMode == mode.fragments.first?.packingMode else {
            throw MadiReceiveError.transportModeMismatch("packingMode")
        }
    }

    private func validateFragmentPlan(_ packet: UdpPcmV2Packet) throws {
        let matchesFragmentPlan = mode.fragments.contains { fragment in
            fragment.fragmentIndex == Int(packet.header.fragmentIndex)
                && fragment.channelOffset == Int(packet.header.channelOffset)
                && fragment.channelsInFragment == Int(packet.header.channelsInFragment)
                && fragment.payloadByteCount == packet.payload.count
                && fragment.metadataRevision == Int(packet.header.metadataRevision)
                && fragment.packingMode == packet.header.packingMode
        }
        guard matchesFragmentPlan else {
            throw MadiReceiveError.transportModeMismatch("fragmentPlan")
        }
    }

    private static func outputPayloadByteCount(
        mode: AudioTransportMode,
        outputChannelCount: Int
    ) -> Int {
        mode.framesPerPacket
            * outputChannelCount
            * mode.sampleFormat.bytesPerSample
    }

    private mutating func applyReceiverMix(_ inputPayload: Data) throws -> Data {
        receiverMixScratch.withUnsafeMutableBytes { scratchBytes in
            if let scratchBaseAddress = scratchBytes.baseAddress {
                memset(scratchBaseAddress, 0, scratchBytes.count)
            }
        }
        try inputPayload.withUnsafeBytes { inputBytes in
            let mode = self.mode
            let outputChannelCount = self.outputChannelCount
            let routes = self.mixStore.prepared.routes
            try receiverMixScratch.withUnsafeMutableBufferPointer { outputBytes in
                for frame in 0..<mode.framesPerPacket {
                    let context = MadiReceiveSampleMixContext(
                        frame: frame,
                        mode: mode,
                        outputChannelCount: outputChannelCount
                    )
                    for route in routes where !route.muted {
                        try Self.mixSample(
                            input: inputBytes,
                            output: &outputBytes,
                            route: route,
                            context: context
                        )
                    }
                }
            }
        }
        return Data(receiverMixScratch)
    }

    private static func mixSample(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        route: PreparedReceiverMixRoute,
        context: MadiReceiveSampleMixContext
    ) throws {
        if context.outputChannelCount == 2, abs(route.pan) > receiverMixPanTolerance {
            try mixSample(
                input: input,
                output: &output,
                request: MadiReceiveSampleMixRequest(
                    sourceChannelIndex: route.sourceChannelIndex,
                    destinationChannelIndex: 0,
                    gain: route.leftGain,
                    context: context
                )
            )
            try mixSample(
                input: input,
                output: &output,
                request: MadiReceiveSampleMixRequest(
                    sourceChannelIndex: route.sourceChannelIndex,
                    destinationChannelIndex: 1,
                    gain: route.rightGain,
                    context: context
                )
            )
            return
        }
        try mixSample(
            input: input,
            output: &output,
            request: MadiReceiveSampleMixRequest(
                sourceChannelIndex: route.sourceChannelIndex,
                destinationChannelIndex: route.destinationChannelIndex,
                gain: route.linearGain,
                context: context
            )
        )
    }

    private static func mixSample(
        input: UnsafeRawBufferPointer,
        output: inout UnsafeMutableBufferPointer<UInt8>,
        request: MadiReceiveSampleMixRequest
    ) throws {
        let mode = request.context.mode
        let bytesPerSample = mode.sampleFormat.bytesPerSample
        let sourceOffset = ((request.context.frame * mode.channelCount) + request.sourceChannelIndex)
            * bytesPerSample
        let destinationOffset = ((request.context.frame * request.context.outputChannelCount)
            + request.destinationChannelIndex)
            * bytesPerSample
        switch mode.sampleFormat {
        case .int16LittleEndian:
            let source = Double(try readInt16(input, offset: sourceOffset))
            let existing = Double(try readInt16(output, offset: destinationOffset))
            let mixed = max(
                Double(Int16.min),
                min(Double(Int16.max), existing + source * request.gain)
            )
            writeInt16(Int16(mixed.rounded()), to: &output, offset: destinationOffset)
        case .float32LittleEndian:
            let source = Double(try readFloat32(input, offset: sourceOffset))
            let existing = Double(try readFloat32(output, offset: destinationOffset))
            writeFloat32(
                Float(existing + source * request.gain),
                to: &output,
                offset: destinationOffset
            )
        }
    }

    private func currentLatency() -> MadiReceiveBufferLatency {
        let packets = currentTargetFrames / mode.framesPerPacket
        return MadiReceiveBufferLatency(
            frames: currentTargetFrames,
            packets: packets,
            microseconds: RxBufferPolicy.microseconds(
                frames: currentTargetFrames,
                sampleRateHertz: rxBufferPolicy.sampleRateHertz
            )
        )
    }

    private mutating func removePendingDeadline(
        playoutFrame: UInt64
    ) -> MadiReceivePendingDeadline? {
        let targetFrames = currentTargetFrames
        return pendingDeadlines.remove { pending in
            guard let pendingPlayoutFrame = try? Self.targetPlayoutFrame(
                senderFrameIndex: pending.reference.senderFrameIndex,
                targetFrames: targetFrames
            ) else {
                return false
            }
            return pendingPlayoutFrame == playoutFrame
        }
    }

    private static func targetPlayoutFrame(senderFrameIndex: UInt64, targetFrames: Int) throws -> UInt64 {
        let target = UInt64(targetFrames)
        let result = senderFrameIndex.addingReportingOverflow(target)
        guard !result.overflow else {
            throw MadiReceiveError.playoutFrameOverflow(
                senderFrameIndex: senderFrameIndex,
                targetFrames: targetFrames
            )
        }
        return result.partialValue
    }

    private func recoveryBlock(
        sequenceNumber: UInt64,
        startFrame: UInt64,
        missingFragmentIndices: [UInt16]
    ) -> MadiReceiveRecoveryBlock {
        MadiReceiveRecoveryBlock(
            sequenceNumber: sequenceNumber,
            startFrame: startFrame,
            frameCount: mode.framesPerPacket,
            missingFragmentIndices: missingFragmentIndices,
            payloadByteCount: mode.framesPerPacket
                * outputChannelCount
                * mode.sampleFormat.bytesPerSample
        )
    }

    private func missingSequenceNumber(dueFrame: UInt64) -> UInt64 {
        guard dueFrame >= UInt64(currentTargetFrames) else {
            return 0
        }
        return (dueFrame - UInt64(currentTargetFrames)) / UInt64(mode.framesPerPacket)
    }

    private mutating func recordLateDrop() {
        metrics.latePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.lostPackets += 1
        metrics.rxBuffer.latePackets += 1
        metrics.rxBuffer.lostPackets += 1
    }

    private mutating func recordDuplicate() {
        metrics.duplicatePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.duplicatePackets += 1
    }

    private mutating func recordFragmentLoss() {
        metrics.lostPackets += 1
        metrics.fragmentLostPackets += 1
        metrics.sameDeadlineRecoveries += 1
        metrics.rxBuffer.lostPackets += 1
        metrics.rxBuffer.fragmentLostPackets += 1
        metrics.rxBuffer.plcEvents += 1
    }

    private mutating func recordUnderrun() {
        guard warmupComplete else {
            return
        }
        metrics.underruns += 1
        metrics.rxBuffer.underruns += 1
    }

    private mutating func recordOverrun() {
        metrics.overruns += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.overruns += 1
    }

    private mutating func recordFutureDrop() {
        metrics.futurePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.futurePackets += 1
    }

    private mutating func recordSameDeadlineRecovery() {
        metrics.sameDeadlineRecoveries += 1
        metrics.rxBuffer.plcEvents += 1
    }

    private mutating func updateMaximumBufferedBlocks() {
        metrics.maximumBufferedBlocks = max(metrics.maximumBufferedBlocks, readyBlocks.count)
        metrics.rxBuffer.recordBufferedPacketCount(readyBlocks.count)
    }

    private mutating func recordPacketAge(
        senderHostTimeNanoseconds: UInt64,
        receivedAtHostTimeNanoseconds: UInt64
    ) -> Double? {
        guard receivedAtHostTimeNanoseconds >= senderHostTimeNanoseconds else {
            return nil
        }
        let age = Double(receivedAtHostTimeNanoseconds - senderHostTimeNanoseconds) / 1_000
        metrics.lastPacketAgeMicroseconds = age
        metrics.maximumPacketAgeMicroseconds = max(metrics.maximumPacketAgeMicroseconds ?? age, age)
        return age
    }

    private mutating func observeAdaptiveRxBuffer(
        sequenceNumber: UInt64,
        packetAgeMicroseconds: Double?,
        pressure: Bool
    ) {
        guard var controller = adaptiveRxBufferController else {
            return
        }
        let previousEventCount = controller.targetChangeEvents.count
        let decision = controller.observe(
            RxBufferAdaptationSample(
                sequenceNumber: sequenceNumber,
                jitterP99Microseconds: packetAgeMicroseconds ?? 0,
                latePackets: pressure ? 1 : 0
            )
        )
        adaptiveRxBufferController = controller
        guard decision.changed else {
            return
        }
        currentTargetFrames = decision.targetFrames
        metrics.rxBuffer.recordTargetFrames(decision.targetFrames)
        for event in controller.targetChangeEvents.dropFirst(previousEventCount) {
            metrics.rxBuffer.targetChangeEvents.append(event)
        }
    }
}
