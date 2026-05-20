import Dispatch
import Foundation

public enum UdpPcmLoopbackSyntheticSmoke {
    public static func run() -> UdpPcmLoopbackReport {
        UdpPcmLoopbackReport(
            id: "udp-pcm-loopback-synthetic",
            capturedAt: "2026-05-03T00:00:00Z",
            route: RouteIdentity(label: "synthetic-loopback", topology: "byte-exact-echo"),
            session: UdpPcmLoopbackSessionAgreement(
                sessionID: "synthetic-loopback",
                localEndpoint: "127.0.0.1",
                peerEndpoint: "127.0.0.1",
                port: UdpPcmLoopbackDefaults.port,
                localRole: .sender,
                peerRole: .looper,
                packetMode: UdpPcmLoopbackDefaults.packetMode,
                durationSeconds: 1
            ),
            role: .sender,
            peer: "127.0.0.1",
            packetMode: UdpPcmLoopbackDefaults.packetMode,
            metrics: UdpPcmLoopbackMetrics(
                packetsSent: 3,
                packetsEchoed: 3,
                lostPackets: 0,
                byteExactEcho: true,
                rtt: LoopbackTimingMetrics(
                    p50Microseconds: SyntheticPlaceholderMetrics.microseconds,
                    p95Microseconds: SyntheticPlaceholderMetrics.microseconds,
                    p99Microseconds: SyntheticPlaceholderMetrics.microseconds,
                    maxMicroseconds: SyntheticPlaceholderMetrics.microseconds
                ),
                oneWayEstimateMicroseconds: SyntheticPlaceholderMetrics.microseconds,
                jitterP99Microseconds: SyntheticPlaceholderMetrics.microseconds,
                duplicatePackets: 0,
                outOfOrderPackets: 0
            ),
            diagnostics: nil,
            verdict: .partial,
            notes: "Synthetic byte-exact UDP PCM echo report."
        )
    }
}

final class UdpPcmLoopbackLooperResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<UdpPcmLoopbackLooperResult, Error>?

    func store(_ result: Result<UdpPcmLoopbackLooperResult, Error>) {
        lock.lock()
        defer { lock.unlock() }
        storedResult = result
    }

    func result() throws -> Result<UdpPcmLoopbackLooperResult, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let storedResult else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        return storedResult
    }
}

func requireLoopbackLooperCompletion(
    _ done: DispatchSemaphore,
    resultBox: UdpPcmLoopbackLooperResultBox,
    expectedPackets: Int,
    timeout: DispatchTimeInterval
) throws -> UdpPcmLoopbackLooperResult {
    guard done.wait(timeout: .now() + timeout) == .success else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
    let result = try resultBox.result().get()
    guard result.packetsEchoed >= expectedPackets else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
    return result
}

public enum UdpPcmLoopbackLocalhostSmoke {
    public static func run(packetCount: Int = 5) throws -> UdpPcmLoopbackReport {
        guard packetCount > 0 else {
            throw UdpPcmRouteProbeError.invalidPacketCount(packetCount)
        }
        let looperSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(looperSocket) }
        try bindLoopback(looperSocket, port: 0)
        try setNonBlocking(looperSocket)
        let port = try boundHostPort(looperSocket)
        let packetMode = UdpPcmPacketMode(
            sampleRateHertz: packetCount,
            framesPerPacket: 1,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
        let configuration = UdpPcmLoopbackRunConfiguration(
            sessionID: "localhost-smoke",
            role: .sender,
            bindHost: "127.0.0.1",
            peer: "127.0.0.1",
            port: port,
            packetMode: packetMode,
            durationSeconds: 1,
            outputPath: "stdout",
            dscp: nil,
            diagnostics: .off,
            debugOutputPath: nil
        )
        let ready = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        let looperResultBox = UdpPcmLoopbackLooperResultBox()
        DispatchQueue.global(qos: .userInitiated).async {
            var looperDebug = DebugTrace(limit: 0)
            ready.signal()
            do {
                let looperResult = try runLooperLoop(
                    socket: looperSocket,
                    expectedByteCount: expectedByteCount(packetMode),
                    expectedPackets: packetCount,
                    durationSeconds: 1,
                    debug: &looperDebug
                )
                looperResultBox.store(.success(looperResult))
            } catch {
                looperResultBox.store(.failure(error))
                looperDebug.record(event: "looper-loop-failed", fields: ["error": "\(error)"])
            }
            done.signal()
        }
        guard ready.wait(timeout: .now() + 2) == .success else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(senderSocket) }
        try bindIPv4(senderSocket, host: "127.0.0.1", port: 0)
        try setNonBlocking(senderSocket)
        try connectUdpSocket(senderSocket, host: configuration.peer, port: configuration.port.bigEndian)
        var senderDebug = DebugTrace(limit: 0)
        let result = try runSenderLoop(
            socket: senderSocket,
            configuration: configuration,
            debug: &senderDebug
        )
        let looperResult = try requireLoopbackLooperCompletion(
            done,
            resultBox: looperResultBox,
            expectedPackets: packetCount,
            timeout: .seconds(2)
        )
        return makeSenderReport(
            configuration: configuration,
            metrics: result.metrics,
            diagnostics: nil,
            notes: "Localhost UDP PCM loopback smoke; looper echoed \(looperResult.packetsEchoed)/\(packetCount) packets with \(looperResult.receiveErrors) receive errors. Not physical route evidence."
        )
    }
}
