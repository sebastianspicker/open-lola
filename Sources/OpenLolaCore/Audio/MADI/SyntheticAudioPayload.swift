import Foundation

enum SyntheticAudioPayload {
    static func make(seed: Int, byteCount: Int) -> Data {
        Data((0..<byteCount).map { UInt8(($0 + seed) % 251) })
    }
}
