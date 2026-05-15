import Darwin
import Dispatch
import Foundation

public enum UdpPcmRouteLocalhostSmoke {
    public static func run(packetCount: Int = 5) throws -> UdpPcmRouteReport {
        guard packetCount > 0 else {
            throw UdpPcmRouteProbeError.invalidPacketCount(packetCount)
        }

        let receiverSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(receiverSocket) }
        let senderSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(senderSocket) }

        try bindLoopback(receiverSocket, port: 0)
        let port = try boundPort(receiverSocket)

        var tracker = UdpPcmSequenceTracker()
        var ages: [Double] = []

        for index in 0..<packetCount {
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
            ages.append(Double(receivedAt - sentAt) / 1_000)
        }

        return UdpPcmRouteReport(
            id: "m05-localhost-smoke",
            title: "Localhost UDP PCM route smoke",
            capturedAt: "2026-05-02T00:00:00Z",
            route: RouteIdentity(label: "localhost", topology: "loopback-udp"),
            routeKind: .localhostSmoke,
            sender: UdpPcmRouteEndpoint(
                label: "localhost-sender",
                hostName: Host.current().localizedName ?? "localhost",
                interfaceName: "lo0",
                ipAddress: "127.0.0.1"
            ),
            receiver: UdpPcmRouteEndpoint(
                label: "localhost-receiver",
                hostName: Host.current().localizedName ?? "localhost",
                interfaceName: "lo0",
                ipAddress: "127.0.0.1"
            ),
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            network: UdpPcmNetworkProfile(
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
            ),
            metrics: UdpPcmRouteMetrics(
                packetsSent: packetCount,
                packetsReceived: packetCount,
                lostPackets: 0,
                latePackets: 0,
                reorderedPackets: 0,
                duplicatePackets: 0,
                packetAge: packetAgeMetrics(for: ages),
                jitterP99Microseconds: jitterP99Microseconds(for: ages),
                playoutTargetMicroseconds: playoutTargetMicroseconds(UdpPcmPacketMode(
                    sampleRateHertz: 48_000,
                    framesPerPacket: 32,
                    channelCount: 2,
                    sampleFormat: .int16LittleEndian
                )),
                hiddenPlayoutGrowthDetected: false
            ),
            verdict: .partial,
            notes: "Source-level route probe passed on localhost; real M05 certification still needs two Macs and packet capture."
        )
    }
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
