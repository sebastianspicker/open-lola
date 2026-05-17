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

        let configuration = UdpPcmRouteRunConfiguration(
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

        let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 0)
        defer { close(senderSocket) }
        try setNonBlocking(senderSocket)
        try bindLoopback(senderSocket, port: 0)
        try connectUdpSocket(senderSocket, host: "127.0.0.1", port: port)

        let receiverBox = UdpPcmRouteReportResultBox()
        let ready = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            ready.signal()
            do {
                let report = try runReceiverLoop(
                    socket: receiverSocket,
                    configuration: configuration
                )
                receiverBox.store(.success(report))
            } catch {
                receiverBox.store(.failure(error))
            }
            done.signal()
        }

        guard ready.wait(timeout: .now() + 2) == .success else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        let senderConfiguration = UdpPcmRouteRunConfiguration(
            role: .sender,
            peer: "127.0.0.1",
            port: UInt16(bigEndian: port),
            packetMode: configuration.packetMode,
            durationSeconds: configuration.durationSeconds,
            outputPath: "stdout",
            dscp: nil
        )
        _ = try runConnectedSenderLoop(
            socket: senderSocket,
            configuration: senderConfiguration
        )
        try requireContinuousReceiverCompletion(done, timeout: .seconds(2))
        return try receiverBox.result().get()
    }
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
    let lostPackets = max(0, configuration.packetCount - result.uniquePacketsReceived)
    let packetAge = packetAgeMetrics(for: result.ages)
    let hostName = Host.current().localizedName ?? "localhost"
    let rxPolicy = try RxBufferPolicy.direct(
        framesPerPacket: configuration.packetMode.framesPerPacket,
        sampleRateHertz: configuration.packetMode.sampleRateHertz,
        targetPackets: 1
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
        receiver: UdpPcmRouteEndpoint(
            label: configuration.receiver.label,
            hostName: configuration.receiver.hostName == "localhost" ? hostName : configuration.receiver.hostName,
            interfaceName: configuration.receiver.interfaceName,
            ipAddress: configuration.receiver.ipAddress
        ),
        packetMode: configuration.packetMode,
        measuredDurationSeconds: configuration.durationSeconds,
        network: UdpPcmNetworkProfile(
            linkRateMbps: configuration.linkRateMbps,
            vlan: configuration.vlan,
            multicastPolicy: configuration.multicastPolicy,
            dscp: dscpObservation(configuration),
            packetCapture: configuration.packetCapture
        ),
        metrics: UdpPcmRouteMetrics(
            packetsSent: configuration.packetCount,
            packetsReceived: result.packetsReceived,
            lostPackets: lostPackets,
            latePackets: result.latePackets,
            reorderedPackets: result.reorderedPackets,
            duplicatePackets: result.duplicatePackets,
            receiveErrors: result.receiveErrors,
            packetAge: packetAge,
            jitterP99Microseconds: jitterP99Microseconds(for: result.ages),
            playoutTargetMicroseconds: playoutTargetMicroseconds(configuration.packetMode),
            hiddenPlayoutGrowthDetected: false,
            rxBuffer: RxBufferRuntimeSnapshot(
                policy: rxPolicy,
                maximumObservedBufferedPackets: result.packetsReceived > 0 ? 1 : 0,
                latePackets: result.latePackets,
                duplicatePackets: result.duplicatePackets,
                reorderedPackets: result.reorderedPackets
            )
        ),
        verdict: configuration.verdict,
        notes: configuration.notes ?? defaultReceiverNotes(for: configuration)
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
