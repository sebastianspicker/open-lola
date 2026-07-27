// Copies persisted AppSettings into an editable draft, keeping UI edits isolated until the user applies them.
extension AppSettingsDraft {
    func loadValues(from settings: AppSettings) {
        loadExecutionValues(from: settings)
        loadDirectPeerValues(from: settings)
        loadPreviewValues(from: settings)
        loadOperatorValues(from: settings)
        loadWindowsLoLaValues(from: settings)
        loadJackTripValues(from: settings)
        loadUltraGridValues(from: settings)
    }

    private func loadExecutionValues(from settings: AppSettings) {
        sessionMode = settings.sessionMode
        controlMode = settings.controlMode
        executablePath = settings.executablePath
        planPath = settings.planPath
        supervisorReportPath = settings.supervisorReportPath
        executionMode = settings.executionMode
        requirePreflight = settings.requirePreflight
        executionMacASSH = settings.executionMacASSH
        executionMacBSSH = settings.executionMacBSSH
        executionMacAWorkingDirectory = settings.executionMacAWorkingDirectory
        executionMacBWorkingDirectory = settings.executionMacBWorkingDirectory
        executionSSHExecutable = settings.executionSSHExecutable
        executionSCPExecutable = settings.executionSCPExecutable
    }

    private func loadDirectPeerValues(from settings: AppSettings) {
        role = settings.role
        localPeer = settings.localPeer
        remotePeer = settings.remotePeer
        localHost = settings.localHost
        remoteHost = settings.remoteHost
        controlPort = settings.controlPort
        remoteControlPort = settings.remoteControlPort
        audioPort = settings.audioPort
        videoPort = settings.videoPort
        metricsPort = settings.metricsPort
        outputPath = settings.outputPath
        channelCount = settings.channelCount
        sampleRate = settings.sampleRate
        frames = settings.frames
        duration = settings.duration
        sampleFormat = settings.sampleFormat
        audioTransport = settings.audioTransport
        videoWidth = settings.videoWidth
        videoHeight = settings.videoHeight
        videoPixelFormat = settings.videoPixelFormat
        videoCompression = settings.videoCompression
        videoFrameRate = settings.videoFrameRate
        videoStreamID = settings.videoStreamID
        timeoutSeconds = settings.timeoutSeconds
        avProfile = settings.avProfile
        rxBufferProfile = settings.rxBufferProfile
        preview = settings.preview
    }

    private func loadPreviewValues(from settings: AppSettings) {
        audioPreviewEnabled = settings.audioPreviewEnabled
        videoPreviewEnabled = settings.videoPreviewEnabled
        showSafeFrame = settings.showSafeFrame
        monitorGain = settings.monitorGain
        remoteReturnBlend = settings.remoteReturnBlend
        videoScale = settings.videoScale
        visibleStreams = settings.visibleStreams
        selectedVideoStream = settings.selectedVideoStream
    }

    private func loadOperatorValues(from settings: AppSettings) {
        operatorPlanArtifactPath = settings.operatorPlanArtifactPath
        operatorSupervisorReportPath = settings.operatorSupervisorReportPath
        operatorMacASSH = settings.operatorMacASSH
        operatorMacBSSH = settings.operatorMacBSSH
    }

    private func loadWindowsLoLaValues(from settings: AppSettings) {
        windowsLoLaLocalHost = settings.windowsLoLaLocalHost
        windowsLoLaWindowsHost = settings.windowsLoLaWindowsHost
        windowsLoLaRole = settings.windowsLoLaRole
        windowsLoLaControlPort = settings.windowsLoLaControlPort
        windowsLoLaAudioPort = settings.windowsLoLaAudioPort
        windowsLoLaVideoPort = settings.windowsLoLaVideoPort
        windowsLoLaMediaMode = settings.windowsLoLaMediaMode
        windowsLoLaPayloadMode = settings.windowsLoLaPayloadMode
        windowsLoLaVideoWidth = settings.windowsLoLaVideoWidth
        windowsLoLaVideoHeight = settings.windowsLoLaVideoHeight
        windowsLoLaVideoFrameRate = settings.windowsLoLaVideoFrameRate
        windowsLoLaVideoBitsPerPixel = settings.windowsLoLaVideoBitsPerPixel
        windowsLoLaDuration = settings.windowsLoLaDuration
        windowsLoLaOutputPath = settings.windowsLoLaOutputPath
        windowsLoLaSampleRate = settings.windowsLoLaSampleRate
        windowsLoLaFrames = settings.windowsLoLaFrames
        windowsLoLaChannelCount = settings.windowsLoLaChannelCount
        windowsLoLaCompression = settings.windowsLoLaCompression
        windowsLoLaBayer = settings.windowsLoLaBayer
    }

    private func loadJackTripValues(from settings: AppSettings) {
        jackTripLocalHost = settings.jackTripLocalHost
        jackTripPeerHost = settings.jackTripPeerHost
        jackTripRole = settings.jackTripRole
        jackTripAudioPort = settings.jackTripAudioPort
        jackTripPeerAudioPort = settings.jackTripPeerAudioPort
        jackTripVideoPort = settings.jackTripVideoPort
        jackTripMediaMode = settings.jackTripMediaMode
        jackTripDuration = settings.jackTripDuration
        jackTripOutputPath = settings.jackTripOutputPath
    }

    private func loadUltraGridValues(from settings: AppSettings) {
        ultraGridLocalHost = settings.ultraGridLocalHost
        ultraGridPeerHost = settings.ultraGridPeerHost
        ultraGridRole = settings.ultraGridRole
        ultraGridAudioPort = settings.ultraGridAudioPort
        ultraGridPeerAudioPort = settings.ultraGridPeerAudioPort
        ultraGridVideoPort = settings.ultraGridVideoPort
        ultraGridMediaMode = settings.ultraGridMediaMode
        ultraGridDuration = settings.ultraGridDuration
        ultraGridOutputPath = settings.ultraGridOutputPath
    }
}
