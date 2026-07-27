// Verifies that real-time UDP profiles bound kernel queueing below diagnostic sockets.
import Dispatch
import Darwin
import Foundation
import Testing
@testable import OpenLolaCore

@Test
func realtimeUdpProfilesBoundKernelQueueingBelowDiagnosticSockets() {
    #expect(UdpSocketBufferProfile.minimumLatencyAudio.byteCount == 24 * 1_024)
    #expect(UdpSocketBufferProfile.realtimeAudio.byteCount == 32 * 1_024)
    #expect(UdpSocketBufferProfile.realtimeVideo.byteCount == 256 * 1_024)
    #expect(UdpSocketBufferProfile.diagnostic.byteCount == 4 * 1_024 * 1_024)
    #expect(UdpSocketBufferProfile.minimumLatencyAudio.usesNonBlockingSend)
    #expect(UdpSocketBufferProfile.realtimeAudio.usesNonBlockingSend)
    #expect(UdpSocketBufferProfile.realtimeVideo.usesNonBlockingSend)
    #expect(!UdpSocketBufferProfile.diagnostic.usesNonBlockingSend)
}

@Test
func realtimeUdpBackpressureIsADropButOtherSendFailuresRemainFatal() throws {
    #expect(try udpDatagramSendResult(
        sentByteCount: -1,
        expectedByteCount: 128,
        savedErrno: EAGAIN,
        nonBlocking: true
    ) == .wouldBlock)
    #expect(throws: UdpPcmRouteProbeError.sendFailed(EACCES)) {
        _ = try udpDatagramSendResult(
            sentByteCount: -1,
            expectedByteCount: 128,
            savedErrno: EACCES,
            nonBlocking: true
        )
    }
    #expect(throws: UdpPcmRouteProbeError.sendFailed(EAGAIN)) {
        _ = try udpDatagramSendResult(
            sentByteCount: -1,
            expectedByteCount: 128,
            savedErrno: EAGAIN,
            nonBlocking: false
        )
    }
}
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
    let result = try runDuplicateEchoSenderProbe()
    #expect(result.metrics.packetsSent == 2)
    #expect(result.metrics.packetsEchoed == 2)
    #expect(result.metrics.duplicatePackets == 1)
    #expect(result.metrics.outOfOrderPackets == 1)
    #expect(result.metrics.lostPackets == 1)
}
private func runDuplicateEchoSenderProbe() throws -> UdpPcmLoopbackSenderResult {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 2_000,
        framesPerPacket: 1_000,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    return try runLoopbackSenderProbe(sessionID: "duplicate-echo", packetMode: packetMode) { socket, byteCount in
        try echoFirstPacketThenDuplicateIt(socket: socket, expectedByteCount: byteCount)
    }
}

private func withConnectedLoopbackSenderSockets<T>(
    _ body: (_ peerSocket: Int32, _ senderSocket: Int32) throws -> T
) throws -> T {
    let peerSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(peerSocket) }
    try bindLoopback(peerSocket, port: 0)
    try setNonBlocking(peerSocket)
    let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(senderSocket) }
    try bindLoopback(senderSocket, port: 0)
    try setNonBlocking(senderSocket)
    try connectUdpSocket(senderSocket, host: "127.0.0.1", port: try boundPort(peerSocket))
    return try body(peerSocket, senderSocket)
}
@Test
func udpPcmLoopbackSenderCountsMalformedAndWrongSizeEchoes() throws {
    let result = try runMalformedEchoSenderProbe()
    #expect(result.metrics.packetsSent == 1)
    #expect(result.metrics.packetsEchoed == 0)
    #expect(result.metrics.lostPackets == 1)
    #expect(result.metrics.wrongSizeEchoPackets == 1)
    #expect(result.metrics.malformedEchoPackets == 1)
}
private func runMalformedEchoSenderProbe() throws -> UdpPcmLoopbackSenderResult {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 1_000,
        framesPerPacket: 1_000,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    return try runLoopbackSenderProbe(sessionID: "malformed-echo", packetMode: packetMode) { socket, byteCount in
        try sendWrongSizeAndMalformedEchoes(socket: socket, expectedByteCount: byteCount)
    }
}

private func runLoopbackSenderProbe(
    sessionID: String,
    packetMode: UdpPcmPacketMode,
    peerAction: @escaping @Sendable (Int32, Int) throws -> Void
) throws -> UdpPcmLoopbackSenderResult {
    try withConnectedLoopbackSenderSockets { peerSocket, senderSocket in
        let peerResult = LoopbackEchoPeerResultBox()
        let peerDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            peerResult.store(Result {
                try peerAction(peerSocket, expectedByteCount(packetMode))
            })
            peerDone.signal()
        }
        var debug = DebugTrace(limit: 20)
        let result = try runSenderLoop(
            socket: senderSocket,
            configuration: UdpPcmLoopbackRunConfiguration(
                connection: .init(
                    sessionID: sessionID,
                    role: .sender,
                    bindHost: "127.0.0.1",
                    peer: "127.0.0.1",
                    port: UInt16(bigEndian: try boundPort(peerSocket))
                ),
                run: .init(
                    packetMode: packetMode,
                    durationSeconds: 1,
                    outputPath: "stdout",
                    dscp: nil,
                    diagnostics: .off,
                    debugOutputPath: nil
                )
            ),
            debug: &debug
        )
        guard peerDone.wait(timeout: .now() + 2) == .success else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        try peerResult.result().get()
        return result
    }
}
private func makeLoopbackSessionPair() -> (
    sender: UdpPcmLoopbackReport,
    looper: UdpPcmLoopbackReport
) {
    let packetMode = loopbackSessionPairPacketMode()
    return (
        makeLoopbackReport(LoopbackReportFixture(
            id: "sender",
            localEndpoint: "10.10.10.1",
            peerEndpoint: "10.10.10.2",
            localRole: .sender,
            peerRole: .looper,
            packetMode: packetMode,
            packetsSent: 2,
            packetsEchoed: 2,
            rtt: LoopbackTimingMetrics(
                p50Microseconds: 100,
                p95Microseconds: 110,
                p99Microseconds: 120,
                maxMicroseconds: 120
            ),
            oneWayEstimateMicroseconds: 50,
            jitterP99Microseconds: 20
        )),
        makeLoopbackReport(LoopbackReportFixture(
            id: "looper",
            localEndpoint: "10.10.10.2",
            peerEndpoint: "10.10.10.1",
            localRole: .looper,
            peerRole: .sender,
            packetMode: packetMode,
            packetsSent: 0,
            packetsEchoed: 2,
            rtt: LoopbackTimingMetrics(
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0
            ),
            oneWayEstimateMicroseconds: 0,
            jitterP99Microseconds: 0
        ))
    )
}

private struct LoopbackReportFixture {
    let id: String
    let localEndpoint: String
    let peerEndpoint: String
    let localRole: UdpPcmLoopbackRole
    let peerRole: UdpPcmLoopbackRole
    let packetMode: UdpPcmPacketMode
    let packetsSent: Int
    let packetsEchoed: Int
    let rtt: LoopbackTimingMetrics
    let oneWayEstimateMicroseconds: Double
    let jitterP99Microseconds: Double
}

private func loopbackSessionPairPacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

private func makeLoopbackReport(_ fixture: LoopbackReportFixture) -> UdpPcmLoopbackReport {
    UdpPcmLoopbackReport(
        identity: .init(
            id: fixture.id,
            capturedAt: "2026-05-03T00:00:00Z",
            route: RouteIdentity(label: "direct", topology: "byte-exact-echo")
        ),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "duo-1",
            localEndpoint: fixture.localEndpoint,
            peerEndpoint: fixture.peerEndpoint,
            port: 5_004,
            localRole: fixture.localRole,
            peerRole: fixture.peerRole,
            packetMode: fixture.packetMode,
            durationSeconds: 2
        ),
        observation: .init(
            role: fixture.localRole,
            peer: fixture.peerEndpoint,
            packetMode: fixture.packetMode,
            metrics: UdpPcmLoopbackMetrics(
                delivery: .init(
                    packetsSent: fixture.packetsSent,
                    packetsEchoed: fixture.packetsEchoed,
                    lostPackets: 0,
                    duplicatePackets: 0,
                    outOfOrderPackets: 0
                ),
                byteExactEcho: true,
                timing: .init(
                    rtt: fixture.rtt,
                    oneWayEstimateMicroseconds: fixture.oneWayEstimateMicroseconds,
                    jitterP99Microseconds: fixture.jitterP99Microseconds
                )
            ),
            diagnostics: nil
        ),
        outcome: .init(verdict: .partial, notes: fixture.id)
    )
}

private func loopbackConfiguration() -> UdpPcmLoopbackRunConfiguration {
    UdpPcmLoopbackRunConfiguration(
        connection: .init(
            sessionID: "duo-1",
            role: .sender,
            bindHost: "10.10.10.1",
            peer: "10.10.10.2",
            port: 5_004
        ),
        run: .init(
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

@Test
func readableSocketTimeoutPreservesSubMillisecondPrecision() {
    let subMillisecond = readableSocketTimeout(timeoutMicroseconds: 250)
    #expect(subMillisecond.tv_sec == 0)
    #expect(subMillisecond.tv_usec == 250)

    let multiSecond = readableSocketTimeout(timeoutMicroseconds: 2_000_125)
    #expect(multiSecond.tv_sec == 2)
    #expect(multiSecond.tv_usec == 125)
}

@Test
func writableSocketWaitUsesReadinessInsteadOfFixedBackoff() throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    #expect(pipe(&descriptors) == 0)
    defer {
        close(descriptors[0])
        close(descriptors[1])
    }

    #expect(try waitForWritableSocket(socket: descriptors[1], timeoutMicroseconds: 250))
}

@Test
func readableSocketWaitSupportsDescriptorsAboveFDSetSize() throws {
    var descriptors = [Int32](repeating: -1, count: 2)
    #expect(pipe(&descriptors) == 0)
    let highDescriptor = fcntl(descriptors[0], F_DUPFD, FD_SETSIZE)
    #expect(highDescriptor >= FD_SETSIZE)
    defer {
        close(descriptors[0])
        close(descriptors[1])
        if highDescriptor >= 0 {
            close(highDescriptor)
        }
    }
    guard highDescriptor >= FD_SETSIZE else { return }

    var byte: UInt8 = 1
    #expect(write(descriptors[1], &byte, 1) == 1)
    #expect(try waitForReadableSockets(
        sockets: [highDescriptor],
        timeoutMicroseconds: 1_000
    ) == [highDescriptor])
}

@Test
func highDescriptorReadinessTimeoutPreservesSubMillisecondPrecision() {
    let timeout = socketEventTimeoutTimespec(timeoutMicroseconds: 125)
    #expect(timeout.tv_sec == 0)
    #expect(timeout.tv_nsec == 125_000)
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
