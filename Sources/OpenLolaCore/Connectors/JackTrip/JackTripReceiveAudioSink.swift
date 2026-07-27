// Handles JackTripReceiveAudioSink receive-side processing, isolating input handling from compatibility and report policy.
import Foundation

/// Bounded in-process accounting for packets accepted by the native UDP receiver.
/// This is intentionally not a CoreAudio playout path.
public final class JackTripReceiveAudioSink: @unchecked Sendable {
    private let payloadEncoding: JackTripPayloadEncoding
    private let opusDecoder: OpusCELTLowDelayDecoder?
    private let lock = NSLock()
    private var acceptedDatagramCount = 0
    private var audioPacketCount = 0
    private var audioPayloadByteCount = 0
    private var rejectedMediaCount = 0

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        payloadEncoding = configuration.jackTrip.payloadEncoding
        opusDecoder = configuration.jackTrip.payloadEncoding == .opusCELTLowDelay
            ? try OpusCELTLowDelayDecoder(channelCount: configuration.channels)
            : nil
    }

    func consume(_ datagram: JackTripCompatibilityDatagram) {
        lock.lock()
        defer { lock.unlock() }
        acceptedDatagramCount += 1
        for packet in datagram.packets {
            do {
                let decodedByteCount: Int
                switch payloadEncoding {
                case .pcm:
                    decodedByteCount = try JackTripAudioPayloadCodec.interleavedPayload(
                        planarLittleEndianPCM: packet.planarAudioPayload,
                        channels: Int(packet.header.payloadChannelCount),
                        frames: Int(packet.header.bufferSizeSamples),
                        bitResolution: packet.header.bitResolution
                    ).count
                case .opusCELTLowDelay:
                    guard let opusDecoder else {
                        throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                            "jacktrip-opus-decoder-unavailable"
                        )
                    }
                    decodedByteCount = try opusDecoder.decode(
                        JackTripAdvancedModeCodec.decodeOpusExtensionPayload(packet)
                    ).count
                }
                audioPacketCount += 1
                audioPayloadByteCount += decodedByteCount
            } catch {
                rejectedMediaCount += 1
            }
        }
    }

    func report() -> ExternalConnectorMediaSinkReport {
        lock.lock()
        defer { lock.unlock() }
        let notes = switch payloadEncoding {
        case .pcm:
            "Incrementally decoded accepted JackTrip UDP PCM datagrams into bounded artifact sink counters; no CoreAudio playout is performed."
        case .opusCELTLowDelay:
            "Incrementally decoded accepted JackTrip Opus CELT extension datagrams with Opus into bounded artifact sink counters; no CoreAudio playout is performed."
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
}
