import Darwin
import Dispatch
import Foundation

public enum UdpPcmRouteLocalhostSmoke {
    public static func run(packetCount: Int = 5) throws -> UdpPcmRouteReport {
        guard packetCount > 0 else {
            throw UdpPcmRouteProbeError.invalidPacketCount(packetCount)
        }

        let probeResult = try runLoopbackProbe(packetCount: packetCount)
        return makeLocalhostReport(packetCount: packetCount, ages: probeResult.ages)
    }

    private static func runLoopbackProbe(packetCount: Int) throws -> UdpPcmRouteLocalhostProbeResult {
        let receiverSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(receiverSocket) }
        let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(senderSocket) }

        try bindLoopback(receiverSocket, port: 0)
        let port = try boundPort(receiverSocket)

        var tracker = UdpPcmSequenceTracker()
        var ages: [Double] = []

        for index in 0..<packetCount {
            let age = try sendAndReceiveProbe(
                index: index,
                senderSocket: senderSocket,
                receiverSocket: receiverSocket,
                port: port,
                tracker: &tracker
            )
            ages.append(age)
        }

        return UdpPcmRouteLocalhostProbeResult(ages: ages)
    }

    private static func sendAndReceiveProbe(
        index: Int,
        senderSocket: Int32,
        receiverSocket: Int32,
        port: UInt16,
        tracker: inout UdpPcmSequenceTracker
    ) throws -> Double {
        let packet = makeProbePacket(
            sequenceNumber: UInt64(index),
            senderFrameIndex: UInt64(index * 32)
        )
        let encoded = try packet.encoded()

        try sendDatagram(encoded, socket: senderSocket, host: "127.0.0.1", port: port)
        let received = try receiveDatagram(socket: receiverSocket, byteCount: encoded.count)
        let decoded = try UdpPcmPacket.decode(received)
        try tracker.accept(decoded)

        let receivedAt = DispatchTime.now().uptimeNanoseconds
        let sentAt = decoded.header.senderHostTimeNanoseconds
        return Double(receivedAt - sentAt) / 1_000
    }

    private static func makeLocalhostReport(packetCount: Int, ages: [Double]) -> UdpPcmRouteReport {
        return UdpPcmRouteReport(
            id: "m05-localhost-smoke",
            title: "Localhost UDP PCM route smoke",
            capturedAt: "2026-05-02T00:00:00Z",
            route: RouteIdentity(label: "localhost", topology: "loopback-udp"),
            routeKind: .localhostSmoke,
            sender: makeLocalhostEndpoint(label: "localhost-sender"),
            receiver: makeLocalhostEndpoint(label: "localhost-receiver"),
            packetMode: localhostPacketMode,
            network: makeLocalhostNetworkProfile(),
            metrics: makeLocalhostMetrics(packetCount: packetCount, ages: ages),
            verdict: .partial,
            notes: "Source-level route probe passed on localhost; real M05 certification still needs two Macs and packet capture."
        )
    }

    private static func makeLocalhostEndpoint(label: String) -> UdpPcmRouteEndpoint {
        UdpPcmRouteEndpoint(
            label: label,
            hostName: Host.current().localizedName ?? "localhost",
            interfaceName: "lo0",
            ipAddress: "127.0.0.1"
        )
    }

    private static func makeLocalhostNetworkProfile() -> UdpPcmNetworkProfile {
        UdpPcmNetworkProfile(
            linkRateMbps: nil,
            vlan: "none",
            multicastPolicy: "loopback-unicast",
            dscp: UdpPcmDscpObservation(
                requested: nil,
                observed: nil,
                classification: .notTested,
                notTestedReason: "localhost smoke does not exercise DSCP marking or route policy"
            ),
            packetCapture: UdpPcmPacketCapture(
                point: nil,
                receiverCorrelation: nil,
                notes: "localhost smoke only; not a physical route packet capture"
            )
        )
    }

    private static func makeLocalhostMetrics(packetCount: Int, ages: [Double]) -> UdpPcmRouteMetrics {
        UdpPcmRouteMetrics(
            packetsSent: packetCount,
            packetsReceived: packetCount,
            lostPackets: 0,
            latePackets: 0,
            reorderedPackets: 0,
            duplicatePackets: 0,
            packetAge: packetAgeMetrics(for: ages),
            jitterP99Microseconds: jitterP99Microseconds(for: ages),
            playoutTargetMicroseconds: playoutTargetMicroseconds(localhostPacketMode),
            hiddenPlayoutGrowthDetected: false
        )
    }

    private static let localhostPacketMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

private struct UdpPcmRouteLocalhostProbeResult {
    var ages: [Double]
}

public enum UdpPcmOneShotSender {
    public static func send(host: String, port: UInt16) throws -> UdpPcmPacket {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 0)
        defer { close(descriptor) }

        let packet = makeProbePacket(sequenceNumber: 0, senderFrameIndex: 0)
        try sendDatagram(try packet.encoded(), socket: descriptor, host: host, port: port.bigEndian)
        return packet
    }
}

public enum UdpPcmOneShotReceiver {
    public static func receive(port: UInt16) throws -> UdpPcmPacket {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 5)
        defer { close(descriptor) }

        try bindAnyIPv4(descriptor, port: port.bigEndian)
        let received = try receiveDatagram(
            socket: descriptor,
            byteCount: UdpPcmPacketHeader.byteCount + 32 * 2 * 2
        )
        return try UdpPcmPacket.decode(received)
    }
}
