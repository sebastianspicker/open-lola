// Copies settings into a mutable draft, preventing in-progress edits from changing active runtime configuration.
extension AppSettingsDraft {
    func copy(from draft: AppSettingsDraft) {
        copyExecutionFields(from: draft)
        copyDirectPeerFields(from: draft)
        copyPreviewFields(from: draft)
        copyOperatorFields(from: draft)
        copyWindowsLoLaFields(from: draft)
        copyJackTripFields(from: draft)
        copyUltraGridFields(from: draft)
    }

    private func copyExecutionFields(from draft: AppSettingsDraft) {
        sessionMode = draft.sessionMode
        controlMode = draft.controlMode
        executablePath = draft.executablePath
        planPath = draft.planPath
        supervisorReportPath = draft.supervisorReportPath
        executionMode = draft.executionMode
        requirePreflight = draft.requirePreflight
        executionMacASSH = draft.executionMacASSH
        executionMacBSSH = draft.executionMacBSSH
        executionMacAWorkingDirectory = draft.executionMacAWorkingDirectory
        executionMacBWorkingDirectory = draft.executionMacBWorkingDirectory
        executionSSHExecutable = draft.executionSSHExecutable
        executionSCPExecutable = draft.executionSCPExecutable
    }

    private func copyDirectPeerFields(from draft: AppSettingsDraft) {
        role = draft.role
        localPeer = draft.localPeer
        remotePeer = draft.remotePeer
        localHost = draft.localHost
        remoteHost = draft.remoteHost
        controlPort = draft.controlPort
        remoteControlPort = draft.remoteControlPort
        audioPort = draft.audioPort
        videoPort = draft.videoPort
        metricsPort = draft.metricsPort
        outputPath = draft.outputPath
        channelCount = draft.channelCount
        sampleRate = draft.sampleRate
        frames = draft.frames
        duration = draft.duration
        sampleFormat = draft.sampleFormat
        audioTransport = draft.audioTransport
        videoWidth = draft.videoWidth
        videoHeight = draft.videoHeight
        videoPixelFormat = draft.videoPixelFormat
        videoCompression = draft.videoCompression
        videoFrameRate = draft.videoFrameRate
        videoStreamID = draft.videoStreamID
        timeoutSeconds = draft.timeoutSeconds
        avProfile = draft.avProfile
        rxBufferProfile = draft.rxBufferProfile
        preview = draft.preview
    }

    private func copyPreviewFields(from draft: AppSettingsDraft) {
        audioPreviewEnabled = draft.audioPreviewEnabled
        videoPreviewEnabled = draft.videoPreviewEnabled
        showSafeFrame = draft.showSafeFrame
        monitorGain = draft.monitorGain
        remoteReturnBlend = draft.remoteReturnBlend
        videoScale = draft.videoScale
        visibleStreams = draft.visibleStreams
        selectedVideoStream = draft.selectedVideoStream
    }

    private func copyOperatorFields(from draft: AppSettingsDraft) {
        operatorPlanArtifactPath = draft.operatorPlanArtifactPath
        operatorSupervisorReportPath = draft.operatorSupervisorReportPath
        operatorMacASSH = draft.operatorMacASSH
        operatorMacBSSH = draft.operatorMacBSSH
    }

    private func copyWindowsLoLaFields(from draft: AppSettingsDraft) {
        windowsLoLaLocalHost = draft.windowsLoLaLocalHost
        windowsLoLaWindowsHost = draft.windowsLoLaWindowsHost
        windowsLoLaRole = draft.windowsLoLaRole
        windowsLoLaControlPort = draft.windowsLoLaControlPort
        windowsLoLaAudioPort = draft.windowsLoLaAudioPort
        windowsLoLaVideoPort = draft.windowsLoLaVideoPort
        windowsLoLaMediaMode = draft.windowsLoLaMediaMode
        windowsLoLaPayloadMode = draft.windowsLoLaPayloadMode
        windowsLoLaVideoWidth = draft.windowsLoLaVideoWidth
        windowsLoLaVideoHeight = draft.windowsLoLaVideoHeight
        windowsLoLaVideoFrameRate = draft.windowsLoLaVideoFrameRate
        windowsLoLaVideoBitsPerPixel = draft.windowsLoLaVideoBitsPerPixel
        windowsLoLaDuration = draft.windowsLoLaDuration
        windowsLoLaOutputPath = draft.windowsLoLaOutputPath
        windowsLoLaSampleRate = draft.windowsLoLaSampleRate
        windowsLoLaFrames = draft.windowsLoLaFrames
        windowsLoLaChannelCount = draft.windowsLoLaChannelCount
        windowsLoLaCompression = draft.windowsLoLaCompression
        windowsLoLaBayer = draft.windowsLoLaBayer
    }

    private func copyJackTripFields(from draft: AppSettingsDraft) {
        jackTripLocalHost = draft.jackTripLocalHost
        jackTripPeerHost = draft.jackTripPeerHost
        jackTripRole = draft.jackTripRole
        jackTripAudioPort = draft.jackTripAudioPort
        jackTripPeerAudioPort = draft.jackTripPeerAudioPort
        jackTripVideoPort = draft.jackTripVideoPort
        jackTripMediaMode = draft.jackTripMediaMode
        jackTripDuration = draft.jackTripDuration
        jackTripOutputPath = draft.jackTripOutputPath
    }

    private func copyUltraGridFields(from draft: AppSettingsDraft) {
        ultraGridLocalHost = draft.ultraGridLocalHost
        ultraGridPeerHost = draft.ultraGridPeerHost
        ultraGridRole = draft.ultraGridRole
        ultraGridAudioPort = draft.ultraGridAudioPort
        ultraGridPeerAudioPort = draft.ultraGridPeerAudioPort
        ultraGridVideoPort = draft.ultraGridVideoPort
        ultraGridMediaMode = draft.ultraGridMediaMode
        ultraGridDuration = draft.ultraGridDuration
        ultraGridOutputPath = draft.ultraGridOutputPath
    }
}
