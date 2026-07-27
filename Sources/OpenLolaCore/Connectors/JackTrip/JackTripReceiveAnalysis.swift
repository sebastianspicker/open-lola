// Handles JackTripReceiveAnalysis receive-side processing, isolating input handling from compatibility and report policy.
struct JackTripReceiveAnalysis: Equatable, Sendable {
    var missing: Int
    var duplicates: Int
    var outOfOrder: Int
    var redundancyRecovered: Int

    static let empty = JackTripReceiveAnalysis(
        missing: 0,
        duplicates: 0,
        outOfOrder: 0,
        redundancyRecovered: 0
    )
}

extension JackTripCompatibilityRunner {
    static func analyze(
        _ datagrams: [JackTripCompatibilityDatagram]
    ) -> JackTripReceiveAnalysis {
        guard !datagrams.isEmpty else {
            return .empty
        }
        let primarySequences = datagrams.compactMap { $0.packets.first?.header.sequenceNumber }
        let packets = datagrams.flatMap(\.packets)
        guard !packets.isEmpty else {
            return .empty
        }
        var outOfOrder = 0
        var previous = primarySequences[0]
        for sequence in primarySequences {
            if sequence < previous {
                outOfOrder += 1
            }
            previous = sequence
        }
        let allSequences = packets.map(\.header.sequenceNumber)
        let uniqueSequences = Set(allSequences)
        let primarySet = Set(primarySequences)
        let minSequence = uniqueSequences.min() ?? 0
        let maxSequence = uniqueSequences.max() ?? minSequence
        let expectedSequences = Set(minSequence...maxSequence)
        let missingAfterRedundancy = expectedSequences.subtracting(uniqueSequences).count
        let recoveredByRedundancy = expectedSequences.subtracting(primarySet).intersection(uniqueSequences).count
        return JackTripReceiveAnalysis(
            missing: missingAfterRedundancy,
            duplicates: max(0, allSequences.count - uniqueSequences.count),
            outOfOrder: outOfOrder,
            redundancyRecovered: recoveredByRedundancy
        )
    }

    static func learnedPeer(
        from datagrams: [JackTripCompatibilityDatagram]
    ) -> (host: String?, port: UInt16?) {
        for datagram in datagrams {
            if datagram.sourceHost != nil || datagram.sourcePort != nil {
                return (datagram.sourceHost, datagram.sourcePort)
            }
        }
        return (nil, nil)
    }

    static func consumeReceivedAudio(
        _ datagrams: [JackTripCompatibilityDatagram],
        payloadEncoding: JackTripPayloadEncoding,
        channels: Int
    ) -> ExternalConnectorMediaSinkReport {
        guard let sink = try? JackTripReceiveAudioSink(
            configuration: ExternalConnectorSessionConfiguration(.init(
                connector: .jackTrip,
                role: .rx,
                peer: "",
                outputPath: "/tmp/jacktrip-receive-analysis"
            ) { configuration in
                configuration.channels = channels
                configuration.jackTrip.payloadEncoding = payloadEncoding
            })
        ) else {
            return ExternalConnectorMediaSinkReport(
                rejectedMediaCount: datagrams.flatMap(\.packets).count,
                notes: "JackTrip receive payload decoder could not be initialized; no CoreAudio playout is performed."
            )
        }
        for datagram in datagrams {
            sink.consume(datagram)
        }
        return sink.report()
    }
}
