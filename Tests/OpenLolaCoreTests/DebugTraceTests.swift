// Verifies that debug trace records bounded JSON lines.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func debugTraceRecordsBoundedJsonLines() throws {
    var trace = DebugTrace(limit: 2)
    trace.record(
        event: "socket-bind",
        fields: ["host": "127.0.0.1", "port": "5004"]
    )
    trace.record(
        event: "packet-sent",
        fields: ["sequence": "1", "bytes": "176"]
    )
    trace.record(
        event: "packet-echoed",
        fields: ["sequence": "1", "bytes": "176"]
    )

    let lines = trace.jsonLines().split(separator: "\n")

    #expect(lines.count == 2)
    #expect(trace.droppedEvents == 1)
    #expect(String(lines[0]).contains("\"event\":\"socket-bind\""))
    #expect(String(lines[1]).contains("\"event\":\"packet-sent\""))
}

@Test
func debugTraceDoesNotRecordPayloadBytes() {
    var trace = DebugTrace(limit: 4)
    trace.record(
        event: "packet-sent",
        fields: [
            "sequence": "1",
            "payload": "must-not-appear",
            "payloadHash": "abc123"
        ]
    )

    let output = trace.jsonLines()

    #expect(!output.contains("must-not-appear"))
    #expect(output.contains("abc123"))
}

@Test
func debugTraceWritesJsonLinesToRequestedFile() throws {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-debug-trace-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("trace.jsonl")
    var trace = DebugTrace(limit: 2)
    trace.record(event: "socket-bind", fields: ["host": "127.0.0.1", "port": "5004"])
    trace.record(event: "packet-sent", fields: ["sequence": "1", "bytes": "176"])

    try trace.write(to: outputURL.path)

    let output = try String(contentsOf: outputURL, encoding: .utf8)
    let lines = output.split(separator: "\n")

    #expect(lines.count == 2)
    #expect(String(lines[0]).contains("\"event\":\"socket-bind\""))
    #expect(String(lines[1]).contains("\"event\":\"packet-sent\""))
    #expect(output.hasSuffix("\n"))
}

@Test
func loopbackLooperFailureTraceIncludesRedactedConfigurationAndSocketState() throws {
    let configuration = makeFailingLoopbackConfiguration(role: .looper)
    let failure = try captureLoopbackFailure(configuration: configuration)
    let output = failure.debugTrace.jsonLines()

    #expect(output.contains("\"role\":\"looper\""))
    #expect(output.contains("\"event\":\"socket-bind-attempt\""))
    #expect(output.contains("\"bindHost\":\"not-an-ip\""))
    #expect(output.contains("\"bindPort\":\"5004\""))
    #expect(output.contains("\"event\":\"loopback-failed\""))
    #expect(!output.contains(configuration.outputPath))
    #expect(!output.contains(configuration.debugOutputPath ?? ""))
    #expect(!output.contains("\"payload\""))
}

private func makeFailingLoopbackConfiguration(
    role: UdpPcmLoopbackRole
) -> UdpPcmLoopbackRunConfiguration {
    UdpPcmLoopbackRunConfiguration(
        connection: .init(
            sessionID: "debug-failure-\(role.rawValue)",
            role: role,
            bindHost: "not-an-ip",
            peer: "127.0.0.1",
            port: 5_004
        ),
        run: .init(
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            durationSeconds: 1,
            outputPath: "/private/tmp/open-lola-debug-failure-report.json",
            dscp: 46,
            diagnostics: .on,
            debugOutputPath: "/private/tmp/open-lola-debug-failure-trace.jsonl"
        )
    )
}

private func captureLoopbackFailure(
    configuration: UdpPcmLoopbackRunConfiguration
) throws -> DebugTracedRunFailure {
    do {
        _ = try UdpPcmLoopbackRunner.run(configuration: configuration)
    } catch let failure as DebugTracedRunFailure {
        return failure
    }

    return try #require(nil as DebugTracedRunFailure?)
}
