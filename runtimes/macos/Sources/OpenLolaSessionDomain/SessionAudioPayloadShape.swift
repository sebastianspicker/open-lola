// Owns pure negotiated audio shape validation without linking a codec or AES67 runtime.
public enum SessionAudioPayloadShape {
    public static func supportsOpusCELTLowDelay(_ stream: AudioStreamDescription) -> Bool {
        stream.sampleRateHertz == 48_000
            && stream.framesPerPacket == 120
            && stream.sampleFormat == .float32LittleEndian
            && (1...2).contains(stream.channelCount)
    }

    public static func supportsAES67L24(_ stream: AudioStreamDescription) -> Bool {
        stream.sampleRateHertz == 48_000
            && [6, 48].contains(stream.framesPerPacket)
            && stream.sampleFormat == .float32LittleEndian
            && stream.channelCount == 2
    }
}
