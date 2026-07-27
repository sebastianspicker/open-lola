// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// Provides deterministic DirectPeerMeshRuntimeSmoke coverage without requiring external direct peer sessions infrastructure.
public enum DirectPeerMeshRuntimeSmoke {
    public static func run(
        peerCount: Int = 3,
        packetCount: Int = 1
    ) throws -> DirectPeerMeshRuntimeReport {
        guard packetCount > 0 else {
            throw DirectPeerMeshRuntimeError.invalidPacketCount(packetCount)
        }
        let sockets = try MeshRuntimeSockets.bind(peerCount: peerCount)
        defer { sockets.close() }
        let topology = try DirectPeerMeshTopologySmoke.run(
            peerCount: peerCount,
            peerMediaEndpoints: sockets.endpoints
        )
        let mode = try meshRuntimeAudioMode(
            stream: topology.configuration.audioStreams[0],
            mtuBytes: topology.configuration.mtuBytes
        )
        let routeMetrics = topology.routes.enumerated().map { routeIndex, route in
            do {
                return try runRoute(
                    route,
                    routeIndex: routeIndex,
                    packetCount: packetCount,
                    mode: mode,
                    sockets: sockets
                )
            } catch {
                return failedRouteMetric(route, packetCount: packetCount)
            }
        }
        return try makeReport(peerCount: peerCount, topology: topology, routeMetrics: routeMetrics)
    }

    private static func makeReport(
        peerCount: Int,
        topology: DirectPeerMeshTopologyReport,
        routeMetrics: [DirectPeerMeshRuntimeRouteMetrics]
    ) throws -> DirectPeerMeshRuntimeReport {
        let metrics = DirectPeerMeshRuntimeMetrics(
            peerCount: topology.configuration.peers.count,
            directedRouteCount: routeMetrics.count,
            audioDeadlinesSent: routeMetrics.map(\.audioDeadlinesSent).reduce(0, +),
            audioDeadlinesReceived: routeMetrics.map(\.audioDeadlinesReceived).reduce(0, +),
            audioFragmentsSent: routeMetrics.map(\.audioFragmentsSent).reduce(0, +),
            audioFragmentsReceived: routeMetrics.map(\.audioFragmentsReceived).reduce(0, +),
            incompleteAudioDeadlines: routeMetrics.map(\.incompleteAudioDeadlines).reduce(0, +),
            duplicateAudioFragments: routeMetrics.map(\.duplicateAudioFragments).reduce(0, +),
            audioPayloadsSentOnControlChannel: 0
        )
        let report = DirectPeerMeshRuntimeReport(
            id: "m06-direct-p2p-mesh-runtime-\(peerCount)",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            topology: topology,
            routeMetrics: routeMetrics,
            metrics: metrics,
            verdict: .partial,
            notes: "Localhost mesh runtime smoke exchanged UDP PCM v2 audio across every directed peer pair. "
                + "PASS requires physical multi-peer route, packet capture, and audio hardware evidence."
        )
        try report.validate()
        return report
    }

    private static func runRoute(
        _ route: DirectPeerMeshRoute,
        routeIndex: Int,
        packetCount: Int,
        mode: AudioTransportMode,
        sockets: MeshRuntimeSockets
    ) throws -> DirectPeerMeshRuntimeRouteMetrics {
        let sender = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 2)
        defer { sender.close() }
        guard let receiver = sockets.audioReceivers[route.receiverPeerID] else {
            throw DirectPeerMeshRuntimeError.routeMetricReferencesUnknownRoute(
                sender: route.senderPeerID,
                receiver: route.receiverPeerID
            )
        }
        try sender.connect(to: receiver.localEndpoint)

        let context = MeshRuntimeRouteContext(
            route: route,
            routeIndex: routeIndex,
            packetCount: packetCount,
            mode: mode,
            sender: sender,
            receiver: receiver
        )
        var counters = MeshRuntimeRouteCounters()
        for packetIndex in 0..<packetCount {
            try runRoutePacket(packetIndex: packetIndex, context: context, counters: &counters)
        }
        return makeRouteMetric(route: route, packetCount: packetCount, counters: counters)
    }

    private static func runRoutePacket(
        packetIndex: Int,
        context: MeshRuntimeRouteContext,
        counters: inout MeshRuntimeRouteCounters
    ) throws {
        let sequence = UInt64(context.routeIndex * context.packetCount + packetIndex + 1)
        let packets = try meshRuntimeAudioPackets(sequenceNumber: sequence, mode: context.mode)
        for packet in packets {
            try context.sender.send(UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .audioPcmV2,
                    streamID: UInt32(context.route.audioStreamID),
                    sequenceNumber: sequence,
                    timestampNanoseconds: packet.header.senderHostTimeNanoseconds
                ),
                payload: try packet.encoded()
            ))
        }
        let received = try receiveRoutePackets(count: packets.count, receiver: context.receiver)
        let reassembled = try UdpPcmV2FragmentReassembler.reassemble(received)
        counters.record(sentFragments: packets.count, reassembled: reassembled)
    }

    private static func receiveRoutePackets(
        count: Int,
        receiver: UdpMediaTransport
    ) throws -> [UdpPcmV2Packet] {
        try (0..<count).map { _ in
            let packet = try receiver.receive(maxByteCount: 2_048)
            return try UdpPcmV2Packet.decode(packet.payload)
        }
    }

    private static func makeRouteMetric(
        route: DirectPeerMeshRoute,
        packetCount: Int,
        counters: MeshRuntimeRouteCounters
    ) -> DirectPeerMeshRuntimeRouteMetrics {
        DirectPeerMeshRuntimeRouteMetrics(
            senderPeerID: route.senderPeerID,
            receiverPeerID: route.receiverPeerID,
            audioDeadlinesSent: packetCount,
            audioDeadlinesReceived: counters.completeDeadlines,
            audioFragmentsSent: counters.sentFragments,
            audioFragmentsReceived: counters.receivedFragments,
            incompleteAudioDeadlines: counters.incompleteDeadlines,
            duplicateAudioFragments: counters.duplicateFragments
        )
    }

    private static func failedRouteMetric(
        _ route: DirectPeerMeshRoute,
        packetCount: Int
    ) -> DirectPeerMeshRuntimeRouteMetrics {
        DirectPeerMeshRuntimeRouteMetrics(
            senderPeerID: route.senderPeerID,
            receiverPeerID: route.receiverPeerID,
            audioDeadlinesSent: packetCount,
            audioDeadlinesReceived: 0,
            audioFragmentsSent: 0,
            audioFragmentsReceived: 0,
            incompleteAudioDeadlines: packetCount,
            duplicateAudioFragments: 0
        )
    }

    private static func meshRuntimeAudioMode(
        stream: AudioStreamDescription,
        mtuBytes: Int
    ) throws -> AudioTransportMode {
        let fragments = try UdpPcmV2FragmentPlanner.plan(stream: stream, mtuBytes: mtuBytes)
        return udpPcmV2AudioTransportMode(
            stream: stream,
            fragments: fragments,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: mtuBytes
        )
    }

    private static func meshRuntimeAudioPackets(
        sequenceNumber: UInt64,
        mode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        try directPeerSyntheticAudioPackets(sequenceNumber: sequenceNumber, mode: mode)
    }
}
private struct MeshRuntimeRouteContext {
    let route: DirectPeerMeshRoute
    let routeIndex: Int
    let packetCount: Int
    let mode: AudioTransportMode
    let sender: UdpMediaTransport
    let receiver: UdpMediaTransport
}
private struct MeshRuntimeRouteCounters {
    var sentFragments = 0
    var receivedFragments = 0
    var completeDeadlines = 0
    var incompleteDeadlines = 0
    var duplicateFragments = 0

    mutating func record(sentFragments: Int, reassembled: UdpPcmV2ReassemblyResult) {
        self.sentFragments += sentFragments
        receivedFragments += sentFragments
        duplicateFragments += reassembled.duplicateFragmentIndices.count
        if reassembled.isComplete {
            completeDeadlines += 1
        } else {
            incompleteDeadlines += 1
        }
    }
}
private struct MeshRuntimeSockets {
    var endpoints: [SessionPeerMediaEndpoints]
    var audioReceivers: [String: UdpMediaTransport]
    var controlSockets: [UdpMediaTransport]
    var videoSockets: [UdpMediaTransport]
    var metricsSockets: [UdpMediaTransport]

    static func bind(peerCount: Int) throws -> MeshRuntimeSockets {
        guard peerCount >= 3 else {
            throw SessionValidationError.peerCountBelowMinimum(requested: peerCount, minimum: 3)
        }
        var endpoints: [SessionPeerMediaEndpoints] = []
        var audioReceivers: [String: UdpMediaTransport] = [:]
        var controlSockets: [UdpMediaTransport] = []
        var videoSockets: [UdpMediaTransport] = []
        var metricsSockets: [UdpMediaTransport] = []

        for index in 0..<peerCount {
            let peerID = "peer-\(UnicodeScalar(97 + index)!)"
            let control = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 2)
            let audio = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 2)
            let video = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 2)
            let metrics = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 2)
            controlSockets.append(control)
            audioReceivers[peerID] = audio
            videoSockets.append(video)
            metricsSockets.append(metrics)
            endpoints.append(SessionPeerMediaEndpoints(
                peerID: peerID,
                controlEndpoint: control.localEndpoint,
                audioEndpoint: audio.localEndpoint,
                videoEndpoint: video.localEndpoint,
                metricsEndpoint: metrics.localEndpoint
            ))
        }
        return MeshRuntimeSockets(
            endpoints: endpoints,
            audioReceivers: audioReceivers,
            controlSockets: controlSockets,
            videoSockets: videoSockets,
            metricsSockets: metricsSockets
        )
    }

    func close() {
        for socket in controlSockets {
            socket.close()
        }
        for socket in audioReceivers.values {
            socket.close()
        }
        for socket in videoSockets {
            socket.close()
        }
        for socket in metricsSockets {
            socket.close()
        }
    }
}
