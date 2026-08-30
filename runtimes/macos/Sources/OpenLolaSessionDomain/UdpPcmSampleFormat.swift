// Defines the PCM scalar representation shared by session capability contracts and transport adapters.
public enum UdpPcmSampleFormat: UInt8, Codable, Equatable, Sendable {
    case int16LittleEndian = 1
    case float32LittleEndian = 2

    public var bytesPerSample: Int {
        switch self {
        case .int16LittleEndian:
            2
        case .float32LittleEndian:
            4
        }
    }
}
