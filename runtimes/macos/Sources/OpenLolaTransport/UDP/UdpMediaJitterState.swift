import OpenLolaSessionDomain
// Tracks per-stream RFC 3550 jitter using clock-offset-independent transit changes.

struct UdpMediaJitterState {
    private var previousTransitByStream: [UdpMediaSequenceKey: Double] = [:]
    private var jitterByStream: [UdpMediaSequenceKey: Double] = [:]
    private var streamOrder: [UdpMediaSequenceKey] = []

    static let maximumTrackedStreams = 256

    var trackedStreamCount: Int {
        previousTransitByStream.count
    }

    mutating func record(
        payloadType: SessionPayloadType,
        streamID: UInt32,
        senderNanoseconds: UInt64,
        arrivalNanoseconds: UInt64
    ) -> Double {
        let key = UdpMediaSequenceKey(payloadType: payloadType, streamID: streamID)
        track(key)
        // Peer uptime has an arbitrary offset from local uptime. Preserve the signed
        // transit; RFC 3550 uses only its change, which cancels that offset.
        let transitMicroseconds = Double(
            Int64(truncatingIfNeeded: arrivalNanoseconds)
                &- Int64(truncatingIfNeeded: senderNanoseconds)
        ) / 1_000
        if let previousTransit = previousTransitByStream[key] {
            let delta = abs(transitMicroseconds - previousTransit)
            let previousJitter = jitterByStream[key] ?? 0
            jitterByStream[key] = previousJitter + (delta - previousJitter) / 16
        }
        previousTransitByStream[key] = transitMicroseconds
        return jitterByStream.values.max() ?? 0
    }

    mutating func remove(_ key: UdpMediaSequenceKey) {
        previousTransitByStream.removeValue(forKey: key)
        jitterByStream.removeValue(forKey: key)
        streamOrder.removeAll { $0 == key }
    }

    private mutating func track(_ key: UdpMediaSequenceKey) {
        guard previousTransitByStream[key] == nil else {
            return
        }
        while previousTransitByStream.count >= Self.maximumTrackedStreams,
              let evicted = streamOrder.first {
            remove(evicted)
        }
        streamOrder.append(key)
    }
}
