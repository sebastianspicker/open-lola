// Converts raw-link transmit and capture outcomes into LoLa session media evidence.
enum LoLaConnectorRawLinkMediaEvidence {
    static func build(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        guard let interfaceName = configuration.rawLinkInterface, !interfaceName.isEmpty else {
            return try fallback(configuration)
        }
        guard configuration.mediaPacketCount > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "mediaPacketCount",
                String(configuration.mediaPacketCount)
            )
        }

        switch configuration.role {
        case .tx:
            return try transmit(configuration, interfaceName: interfaceName)
        case .rx:
            return try receive(configuration, interfaceName: interfaceName)
        case .txRx:
            return try bidirectional(configuration)
        }
    }

    private static func receive(
        _ configuration: ExternalConnectorSessionConfiguration,
        interfaceName: String
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let run = LoLaRawLinkReceiveRunConfiguration(
            interfaceName: interfaceName,
            localIP: configuration.localHost,
            peerIP: configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer,
            outputPath: configuration.outputPath,
            dryRun: configuration.dryRun,
            maxFrames: mediaFrameReadCount(configuration),
            mediaMode: configuration.mediaMode,
            timeoutSeconds: configuration.durationSeconds
        )
        return try LoLaRawLinkReceiveRunner.run(configuration: run)
    }

    private static func bidirectional(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        guard let sourceMAC = configuration.sourceMAC else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--source-mac")
        }
        guard let destinationMAC = configuration.destinationMAC else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--destination-mac")
        }
        return try LoLaCompatibilityMediaSession.bidirectionalReport(
            configuration: configuration,
            frameCountPerStream: configuration.mediaPacketCount,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )
    }

    private static func fallback(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        switch configuration.role {
        case .tx:
            return try LoLaCompatibilityMediaSession.transmitReport(configuration: configuration)
        case .rx:
            let source = loLaLoopbackTransmitConfiguration(from: configuration)
            let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
                configuration: source
            )
            return try LoLaCompatibilityMediaSession.receiveReport(
                configuration: configuration,
                encodedFrames: frames.map(\.encodedFrame)
            )
        case .txRx:
            return try LoLaCompatibilityMediaSession.bidirectionalReport(
                configuration: configuration,
                frameCountPerStream: configuration.mediaPacketCount
            )
        }
    }

    private static func transmit(
        _ configuration: ExternalConnectorSessionConfiguration,
        interfaceName: String
    ) throws -> LoLaCompatibilityMediaSessionReport {
        guard let sourceMAC = configuration.sourceMAC else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--source-mac")
        }
        guard let destinationMAC = configuration.destinationMAC else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--destination-mac")
        }
        let run = LoLaRawLinkTransmitRunConfiguration(
            link: .init(
                interfaceName: interfaceName,
                sourceIP: configuration.localHost,
                destinationIP: configuration.peer,
                sourceMAC: sourceMAC,
                destinationMAC: destinationMAC
            ),
            execution: .init(
                outputPath: configuration.outputPath,
                dryRun: configuration.dryRun,
                packetCount: configuration.mediaPacketCount
            ),
            media: .init(
                mode: configuration.mediaMode,
                audio: .init(
                    channels: configuration.channels,
                    sampleRateHertz: configuration.sampleRateHertz,
                    framesPerPacket: configuration.framesPerPacket
                ),
                video: .init(
                    width: configuration.videoWidth,
                    height: configuration.videoHeight,
                    bitsPerPixel: configuration.videoBitsPerPixel
                )
            )
        )
        return try LoLaRawLinkTransmitRunner.run(configuration: run)
    }

    private static func mediaFrameReadCount(
        _ configuration: ExternalConnectorSessionConfiguration
    ) -> Int {
        LoLaCompatibilityMediaCodec.expectedDatagramCount(
            mediaMode: configuration.mediaMode,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel,
            frameCountPerStream: configuration.mediaPacketCount
        )
    }
}
