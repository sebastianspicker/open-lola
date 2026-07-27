// Implements payload copying and validation for bounded packet handoff into audio playout.
import CoreAudio
import Darwin
import Foundation

struct RealtimeAudioPacketHandoffInitialState {
    var clock: RealtimeAudioPacketHandoffClock
    var packetMode: UdpPcmPacketMode
    var inputChannelMap: [Int]
    var playoutTargetFrames: Int
    var captureRing: RealtimeAudioPayloadCaptureRing
    var packetPayloadScratch: Data
    var playout: RealtimeAudioDueBlockPlayout
    var metrics: RealtimeAudioHandoffMetrics

    init(configuration: RealtimeAudioEngineConfiguration) throws {
        clock = RealtimeAudioPacketHandoffClock()
        packetMode = Self.packetMode(configuration: configuration)
        inputChannelMap = normalizedRealtimeAudioChannelMap(
            configuration.inputChannelMap,
            channelCount: configuration.channelCount
        )
        playoutTargetFrames = Self.playoutTargetFrames(configuration: configuration)
        captureRing = RealtimeAudioPayloadCaptureRing(
            capacity: configuration.preallocatedBlockCount,
            shape: try RealtimeAudioPayloadShape(mode: packetMode),
            inputChannelMap: inputChannelMap
        )
        packetPayloadScratch = Self.scratchBuffer(mode: packetMode)
        playout = RealtimeAudioDueBlockPlayout(
            startFrame: 0,
            framesPerBlock: configuration.framesPerBuffer,
            capacity: configuration.preallocatedBlockCount
        )
        metrics = Self.metrics(configuration: configuration)
    }

    private static func packetMode(configuration: RealtimeAudioEngineConfiguration) -> UdpPcmPacketMode {
        UdpPcmPacketMode(
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerBuffer,
            channelCount: configuration.channelCount,
            sampleFormat: configuration.packetFormat
        )
    }

    private static func playoutTargetFrames(configuration: RealtimeAudioEngineConfiguration) -> Int {
        let configuredPlayoutTargetFrames = configuration.rxBufferPolicy?.targetFrames
            ?? configuration.playoutTargetFrames
        return configuredPlayoutTargetFrames > 0
            ? configuredPlayoutTargetFrames
            : configuration.framesPerBuffer
    }

    private static func scratchBuffer(mode: UdpPcmPacketMode) -> Data {
        var packetPayloadScratch = Data()
        packetPayloadScratch.reserveCapacity(mode.payloadByteCount)
        return packetPayloadScratch
    }

    private static func metrics(configuration: RealtimeAudioEngineConfiguration) -> RealtimeAudioHandoffMetrics {
    RealtimeAudioHandoffMetrics(
        counters: .init(
            inputBlocks: 0, outputBlocks: 0, networkSendBlocks: 0, networkReceiveBlocks: 0,
            droppedInputBlocks: 0, droppedNetworkBlocks: 0, outputUnderrunBlocks: 0, callbackOverrunBlocks: 0
        ),
        buffering: .init(
            latePackets: 0, maximumBufferedBlocks: 0, ringCapacityBlocks: configuration.preallocatedBlockCount,
            fullCaptureRingBlocks: 0, invalidInputBlocks: 0, directInputBlocks: 0, remappedInputBlocks: 0, packetFragmentCount: 0
        ),
        observability: .init(
            allocationWarnings: 0, maximumCaptureRingOccupancyBlocks: 0, maximumPlayoutQueueDepthBlocks: 0,
            packetizationDuration: .empty, depacketizationDuration: .empty
        ),
        completion: .init(
            hiddenPlayoutGrowthDetected: false,
            shutdownCompleted: false,
            rxBuffer: configuration.rxBufferPolicy.map {
                RxBufferRuntimeSnapshot(policy: $0)
            }
        )
    )
    }
}

/// Host-thread convenience wrapper for tests and non-real-time owners.
///
/// Do not call this wrapper from real-time audio callbacks. Real-time IOProc
/// paths must own `RealtimeAudioPacketHandoff` directly or use a bounded
/// nonblocking handoff primitive.
public final class RealtimeAudioPacketHandoffRuntime: @unchecked Sendable {
    private let lock = NSLock()
    private var handoff: RealtimeAudioPacketHandoff

    public init(configuration: RealtimeAudioEngineConfiguration) throws {
        self.handoff = try RealtimeAudioPacketHandoff(configuration: configuration)
    }

    public func receive(_ packet: UdpPcmPacket) throws -> RealtimeAudioPacketReceiveResult {
        lock.lock()
        defer { lock.unlock() }
        return try handoff.receive(packet)
    }

    public func renderCallback() -> RealtimeAudioPlayoutResult {
        lock.lock()
        defer { lock.unlock() }
        return handoff.renderCallback()
    }

    public func metricsSnapshot() -> RealtimeAudioHandoffMetrics {
        lock.lock()
        defer { lock.unlock() }
        return handoff.metrics
    }
}

struct RealtimeAudioPacketHandoffClock: Sendable {
    private let numerator: UInt64
    private let denominator: UInt64

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        self.numerator = UInt64(info.numer)
        self.denominator = max(UInt64(info.denom), 1)
    }

    func nowNanoseconds() -> UInt64 {
        let ticks = mach_absolute_time()
        let product = ticks.multipliedReportingOverflow(by: numerator)
        guard !product.overflow else {
            return UInt64.max
        }
        return product.partialValue / denominator
    }

    func elapsedMicroseconds(since startNanoseconds: UInt64) -> Double {
        let end = nowNanoseconds()
        return Double(end >= startNanoseconds ? end - startNanoseconds : 0) / 1_000
    }
}
