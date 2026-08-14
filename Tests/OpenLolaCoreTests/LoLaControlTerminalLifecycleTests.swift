// Verifies terminal LoLa control cleanup remains ordered, best-effort, and evidence-accurate.
import Testing

@testable import OpenLolaCore

@Test
func lolaTerminalControlAppendsStopThenDisconnectWithExactBytes() throws {
    var sent: [String] = []
    let session = try terminalSession { message in
        sent.append(message)
        return message.utf8.count
    }
    var exchange = LoLaControlExchange(sentMessages: ["/MESG_QUICKCONN"], bytesTransferred: 17)

    #expect(session.finish(exchange: &exchange) == nil)
    #expect(exchange.sentMessages.suffix(2) == sent[...])
    #expect(exchange.sentMessages.suffix(2).map(messageName) == [
        "/MESG_STOP_AUDIO_SIGNAL", "/MESG_DISCONNECT"
    ])
    #expect(!sent.contains { messageName($0) == "/MESG_SEND_AUDIO_SIGNAL" })
    #expect(sent.allSatisfy { $0.contains("DSTIP:198.51.100.7") })
    #expect(exchange.bytesTransferred == 17 + sent.reduce(0) { $0 + $1.utf8.count })
    #expect(exchange.sentMessage == sent.last)
    #expect(session.finish(exchange: &exchange) == nil)
    #expect(sent.count == 2)
}

@Test
func lolaTerminalControlContinuesAfterStopFailureAndRecordsOnlySuccessfulWrites() throws {
    var sent: [String] = []
    let session = try terminalSession { message in
        if messageName(message) == "/MESG_STOP_AUDIO_SIGNAL" {
            throw TerminalControlTestError.stopFailed
        }
        sent.append(message)
        return 37
    }
    var exchange = LoLaControlExchange(bytesTransferred: 5)

    let cleanupError = session.finish(exchange: &exchange)

    #expect(cleanupError?.contains("STOP_AUDIO_SIGNAL") == true)
    #expect(sent.map(messageName) == ["/MESG_DISCONNECT"])
    #expect(exchange.sentMessages == sent)
    #expect(exchange.bytesTransferred == 42)
    #expect(lolaCombinedRuntimeError(["media failed", cleanupError])?.hasPrefix("media failed; ") == true)
}

private enum TerminalControlTestError: Error {
    case stopFailed
}

private func terminalSession(
    send: @escaping (String) throws -> Int
) throws -> LoLaControlTerminalSession {
    try makeLoLaControlTerminalSession(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .tx,
            peer: "198.51.100.7",
            outputPath: "/tmp/lola-terminal-control.json"
        ) { $0.sessionID = "41" }),
        exchange: LoLaControlExchange(fields: [
            "SRCIP": "198.51.100.7",
            "DSTIP": "192.0.2.9"
        ]),
        send: send
    )
}

private func messageName(_ message: String) -> String {
    String(message.split(separator: ";", maxSplits: 1).first ?? "")
}
