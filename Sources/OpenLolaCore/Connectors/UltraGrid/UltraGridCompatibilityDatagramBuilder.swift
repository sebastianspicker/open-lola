import Foundation

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
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let encryption = try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration)
        var datagrams: [UltraGridCompatibilityDatagram] = []
        for packetIndex in 0..<configuration.mediaPacketCount {
            if profile.audioEnabled {
                datagrams.append(try audioDatagram(
                    packetIndex: packetIndex,
                    configuration: configuration,
                    mediaProvider: mediaProvider,
                    encryption: encryption
                ))
            }
            if profile.videoEnabled {
                datagrams.append(contentsOf: try videoDatagrams(
                    packetIndex: packetIndex,
                    configuration: configuration,
                    mediaProvider: mediaProvider,
                    encryption: encryption
                ))
            }
        }
        return datagrams
    }

    private static func audioDatagram(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding,
        encryption: UltraGridEncryptionConfiguration?
    ) throws -> UltraGridCompatibilityDatagram {
        let audioPayload = try mediaProvider.audioPCM(
            sequenceNumber: packetIndex,
            channels: configuration.channels,
            framesPerPacket: configuration.framesPerPacket
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

    private static func videoDatagrams(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding,
        encryption: UltraGridEncryptionConfiguration?
    ) throws -> [UltraGridCompatibilityDatagram] {
        let packets = try videoRTPPackets(
            packetIndex: packetIndex,
            configuration: configuration,
            mediaProvider: mediaProvider
        )
        var datagrams = try encryptedVideoDatagrams(
            packets,
            configuration: configuration,
            encryption: encryption
        )
        if configuration.ultraGridFECMode == .singleParity {
            datagrams.append(try videoFECDatagram(
                packetIndex: packetIndex,
                packets: packets,
                configuration: configuration
            ))
        }
        return datagrams
    }

    private static func videoRTPPackets(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) throws -> [RTPPacket] {
        let videoPayload = try mediaProvider.videoFrame(
            frameID: packetIndex,
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bitsPerPixel: configuration.videoBitsPerPixel
        )
        return try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
            frame: UltraGridVideoFragmentFrame(
                payload: videoPayload,
                id: UInt32(packetIndex),
                width: configuration.videoWidth,
                height: configuration.videoHeight,
                frameRate: configuration.videoFrameRate,
                bitsPerPixel: configuration.videoBitsPerPixel
            ),
            transport: UltraGridVideoFragmentTransport(
                sequenceStart: UInt16(packetIndex * 8),
                timestamp: videoTimestamp(packetIndex: packetIndex, configuration: configuration),
                ssrc: 0x4F4C_5556,
                payloadType: configuration.ultraGridVideoPayloadType
            )
        ))
    }

    private static func encryptedVideoDatagrams(
        _ packets: [RTPPacket],
        configuration: ExternalConnectorSessionConfiguration,
        encryption: UltraGridEncryptionConfiguration?
    ) throws -> [UltraGridCompatibilityDatagram] {
        try packets.map { packet in
            let rtp = try encryption.map {
                try UltraGridCompatibility.encryptedVideoPacket(packet, configuration: $0)
            } ?? packet
            return UltraGridCompatibilityDatagram(
                stream: .video,
                destinationPort: configuration.videoPort,
                rtp: rtp
            )
        }
    }

    private static func videoFECDatagram(
        packetIndex: Int,
        packets: [RTPPacket],
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridCompatibilityDatagram {
        let fec = try UltraGridCompatibility.fecParityPacket(
            protecting: packets,
            sequenceNumber: UInt16(packetIndex * 8 + packets.count),
            timestamp: videoTimestamp(packetIndex: packetIndex, configuration: configuration),
            ssrc: 0x4F4C_5556
        )
        return UltraGridCompatibilityDatagram(
            stream: .video,
            destinationPort: configuration.videoPort,
            rtp: fec
        )
    }

    private static func videoTimestamp(
        packetIndex: Int,
        configuration: ExternalConnectorSessionConfiguration
    ) -> UInt32 {
        UInt32(packetIndex * UltraGridCompatibility.videoClockRateHertz / max(1, configuration.videoFrameRate))
    }
}
