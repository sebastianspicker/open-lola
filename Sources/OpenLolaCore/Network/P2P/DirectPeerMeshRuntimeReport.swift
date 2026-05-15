import Dispatch
import Foundation

public struct DirectPeerMeshRuntimeRouteMetrics: Codable, Equatable, Sendable {
    public var senderPeerID: String
    public var receiverPeerID: String
    public var audioDeadlinesSent: Int
    public var audioDeadlinesReceived: Int
    public var audioFragmentsSent: Int
    public var audioFragmentsReceived: Int
    public var incompleteAudioDeadlines: Int
    public var duplicateAudioFragments: Int

    public init(
        senderPeerID: String,
        receiverPeerID: String,
        audioDeadlinesSent: Int,
        audioDeadlinesReceived: Int,
        audioFragmentsSent: Int,
        audioFragmentsReceived: Int,
        incompleteAudioDeadlines: Int,
        duplicateAudioFragments: Int
    ) {
        self.senderPeerID = senderPeerID
        self.receiverPeerID = receiverPeerID
        self.audioDeadlinesSent = audioDeadlinesSent
        self.audioDeadlinesReceived = audioDeadlinesReceived
        self.audioFragmentsSent = audioFragmentsSent
        self.audioFragmentsReceived = audioFragmentsReceived
        self.incompleteAudioDeadlines = incompleteAudioDeadlines
        self.duplicateAudioFragments = duplicateAudioFragments
    }
}

public struct DirectPeerMeshRuntimeMetrics: Codable, Equatable, Sendable {
    public var peerCount: Int
    public var directedRouteCount: Int
    public var audioDeadlinesSent: Int
    public var audioDeadlinesReceived: Int
    public var audioFragmentsSent: Int
    public var audioFragmentsReceived: Int
    public var incompleteAudioDeadlines: Int
    public var duplicateAudioFragments: Int
    public var audioPayloadsSentOnControlChannel: Int

    public init(
        peerCount: Int,
        directedRouteCount: Int,
        audioDeadlinesSent: Int,
        audioDeadlinesReceived: Int,
        audioFragmentsSent: Int,
        audioFragmentsReceived: Int,
        incompleteAudioDeadlines: Int,
        duplicateAudioFragments: Int,
        audioPayloadsSentOnControlChannel: Int
    ) {
        self.peerCount = peerCount
        self.directedRouteCount = directedRouteCount
        self.audioDeadlinesSent = audioDeadlinesSent
        self.audioDeadlinesReceived = audioDeadlinesReceived
        self.audioFragmentsSent = audioFragmentsSent
        self.audioFragmentsReceived = audioFragmentsReceived
        self.incompleteAudioDeadlines = incompleteAudioDeadlines
        self.duplicateAudioFragments = duplicateAudioFragments
        self.audioPayloadsSentOnControlChannel = audioPayloadsSentOnControlChannel
    }
}

public enum DirectPeerMeshRuntimeError: Error, Equatable, Sendable {
    case emptyField(String)
    case invalidPacketCount(Int)
    case negativeMetric(String)
    case routeMetricReferencesUnknownRoute(sender: String, receiver: String)
    case duplicateRouteMetric(sender: String, receiver: String)
    case metricMismatch(String)
    case passRequiresPhysicalMeshEvidence
}

public struct DirectPeerMeshRuntimeReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var topology: DirectPeerMeshTopologyReport
    public var routeMetrics: [DirectPeerMeshRuntimeRouteMetrics]
    public var metrics: DirectPeerMeshRuntimeMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        topology: DirectPeerMeshTopologyReport,
        routeMetrics: [DirectPeerMeshRuntimeRouteMetrics],
        metrics: DirectPeerMeshRuntimeMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.topology = topology
        self.routeMetrics = routeMetrics
        self.metrics = metrics
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireMeshRuntimeNonEmpty(id, "id")
        try requireMeshRuntimeNonEmpty(capturedAt, "capturedAt")
        try requireMeshRuntimeNonEmpty(notes, "notes")
        try topology.validate()
        try validateRouteMetrics()
        try validateMetrics()
        if verdict == .pass {
            throw DirectPeerMeshRuntimeError.passRequiresPhysicalMeshEvidence
        }
    }

    private func validateRouteMetrics() throws {
        let expectedRoutes = Set(topology.routes.map {
            DirectPeerMeshDirectedPair(sender: $0.senderPeerID, receiver: $0.receiverPeerID)
        })
        try requireMeshRuntimeMetric(routeMetrics.count == expectedRoutes.count, "routeMetrics.count")
        var seenRoutes = Set<DirectPeerMeshDirectedPair>()
        for metric in routeMetrics {
            try requireMeshRuntimeNonEmpty(metric.senderPeerID, "routeMetrics.senderPeerID")
            try requireMeshRuntimeNonEmpty(metric.receiverPeerID, "routeMetrics.receiverPeerID")
            try requireMeshRuntimeNonNegative(metric.audioDeadlinesSent, "routeMetrics.audioDeadlinesSent")
            try requireMeshRuntimeNonNegative(metric.audioDeadlinesReceived, "routeMetrics.audioDeadlinesReceived")
            try requireMeshRuntimeNonNegative(metric.audioFragmentsSent, "routeMetrics.audioFragmentsSent")
            try requireMeshRuntimeNonNegative(metric.audioFragmentsReceived, "routeMetrics.audioFragmentsReceived")
            try requireMeshRuntimeNonNegative(
                metric.incompleteAudioDeadlines,
                "routeMetrics.incompleteAudioDeadlines"
            )
            try requireMeshRuntimeNonNegative(
                metric.duplicateAudioFragments,
                "routeMetrics.duplicateAudioFragments"
            )
            let pair = DirectPeerMeshDirectedPair(
                sender: metric.senderPeerID,
                receiver: metric.receiverPeerID
            )
            guard expectedRoutes.contains(pair) else {
                throw DirectPeerMeshRuntimeError.routeMetricReferencesUnknownRoute(
                    sender: metric.senderPeerID,
                    receiver: metric.receiverPeerID
                )
            }
            guard seenRoutes.insert(pair).inserted else {
                throw DirectPeerMeshRuntimeError.duplicateRouteMetric(
                    sender: metric.senderPeerID,
                    receiver: metric.receiverPeerID
                )
            }
        }
    }

    private func validateMetrics() throws {
        let peerCount = topology.configuration.peers.count
        try requireMeshRuntimeNonNegative(metrics.peerCount, "metrics.peerCount")
        try requireMeshRuntimeNonNegative(metrics.directedRouteCount, "metrics.directedRouteCount")
        try requireMeshRuntimeNonNegative(metrics.audioDeadlinesSent, "metrics.audioDeadlinesSent")
        try requireMeshRuntimeNonNegative(metrics.audioDeadlinesReceived, "metrics.audioDeadlinesReceived")
        try requireMeshRuntimeNonNegative(metrics.audioFragmentsSent, "metrics.audioFragmentsSent")
        try requireMeshRuntimeNonNegative(metrics.audioFragmentsReceived, "metrics.audioFragmentsReceived")
        try requireMeshRuntimeNonNegative(
            metrics.incompleteAudioDeadlines,
            "metrics.incompleteAudioDeadlines"
        )
        try requireMeshRuntimeNonNegative(
            metrics.duplicateAudioFragments,
            "metrics.duplicateAudioFragments"
        )
        try requireMeshRuntimeNonNegative(
            metrics.audioPayloadsSentOnControlChannel,
            "metrics.audioPayloadsSentOnControlChannel"
        )
        try requireMeshRuntimeMetric(metrics.peerCount == peerCount, "metrics.peerCount")
        try requireMeshRuntimeMetric(
            metrics.directedRouteCount == routeMetrics.count,
            "metrics.directedRouteCount"
        )
        try requireMeshRuntimeMetric(
            metrics.audioDeadlinesSent == routeMetrics.map(\.audioDeadlinesSent).reduce(0, +),
            "metrics.audioDeadlinesSent"
        )
        try requireMeshRuntimeMetric(
            metrics.audioDeadlinesReceived == routeMetrics.map(\.audioDeadlinesReceived).reduce(0, +),
            "metrics.audioDeadlinesReceived"
        )
        try requireMeshRuntimeMetric(
            metrics.audioFragmentsSent == routeMetrics.map(\.audioFragmentsSent).reduce(0, +),
            "metrics.audioFragmentsSent"
        )
        try requireMeshRuntimeMetric(
            metrics.audioFragmentsReceived == routeMetrics.map(\.audioFragmentsReceived).reduce(0, +),
            "metrics.audioFragmentsReceived"
        )
        try requireMeshRuntimeMetric(
            metrics.incompleteAudioDeadlines == routeMetrics.map(\.incompleteAudioDeadlines).reduce(0, +),
            "metrics.incompleteAudioDeadlines"
        )
        try requireMeshRuntimeMetric(
            metrics.duplicateAudioFragments == routeMetrics.map(\.duplicateAudioFragments).reduce(0, +),
            "metrics.duplicateAudioFragments"
        )
    }
}

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
            notes: "Localhost mesh runtime smoke exchanged UDP PCM v2 audio across every directed peer pair. PASS requires physical multi-peer route, packet capture, and audio hardware evidence."
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

        var sentFragments = 0
        var receivedFragments = 0
        var completeDeadlines = 0
        var incompleteDeadlines = 0
        var duplicateFragments = 0
        for packetIndex in 0..<packetCount {
            let sequence = UInt64(routeIndex * packetCount + packetIndex + 1)
            let packets = try meshRuntimeAudioPackets(sequenceNumber: sequence, mode: mode)
            for packet in packets {
                try sender.send(UdpMediaPacket(
                    header: UdpMediaPacketHeader(
                        payloadType: .audioPcmV2,
                        streamID: UInt32(route.audioStreamID),
                        sequenceNumber: sequence,
                        timestampNanoseconds: packet.header.senderHostTimeNanoseconds
                    ),
                    payload: try packet.encoded()
                ))
            }
            sentFragments += packets.count

            let received = try (0..<packets.count).map { _ in
                let packet = try receiver.receive(maxByteCount: 2_048)
                receivedFragments += 1
                return try UdpPcmV2Packet.decode(packet.payload)
            }
            let reassembled = try UdpPcmV2FragmentReassembler.reassemble(received)
            duplicateFragments += reassembled.duplicateFragmentIndices.count
            if reassembled.isComplete {
                completeDeadlines += 1
            } else {
                incompleteDeadlines += 1
            }
        }
        return DirectPeerMeshRuntimeRouteMetrics(
            senderPeerID: route.senderPeerID,
            receiverPeerID: route.receiverPeerID,
            audioDeadlinesSent: packetCount,
            audioDeadlinesReceived: completeDeadlines,
            audioFragmentsSent: sentFragments,
            audioFragmentsReceived: receivedFragments,
            incompleteAudioDeadlines: incompleteDeadlines,
            duplicateAudioFragments: duplicateFragments
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
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: stream.id,
                totalChannelCount: stream.channelCount,
                framesPerPacket: stream.framesPerPacket,
                sampleRateHertz: stream.sampleRateHertz,
                sampleFormat: stream.sampleFormat,
                maxTransmissionUnitBytes: mtuBytes,
                maxFragmentsPerDeadline: 16,
                metadataRevision: 0,
                packingMode: .interleavedChannelRange
            )
        )
        return AudioTransportMode(
            protocolVersion: .udpPcmV2,
            sampleRateHertz: stream.sampleRateHertz,
            framesPerPacket: stream.framesPerPacket,
            channelCount: stream.channelCount,
            sampleFormat: stream.sampleFormat,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: mtuBytes,
            channelOrder: stream.channelOrder,
            fragments: fragments
        )
    }

    private static func meshRuntimeAudioPackets(
        sequenceNumber: UInt64,
        mode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        try UdpPcmV2Packetizer.packetize(
            Data(
                repeating: UInt8(sequenceNumber & 0xFF),
                count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
            ),
            sequenceNumber: sequenceNumber,
            senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
            senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            mode: mode
        )
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

private func requireMeshRuntimeNonEmpty(_ value: String, _ field: String) throws {
    try requireDirectPeerMeshNonEmpty(value, field, makeError: DirectPeerMeshRuntimeError.emptyField)
}

private func requireMeshRuntimeNonNegative(_ value: Int, _ field: String) throws {
    try requireDirectPeerMeshNonNegative(value, field, makeError: DirectPeerMeshRuntimeError.negativeMetric)
}

private func requireMeshRuntimeMetric(_ condition: Bool, _ field: String) throws {
    try requireDirectPeerMeshMetric(condition, field, makeError: DirectPeerMeshRuntimeError.metricMismatch)
}
