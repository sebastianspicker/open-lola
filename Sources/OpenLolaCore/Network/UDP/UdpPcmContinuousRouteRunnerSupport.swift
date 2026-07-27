// Runs connected sender and receiver loops, accumulates packet metrics, and prepares endpoint report context outside command orchestration.
import Darwin
import Dispatch
import Foundation

struct UdpPcmSenderLoopResult: Equatable, Sendable {
    var packetsSent: Int
    var sendErrors: Int
}

struct UdpPcmReceiverLoopResult: Equatable, Sendable {
    var packetsReceived: Int
    var uniquePacketsReceived: Int
    var latePackets: Int
    var reorderedPackets: Int
    var duplicatePackets: Int
    var receiveErrors: Int
    var ages: [Double]
}

struct UdpPcmReceiverMetricsAccumulator {
    var expectedSequence: UInt64?
    var seenSequences = Set<UInt64>()
    var ages: [Double] = []
    var packetsReceived = 0
    var latePackets = 0
    var reorderedPackets = 0
    var duplicatePackets = 0
    var receiveErrors = 0

    init(expectedPacketCount: Int) {
        ages.reserveCapacity(expectedPacketCount)
    }

    mutating func record(packet: UdpPcmPacket, receivedAt: UInt64, playoutTarget: Double) {
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
    }

    func result() -> UdpPcmReceiverLoopResult {
        UdpPcmReceiverLoopResult(
            packetsReceived: packetsReceived,
            uniquePacketsReceived: seenSequences.count,
            latePackets: latePackets,
            reorderedPackets: reorderedPackets,
            duplicatePackets: duplicatePackets,
            receiveErrors: receiveErrors,
            ages: ages
        )
    }
}

final class UdpPcmRouteReportResultBox: @unchecked Sendable {
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

func runConnectedSenderLoop(
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

func runReceiverLoop(
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
        identity: .init(
            id: configuration.reportID ?? "m05-continuous-receiver-\(UUID().uuidString)",
            title: configuration.title ?? "Continuous UDP PCM route receiver report",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            route: RouteIdentity(
                label: configuration.routeLabel,
                topology: configuration.routeTopology
            ),
            routeKind: configuration.routeKind
        ),
        endpoints: .init(
            sender: configuration.sender,
            receiver: continuousReceiverEndpoint(configuration.receiver, hostName: context.hostName)
        ),
        measurement: .init(
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
            )
        ),
        outcome: .init(
            verdict: configuration.verdict,
            notes: configuration.notes ?? defaultReceiverNotes(for: configuration)
        )
    )
}

struct ContinuousReceiverReportContext {
    var lostPackets: Int
    var packetAge: UdpPcmPacketAgeMetrics
    var hostName: String
    var rxPolicy: RxBufferPolicy
}

func continuousReceiverReportContext(
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

func continuousReceiverEndpoint(
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

func continuousReceiverMetrics(
    configuration: UdpPcmRouteRunConfiguration,
    result: UdpPcmReceiverLoopResult,
    context: ContinuousReceiverReportContext
) -> UdpPcmRouteMetrics {
    UdpPcmRouteMetrics(
        delivery: .init(
            packetsSent: configuration.packetCount,
            packetsReceived: result.packetsReceived,
            lostPackets: context.lostPackets,
            latePackets: result.latePackets,
            reorderedPackets: result.reorderedPackets,
            duplicatePackets: result.duplicatePackets,
            receiveErrors: result.receiveErrors
        ),
        timing: .init(
            packetAge: context.packetAge,
            jitterP99Microseconds: jitterP99Microseconds(for: result.ages),
            playoutTargetMicroseconds: playoutTargetMicroseconds(configuration.packetMode)
        ),
        hiddenPlayoutGrowthDetected: false,
        rxBuffer: continuousReceiverRxBuffer(result: result, context: context)
    )
}

func continuousReceiverRxBuffer(
    result: UdpPcmReceiverLoopResult,
    context: ContinuousReceiverReportContext
) -> RxBufferRuntimeSnapshot {
    let maximumObservedBufferedPackets = result.packetsReceived > 0 ? 1 : 0
    let targetObservation = RxBufferRuntimeSnapshot.TargetObservation(
        maximumObservedBufferedPackets: maximumObservedBufferedPackets
    )
    let packetCounters = RxBufferRuntimeSnapshot.PacketCounters(
        latePackets: result.latePackets,
        duplicatePackets: result.duplicatePackets,
        reorderedPackets: result.reorderedPackets
    )
    return RxBufferRuntimeSnapshot(
        policy: context.rxPolicy,
        targetObservation: targetObservation,
        packetCounters: packetCounters
    )
}

func collectReceiverMetrics(
    socket: Int32,
    configuration: UdpPcmRouteRunConfiguration
) throws -> UdpPcmReceiverLoopResult {
    let expectedByteCount = UdpPcmPacketHeader.byteCount
        + configuration.packetMode.framesPerPacket
        * configuration.packetMode.channelCount
        * configuration.packetMode.sampleFormat.bytesPerSample
    let deadline = try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)
    let playoutTarget = playoutTargetMicroseconds(configuration.packetMode)
    var accumulator = UdpPcmReceiverMetricsAccumulator(expectedPacketCount: configuration.packetCount)

    while DispatchTime.now().uptimeNanoseconds < deadline
        && accumulator.seenSequences.count < configuration.packetCount {
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
                accumulator.receiveErrors += 1
                continue
            }

            accumulator.record(packet: packet, receivedAt: receivedAt, playoutTarget: playoutTarget)
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where error == EAGAIN || error == EWOULDBLOCK {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        } catch {
            throw error
        }
    }

    return accumulator.result()
}
