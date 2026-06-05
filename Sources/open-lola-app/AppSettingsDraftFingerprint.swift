@MainActor
enum AppSettingsDraftFingerprint {
    static func make(from draft: AppSettingsDraft) -> [String] {
        executionFields(from: draft)
            + directPeerFields(from: draft)
            + previewFields(from: draft)
            + operatorFields(from: draft)
            + windowsLoLaFields(from: draft)
            + jackTripFields(from: draft)
            + ultraGridFields(from: draft)
    }

    private static func executionFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.sessionMode,
            draft.controlMode,
            draft.executablePath,
            draft.planPath,
            draft.supervisorReportPath,
            draft.executionMode,
            String(draft.requirePreflight),
            draft.executionMacASSH,
            draft.executionMacBSSH,
            draft.executionMacAWorkingDirectory,
            draft.executionMacBWorkingDirectory,
            draft.executionSSHExecutable,
            draft.executionSCPExecutable
        ]
    }

    private static func directPeerFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.role,
            draft.localPeer,
            draft.remotePeer,
            draft.localHost,
            draft.remoteHost,
            String(draft.controlPort),
            String(draft.remoteControlPort),
            String(draft.audioPort),
            String(draft.videoPort),
            String(draft.metricsPort),
            draft.outputPath,
            String(draft.channelCount),
            String(draft.sampleRate),
            String(draft.frames),
            String(draft.duration),
            draft.sampleFormat,
            draft.audioTransport,
            String(draft.videoWidth),
            String(draft.videoHeight),
            draft.videoPixelFormat,
            draft.videoCompression,
            String(draft.videoFrameRate),
            String(draft.videoStreamID),
            String(draft.timeoutSeconds),
            draft.avProfile,
            draft.rxBufferProfile,
            draft.preview
        ]
    }

    private static func previewFields(from draft: AppSettingsDraft) -> [String] {
        [
            String(draft.audioPreviewEnabled),
            String(draft.videoPreviewEnabled),
            String(draft.showSafeFrame),
            String(draft.monitorGain),
            String(draft.remoteReturnBlend),
            String(draft.videoScale),
            String(draft.visibleStreams),
            String(draft.selectedVideoStream)
        ]
    }

    private static func operatorFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.operatorPlanArtifactPath,
            draft.operatorSupervisorReportPath,
            draft.operatorMacASSH,
            draft.operatorMacBSSH
        ]
    }

    private static func windowsLoLaFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.windowsLoLaLocalHost,
            draft.windowsLoLaWindowsHost,
            draft.windowsLoLaRole,
            String(draft.windowsLoLaControlPort),
            String(draft.windowsLoLaAudioPort),
            String(draft.windowsLoLaVideoPort),
            draft.windowsLoLaMediaMode,
            draft.windowsLoLaPayloadMode,
            String(draft.windowsLoLaVideoWidth),
            String(draft.windowsLoLaVideoHeight),
            String(draft.windowsLoLaVideoFrameRate),
            String(draft.windowsLoLaVideoBitsPerPixel),
            String(draft.windowsLoLaDuration),
            draft.windowsLoLaOutputPath,
            String(draft.windowsLoLaSampleRate),
            String(draft.windowsLoLaFrames),
            String(draft.windowsLoLaChannelCount),
            String(draft.windowsLoLaCompression),
            String(draft.windowsLoLaBayer)
        ]
    }

    private static func jackTripFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.jackTripLocalHost,
            draft.jackTripPeerHost,
            draft.jackTripRole,
            String(draft.jackTripAudioPort),
            String(draft.jackTripPeerAudioPort),
            String(draft.jackTripVideoPort),
            draft.jackTripMediaMode,
            String(draft.jackTripDuration),
            draft.jackTripOutputPath
        ]
    }

    private static func ultraGridFields(from draft: AppSettingsDraft) -> [String] {
        [
            draft.ultraGridLocalHost,
            draft.ultraGridPeerHost,
            draft.ultraGridRole,
            String(draft.ultraGridAudioPort),
            String(draft.ultraGridPeerAudioPort),
            String(draft.ultraGridVideoPort),
            draft.ultraGridMediaMode,
            String(draft.ultraGridDuration),
            draft.ultraGridOutputPath
        ]
    }
}
