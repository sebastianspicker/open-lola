import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Handles JackTripReceiveAudioSink receive-side processing, isolating input handling from compatibility and report policy.
import Foundation
import CoreAudio

protocol JackTripReceiveAudioPlayout: AnyObject, Sendable {
    func start() throws
    func stop()
    func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome
}

private final class JackTripCoreAudioReceivePlayout: @unchecked Sendable, JackTripReceiveAudioPlayout {
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
                "jacktrip-coreaudio-playback-sample-rate"
            )
        }
        return rate
    }
}

/// Decodes accepted JackTrip media and optionally enqueues it for live CoreAudio playout.
public final class JackTripReceiveAudioSink: @unchecked Sendable {
    private let payloadEncoding: JackTripPayloadEncoding
    private let opusDecoder: OpusCELTLowDelayDecoder?
    private let channels: Int
    private let coreAudioPlayout: (any JackTripReceiveAudioPlayout)?
    private let lock = NSLock()
    private var acceptedDatagramCount = 0
    private var audioPacketCount = 0
    private var audioPayloadByteCount = 0
    private var rejectedMediaCount = 0

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        payloadEncoding = configuration.jackTrip.payloadEncoding
        channels = configuration.channels
        opusDecoder = configuration.jackTrip.payloadEncoding == .opusCELTLowDelay
            ? try OpusCELTLowDelayDecoder(channelCount: configuration.channels)
            : nil
        coreAudioPlayout = try Self.coreAudioPlayout(configuration)
    }

    init(
        configuration: ExternalConnectorSessionConfiguration,
        audioPlayout: any JackTripReceiveAudioPlayout
    ) throws {
        payloadEncoding = configuration.jackTrip.payloadEncoding
        channels = configuration.channels
        opusDecoder = configuration.jackTrip.payloadEncoding == .opusCELTLowDelay
            ? try OpusCELTLowDelayDecoder(channelCount: configuration.channels)
            : nil
        coreAudioPlayout = audioPlayout
    }

    func start() throws {
        try coreAudioPlayout?.start()
    }

    func stop() {
        coreAudioPlayout?.stop()
    }

    func consume(_ datagram: JackTripCompatibilityDatagram) {
        lock.lock()
        defer { lock.unlock() }
        acceptedDatagramCount += 1
        for packet in datagram.packets {
            do {
                let block = try decodedBlock(packet)
                if let playout = coreAudioPlayout {
                    let outcome = try playout.enqueue(
                        block,
                        hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
                    )
                    rejectedMediaCount += outcome.droppedBlocks
                    guard !outcome.wasEntirelyDropped else {
                        continue
                    }
                }
                audioPacketCount += 1
                audioPayloadByteCount += block.payload.count
            } catch {
                rejectedMediaCount += 1
            }
        }
    }

    func report() -> ExternalConnectorMediaSinkReport {
        lock.lock()
        defer { lock.unlock() }
        let delivery = coreAudioPlayout == nil
            ? "bounded artifact sink counters; no live CoreAudio playout was requested"
            : "the shared decoded-audio CoreAudio playout sink"
        let notes = switch payloadEncoding {
        case .pcm:
            "Incrementally decoded accepted JackTrip UDP PCM datagrams into \(delivery)."
        case .opusCELTLowDelay:
            "Incrementally decoded accepted JackTrip Opus CELT extension datagrams with Opus into \(delivery)."
        }
        return ExternalConnectorMediaSinkReport(
            audioPacketCount: audioPacketCount,
            audioPayloadByteCount: audioPayloadByteCount,
            rejectedMediaCount: rejectedMediaCount,
            notes: notes
        )
    }

    var didConsumeDatagrams: Bool {
        lock.lock()
        defer { lock.unlock() }
        return acceptedDatagramCount > 0
    }

    private static func coreAudioPlayout(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> (any JackTripReceiveAudioPlayout)? {
        guard configuration.role.receives, !configuration.dryRun else { return nil }
        guard configuration.jackTrip.audioBackend == .coreAudio else {
            throw ExternalConnectorSessionError.processLaunchFailed(
                "jack-graph-backend requires a measured JACK graph receive playout in this environment"
            )
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
        return try JackTripCoreAudioReceivePlayout(
            configuration: configuration,
            outputDeviceUID: String(playback.dropFirst(prefix.count))
        )
    }

    private func decodedBlock(_ packet: JackTripAudioPacket) throws -> DecodedInterleavedPCM {
        guard packet.header.payloadChannelCount == channels else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-receive-channel-count-\(packet.header.payloadChannelCount)"
            )
        }
        switch payloadEncoding {
        case .pcm:
            let payload = try JackTripAudioPayloadCodec.interleavedPayload(
                planarLittleEndianPCM: packet.planarAudioPayload,
                channels: channels,
                frames: Int(packet.header.bufferSizeSamples),
                bitResolution: packet.header.bitResolution
            )
            return try decodedPCMBlock(payload, header: packet.header)
        case .opusCELTLowDelay:
            guard let opusDecoder else {
                throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                    "jacktrip-opus-decoder-unavailable"
                )
            }
            return .init(
                payload: try opusDecoder.decode(JackTripAdvancedModeCodec.decodeOpusExtensionPayload(packet)),
                sampleRateHertz: OpusCELTLowDelayConstants.sampleRateHertz,
                channels: channels,
                representation: .float32LittleEndian
            )
        }
    }

    private func decodedPCMBlock(
        _ payload: Data,
        header: JackTripDefaultHeader
    ) throws -> DecodedInterleavedPCM {
        switch header.bitResolution {
        case .bit16:
            return .init(
                payload: payload,
                sampleRateHertz: header.sampleRate.hertz,
                channels: channels,
                representation: .int16LittleEndian
            )
        case .bit8, .bit24, .bit32:
            return .init(
                payload: float32Payload(payload, bitResolution: header.bitResolution),
                sampleRateHertz: header.sampleRate.hertz,
                channels: channels,
                representation: .float32LittleEndian
            )
        }
    }

    private func float32Payload(_ payload: Data, bitResolution: JackTripBitResolution) -> Data {
        let bytesPerSample = bitResolution.bytesPerSample
        let scale = Float(Int64(1) << (bitResolution.bits - 1))
        var samples: [Float] = []
        samples.reserveCapacity(payload.count / bytesPerSample)
        let bytes = [UInt8](payload)
        for offset in stride(from: 0, to: bytes.count, by: bytesPerSample) {
            var value: Int64 = 0
            for byte in 0..<bytesPerSample {
                value |= Int64(bytes[offset + byte]) << (byte * 8)
            }
            let signBit = Int64(1) << (bitResolution.bits - 1)
            if value & signBit != 0 {
                value |= ~((Int64(1) << bitResolution.bits) - 1)
            }
            samples.append(Float(value) / scale)
        }
        return samples.withUnsafeBytes { Data($0) }
    }
}
