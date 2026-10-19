// Detects duplicate media sequence numbers in a fixed 256-entry bitmap window so the receive path never allocates.

/// Remembers which of the 256 sequence numbers ending at the highest one seen have arrived.
/// Bit `sequence % 256` stands for `sequence` while it lies inside the window; numbers older than the window
/// cannot be classified and count as new (the transport still counts them as late).
package struct UdpMediaRecentSequences {
    static let capacity: UInt64 = 256
    private var word0: UInt64 = 0
    private var word1: UInt64 = 0
    private var word2: UInt64 = 0
    private var word3: UInt64 = 0
    private var highest: UInt64 = 0
    private var hasHighest = false

    package init() {}

    /// Records `sequenceNumber`; returns false when it was already seen inside the window (a duplicate).
    package mutating func insert(_ sequenceNumber: UInt64) -> Bool {
        guard hasHighest else {
            hasHighest = true
            highest = sequenceNumber
            setBit(sequenceNumber)
            return true
        }
        let forward = sequenceNumber &- highest
        if forward != 0, forward <= UInt64.max / 2 {
            advance(to: sequenceNumber, by: forward)
            return true
        }
        let backward = highest &- sequenceNumber
        guard backward < Self.capacity else {
            return true
        }
        guard !bit(sequenceNumber) else {
            return false
        }
        setBit(sequenceNumber)
        return true
    }

    // Clears the slots that leave the window as the highest sequence number moves forward.
    private mutating func advance(to sequenceNumber: UInt64, by forward: UInt64) {
        if forward >= Self.capacity {
            word0 = 0
            word1 = 0
            word2 = 0
            word3 = 0
        } else {
            var cleared = highest
            for _ in 0..<forward {
                cleared &+= 1
                clearBit(cleared)
            }
        }
        highest = sequenceNumber
        setBit(sequenceNumber)
    }

    private func bit(_ sequenceNumber: UInt64) -> Bool {
        let slot = sequenceNumber % Self.capacity
        return word(slot / 64) & (1 << (slot % 64)) != 0
    }

    private mutating func setBit(_ sequenceNumber: UInt64) {
        let slot = sequenceNumber % Self.capacity
        update(slot / 64) { $0 | (1 << (slot % 64)) }
    }

    private mutating func clearBit(_ sequenceNumber: UInt64) {
        let slot = sequenceNumber % Self.capacity
        update(slot / 64) { $0 & ~(1 << (slot % 64)) }
    }

    private func word(_ index: UInt64) -> UInt64 {
        switch index {
        case 0: word0
        case 1: word1
        case 2: word2
        default: word3
        }
    }

    private mutating func update(_ index: UInt64, _ transform: (UInt64) -> UInt64) {
        switch index {
        case 0: word0 = transform(word0)
        case 1: word1 = transform(word1)
        case 2: word2 = transform(word2)
        default: word3 = transform(word3)
        }
    }
}
