func validateExternalConnectorRuntimeInputs(
    _ configuration: ExternalConnectorSessionConfiguration
) throws {
    guard configuration.durationSeconds >= 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(
            "durationSeconds",
            String(configuration.durationSeconds)
        )
    }
    if configuration.connector == .lola {
        try validateExternalConnectorPort(configuration.controlPort, "controlPort")
    }
    try validateExternalConnectorPort(configuration.audioPort, "audioPort")
    try validateExternalConnectorPort(configuration.videoPort, "videoPort")
    if configuration.connector == .mvtpUltraGrid {
        try validateUltraGridPayloadType(configuration.ultraGridAudioPayloadType, "ultraGrid.audioPayloadType")
        try validateUltraGridPayloadType(configuration.ultraGridVideoPayloadType, "ultraGrid.videoPayloadType")
        if configuration.ultraGridEncryptionMode != .none,
           configuration.ultraGridEncryptionPassphrase?.isEmpty ?? true {
            throw ExternalConnectorSessionError.missingRequiredArgument("--ultragrid-encryption-passphrase")
        }
        if configuration.ultraGridControlMode == .disabled,
           !configuration.ultraGridControlCommands.isEmpty {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-control-command-without-control")
        }
        for command in configuration.ultraGridControlCommands {
            _ = try command.encodedLine()
        }
    }
    if configuration.connector == .jackTrip {
        try validateJackTripRuntimeInputs(configuration)
    }
}

private func validateJackTripRuntimeInputs(_ session: ExternalConnectorSessionConfiguration) throws {
    let configuration = session.jackTrip
    guard configuration.queueDepth > 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger("jackTrip.queueDepth", String(configuration.queueDepth))
    }
    guard configuration.redundancy > 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger("jackTrip.redundancy", String(configuration.redundancy))
    }
    _ = try JackTripBitResolution(bits: configuration.bitResolutionBits)
    if configuration.topologyMode == .directPeer, configuration.topologyRole != .direct {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(
            "jacktrip-topology-role-\(configuration.topologyRole.rawValue)"
        )
    }
    if configuration.topologyMode == .hubVirtualStudio, configuration.topologyRole == .direct {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-topology-role-direct")
    }
    if configuration.hubTCPHandshakeMode == .unauthenticated,
       configuration.topologyMode != .hubVirtualStudio {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-hub-tcp-handshake-direct-peer")
    }
    if configuration.packetHeaderMode == .empty,
       configuration.redundancy != 1 {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-empty-header-redundancy")
    }
    if configuration.payloadEncoding == .opusCELTLowDelay {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: session.sampleRateHertz,
            frameCount: session.framesPerPacket,
            sampleFormat: .float32LittleEndian,
            channelCount: session.channels
        )
    }
    if let remoteClientName = configuration.remoteClientName {
        _ = try validateExternalConnectorProcessArgument(
            remoteClientName,
            field: "jackTrip.remoteClientName",
            argumentClass: .jackTripRemoteClientName
        )
    }
}

private func validateUltraGridPayloadType(_ payloadType: UInt8, _ field: String) throws {
    guard payloadType <= 127 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(payloadType))
    }
}

private func validateExternalConnectorPort(_ port: UInt16, _ field: String) throws {
    guard port > 0 else {
        throw ExternalConnectorSessionError.invalidPort(field, String(port))
    }
}
