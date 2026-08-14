// Implements LoLaCoreAudioLiveBridge audio-path behavior, isolating device and sample handling from higher-level routing.
import CoreAudio
import Dispatch
import Foundation
import os

enum LoLaCoreAudioLiveBridgeError: Error, Equatable, Sendable {
    case missingCaptureDevice
    case missingPlaybackDevice
    case unsupportedDeviceSampleRate(inputUID: String, outputUID: String)
    case malformedAudioPayload(expected: Int, actual: Int)
}

struct LoLaCoreAudioLiveSnapshot: Equatable, Sendable {
    var graphSampleRateHertz: Int
    var capturedBlocks: Int
    var droppedCapturedBlocksBeforeSend: Int
    var preparedAudioPackets: Int
    var receivedAudioPackets: Int
    var queuedPlayoutBlocks: Int
    var droppedPlayoutBlocks: Int
}

final class LoLaCoreAudioLiveBridge: @unchecked Sendable {
    private let configuration: ExternalConnectorSessionConfiguration
    private let graph: DirectPeerRealtimeAudioGraph
    private let graphSampleRateHertz: Int
    private let inputDeviceID: AudioObjectID?
    private let outputDeviceID: AudioObjectID?
    let graphMode: DirectPeerRealtimeAudioGraphMode
    private let playoutSink: DecodedAudioPlayoutSink
    private let lock = NSLock()
    private var started = false
    private var txResampler: LoLaLinearPCMResampler
    private var txFloatAccumulator: [Float] = []
    private var droppedCapturedBlocksBeforeSend = 0
    private var preparedAudioPackets = 0

    static func makeIfRequested(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCoreAudioLiveBridge? {
        let captureUID = try parseCoreAudioUID(configuration.audioCapture, field: "audioCapture")
        let playbackUID = try parseCoreAudioUID(configuration.audioPlayback, field: "audioPlayback")
        guard captureUID != nil || playbackUID != nil else {
            return nil
        }
        if configuration.role.transmits, captureUID == nil {
            throw LoLaCoreAudioLiveBridgeError.missingCaptureDevice
        }
        if configuration.role.receives, playbackUID == nil {
            throw LoLaCoreAudioLiveBridgeError.missingPlaybackDevice
        }
        return try LoLaCoreAudioLiveBridge(
            configuration: configuration,
            inputDeviceUID: captureUID,
            outputDeviceUID: playbackUID,
            inventory: CoreAudioInventoryReader().capture()
        )
    }

    init(
        configuration: ExternalConnectorSessionConfiguration,
        inputDeviceUID: String?,
        outputDeviceUID: String?,
        inventory: CoreAudioInventoryReport
    ) throws {
        guard !configuration.role.transmits || inputDeviceUID != nil else {
            throw LoLaCoreAudioLiveBridgeError.missingCaptureDevice
        }
        guard !configuration.role.receives || outputDeviceUID != nil else {
            throw LoLaCoreAudioLiveBridgeError.missingPlaybackDevice
        }
        let requestedInputDeviceUID = configuration.role.transmits ? inputDeviceUID : nil
        let requestedOutputDeviceUID = configuration.role.receives ? outputDeviceUID : nil
        let inputDevice = try requestedInputDeviceUID.map { try Self.device($0, in: inventory) }
        let outputDevice = try requestedOutputDeviceUID.map { try Self.device($0, in: inventory) }
        let graphMode: DirectPeerRealtimeAudioGraphMode = switch configuration.role {
        case .tx: .inputOnly
        case .rx: .outputOnly
        case .txRx: .fullDuplex
        }
        let graphSampleRate = try Self.graphSampleRate(
            configuration: configuration,
            inputDevice: inputDevice,
            outputDevice: outputDevice
        )
        let sharedUID = requestedInputDeviceUID ?? requestedOutputDeviceUID ?? ""
        let graphConfiguration = DirectPeerRealtimeAudioGraphConfiguration(
            devices: .init(
                audioDeviceUID: sharedUID,
                inputDeviceUID: requestedInputDeviceUID,
                outputDeviceUID: requestedOutputDeviceUID
            ),
            format: .init(sampleRateHertz: graphSampleRate, framesPerBuffer: configuration.framesPerPacket, channelCount: configuration.channels, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: Self.inputChannelMap(
                requestedChannels: configuration.channels,
                availableChannels: inputDevice?.inputChannelCount ?? configuration.channels
            ), output: Array(0..<configuration.channels)),
            buffering: .init(ringCapacityBlocks: 2, rxBufferPolicy: nil)
        )
        _ = try DirectPeerRealtimeAudioGraph.preflight(
            configuration: graphConfiguration,
            inventory: inventory,
            mode: graphMode
        )
        self.configuration = configuration
        let graph = try DirectPeerRealtimeAudioGraph(configuration: graphConfiguration, mode: graphMode)
        self.graph = graph
        self.graphSampleRateHertz = graphSampleRate
        self.inputDeviceID = inputDevice.map { AudioObjectID($0.id) }
        self.outputDeviceID = outputDevice.map { AudioObjectID($0.id) }
        self.graphMode = graphMode
        self.playoutSink = DecodedAudioPlayoutSink(target: graph, outputRate: graphSampleRate, channels: configuration.channels, framesPerBlock: configuration.framesPerPacket)
        self.txResampler = LoLaLinearPCMResampler(
            inputRate: graphSampleRate,
            outputRate: configuration.sampleRateHertz,
            channels: configuration.channels
        )
    }

    private static func device(
        _ uid: String,
        in inventory: CoreAudioInventoryReport
    ) throws -> CoreAudioDeviceInventory {
        guard let device = inventory.devices.first(where: { $0.uid == uid }) else {
            throw DirectPeerAudioGraphError.missingDeviceUID(uid)
        }
        return device
    }

    func start() throws {
        lock.lock()
        let shouldStart = !started
        if shouldStart {
            started = true
            resetTXCaptureState()
        }
        lock.unlock()
        guard shouldStart else {
            return
        }
        do {
            switch graphMode {
            case .fullDuplex:
                guard let inputDeviceID, let outputDeviceID else { throw LoLaCoreAudioLiveBridgeError.missingCaptureDevice }
                try graph.start(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID)
            case .inputOnly:
                guard let inputDeviceID else { throw LoLaCoreAudioLiveBridgeError.missingCaptureDevice }
                try graph.start(inputDeviceID: inputDeviceID)
            case .outputOnly:
                guard let outputDeviceID else { throw LoLaCoreAudioLiveBridgeError.missingPlaybackDevice }
                try graph.start(outputDeviceID: outputDeviceID)
            }
            playoutSink.start()
        } catch {
            lock.lock()
            started = false
            lock.unlock()
            throw error
        }
    }

    func stop() {
        lock.lock()
        let shouldStop = started
        started = false
        resetTXCaptureState()
        lock.unlock()
        if shouldStop {
            playoutSink.stop()
            let cleanupResult = graph.stop()
            if !cleanupResult.succeeded {
                os_log(
                    .error,
                    "LoLa Core Audio graph cleanup failures: %{public}@",
                    directPeerRealtimeAudioCleanupFailureSummary(cleanupResult)
                )
            }
        }
    }

    func nextLoLaAudioPayload() throws -> Data? {
        guard graphMode != .outputOnly else { return nil }
        let requiredSamples = configuration.framesPerPacket * configuration.channels
        let dropped = graph.dropCapturedPayloadsKeepingNewest()
        if dropped > 0 {
            txResampler.reset()
            txFloatAccumulator.removeAll(keepingCapacity: true)
            lock.lock()
            droppedCapturedBlocksBeforeSend += dropped
            lock.unlock()
        }
        while txFloatAccumulator.count < requiredSamples,
              let resampled = graph.withCapturedPayload({ _, payload in
            txResampler.append(Array(payload.bindMemory(to: Float.self)))
            return txResampler.produce()
        }) {
            txFloatAccumulator.append(contentsOf: resampled)
        }
        guard txFloatAccumulator.count >= requiredSamples else {
            return nil
        }
        let block = Array(txFloatAccumulator.prefix(requiredSamples))
        txFloatAccumulator.removeFirst(requiredSamples)
        lock.lock()
        preparedAudioPackets += 1
        lock.unlock()
        return int16LittleEndianData(fromInterleavedFloat: block)
    }

    func nextLoLaAudioPayload(until deadline: DispatchTime) throws -> Data? {
        while DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
            if let payload = try nextLoLaAudioPayload() {
                return payload
            }
            guard graph.waitForCapturedPayload(until: deadline) else {
                return nil
            }
        }
        return nil
    }

    func enqueueLoLaPlaybackPayload(_ payload: Data, hostTimeNanoseconds: UInt64) throws {
        guard graphMode != .inputOnly else { return }
        let expected = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: configuration.channels)
        guard payload.count == expected else {
            throw LoLaCoreAudioLiveBridgeError.malformedAudioPayload(expected: expected, actual: payload.count)
        }
        try playoutSink.enqueue(.init(payload: payload, sampleRateHertz: configuration.sampleRateHertz, channels: configuration.channels, representation: .int16LittleEndian), hostTimeNanoseconds: hostTimeNanoseconds)
    }

    var snapshot: LoLaCoreAudioLiveSnapshot {
        let graphCounters = graph.runtimeCounters()
        let playout = playoutSink.snapshot
        lock.lock()
        defer { lock.unlock() }
        return LoLaCoreAudioLiveSnapshot(
            graphSampleRateHertz: graphSampleRateHertz,
            capturedBlocks: graphCounters.capturedInputBlocks,
            droppedCapturedBlocksBeforeSend: droppedCapturedBlocksBeforeSend,
            preparedAudioPackets: preparedAudioPackets,
            receivedAudioPackets: playout.receivedBlocks,
            queuedPlayoutBlocks: playout.queuedBlocks,
            droppedPlayoutBlocks: playout.droppedBlocks
        )
    }

    private func resetTXCaptureState() {
        txResampler.reset()
        txFloatAccumulator.removeAll(keepingCapacity: true)
    }

    private static func parseCoreAudioUID(_ value: String?, field: String) throws -> String? {
        guard let value else {
            return nil
        }
        let prefix = "coreaudio:"
        guard value.hasPrefix(prefix), value.count > prefix.count else {
            throw ExternalConnectorSessionError.invalidProcessArgument(field, value)
        }
        return String(value.dropFirst(prefix.count))
    }

    private static func graphSampleRate(
        configuration: ExternalConnectorSessionConfiguration,
        inputDevice: CoreAudioDeviceInventory?,
        outputDevice: CoreAudioDeviceInventory?
    ) throws -> Int {
        let candidates = [
            configuration.sampleRateHertz,
            inputDevice?.nominalSampleRateHertz.map { Int($0.rounded()) },
            outputDevice?.nominalSampleRateHertz.map { Int($0.rounded()) },
            48_000,
        44_100
        ].compactMap { $0 }
        for candidate in stableUnique(candidates) {
            let supportedByBothDevices = [inputDevice, outputDevice].compactMap { $0 }.allSatisfy { supports($0, candidate) }
            guard supportedByBothDevices else {
                continue
            }
            return candidate
        }
        throw LoLaCoreAudioLiveBridgeError.unsupportedDeviceSampleRate(
            inputUID: inputDevice?.uid ?? "none",
            outputUID: outputDevice?.uid ?? "none"
        )
    }

    private static func inputChannelMap(requestedChannels: Int, availableChannels: Int) -> [Int] {
        guard availableChannels > 1 else {
            return Array(repeating: 0, count: requestedChannels)
        }
        return (0..<requestedChannels).map { min($0, availableChannels - 1) }
    }

    private static func supports(_ device: CoreAudioDeviceInventory, _ sampleRate: Int) -> Bool {
        device.availableSampleRateRanges.contains {
            Double(sampleRate) >= $0.minimum && Double(sampleRate) <= $0.maximum
        }
    }
}

private func stableUnique(_ values: [Int]) -> [Int] {
    var seen = Set<Int>()
    var output: [Int] = []
    for value in values where !seen.contains(value) {
        seen.insert(value)
        output.append(value)
    }
    return output
}

final class LoLaLinearPCMResampler: @unchecked Sendable {
    private let inputRate: Int
    private let outputRate: Int
    private let channels: Int
    private var input: [Float] = []
    private var position: Double = 0

    init(inputRate: Int, outputRate: Int, channels: Int) {
        self.inputRate = max(1, inputRate)
        self.outputRate = max(1, outputRate)
        self.channels = max(1, channels)
    }

    func append(_ samples: [Float]) {
        input.append(contentsOf: samples)
    }

    func appendAndProduce(_ samples: [Float]) -> [Float] {
        append(samples)
        return produce()
    }

    func reset() {
        input.removeAll(keepingCapacity: true)
        position = 0
    }

    func produce() -> [Float] {
        let frameCount = input.count / channels
        if inputRate == outputRate {
            let sampleCount = frameCount * channels
            guard sampleCount > 0 else {
                return []
            }
            let output = Array(input.prefix(sampleCount))
            input.removeFirst(sampleCount)
            position = 0
            return output
        }
        guard frameCount > 1 else {
            return []
        }
        let step = Double(inputRate) / Double(outputRate)
        var output: [Float] = []
        while position + 1 < Double(frameCount) {
            let baseFrame = Int(position)
            let fraction = Float(position - Double(baseFrame))
            for channel in 0..<channels {
                let currentSample = input[baseFrame * channels + channel]
                let nextSample = input[(baseFrame + 1) * channels + channel]
                output.append(currentSample + (nextSample - currentSample) * fraction)
            }
            position += step
        }
        let consumedFrames = max(0, Int(position) - 1)
        if consumedFrames > 0 {
            input.removeFirst(consumedFrames * channels)
            position -= Double(consumedFrames)
        }
        return output
    }
}

func int16LittleEndianData(fromInterleavedFloat samples: [Float]) -> Data {
    var data = Data()
    data.reserveCapacity(samples.count * MemoryLayout<Int16>.size)
    for sample in samples {
        let clamped = max(-1.0, min(1.0, sample))
        let intValue = Int16(clamping: Int((clamped * 32767.0).rounded()))
        var littleEndian = intValue.littleEndian
        withUnsafeBytes(of: &littleEndian) {
            data.append(contentsOf: $0)
        }
    }
    return data
}

func interleavedFloatData(fromInt16LittleEndian data: Data) -> [Float] {
    let bytes = [UInt8](data)
    var output: [Float] = []
    output.reserveCapacity(bytes.count / 2)
    var index = 0
    while index + 1 < bytes.count {
        let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
        output.append(Float(Int16(bitPattern: raw)) / 32768.0)
        index += 2
    }
    return output
}

private func float32LittleEndianData(from samples: [Float]) -> Data {
    var samples = samples
    return samples.withUnsafeMutableBytes { Data($0) }
}
