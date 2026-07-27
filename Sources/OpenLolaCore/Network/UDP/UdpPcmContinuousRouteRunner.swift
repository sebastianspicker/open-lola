// Coordinates UDP media execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

/// Runs UdpPcmContinuousRouteRunner while keeping its stateful execution separate from report validation.
public enum UdpPcmContinuousRouteRunner {
    public static func runSender(
        configuration: UdpPcmRouteRunConfiguration
    ) throws -> UdpPcmRouteRunSummary {
        try configuration.validate()
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 0)
        defer { close(descriptor) }
        try setNonBlocking(descriptor)
        if let dscp = configuration.dscp {
            try setDscp(dscp, socket: descriptor)
        }
        try bindIPv4(descriptor, host: configuration.bindHost, port: 0)
        try connectUdpSocket(
            descriptor,
            host: configuration.peer,
            port: configuration.port.bigEndian
        )

        let result = try runConnectedSenderLoop(
            socket: descriptor,
            configuration: configuration
        )
        return UdpPcmRouteRunSummary(
            id: "m05-continuous-sender-\(UUID().uuidString)",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            hostName: Host.current().localizedName ?? "localhost",
            role: .sender,
            configuration: configuration,
            packetsSent: result.packetsSent,
            packetsReceived: 0,
            sendErrors: result.sendErrors,
            receiveErrors: 0,
            verdict: .partial,
            notes: "Continuous UDP PCM sender completed. Receiver report and packet capture are required for M05 PASS."
        )
    }

    public static func runReceiver(
        configuration: UdpPcmRouteRunConfiguration
    ) throws -> UdpPcmRouteReport {
        try configuration.validate()
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(descriptor) }
        try bindIPv4(descriptor, host: configuration.bindHost, port: configuration.port.bigEndian)
        try setNonBlocking(descriptor)

        return try runReceiverLoop(socket: descriptor, configuration: configuration)
    }
}

/// Provides deterministic UdpPcmContinuousRouteLocalhostSmoke coverage without requiring external UDP media transport infrastructure.
public enum UdpPcmContinuousRouteLocalhostSmoke {
    public static func run(packetCount: Int = 5) throws -> UdpPcmRouteReport {
        guard packetCount > 0 else {
            throw UdpPcmRouteProbeError.invalidPacketCount(packetCount)
        }

        let receiverSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(receiverSocket) }
        try bindLoopback(receiverSocket, port: 0)
        try setNonBlocking(receiverSocket)
        let port = try boundPort(receiverSocket)

        let configuration = continuousLocalhostReceiverConfiguration(
            packetCount: packetCount,
            port: port
        )
        let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 0)
        defer { close(senderSocket) }
        try setNonBlocking(senderSocket)
        try bindLoopback(senderSocket, port: 0)
        try connectUdpSocket(senderSocket, host: "127.0.0.1", port: port)

        let receiverTask = try startContinuousReceiver(
            socket: receiverSocket,
            configuration: configuration
        )
        _ = try runConnectedSenderLoop(
            socket: senderSocket,
            configuration: continuousLocalhostSenderConfiguration(
                port: port,
                receiverConfiguration: configuration
            )
        )
        try requireContinuousReceiverCompletion(receiverTask.done, timeout: .seconds(2))
        return try receiverTask.reportBox.result().get()
    }
}

private struct ContinuousReceiverTask: Sendable {
    var reportBox: UdpPcmRouteReportResultBox
    var done: DispatchSemaphore
}

private func continuousLocalhostReceiverConfiguration(
    packetCount: Int,
    port: UInt16
) -> UdpPcmRouteRunConfiguration {
    UdpPcmRouteRunConfiguration(UdpPcmRouteRunConfiguration.Input(
        transport: .init(
            role: .receiver,
            peer: "127.0.0.1",
            port: UInt16(bigEndian: port),
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: packetCount,
                framesPerPacket: 1,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            durationSeconds: 1,
            outputPath: "stdout"
        )
    ))
}

private func continuousLocalhostSenderConfiguration(
    port: UInt16,
    receiverConfiguration: UdpPcmRouteRunConfiguration
) -> UdpPcmRouteRunConfiguration {
    UdpPcmRouteRunConfiguration(UdpPcmRouteRunConfiguration.Input(
        transport: .init(
            role: .sender,
            peer: "127.0.0.1",
            port: UInt16(bigEndian: port),
            packetMode: receiverConfiguration.packetMode,
            durationSeconds: receiverConfiguration.durationSeconds,
            outputPath: "stdout"
        )
    ))
}

private func startContinuousReceiver(
    socket: Int32,
    configuration: UdpPcmRouteRunConfiguration
) throws -> ContinuousReceiverTask {
    let reportBox = UdpPcmRouteReportResultBox()
    let ready = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        ready.signal()
        do {
            let report = try runReceiverLoop(
                socket: socket,
                configuration: configuration
            )
            reportBox.store(.success(report))
        } catch {
            reportBox.store(.failure(error))
        }
        done.signal()
    }
    guard ready.wait(timeout: .now() + 2) == .success else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
    return ContinuousReceiverTask(reportBox: reportBox, done: done)
}

func requireContinuousReceiverCompletion(
    _ done: DispatchSemaphore,
    timeout: DispatchTimeInterval
) throws {
    guard done.wait(timeout: .now() + timeout) == .success else {
        throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
    }
}
