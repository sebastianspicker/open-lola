public struct PeerSessionRunnerLoopbackPair: Sendable {
    public var first: PeerSessionRunner
    public var second: PeerSessionRunner

    public static func make() throws -> PeerSessionRunnerLoopbackPair {
        PeerSessionRunnerLoopbackPair(
            first: try .localhost(peerID: "peer-a", remotePeerID: "peer-b"),
            second: try .localhost(peerID: "peer-b", remotePeerID: "peer-a")
        )
    }

    public mutating func negotiate() throws {
        do {
            let firstHandshake = try first.beginHandshake()
            let secondHandshake = try second.beginHandshake()
            try first.receiveControlMessages(secondHandshake)
            try second.receiveControlMessages(firstHandshake)
            let proposal = try first.makeSessionProposal()
            let accept = try second.acceptProposal(
                proposal,
                proposerCapabilities: first.localCapabilities
            )
            try first.receiveControlMessages([accept])
        } catch {
            first.shutdown(reason: "loopback negotiation failed")
            second.shutdown(reason: "loopback negotiation failed")
            throw error
        }
    }

    public mutating func startMedia() throws {
        try first.startMedia()
        let firstMediaStart = try Self.latestMediaStartMessage(from: first)
        try second.startMedia()
        let secondMediaStart = try Self.latestMediaStartMessage(from: second)
        try first.receiveControlMessages([secondMediaStart])
        try second.receiveControlMessages([firstMediaStart])
    }

    public mutating func sendAudioPacketFromFirstToSecond(
        sequenceNumber: UInt64
    ) throws {
        try first.sendAudioPacket(sequenceNumber: sequenceNumber)
        try second.receiveMediaPacket()
    }

    private static func latestMediaStartMessage(
        from runner: PeerSessionRunner
    ) throws -> SessionControlMessage {
        guard let message = runner.controlTranscript.last,
              message.type == .mediaStart else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.mediaStart)
        }
        return message
    }
}
