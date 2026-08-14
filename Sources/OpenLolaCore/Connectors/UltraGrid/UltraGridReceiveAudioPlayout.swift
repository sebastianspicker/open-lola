// Bridges validated UltraGrid PT21 PCM into the shared Core Audio playout sink.
import CoreAudio
import Foundation

/// Delivers decoded UltraGrid PCM to the sole receive-side playout graph.
public protocol UltraGridReceiveAudioPlayout: AnyObject, Sendable {
    func start() throws
    func stop()
    func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome
}

final class UltraGridCoreAudioReceivePlayout: @unchecked Sendable, UltraGridReceiveAudioPlayout {
    private let graph: DirectPeerRealtimeAudioGraph
    private let outputDeviceID: AudioObjectID
    private let playoutSink: DecodedAudioPlayoutSink
    private let lock = NSLock()
    private var started = false

    init(configuration: ExternalConnectorSessionConfiguration, outputDeviceUID: String) throws {
        let inventory = try CoreAudioInventoryReader().capture()
        guard let outputDevice = inventory.devices.first(where: { $0.uid == outputDeviceUID }) else {
            throw DirectPeerAudioGraphError.missingDeviceUID(outputDeviceUID)
        }
        let outputRate = try Self.outputRate(configuration: configuration, device: outputDevice)
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
        device: CoreAudioDeviceInventory
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
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "ultragrid-coreaudio-playback-sample-rate"
            )
        }
        return rate
    }
}

extension UltraGridCompatibilityRunner {
    static func liveAudioPlayout(
        configuration: ExternalConnectorSessionConfiguration,
        receiver: any UltraGridCompatibilityMediaReceiving,
        injected: (any UltraGridReceiveAudioPlayout)?
    ) throws -> (any UltraGridReceiveAudioPlayout)? {
        if let injected { return injected }
        guard !configuration.dryRun, configuration.role.receives, configuration.mediaMode.hasAudio,
              receiver is UltraGridSocketMediaReceiver else {
            return nil
        }
        guard let playback = configuration.audioPlayback else {
            throw ExternalConnectorSessionError.missingRequiredArgument(
                "--audio-playback coreaudio:<device-uid>"
            )
        }
        let prefix = "coreaudio:"
        guard playback.hasPrefix(prefix), playback.count > prefix.count else {
            throw ExternalConnectorSessionError.invalidProcessArgument("audioPlayback", playback)
        }
        return try UltraGridCoreAudioReceivePlayout(
            configuration: configuration,
            outputDeviceUID: String(playback.dropFirst(prefix.count))
        )
    }
}
