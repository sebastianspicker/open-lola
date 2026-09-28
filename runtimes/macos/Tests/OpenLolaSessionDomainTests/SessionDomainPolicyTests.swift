// Characterizes pure session payload policy independently from runtime codec adapters.
import Testing
@testable import OpenLolaSessionDomain

@Test func sessionPayloadPolicyAcceptsOnlyTheSupportedLowDelayShapes() {
    let opus = audioStream(payloadType: .audioOpusCeltLowDelayFrame, framesPerPacket: 120)
    let aes67 = audioStream(payloadType: .audioRtpL24, framesPerPacket: 48)

    #expect(SessionAudioPayloadShape.supportsOpusCELTLowDelay(opus))
    #expect(SessionAudioPayloadShape.supportsAES67L24(aes67))
    #expect(!SessionAudioPayloadShape.supportsOpusCELTLowDelay(
        audioStream(payloadType: .audioOpusCeltLowDelayFrame, framesPerPacket: 48)
    ))
    #expect(!SessionAudioPayloadShape.supportsAES67L24(
        audioStream(payloadType: .audioRtpL24, framesPerPacket: 120, channelCount: 1)
    ))
}

private func audioStream(
    payloadType: SessionPayloadType,
    framesPerPacket: Int,
    channelCount: Int = 2
) -> AudioStreamDescription {
    AudioStreamDescription(
        identity: .init(id: 1, direction: .bidirectional, clockDomain: "clock-0"),
        format: .init(
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            channelCount: channelCount,
            channelOrder: (0 ..< channelCount).map { .init(stableSourceIndex: $0, label: "ch-\($0)") }
        ),
        packet: .init(framesPerPacket: framesPerPacket, payloadType: payloadType)
    )
}
