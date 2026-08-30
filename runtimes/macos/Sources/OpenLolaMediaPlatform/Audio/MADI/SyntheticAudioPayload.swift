// Supplies SyntheticAudioPayload media payload handling, keeping source-specific representation out of session orchestration.
import Foundation

public enum SyntheticAudioPayload {
    public static func make(seed: Int, byteCount: Int) -> Data {
        Data((0..<byteCount).map { UInt8(($0 + seed) % 251) })
    }
}
