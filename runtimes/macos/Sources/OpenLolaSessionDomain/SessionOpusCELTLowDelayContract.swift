/// LoLa's negotiated low-delay Opus/CELT wire contract, independent of the codec bridge.
public enum SessionOpusCELTLowDelayContract {
    public static let sampleRateHertz = 48_000
    public static let frameCount = 120
    public static let bitrateBitsPerSecond = 64_000
    public static let frameDurationMilliseconds = 2.5
    public static let maxEncodedByteCount = 1_500
}
