// Coordinates UDP media execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

/// Runs UdpPcmLoopbackEstablishedSocketRunner while keeping its stateful execution separate from report validation.
public enum UdpPcmLoopbackEstablishedSocketRunner {
    public static func run(
        socket: Int32,
        configuration: UdpPcmLoopbackRunConfiguration,
        debug: inout DebugTrace
    ) throws -> UdpPcmLoopbackReport {
        switch configuration.role {
        case .sender:
            let result = try runSenderLoop(
                socket: socket,
                configuration: configuration,
                debug: &debug
            )
            return makeSenderReport(
                configuration: configuration,
                metrics: result.metrics,
                diagnostics: nil,
                notes: "UDP PCM loopback sender measured byte-exact echo RTT " +
"through an established NAT traversal socket."
            )
        case .looper:
            return try runEstablishedLooper(socket: socket, configuration: configuration, debug: &debug)
        }
    }
}

private func runEstablishedLooper(
    socket: Int32,
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackReport {
    let result = try runUdpPcmLooperLoop(
        request: UdpPcmLooperLoopRequest(
            socket: socket,
            expectedByteCount: expectedByteCount(configuration.packetMode),
            expectedPackets: configuration.packetCount,
            durationSeconds: configuration.durationSeconds
        ),
        debug: &debug,
        io: UdpPcmLooperLoopIO(
            receive: receiveDatagramIfAvailable,
            echo: echoConnectedLooperDatagram
        )
    )
    return makeLooperReport(
        configuration: configuration,
        metrics: makeLooperMetrics(result: result),
        notes: "Looper echoed NAT traversal socket datagrams unchanged. Sender report carries RTT evidence."
    )
}

private func echoConnectedLooperDatagram(
    _ received: Data,
    socket: Int32,
    expectedByteCount: Int,
    debug: inout DebugTrace
) throws -> Bool {
    guard received.count == expectedByteCount else {
        debug.record(
            event: "non-pcm-datagram-ignored",
            fields: ["bytes": "\(received.count)"]
        )
        return false
    }
    do {
        _ = try UdpPcmPacket.decode(received)
    } catch {
        debug.record(
            event: "non-pcm-datagram-ignored",
            fields: ["bytes": "\(received.count)", "error": String(describing: error)]
        )
        return false
    }
    try sendConnectedDatagram(received, socket: socket)
    debug.record(event: "packet-looped", fields: ["bytes": "\(received.count)"])
    return true
}
