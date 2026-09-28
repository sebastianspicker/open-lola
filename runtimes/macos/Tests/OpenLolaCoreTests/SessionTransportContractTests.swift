// Protects stable session control encoding and ordered state transitions at the transport boundary.

import Foundation
import Testing
@testable import OpenLolaCore

@Test func controlCodecIsDeterministicAndRoundTripsErrorPayload() throws {
    let message = SessionControlMessage.error(
        .init(sessionID: "session-42", code: "transport-unavailable", message: "retry", fatal: false)
    )

    let encoded = try SessionControlCodec.encode(message)
    let json = try #require(String(data: encoded, encoding: .utf8))

    #expect(json.hasPrefix("{\n  \"error\""))
    #expect(try SessionControlCodec.decode(encoded) == message)
}

@Test func stateMachineOnlyAcceptsOrderedSessionControlTransitions() throws {
    var stateMachine = SessionStateMachine()

    try stateMachine.apply(.init(type: .hello))
    try stateMachine.apply(.init(type: .capabilities))
    try stateMachine.apply(.init(type: .sessionPropose))
    try stateMachine.apply(.init(type: .sessionAccept))
    try stateMachine.apply(.init(type: .mediaStart))
    try stateMachine.apply(.init(type: .mediaPause))

    #expect(stateMachine.state == .paused)
    #expect(throws: SessionStateMachineError.self) {
        try stateMachine.apply(.init(type: .sessionAccept))
    }
    #expect(stateMachine.state == .paused)
}
