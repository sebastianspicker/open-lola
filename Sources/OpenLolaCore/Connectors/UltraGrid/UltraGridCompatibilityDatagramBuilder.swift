// Defines UltraGrid interoperability packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation

protocol UltraGridMonotonicClock {
    func nowNanoseconds() -> UInt64
    func sleep(untilNanoseconds: UInt64) throws
}

struct UltraGridSystemMonotonicClock: UltraGridMonotonicClock {
    func nowNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    func sleep(untilNanoseconds: UInt64) throws {
        _ = DispatchSemaphore(value: 0).wait(
            timeout: DispatchTime(uptimeNanoseconds: untilNanoseconds)
        )
    }
}

enum UltraGridCompatibilityDatagramBuilder {
    static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> [UltraGridCompatibilityDatagram] {
        try buildDatagrams(
            configuration: configuration,
            mediaProvider: UltraGridSyntheticMediaProvider()
        )
    }

    static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) throws -> [UltraGridCompatibilityDatagram] {
        var datagrams: [UltraGridCompatibilityDatagram] = []
        try forEachDatagram(configuration: configuration, mediaProvider: mediaProvider) {
            datagrams.append($0)
        }
        return datagrams
    }

    static func forEachDatagram(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding,
        deadline: UltraGridRuntimeDeadline? = nil,
        clock: (any UltraGridMonotonicClock)? = nil,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let encryption = try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration)
        try UltraGridDatagramGenerationContext(
            configuration: configuration,
            mediaProvider: mediaProvider,
            deadline: deadline,
            clock: clock,
            profile: profile,
            encryption: encryption
        ).generate(emit: emit)
    }

    static func audioDatagram(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding,
        encryption: UltraGridEncryptionConfiguration?,
        deadlineNanoseconds: UInt64?
    ) throws -> UltraGridCompatibilityDatagram {
        let audioPayload = try mediaProvider.audioPCM(
            sequenceNumber: packetIndex,
            channels: configuration.channels,
            framesPerPacket: configuration.framesPerPacket,
            deadlineNanoseconds: deadlineNanoseconds
        )
        let rtp = try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
            sequenceNumber: UInt16(packetIndex),
            timestamp: UInt32(packetIndex * configuration.framesPerPacket),
            ssrc: 0x4F4C_5541,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            pcmPayload: audioPayload,
            payloadType: configuration.ultraGridAudioPayloadType
        ))
        let transmittedRTP = try encryption.map {
            try UltraGridCompatibility.encryptedAudioPacket(rtp, configuration: $0)
        } ?? rtp
        return UltraGridCompatibilityDatagram(
            stream: .audio,
            destinationPort: configuration.audioPort,
            rtp: transmittedRTP
        )
    }

    static func mediaPeriodNanoseconds(units: Int, rate: Int) -> UInt64 {
        let product = UInt64(max(1, units)).multipliedReportingOverflow(by: 1_000_000_000)
        let numerator = product.overflow ? UInt64.max : product.partialValue
        return max(1, numerator / UInt64(max(1, rate)))
    }

    static func pacedIndex(_ request: UltraGridPacedIndexRequest) -> Int {
        guard request.current < request.count else { return request.current }
        var index = max(request.current, slotIndex(at: request.now, start: request.start, period: request.period))
        if let lastEmission = request.lastEmission {
            index = max(index, firstSlotIndex(
                atOrAfter: saturatedAdd(lastEmission, request.period),
                start: request.start,
                period: request.period
            ))
        }
        return min(index, request.count)
    }

    private static func slotIndex(at value: UInt64, start: UInt64, period: UInt64) -> Int {
        guard value > start else { return 0 }
        return Int(clamping: (value - start) / period)
    }

    private static func firstSlotIndex(atOrAfter value: UInt64, start: UInt64, period: UInt64) -> Int {
        guard value > start else { return 0 }
        let elapsed = value - start
        let quotient = elapsed / period
        let rounded = elapsed % period == 0 ? quotient : saturatedAdd(quotient, 1)
        return Int(clamping: rounded)
    }

    static func slotTarget(index: Int, start: UInt64, period: UInt64) -> UInt64 {
        let product = UInt64(index).multipliedReportingOverflow(by: period)
        return saturatedAdd(start, product.overflow ? UInt64.max : product.partialValue)
    }

    static func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }

    static func videoFECDatagram(
        packetIndex: Int,
        packets: [RTPPacket],
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridCompatibilityDatagram {
        let fec = try UltraGridCompatibility.fecParityPacket(
            protecting: packets,
            sequenceNumber: packets.last.map { $0.header.sequenceNumber &+ 1 } ?? 0,
            timestamp: videoTimestamp(packetIndex: packetIndex, configuration: configuration),
            ssrc: 0x4F4C_5556
        )
        return UltraGridCompatibilityDatagram(
            stream: .video,
            destinationPort: configuration.videoPort,
            rtp: fec
        )
    }

    static func videoTimestamp(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration
    ) -> UInt32 {
        UInt32(packetIndex * UltraGridCompatibility.videoClockRateHertz / max(1, configuration.videoFrameRate))
    }
}
