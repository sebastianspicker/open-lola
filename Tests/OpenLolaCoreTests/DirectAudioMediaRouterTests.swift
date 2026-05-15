import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directAudioMediaRouterSerializesReceiverMutation() throws {
    let source = try readDirectAudioMediaRouterSource()

    #expect(source.contains("final class DirectAudioMediaRouter"))
    #expect(source.contains("private final class DirectAudioMediaRouterReceiver"))
    #expect(source.contains("private let lock = NSLock()"))
    #expect(source.contains("lock.lock()"))
    #expect(source.contains("defer { lock.unlock() }"))
    #expect(source.contains("let receiverState = receivers[packet.header.streamID]"))
    #expect(source.contains("try receiverState.route("))
    #expect(source.contains("return try receiver.receive("))
    #expect(!source.contains("guard var receiver = receivers[packet.header.streamID]"))
    #expect(!source.contains("receivers[packet.header.streamID] = receiver"))
}

private func readDirectAudioMediaRouterSource() throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(
            "Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift"
        ),
        encoding: .utf8
    )
}
