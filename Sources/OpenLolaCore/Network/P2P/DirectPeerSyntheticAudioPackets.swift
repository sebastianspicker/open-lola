// Generates deterministic payload content for direct-peer synthetic media runs.
import Dispatch
import Foundation

func directPeerSyntheticAudioPackets(
    sequenceNumber: UInt64,
    mode: AudioTransportMode
) throws -> [UdpPcmV2Packet] {
    try UdpPcmV2Packetizer.packetize(
        Data(
            repeating: UInt8(sequenceNumber & 0xFF),
            count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
        ),
        sequenceNumber: sequenceNumber,
        senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
        mode: mode
    )
}
