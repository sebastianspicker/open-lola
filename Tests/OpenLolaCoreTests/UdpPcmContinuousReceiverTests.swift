import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmContinuousReceiverReportsLossFromUniqueSequences() throws {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 4,
        framesPerPacket: 1,
        channelCount: 1,
        sampleFormat: .int16LittleEndian
    )
    let port = try availableLoopbackUdpPort()
    let configuration = UdpPcmRouteRunConfiguration(
        role: .receiver,
        bindHost: "127.0.0.1",
        peer: "127.0.0.1",
        port: port,
        packetMode: packetMode,
        durationSeconds: 1,
        outputPath: "stdout",
        dscp: nil
    )
    let receiver = UdpPcmRouteReportTestResultBox()
    let receiverDone = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            receiver.store(.success(try UdpPcmContinuousRouteRunner.runReceiver(configuration: configuration)))
        } catch {
            receiver.store(.failure(error))
        }
        receiverDone.signal()
    }

    Thread.sleep(forTimeInterval: 0.05)
    let sender = try makeUdpSocket(receiveTimeoutSeconds: 0)
    defer { closeUdpSocket(sender) }
    try bindLoopback(sender, port: 0)
    let wrongMode = UdpPcmPacketMode(
        sampleRateHertz: 8,
        framesPerPacket: packetMode.framesPerPacket,
        channelCount: packetMode.channelCount,
        sampleFormat: packetMode.sampleFormat
    )
    let invalidModePacket = makeProbePacket(
        sequenceNumber: 1,
        senderFrameIndex: 1,
        packetMode: wrongMode
    )
    try sendDatagram(try invalidModePacket.encoded(), socket: sender, host: "127.0.0.1", port: port.bigEndian)

    for sequence in [0, 2, 2] {
        let packet = makeProbePacket(
            sequenceNumber: UInt64(sequence),
            senderFrameIndex: UInt64(sequence),
            packetMode: packetMode
        )
        try sendDatagram(try packet.encoded(), socket: sender, host: "127.0.0.1", port: port.bigEndian)
    }

    #expect(receiverDone.wait(timeout: .now() + 3) == .success)
    let report = try receiver.result().get()
    try report.validate()

    #expect(report.metrics.packetsSent == 4)
    #expect(report.metrics.packetsReceived == 3)
    #expect(report.metrics.receiveErrors == 1)
    #expect(report.metrics.lostPackets == 2)
    #expect(report.metrics.duplicatePackets == 1)
    #expect(report.metrics.rxBuffer?.duplicatePackets == 1)
}

@Test
func udpPcmContinuousReceiverCompletionTimeoutFailsExplicitly() throws {
    let neverCompleted = DispatchSemaphore(value: 0)

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)) {
        try requireContinuousReceiverCompletion(neverCompleted, timeout: .nanoseconds(0))
    }
}

private func availableLoopbackUdpPort() throws -> UInt16 {
    let socket = try makeUdpSocket(receiveTimeoutSeconds: 0)
    defer { closeUdpSocket(socket) }
    try bindLoopback(socket, port: 0)
    return try boundHostPort(socket)
}

private final class UdpPcmRouteReportTestResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<UdpPcmRouteReport, Error>?

    func store(_ result: Result<UdpPcmRouteReport, Error>) {
        lock.lock()
        defer { lock.unlock() }
        storedResult = result
    }

    func result() throws -> Result<UdpPcmRouteReport, Error> {
        lock.lock()
        defer { lock.unlock() }
        return try #require(storedResult)
    }
}
