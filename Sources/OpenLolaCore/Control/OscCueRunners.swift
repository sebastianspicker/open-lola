import Darwin
import Dispatch
import Foundation

public enum OscCueExternalRunner {
    public static func run(configuration: OscCueExternalRunConfiguration) throws -> OscCueReport {
        let loopback = try OscCueUdpLoopbackRunner.run(
            count: configuration.count,
            port: configuration.port
        )
        var report = loopback
        report.id = "m11-osc-cue-external-run"
        report.title = "OSC cue loopback with first external peer evidence"
        report.firstExternalPeer = OscCueExternalPeerEvidence(
            kind: configuration.firstExternalPeerKind,
            host: configuration.externalHost,
            port: Int(configuration.externalPort),
            available: configuration.externalAvailable,
            unavailableReason: configuration.externalUnavailableReason
        )
        report.audioImpact.baselineReportId = configuration.audioBaselineReportId
        return report
    }
}

public enum OscCueUdpLoopbackRunner {
    public static func run(count: Int = 3, port: UInt16 = 0) throws -> OscCueReport {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(descriptor) }
        try bindLoopback(descriptor, port: port.bigEndian)
        let bound = try boundUdpPort(for: descriptor)

        var cues: [OscCueTimingSample] = []
        for index in 0..<count {
            let sent = DispatchTime.now().uptimeNanoseconds
            let message = OscCueMessage(
                cueId: String(format: "cue-%03d", index),
                senderTimestampNanoseconds: sent
            )
            try sendUdpPacket(try message.packetData(), socket: descriptor, port: bound)
            let received = try receiveUdpOscMessage(socket: descriptor)
            let receivedAt = DispatchTime.now().uptimeNanoseconds
            cues.append(
                OscCueTimingSample(
                    cueId: received.cueId,
                    senderTimestampNanoseconds: received.senderTimestampNanoseconds,
                    receiverTimestampNanoseconds: receivedAt,
                    jitterMicroseconds: Double(receivedAt - received.senderTimestampNanoseconds) / 1_000
                )
            )
        }

        return makeOscCueReport(
            id: "m11-osc-cue-udp-loopback",
            title: "OSC cue UDP loopback",
            cues: cues,
            transport: OscCueTransportEvidence(
                protocolName: "udp",
                localBindHost: "127.0.0.1",
                peerHost: "127.0.0.1",
                peerPort: Int(bound),
                liveUdpLoopback: true,
                sentPackets: count,
                receivedPackets: cues.count
            ),
            baselineReportId: nil
        )
    }
}

public enum OscCueSyntheticLoopback {
    public static func run() -> OscCueReport {
        let cues = [
            OscCueTimingSample(
                cueId: "cue-000",
                senderTimestampNanoseconds: 1_000_000,
                receiverTimestampNanoseconds: 2_000_000,
                jitterMicroseconds: 1_000
            ),
            OscCueTimingSample(
                cueId: "cue-001",
                senderTimestampNanoseconds: 2_000_000,
                receiverTimestampNanoseconds: 3_100_000,
                jitterMicroseconds: 1_100
            ),
            OscCueTimingSample(
                cueId: "cue-002",
                senderTimestampNanoseconds: 3_000_000,
                receiverTimestampNanoseconds: 4_200_000,
                jitterMicroseconds: 1_200
            ),
        ]
        return makeOscCueReport(
            id: "m11-osc-cue-synthetic-loopback",
            title: "Synthetic OSC cue loopback",
            cues: cues,
            transport: nil,
            baselineReportId: nil
        )
    }
}

private func makeOscCueReport(
    id: String,
    title: String,
    cues: [OscCueTimingSample],
    transport: OscCueTransportEvidence?,
    baselineReportId: String?
) -> OscCueReport {
    OscCueReport(
        id: id,
        title: title,
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        peer: OscCuePeerReport(
            kind: .localLoopback,
            label: "local loopback",
            available: true,
            unavailableReason: nil
        ),
        transport: transport,
        firstExternalPeer: nil,
        message: OscCueMessageProfile(
            address: OscCueMessage.address,
            typeTags: OscCueMessage.typeTags,
            timestampEncoding: "nanoseconds-string",
            cueCount: cues.count
        ),
        cues: cues,
        jitter: packetAgeMetrics(for: cues.map(\.jitterMicroseconds)),
        audioImpact: OscCueAudioImpactMetrics(
            baselineCallbackP99Microseconds: 80,
            cueLoopCallbackP99Microseconds: 80,
            baselineCallbackMaxMicroseconds: 95,
            cueLoopCallbackMaxMicroseconds: 95,
            baselinePlayoutTargetFrames: 32,
            cueLoopPlayoutTargetFrames: 32,
            underruns: 0,
            hiddenAudioImpactDetected: false,
            baselineReportId: baselineReportId,
            synthetic: true
        ),
        durationSeconds: 1,
        verdict: .partial,
        notes: "OSC cue loopback validates message and timing contracts; external cue peer PASS evidence remains open."
    )
}
