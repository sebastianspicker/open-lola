extension JackTripCompatibilityRunner {
    static func analyze(
        _ datagrams: [JackTripCompatibilityDatagram]
    ) -> (missing: Int, duplicates: Int, outOfOrder: Int, redundancyRecovered: Int) {
        guard !datagrams.isEmpty else {
            return (0, 0, 0, 0)
        }
        let primarySequences = datagrams.compactMap { $0.packets.first?.header.sequenceNumber }
        let packets = datagrams.flatMap(\.packets)
        guard !packets.isEmpty else {
            return (0, 0, 0, 0)
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
        return (
            missingAfterRedundancy,
            max(0, allSequences.count - uniqueSequences.count),
            outOfOrder,
            recoveredByRedundancy
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
        _ datagrams: [JackTripCompatibilityDatagram]
    ) -> ExternalConnectorMediaSinkReport {
        var audioPacketCount = 0
        var audioPayloadByteCount = 0
        var rejectedMediaCount = 0

        for packet in datagrams.flatMap(\.packets) {
            do {
                let interleaved = try JackTripAudioPayloadCodec.interleavedPayload(
                    planarLittleEndianPCM: packet.planarAudioPayload,
                    channels: Int(packet.header.payloadChannelCount),
                    frames: Int(packet.header.bufferSizeSamples),
                    bitResolution: packet.header.bitResolution
                )
                audioPacketCount += 1
                audioPayloadByteCount += interleaved.count
            } catch {
                rejectedMediaCount += 1
            }
        }

        return ExternalConnectorMediaSinkReport(
            audioPacketCount: audioPacketCount,
            audioPayloadByteCount: audioPayloadByteCount,
            videoFrameCount: 0,
            videoPayloadByteCount: 0,
            rejectedMediaCount: rejectedMediaCount,
            notes: "Decoded JackTrip DEFAULT planar PCM into bounded interleaved PCM artifact sink counters."
        )
    }
}
