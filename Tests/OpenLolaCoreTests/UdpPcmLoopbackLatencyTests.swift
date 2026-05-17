import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmLoopbackReportRejectsPassWhenEchoBytesWereModified() throws {
    var report = UdpPcmLoopbackSyntheticSmoke.run()
    report.verdict = .pass
    report.metrics.byteExactEcho = false

    #expect(throws: UdpPcmLoopbackValidationError.passWithoutByteExactEcho) {
        try report.validate()
    }
}

@Test
func udpPcmLoopbackReportsValidateSessionPair() throws {
    let (sender, looper) = makeLoopbackSessionPair()

    try sender.validateSessionPair(with: looper)
    try looper.validateSessionPair(with: sender)
}

@Test
func udpPcmLoopbackLocalhostSmokeEchoesBytesExactly() throws {
    let report = try UdpPcmLoopbackLocalhostSmoke.run(packetCount: 4)

    try report.validate()

    #expect(report.metrics.packetsSent == 4)
    #expect(report.metrics.packetsEchoed == 4)
    #expect(report.metrics.byteExactEcho == true)
    #expect(report.verdict == .partial)
    #expect(report.notes.contains("looper echoed 4/4 packets"))
}

@Test
func udpPcmLoopbackLooperCompletionTimeoutFailsExplicitly() throws {
    let done = DispatchSemaphore(value: 0)
    let resultBox = UdpPcmLoopbackLooperResultBox()

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)) {
        try requireLoopbackLooperCompletion(
            done,
            resultBox: resultBox,
            expectedPackets: 1,
            timeout: .nanoseconds(0)
        )
    }
}

@Test
func udpPcmLoopbackLooperCompletionPropagatesFailure() throws {
    let done = DispatchSemaphore(value: 0)
    let resultBox = UdpPcmLoopbackLooperResultBox()
    resultBox.store(.failure(UdpPcmRouteProbeError.receiveFailed(EINVAL)))
    done.signal()

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        try requireLoopbackLooperCompletion(
            done,
            resultBox: resultBox,
            expectedPackets: 1,
            timeout: .seconds(1)
        )
    }
}

@Test
func udpPcmLoopbackLooperCompletionRejectsPartialEchoCount() throws {
    let done = DispatchSemaphore(value: 0)
    let resultBox = UdpPcmLoopbackLooperResultBox()
    resultBox.store(.success(UdpPcmLoopbackLooperResult(packetsEchoed: 1, receiveErrors: 0)))
    done.signal()

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)) {
        try requireLoopbackLooperCompletion(
            done,
            resultBox: resultBox,
            expectedPackets: 2,
            timeout: .seconds(1)
        )
    }
}

@Test
func udpPcmLoopbackSenderCountsLossFromUniqueEchoes() throws {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 2_000,
        framesPerPacket: 1_000,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    let peerSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(peerSocket) }
    try bindLoopback(peerSocket, port: 0)
    try setNonBlocking(peerSocket)

    let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(senderSocket) }
    try bindLoopback(senderSocket, port: 0)
    try setNonBlocking(senderSocket)
    try connectUdpSocket(senderSocket, host: "127.0.0.1", port: try boundPort(peerSocket))

    let peerResult = LoopbackEchoPeerResultBox()
    let peerDone = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        peerResult.store(Result {
            try echoFirstPacketThenDuplicateIt(
                socket: peerSocket,
                expectedByteCount: expectedByteCount(packetMode)
            )
        })
        peerDone.signal()
    }

    var debug = DebugTrace(limit: 20)
    let result = try runSenderLoop(
        socket: senderSocket,
        configuration: UdpPcmLoopbackRunConfiguration(
            sessionID: "duplicate-echo",
            role: .sender,
            bindHost: "127.0.0.1",
            peer: "127.0.0.1",
            port: UInt16(bigEndian: try boundPort(peerSocket)),
            packetMode: packetMode,
            durationSeconds: 1,
            outputPath: "stdout",
            dscp: nil,
            diagnostics: .off,
            debugOutputPath: nil
        ),
        debug: &debug
    )

    guard peerDone.wait(timeout: .now() + 2) == .success else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
    try peerResult.result().get()

    #expect(result.metrics.packetsSent == 2)
    #expect(result.metrics.packetsEchoed == 2)
    #expect(result.metrics.duplicatePackets == 1)
    #expect(result.metrics.outOfOrderPackets == 1)
    #expect(result.metrics.lostPackets == 1)
}

@Test
func udpPcmLoopbackSenderCountsMalformedAndWrongSizeEchoes() throws {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 1_000,
        framesPerPacket: 1_000,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    let peerSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(peerSocket) }
    try bindLoopback(peerSocket, port: 0)
    try setNonBlocking(peerSocket)

    let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(senderSocket) }
    try bindLoopback(senderSocket, port: 0)
    try setNonBlocking(senderSocket)
    try connectUdpSocket(senderSocket, host: "127.0.0.1", port: try boundPort(peerSocket))

    let peerResult = LoopbackEchoPeerResultBox()
    let peerDone = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        peerResult.store(Result {
            try sendWrongSizeAndMalformedEchoes(
                socket: peerSocket,
                expectedByteCount: expectedByteCount(packetMode)
            )
        })
        peerDone.signal()
    }

    var debug = DebugTrace(limit: 20)
    let result = try runSenderLoop(
        socket: senderSocket,
        configuration: UdpPcmLoopbackRunConfiguration(
            sessionID: "malformed-echo",
            role: .sender,
            bindHost: "127.0.0.1",
            peer: "127.0.0.1",
            port: UInt16(bigEndian: try boundPort(peerSocket)),
            packetMode: packetMode,
            durationSeconds: 1,
            outputPath: "stdout",
            dscp: nil,
            diagnostics: .off,
            debugOutputPath: nil
        ),
        debug: &debug
    )

    guard peerDone.wait(timeout: .now() + 2) == .success else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
    try peerResult.result().get()

    #expect(result.metrics.packetsSent == 1)
    #expect(result.metrics.packetsEchoed == 0)
    #expect(result.metrics.lostPackets == 1)
    #expect(result.metrics.wrongSizeEchoPackets == 1)
    #expect(result.metrics.malformedEchoPackets == 1)
}

private func makeLoopbackSessionPair() -> (
    sender: UdpPcmLoopbackReport,
    looper: UdpPcmLoopbackReport
) {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    let metrics = UdpPcmLoopbackMetrics(
        packetsSent: 2,
        packetsEchoed: 2,
        lostPackets: 0,
        byteExactEcho: true,
        rtt: LoopbackTimingMetrics(
            p50Microseconds: 100,
            p95Microseconds: 110,
            p99Microseconds: 120,
            maxMicroseconds: 120
        ),
        oneWayEstimateMicroseconds: 50,
        jitterP99Microseconds: 20,
        duplicatePackets: 0,
        outOfOrderPackets: 0
    )
    let sender = UdpPcmLoopbackReport(
        id: "sender",
        capturedAt: "2026-05-03T00:00:00Z",
        route: RouteIdentity(label: "direct", topology: "byte-exact-echo"),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "duo-1",
            localEndpoint: "10.10.10.1",
            peerEndpoint: "10.10.10.2",
            port: 5_004,
            localRole: .sender,
            peerRole: .looper,
            packetMode: packetMode,
            durationSeconds: 2
        ),
        role: .sender,
        peer: "10.10.10.2",
        packetMode: packetMode,
        metrics: metrics,
        diagnostics: nil,
        verdict: .partial,
        notes: "sender"
    )
    let looper = UdpPcmLoopbackReport(
        id: "looper",
        capturedAt: "2026-05-03T00:00:00Z",
        route: RouteIdentity(label: "direct", topology: "byte-exact-echo"),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "duo-1",
            localEndpoint: "10.10.10.2",
            peerEndpoint: "10.10.10.1",
            port: 5_004,
            localRole: .looper,
            peerRole: .sender,
            packetMode: packetMode,
            durationSeconds: 2
        ),
        role: .looper,
        peer: "10.10.10.1",
        packetMode: packetMode,
        metrics: UdpPcmLoopbackMetrics(
            packetsSent: 0,
            packetsEchoed: 2,
            lostPackets: 0,
            byteExactEcho: true,
            rtt: LoopbackTimingMetrics(
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0
            ),
            oneWayEstimateMicroseconds: 0,
            jitterP99Microseconds: 0,
            duplicatePackets: 0,
            outOfOrderPackets: 0
        ),
        diagnostics: nil,
        verdict: .partial,
        notes: "looper"
    )
    return (sender, looper)
}

private func loopbackConfiguration() -> UdpPcmLoopbackRunConfiguration {
    UdpPcmLoopbackRunConfiguration(
        sessionID: "duo-1",
        role: .sender,
        bindHost: "10.10.10.1",
        peer: "10.10.10.2",
        port: 5_004,
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        durationSeconds: 2,
        outputPath: "stdout",
        dscp: nil,
        diagnostics: .off,
        debugOutputPath: nil
    )
}

private final class LoopbackEchoPeerResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<Void, Error>?

    func store(_ result: Result<Void, Error>) {
        lock.lock()
        defer { lock.unlock() }
        storedResult = result
    }

    func result() throws -> Result<Void, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let storedResult else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        return storedResult
    }
}

private func echoFirstPacketThenDuplicateIt(socket: Int32, expectedByteCount: Int) throws {
    var firstEcho: Data?
    var receivedSequences = Set<UInt64>()
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000

    while DispatchTime.now().uptimeNanoseconds < deadline && receivedSequences.count < 2 {
        guard let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: socket,
            byteCount: expectedByteCount
        ) else {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
            continue
        }
        let packet = try UdpPcmPacket.decode(datagram.data)
        receivedSequences.insert(packet.header.sequenceNumber)

        if packet.header.sequenceNumber == 0 {
            firstEcho = datagram.data
            try sendDatagram(datagram.data, socket: socket, host: datagram.host, port: datagram.port.bigEndian)
        } else if let firstEcho {
            try sendDatagram(firstEcho, socket: socket, host: datagram.host, port: datagram.port.bigEndian)
        }
    }

    guard receivedSequences == [0, 1] else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
}

private func sendWrongSizeAndMalformedEchoes(socket: Int32, expectedByteCount: Int) throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000

    while DispatchTime.now().uptimeNanoseconds < deadline {
        guard let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: socket,
            byteCount: expectedByteCount
        ) else {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
            continue
        }
        try sendDatagram(Data([0x01]), socket: socket, host: datagram.host, port: datagram.port.bigEndian)
        try sendDatagram(
            Data(repeating: 0, count: expectedByteCount),
            socket: socket,
            host: datagram.host,
            port: datagram.port.bigEndian
        )
        return
    }

    throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
}
