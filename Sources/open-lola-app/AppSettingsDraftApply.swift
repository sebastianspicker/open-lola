// Applies an editable settings draft to runtime state, keeping validation and mutation ordered at one boundary.
import OpenLolaCore

extension AppSettingsDraft {
    func apply(to settings: AppSettings) {
        applyExecutionSettings(to: settings)
        applyDirectPeerSettings(to: settings)
        applyPreviewSettings(to: settings)
        applyOperatorSettings(to: settings)
        applyWindowsLoLaSettings(to: settings)
        applyJackTripSettings(to: settings)
        applyUltraGridSettings(to: settings)
    }

    private func applyExecutionSettings(to settings: AppSettings) {
        settings.sessionMode = sessionMode
        settings.controlMode = controlMode
        settings.executablePath = executablePath
        settings.planPath = planPath
        settings.supervisorReportPath = supervisorReportPath
        settings.executionMode = AppExecutionModeAvailability.normalized(
            DirectPeerTwoPeerRunExecutionMode(rawValue: executionMode) ?? .local
        ).rawValue
        settings.requirePreflight = requirePreflight
        settings.executionMacASSH = executionMacASSH
        settings.executionMacBSSH = executionMacBSSH
        settings.executionMacAWorkingDirectory = executionMacAWorkingDirectory
        settings.executionMacBWorkingDirectory = executionMacBWorkingDirectory
        settings.executionSSHExecutable = executionSSHExecutable
        settings.executionSCPExecutable = executionSCPExecutable
    }

    private func applyDirectPeerSettings(to settings: AppSettings) {
        settings.role = role
        settings.localPeer = localPeer
        settings.remotePeer = remotePeer
        settings.localHost = localHost
        settings.remoteHost = remoteHost
        settings.controlPort = controlPort
        settings.remoteControlPort = remoteControlPort
        settings.audioPort = audioPort
        settings.videoPort = videoPort
        settings.metricsPort = metricsPort
        settings.outputPath = outputPath
        settings.channelCount = channelCount
        settings.sampleRate = sampleRate
        settings.frames = frames
        settings.duration = duration
        settings.sampleFormat = sampleFormat
        settings.audioTransport = audioTransport
        settings.videoWidth = videoWidth
        settings.videoHeight = videoHeight
        settings.videoPixelFormat = videoPixelFormat
        settings.videoCompression = videoCompression
        settings.videoFrameRate = videoFrameRate
        settings.videoStreamID = videoStreamID
        settings.timeoutSeconds = timeoutSeconds
        settings.avProfile = avProfile
        settings.rxBufferProfile = rxBufferProfile
        settings.preview = preview
    }

    private func applyPreviewSettings(to settings: AppSettings) {
        settings.audioPreviewEnabled = audioPreviewEnabled
        settings.videoPreviewEnabled = videoPreviewEnabled
        settings.showSafeFrame = showSafeFrame
        settings.monitorGain = monitorGain
        settings.remoteReturnBlend = remoteReturnBlend
        settings.videoScale = videoScale
        settings.visibleStreams = visibleStreams
        settings.selectedVideoStream = selectedVideoStream
    }

    private func applyOperatorSettings(to settings: AppSettings) {
        settings.operatorPlanArtifactPath = operatorPlanArtifactPath
        settings.operatorSupervisorReportPath = operatorSupervisorReportPath
        settings.operatorMacASSH = operatorMacASSH
        settings.operatorMacBSSH = operatorMacBSSH
    }

    private func applyWindowsLoLaSettings(to settings: AppSettings) {
        settings.windowsLoLaLocalHost = windowsLoLaLocalHost
        settings.windowsLoLaWindowsHost = windowsLoLaWindowsHost
        settings.windowsLoLaRole = windowsLoLaRole
        settings.windowsLoLaControlPort = windowsLoLaControlPort
        settings.windowsLoLaAudioPort = windowsLoLaAudioPort
        settings.windowsLoLaVideoPort = windowsLoLaVideoPort
        settings.windowsLoLaMediaMode = windowsLoLaMediaMode
        settings.windowsLoLaPayloadMode = windowsLoLaPayloadMode
        settings.windowsLoLaVideoWidth = windowsLoLaVideoWidth
        settings.windowsLoLaVideoHeight = windowsLoLaVideoHeight
        settings.windowsLoLaVideoFrameRate = windowsLoLaVideoFrameRate
        settings.windowsLoLaVideoBitsPerPixel = windowsLoLaVideoBitsPerPixel
        settings.windowsLoLaDuration = windowsLoLaDuration
        settings.windowsLoLaOutputPath = windowsLoLaOutputPath
        settings.windowsLoLaSampleRate = windowsLoLaSampleRate
        settings.windowsLoLaFrames = windowsLoLaFrames
        settings.windowsLoLaChannelCount = windowsLoLaChannelCount
        settings.windowsLoLaCompression = windowsLoLaCompression
        settings.windowsLoLaBayer = windowsLoLaBayer
    }

    private func applyJackTripSettings(to settings: AppSettings) {
        settings.jackTripLocalHost = jackTripLocalHost
        settings.jackTripPeerHost = jackTripPeerHost
        settings.jackTripRole = jackTripRole
        settings.jackTripAudioPort = jackTripAudioPort
        settings.jackTripPeerAudioPort = jackTripPeerAudioPort
        settings.jackTripVideoPort = jackTripVideoPort
        settings.jackTripMediaMode = jackTripMediaMode
        settings.jackTripDuration = jackTripDuration
        settings.jackTripOutputPath = jackTripOutputPath
    }

    private func applyUltraGridSettings(to settings: AppSettings) {
        settings.ultraGridLocalHost = ultraGridLocalHost
        settings.ultraGridPeerHost = ultraGridPeerHost
        settings.ultraGridRole = ultraGridRole
        settings.ultraGridAudioPort = ultraGridAudioPort
        settings.ultraGridPeerAudioPort = ultraGridPeerAudioPort
        settings.ultraGridVideoPort = ultraGridVideoPort
        settings.ultraGridMediaMode = ultraGridMediaMode
        settings.ultraGridDuration = ultraGridDuration
        settings.ultraGridOutputPath = ultraGridOutputPath
    }

    func apply(to operatorSurface: inout NativeAppShellOperatorPrototypeState) {
        operatorSurface.sessionMode = NativeAppShellSessionMode(rawValue: sessionMode) ?? .directMacPeer
        operatorSurface.controlMode = NativeAppShellControlMode(rawValue: controlMode) ?? .normal
        applyExecutablePaths(to: &operatorSurface)
        applyDirectPeerCommandFields(to: &operatorSurface.directPeerCommandFields)
        applyWindowsLoLaPeerFields(to: &operatorSurface.windowsLoLaPeerFields)
        applyJackTripPeerFields(to: &operatorSurface.jackTripPeerFields)
        applyUltraGridPeerFields(to: &operatorSurface.ultraGridPeerFields)
    }

    private func applyExecutablePaths(to operatorSurface: inout NativeAppShellOperatorPrototypeState) {
        operatorSurface.directPeerCommandFields.executablePath = executablePath
        operatorSurface.windowsLoLaPeerFields.executablePath = executablePath
        operatorSurface.jackTripPeerFields.executablePath = executablePath
        operatorSurface.ultraGridPeerFields.executablePath = executablePath
    }

    private func applyDirectPeerCommandFields(to fields: inout NativeAppShellDirectPeerCommandFields) {
        fields.role = DirectPeerSessionManualRole(rawValue: role) ?? .initiator
        fields.localPeer = localPeer
        fields.remotePeer = remotePeer
        fields.localHost = localHost
        fields.remoteHost = remoteHost
        fields.controlPort = uint16(controlPort)
        fields.remoteControlPort = uint16(remoteControlPort)
        fields.audioPort = uint16(audioPort)
        fields.videoPort = uint16(videoPort)
        fields.metricsPort = uint16(metricsPort)
        fields.outputPath = outputPath
        fields.channelCount = positive(channelCount)
        fields.sampleRateHertz = positive(sampleRate)
        fields.framesPerPacket = positive(frames)
        fields.durationSeconds = positive(duration)
        fields.sampleFormat = sampleFormat
        fields.audioTransport =
            DirectPeerSessionAudioTransport(rawValue: audioTransport) ?? .openLolaRaw
        fields.videoWidth = positive(videoWidth)
        fields.videoHeight = positive(videoHeight)
        fields.videoPixelFormat = videoPixelFormat
        fields.videoCompression =
            DirectPeerSessionVideoCompression(rawValue: videoCompression) ?? .jpegXS
        fields.videoFrameRate = positive(videoFrameRate)
        fields.videoStreamID = positive(videoStreamID)
        fields.timeoutSeconds = positive(timeoutSeconds)
        fields.avProfile = DirectPeerSessionAVProfile(rawValue: avProfile) ?? .fastest
        let fallbackRXBufferProfile = fields.avProfile.defaultRXBufferProfile
        fields.rxBufferProfile =
            RxBufferProfile(rawValue: rxBufferProfile) ?? fallbackRXBufferProfile
        fields.preview = DirectPeerSessionPreviewMode(rawValue: preview) ?? .on
    }

    private func applyWindowsLoLaPeerFields(to fields: inout NativeAppShellWindowsLoLaPeerFields) {
        fields.localHost = windowsLoLaLocalHost
        fields.windowsHost = windowsLoLaWindowsHost
        fields.role = ExternalConnectorSessionRole(rawValue: windowsLoLaRole) ?? .txRx
        fields.controlPort = uint16(windowsLoLaControlPort)
        fields.audioPort = uint16(windowsLoLaAudioPort)
        fields.videoPort = uint16(windowsLoLaVideoPort)
        fields.mediaMode =
            ExternalConnectorMediaMode(rawValue: windowsLoLaMediaMode) ?? .audioVideo
        fields.payloadMode =
            LoLaVideoPayloadKind(rawValue: windowsLoLaPayloadMode) ?? .generated
        fields.videoWidth = positive(windowsLoLaVideoWidth)
        fields.videoHeight = positive(windowsLoLaVideoHeight)
        fields.videoFrameRate = positive(windowsLoLaVideoFrameRate)
        fields.videoBitsPerPixel = positive(windowsLoLaVideoBitsPerPixel)
        fields.durationSeconds = positive(windowsLoLaDuration)
        fields.outputPath = windowsLoLaOutputPath
        fields.sampleRateHertz = positive(windowsLoLaSampleRate)
        fields.framesPerPacket = positive(windowsLoLaFrames)
        fields.channelCount = positive(windowsLoLaChannelCount)
        fields.compression = nonNegative(windowsLoLaCompression)
        fields.bayer = nonNegative(windowsLoLaBayer)
    }

    private func applyJackTripPeerFields(to fields: inout NativeAppShellExternalConnectorPeerFields) {
        fields.localHost = jackTripLocalHost
        fields.peerHost = jackTripPeerHost
        fields.role = ExternalConnectorSessionRole(rawValue: jackTripRole) ?? .txRx
        fields.audioPort = uint16(jackTripAudioPort)
        fields.peerAudioPort = uint16(jackTripPeerAudioPort)
        fields.videoPort = uint16(jackTripVideoPort)
        fields.mediaMode = ExternalConnectorMediaMode(rawValue: jackTripMediaMode) ?? .audio
        fields.durationSeconds = positive(jackTripDuration)
        fields.outputPath = jackTripOutputPath
    }

    private func applyUltraGridPeerFields(to fields: inout NativeAppShellExternalConnectorPeerFields) {
        fields.localHost = ultraGridLocalHost
        fields.peerHost = ultraGridPeerHost
        fields.role = ExternalConnectorSessionRole(rawValue: ultraGridRole) ?? .txRx
        fields.audioPort = uint16(ultraGridAudioPort)
        fields.peerAudioPort = uint16(ultraGridPeerAudioPort)
        fields.videoPort = uint16(ultraGridVideoPort)
        fields.mediaMode =
            ExternalConnectorMediaMode(rawValue: ultraGridMediaMode) ?? .audioVideo
        fields.durationSeconds = positive(ultraGridDuration)
        fields.outputPath = ultraGridOutputPath
    }

    func apply(to settings: inout NativeAppShellExecutionSettings) {
        settings.planPath = planPath
        settings.supervisorReportPath = supervisorReportPath
        settings.executionMode = AppExecutionModeAvailability.normalized(
            DirectPeerTwoPeerRunExecutionMode(rawValue: executionMode) ?? .local
        )
        settings.requirePreflight = requirePreflight
        settings.macASSH = executionMacASSH
        settings.macBSSH = executionMacBSSH
        settings.macAWorkingDirectory = executionMacAWorkingDirectory
        settings.macBWorkingDirectory = executionMacBWorkingDirectory
        settings.sshExecutable = executionSSHExecutable
        settings.scpExecutable = executionSCPExecutable
    }

    func apply(to previewState: AppPreviewReceiverState) {
        previewState.audioPreviewEnabled = audioPreviewEnabled
        previewState.videoPreviewEnabled = videoPreviewEnabled
        previewState.showSafeFrame = showSafeFrame
        previewState.monitorGain = monitorGain
        previewState.remoteReturnBlend = remoteReturnBlend
        previewState.videoScale = videoScale
        previewState.visibleStreams = positive(visibleStreams)
        previewState.selectedVideoStream = positive(selectedVideoStream)
        previewState.reconcilePreviewPhase()
    }

    private func positive(_ value: Int) -> Int { max(1, value) }
    private func nonNegative(_ value: Int) -> Int { max(0, value) }
    private func uint16(_ value: Int) -> UInt16 {
        UInt16(clamping: nonNegative(value))
    }
}
