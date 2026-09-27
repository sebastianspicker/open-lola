import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Generates deterministic payload content for direct-peer synthetic media runs.
import Dispatch
import Foundation

func directPeerSyntheticAudioPackets(
    sequenceNumber: UInt64,
    plan: UdpPcmV2ValidatedFragmentPlan
) throws -> [UdpPcmV2Packet] {
    let mode = plan.mode
    let payload = Data(
            repeating: UInt8(sequenceNumber & 0xFF),
            count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
    )
    return try payload.withUnsafeBytes {
        try UdpPcmV2Packetizer.packetize(
            $0,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
            senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            plan: plan
        )
    }
}
