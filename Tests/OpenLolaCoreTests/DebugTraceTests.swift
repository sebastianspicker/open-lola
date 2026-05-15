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
func debugTraceRejectsUnknownAndSensitiveFieldNamesByDefault() {
    var trace = DebugTrace(limit: 1)
    trace.record(
        event: "auth-attempt",
        fields: [
            "sequence": "1",
            "apiToken": "must-not-appear",
            "privateKey": "must-not-appear",
            "credential": "must-not-appear",
            "secret": "must-not-appear",
            "unexpectedField": "must-not-appear",
        ]
    )

    let output = trace.jsonLines()

    #expect(output.contains("\"sequence\":\"1\""))
    #expect(!output.contains("must-not-appear"))
    #expect(!output.contains("apiToken"))
    #expect(!output.contains("privateKey"))
    #expect(!output.contains("credential"))
    #expect(!output.contains("secret"))
    #expect(!output.contains("unexpectedField"))
}

@Test
func debugTraceFieldPolicyCanAllowNewSafeFieldsWithoutChangingDefaultList() {
    let policy = DebugTraceFieldPolicy.default.allowing(["routeLabel"])
    var trace = DebugTrace(limit: 1, fieldPolicy: policy)
    trace.record(
        event: "route-selected",
        fields: [
            "routeLabel": "direct",
            "unknownField": "must-not-appear",
            "apiToken": "must-not-appear",
        ]
    )

    let output = trace.jsonLines()

    #expect(output.contains("\"routeLabel\":\"direct\""))
    #expect(!output.contains("unknownField"))
    #expect(!output.contains("apiToken"))
    #expect(!output.contains("must-not-appear"))
}

@Test
func debugTraceIsAFileBackedEventTraceNotPrintDebugging() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Core/DebugTrace.swift")

    #expect(!source.contains("print("))
    #expect(!source.contains("debugEnabled"))
    #expect(source.contains("public struct DebugTraceFieldPolicy"))
    #expect(source.contains("public func write(to path: String) throws"))
}

@Test
func debugTraceEncodingFailureFallbackDoesNotUseThrowingEncoding() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Core/DebugTrace.swift")
    let fallbackBody = try #require(source.range(of: "private enum DebugTraceEncodingFailureLine"))
    let fallbackSource = source[fallbackBody.lowerBound...]

    #expect(fallbackSource.contains("jsonEscaped"))
    #expect(!fallbackSource.contains("try? DebugTraceJSONEncoder.encode"))
    #expect(!fallbackSource.contains("{\\\"event\\\":\\\"debug-trace-encoding-failed\\\"}"))
    #expect(fallbackSource.contains("\\\"sourceEvent\\\""))
    #expect(fallbackSource.contains("\\\"error\\\""))
}

@Test
func loopbackSenderFailureTraceIncludesRedactedConfigurationAndSocketState() throws {
    let configuration = makeFailingLoopbackConfiguration(role: .sender)
    let failure = try captureLoopbackFailure(configuration: configuration)
    let output = failure.debugTrace.jsonLines()

    #expect(output.contains("\"event\":\"run-configuration\""))
    #expect(output.contains("\"outputPath\":\"<redacted>\""))
    #expect(output.contains("\"debugOutputPath\":\"<redacted>\""))
    #expect(!output.contains(configuration.outputPath))
    #expect(!output.contains(configuration.debugOutputPath ?? ""))
    #expect(output.contains("\"event\":\"socket-bind-attempt\""))
    #expect(output.contains("\"event\":\"loopback-failed\""))
    #expect(output.contains("invalidHost"))
    #expect(!output.contains("must-not-appear"))
    #expect(!output.contains("\"payload\""))
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
        sessionID: "debug-failure-\(role.rawValue)",
        role: role,
        bindHost: "not-an-ip",
        peer: "127.0.0.1",
        port: 5_004,
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
