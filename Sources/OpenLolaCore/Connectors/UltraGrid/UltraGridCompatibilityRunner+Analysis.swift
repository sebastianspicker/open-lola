// Analyzes received UltraGrid RTP packets, fragment reassembly, quality counters, and evidence completeness.
import Foundation

extension UltraGridCompatibilityRunner {
    static func analyze(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> RuntimeMediaAnalysis {
        var lost = 0
        var duplicates = 0
        var outOfOrder = 0
        var ssrcChanges = 0
        var timestampRegressions = 0
        var jitterLikeArrivalDeltaChanges = 0
        for streamDatagrams in Dictionary(grouping: datagrams, by: \.stream).values {
            let stream = analyzeSequence(streamDatagrams)
            lost += stream.lost
            duplicates += stream.duplicates
            outOfOrder += stream.outOfOrder
            ssrcChanges += stream.ssrcChanges
            timestampRegressions += stream.timestampRegressions
            jitterLikeArrivalDeltaChanges += stream.jitterLikeArrivalDeltaChanges
        }
        let videoReassembly = countVideoFrameReassemblyFailures(datagrams)
        return RuntimeMediaAnalysis(
            lost: lost,
            duplicates: duplicates,
            outOfOrder: outOfOrder,
            ssrcChanges: ssrcChanges,
            timestampRegressions: timestampRegressions,
            jitterLikeArrivalDeltaChanges: jitterLikeArrivalDeltaChanges,
            videoFrameReassemblyFailures: videoReassembly.failureCount,
            videoFrameRecoveryFailed: videoReassembly.recoveryFailed
        )
    }

    static func analyzeSequence(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> RuntimeSequenceAnalysis {
        guard !datagrams.isEmpty else {
            return RuntimeSequenceAnalysis(
                lost: 0,
                duplicates: 0,
                outOfOrder: 0,
                ssrcChanges: 0,
                timestampRegressions: 0,
                jitterLikeArrivalDeltaChanges: 0
            )
        }
        let datagramsBySSRC = Dictionary(grouping: datagrams, by: \.rtp.header.ssrc)
        var lost = 0
        var duplicates = 0
        var outOfOrder = 0
        var timestampRegressions = 0
        var jitterLikeArrivalDeltaChanges = 0
        for ssrcDatagrams in datagramsBySSRC.values {
            let extendedSequences = extendSequenceNumbers(ssrcDatagrams.map(\.rtp.header.sequenceNumber))
            let uniqueSequences = Set(extendedSequences)
            let expected = (uniqueSequences.max() ?? 0) - (uniqueSequences.min() ?? 0) + 1
            lost += max(0, Int(expected) - uniqueSequences.count)
            duplicates += extendedSequences.count - uniqueSequences.count
            let timing = analyzeSequenceTiming(
                ssrcDatagrams,
                extendedSequences: extendedSequences,
                extendedTimestamps: extendTimestamps(ssrcDatagrams.map(\.rtp.header.timestamp))
            )
            outOfOrder += timing.outOfOrder
            timestampRegressions += timing.timestampRegressions
            jitterLikeArrivalDeltaChanges += timing.jitterLikeArrivalDeltaChanges
        }
        return RuntimeSequenceAnalysis(
            lost: lost,
            duplicates: duplicates,
            outOfOrder: outOfOrder,
            ssrcChanges: max(0, datagramsBySSRC.count - 1),
            timestampRegressions: timestampRegressions,
            jitterLikeArrivalDeltaChanges: jitterLikeArrivalDeltaChanges
        )
    }

    static func analyzeSequenceTiming(
        _ datagrams: [UltraGridCompatibilityDatagram],
        extendedSequences: [Int64],
        extendedTimestamps: [Int64]
    ) -> RuntimeSequenceTimingAnalysis {
        guard !datagrams.isEmpty else {
            return RuntimeSequenceTimingAnalysis(
                outOfOrder: 0,
                timestampRegressions: 0,
                jitterLikeArrivalDeltaChanges: 0
            )
        }
        var outOfOrder = 0
        var timestampRegressions = 0
        var jitterLikeDeltaChanges = 0
        var previousSequence = extendedSequences[0]
        var previousTimestamp = extendedTimestamps[0]
        var expectedTimestampDelta: Int64?
        for (sequence, timestamp) in zip(extendedSequences.dropFirst(), extendedTimestamps.dropFirst()) {
            if sequence < previousSequence {
                outOfOrder += 1
            }
            if timestamp < previousTimestamp {
                timestampRegressions += 1
            } else {
                let delta = timestamp - previousTimestamp
                if delta > 0 {
                    if let expectedTimestampDelta, delta != expectedTimestampDelta {
                        jitterLikeDeltaChanges += 1
                    } else if expectedTimestampDelta == nil {
                        expectedTimestampDelta = delta
                    }
                }
            }
            previousSequence = sequence
            previousTimestamp = timestamp
        }
        return RuntimeSequenceTimingAnalysis(
            outOfOrder: outOfOrder,
            timestampRegressions: timestampRegressions,
            jitterLikeArrivalDeltaChanges: jitterLikeDeltaChanges
        )
    }

    static func extendSequenceNumbers(_ sequenceNumbers: [UInt16]) -> [Int64] {
        guard let first = sequenceNumbers.first else {
            return []
        }
        let sequenceSpace: Int64 = 1 << 16
        let halfSequenceSpace = sequenceSpace / 2
        var highestExtendedSequence = Int64(first)
        return sequenceNumbers.map { sequenceNumber in
            var extendedSequence = (highestExtendedSequence / sequenceSpace) * sequenceSpace
                + Int64(sequenceNumber)
            if extendedSequence - highestExtendedSequence > halfSequenceSpace {
                extendedSequence -= sequenceSpace
            } else if highestExtendedSequence - extendedSequence > halfSequenceSpace {
                extendedSequence += sequenceSpace
            }
            highestExtendedSequence = max(highestExtendedSequence, extendedSequence)
            return extendedSequence
        }
    }

    static func extendTimestamps(_ timestamps: [UInt32]) -> [Int64] {
        guard let first = timestamps.first else {
            return []
        }
        let timestampSpace: Int64 = 1 << 32
        let halfTimestampSpace = timestampSpace / 2
        var highestExtendedTimestamp = Int64(first)
        return timestamps.map { timestamp in
            var extendedTimestamp = (highestExtendedTimestamp / timestampSpace) * timestampSpace
                + Int64(timestamp)
            if extendedTimestamp - highestExtendedTimestamp > halfTimestampSpace {
                extendedTimestamp -= timestampSpace
            } else if highestExtendedTimestamp - extendedTimestamp > halfTimestampSpace {
                extendedTimestamp += timestampSpace
            }
            highestExtendedTimestamp = max(highestExtendedTimestamp, extendedTimestamp)
            return extendedTimestamp
        }
    }

    static func countVideoFrameReassemblyFailures(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> VideoFrameReassemblyAnalysis {
        let videoPackets = datagrams
            .filter {
                $0.stream == .video
                    && $0.rtp.header.payloadType != UltraGridCompatibility.encryptedVideoPayloadType
            }
            .map(\.rtp)
        let videoFragments: [UltraGridVideoRawFragmentPayload]
        do {
            videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: videoPackets)
        } catch {
            return VideoFrameReassemblyAnalysis(
                failureCount: videoPackets.isEmpty ? 0 : 1,
                recoveryFailed: true
            )
        }
        let byFrame = Dictionary(grouping: videoFragments, by: \.frameID)
        let failureCount = byFrame.values.reduce(0) { count, fragments in
            do {
                _ = try UltraGridCompatibility.reassembleVideoFrame(fragments)
                return count
            } catch {
                return count + 1
            }
        }
        return VideoFrameReassemblyAnalysis(failureCount: failureCount, recoveryFailed: false)
    }
}
