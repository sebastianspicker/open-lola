import Darwin
import Dispatch
import Foundation

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
    UdpPcmRouteRunConfiguration(
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
        outputPath: "stdout",
        dscp: nil
    )
}

private func continuousLocalhostSenderConfiguration(
    port: UInt16,
    receiverConfiguration: UdpPcmRouteRunConfiguration
) -> UdpPcmRouteRunConfiguration {
    UdpPcmRouteRunConfiguration(
        role: .sender,
        peer: "127.0.0.1",
        port: UInt16(bigEndian: port),
        packetMode: receiverConfiguration.packetMode,
        durationSeconds: receiverConfiguration.durationSeconds,
        outputPath: "stdout",
        dscp: nil
    )
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

private struct UdpPcmSenderLoopResult: Equatable, Sendable {
    var packetsSent: Int
    var sendErrors: Int
}

private struct UdpPcmReceiverLoopResult: Equatable, Sendable {
    var packetsReceived: Int
    var uniquePacketsReceived: Int
    var latePackets: Int
    var reorderedPackets: Int
    var duplicatePackets: Int
    var receiveErrors: Int
    var ages: [Double]
}

private final class UdpPcmRouteReportResultBox: @unchecked Sendable {
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
        guard let storedResult else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        return storedResult
    }
}

private func runConnectedSenderLoop(
    socket: Int32,
    configuration: UdpPcmRouteRunConfiguration
) throws -> UdpPcmSenderLoopResult {
    var packetsSent = 0
    var sendErrors = 0
    let intervalNanoseconds = packetIntervalNanoseconds(configuration.packetMode)
    let start = DispatchTime.now().uptimeNanoseconds

    for index in 0..<configuration.packetCount {
        let packet = makeProbePacket(
            sequenceNumber: UInt64(index),
            senderFrameIndex: UInt64(index * configuration.packetMode.framesPerPacket),
            packetMode: configuration.packetMode
        )
        do {
            try sendConnectedDatagram(try packet.encoded(), socket: socket)
            packetsSent += 1
        } catch UdpPcmRouteProbeError.sendFailed {
            sendErrors += 1
        } catch UdpPcmRouteProbeError.shortSend {
            sendErrors += 1
        } catch {
            throw error
        }

        let nextDeadline = start + (UInt64(index + 1) * intervalNanoseconds)
        sleepUntilUptimeNanoseconds(nextDeadline)
    }

    return UdpPcmSenderLoopResult(packetsSent: packetsSent, sendErrors: sendErrors)
}

private func runReceiverLoop(
    socket: Int32,
    configuration: UdpPcmRouteRunConfiguration
) throws -> UdpPcmRouteReport {
    let result = try collectReceiverMetrics(
        socket: socket,
        configuration: configuration
    )
    let context = try continuousReceiverReportContext(
        configuration: configuration,
        result: result
    )
    return UdpPcmRouteReport(
        id: configuration.reportID ?? "m05-continuous-receiver-\(UUID().uuidString)",
        title: configuration.title ?? "Continuous UDP PCM route receiver report",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        route: RouteIdentity(
            label: configuration.routeLabel,
            topology: configuration.routeTopology
        ),
        routeKind: configuration.routeKind,
        sender: configuration.sender,
        receiver: continuousReceiverEndpoint(configuration.receiver, hostName: context.hostName),
        packetMode: configuration.packetMode,
        measuredDurationSeconds: configuration.durationSeconds,
        network: UdpPcmNetworkProfile(
            linkRateMbps: configuration.linkRateMbps,
            vlan: configuration.vlan,
            multicastPolicy: configuration.multicastPolicy,
            dscp: dscpObservation(configuration),
            packetCapture: configuration.packetCapture
        ),
        metrics: continuousReceiverMetrics(
            configuration: configuration,
            result: result,
            context: context
        ),
        verdict: configuration.verdict,
        notes: configuration.notes ?? defaultReceiverNotes(for: configuration)
    )
}

private struct ContinuousReceiverReportContext {
    var lostPackets: Int
    var packetAge: UdpPcmPacketAgeMetrics
    var hostName: String
    var rxPolicy: RxBufferPolicy
}

private func continuousReceiverReportContext(
    configuration: UdpPcmRouteRunConfiguration,
    result: UdpPcmReceiverLoopResult
) throws -> ContinuousReceiverReportContext {
    ContinuousReceiverReportContext(
        lostPackets: max(0, configuration.packetCount - result.uniquePacketsReceived),
        packetAge: packetAgeMetrics(for: result.ages),
        hostName: Host.current().localizedName ?? "localhost",
        rxPolicy: try RxBufferPolicy.direct(
            framesPerPacket: configuration.packetMode.framesPerPacket,
            sampleRateHertz: configuration.packetMode.sampleRateHertz,
            targetPackets: 1
        )
    )
}

private func continuousReceiverEndpoint(
    _ receiver: UdpPcmRouteEndpoint,
    hostName: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: receiver.label,
        hostName: receiver.hostName == "localhost" ? hostName : receiver.hostName,
        interfaceName: receiver.interfaceName,
        ipAddress: receiver.ipAddress
    )
}

private func continuousReceiverMetrics(
    configuration: UdpPcmRouteRunConfiguration,
    result: UdpPcmReceiverLoopResult,
    context: ContinuousReceiverReportContext
) -> UdpPcmRouteMetrics {
    UdpPcmRouteMetrics(
        packetsSent: configuration.packetCount,
        packetsReceived: result.packetsReceived,
        lostPackets: context.lostPackets,
        latePackets: result.latePackets,
        reorderedPackets: result.reorderedPackets,
        duplicatePackets: result.duplicatePackets,
        receiveErrors: result.receiveErrors,
        packetAge: context.packetAge,
        jitterP99Microseconds: jitterP99Microseconds(for: result.ages),
        playoutTargetMicroseconds: playoutTargetMicroseconds(configuration.packetMode),
        hiddenPlayoutGrowthDetected: false,
        rxBuffer: continuousReceiverRxBuffer(result: result, context: context)
    )
}

private func continuousReceiverRxBuffer(
    result: UdpPcmReceiverLoopResult,
    context: ContinuousReceiverReportContext
) -> RxBufferRuntimeSnapshot {
    RxBufferRuntimeSnapshot(
        policy: context.rxPolicy,
        maximumObservedBufferedPackets: result.packetsReceived > 0 ? 1 : 0,
        latePackets: result.latePackets,
        duplicatePackets: result.duplicatePackets,
        reorderedPackets: result.reorderedPackets
    )
}

private func collectReceiverMetrics(
    socket: Int32,
    configuration: UdpPcmRouteRunConfiguration
) throws -> UdpPcmReceiverLoopResult {
    let expectedByteCount = UdpPcmPacketHeader.byteCount
        + configuration.packetMode.framesPerPacket
        * configuration.packetMode.channelCount
        * configuration.packetMode.sampleFormat.bytesPerSample
    let deadline = try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)
    let playoutTarget = playoutTargetMicroseconds(configuration.packetMode)
    var expectedSequence: UInt64?
    var seenSequences = Set<UInt64>()
    var ages: [Double] = []
    ages.reserveCapacity(configuration.packetCount)
    var packetsReceived = 0
    var latePackets = 0
    var reorderedPackets = 0
    var duplicatePackets = 0
    var receiveErrors = 0

    while DispatchTime.now().uptimeNanoseconds < deadline
        && seenSequences.count < configuration.packetCount {
        do {
            guard let data = try receiveDatagramIfAvailable(
                socket: socket,
                byteCount: expectedByteCount
            ) else {
                try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
                continue
            }

            let receivedAt = DispatchTime.now().uptimeNanoseconds
            let packet = try UdpPcmPacket.decode(data)
            guard packet.header.sampleRateHertz == UInt32(configuration.packetMode.sampleRateHertz),
                  packet.header.framesPerPacket == UInt32(configuration.packetMode.framesPerPacket),
                  packet.header.channelCount == UInt16(configuration.packetMode.channelCount),
                  packet.header.sampleFormat == configuration.packetMode.sampleFormat else {
                receiveErrors += 1
                continue
            }

            packetsReceived += 1
            let sequenceNumber = packet.header.sequenceNumber
            if seenSequences.contains(sequenceNumber) {
                duplicatePackets += 1
            } else if let nextExpectedSequence = expectedSequence {
                if sequenceNumber < nextExpectedSequence {
                    reorderedPackets += 1
                } else {
                    expectedSequence = sequenceNumber + 1
                }
            } else {
                expectedSequence = sequenceNumber + 1
            }
            seenSequences.insert(sequenceNumber)

            let sentAt = packet.header.senderHostTimeNanoseconds
            let age = receivedAt >= sentAt ? Double(receivedAt - sentAt) / 1_000 : 0
            ages.append(age)
            if age > playoutTarget {
                latePackets += 1
            }
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where error == EAGAIN || error == EWOULDBLOCK {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        } catch {
            throw error
        }
    }

    return UdpPcmReceiverLoopResult(
        packetsReceived: packetsReceived,
        uniquePacketsReceived: seenSequences.count,
        latePackets: latePackets,
        reorderedPackets: reorderedPackets,
        duplicatePackets: duplicatePackets,
        receiveErrors: receiveErrors,
        ages: ages
    )
}
