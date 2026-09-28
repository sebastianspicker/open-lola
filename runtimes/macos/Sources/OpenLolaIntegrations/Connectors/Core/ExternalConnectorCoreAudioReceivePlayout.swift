import CoreAudio
import Foundation
import OpenLolaMediaPlatform

/// Owns the common output-only Core Audio graph used by connector receive playouts.
final class ExternalConnectorCoreAudioReceivePlayout: @unchecked Sendable {
    private let graph: DirectPeerRealtimeAudioGraph
    private let outputDeviceID: AudioObjectID
    private let playoutSink: DecodedAudioPlayoutSink
    private let lock = NSLock()
    private var started = false

    init(
        configuration: ExternalConnectorSessionConfiguration,
        outputDeviceUID: String,
        unsupportedSampleRateMode: String
    ) throws {
        let inventory = try CoreAudioInventoryReader().capture()
        guard let outputDevice = inventory.devices.first(where: { $0.uid == outputDeviceUID }) else {
            throw DirectPeerAudioGraphError.missingDeviceUID(outputDeviceUID)
        }
        let outputRate = try Self.outputRate(
            configuration: configuration,
            device: outputDevice,
            unsupportedSampleRateMode: unsupportedSampleRateMode
        )
        let graphConfiguration = DirectPeerRealtimeAudioGraphConfiguration(
            devices: .init(audioDeviceUID: outputDeviceUID, outputDeviceUID: outputDeviceUID),
            format: .init(
                sampleRateHertz: outputRate,
                framesPerBuffer: configuration.framesPerPacket,
                channelCount: configuration.channels,
                sampleFormat: .float32LittleEndian
            ),
            channelMaps: .init(
                input: Array(0..<configuration.channels),
                output: Array(0..<configuration.channels)
            ),
            buffering: .init(ringCapacityBlocks: 2)
        )
        _ = try DirectPeerRealtimeAudioGraph.preflight(
            configuration: graphConfiguration,
            inventory: inventory,
            mode: .outputOnly
        )
        let graph = try DirectPeerRealtimeAudioGraph(configuration: graphConfiguration, mode: .outputOnly)
        self.graph = graph
        outputDeviceID = AudioObjectID(outputDevice.id)
        playoutSink = DecodedAudioPlayoutSink(
            target: graph,
            outputRate: outputRate,
            channels: configuration.channels,
            framesPerBlock: configuration.framesPerPacket
        )
    }

    func start() throws {
        lock.lock()
        let shouldStart = !started
        started = true
        lock.unlock()
        guard shouldStart else { return }
        do {
            try graph.start(outputDeviceID: outputDeviceID)
            playoutSink.start()
        } catch {
            playoutSink.stop()
            _ = graph.stop()
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
        lock.unlock()
        guard shouldStop else { return }
        playoutSink.stop()
        _ = graph.stop()
    }

    func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome {
        try playoutSink.enqueue(block, hostTimeNanoseconds: hostTimeNanoseconds)
    }

    private static func outputRate(
        configuration: ExternalConnectorSessionConfiguration,
        device: CoreAudioDeviceInventory,
        unsupportedSampleRateMode: String
    ) throws -> Int {
        let candidates = [
            configuration.sampleRateHertz,
            device.nominalSampleRateHertz.map { Int($0.rounded()) },
            48_000,
            44_100,
        ].compactMap { $0 }
        var seen = Set<Int>()
        let uniqueCandidates = candidates.filter { seen.insert($0).inserted }
        guard let rate = uniqueCandidates.first(where: { candidate in
            device.availableSampleRateRanges.contains {
                Double(candidate) >= $0.minimum && Double(candidate) <= $0.maximum
            }
        }) else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(unsupportedSampleRateMode)
        }
        return rate
    }
}

extension ExternalConnectorCoreAudioReceivePlayout: JackTripReceiveAudioPlayout {}
extension ExternalConnectorCoreAudioReceivePlayout: UltraGridReceiveAudioPlayout {}
