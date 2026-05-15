import Foundation

// FNV-1a is used here only for deterministic local identifiers and evidence
// labels. It is not a cryptographic integrity check.
let directPeerFNV1A32OffsetBasis: UInt32 = 2_166_136_261
let directPeerFNV1A32Prime: UInt32 = 16_777_619

func directPeerFNV1A32(_ value: String) -> UInt32 {
    var hash = directPeerFNV1A32OffsetBasis
    for byte in value.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* directPeerFNV1A32Prime
    }
    return hash
}
