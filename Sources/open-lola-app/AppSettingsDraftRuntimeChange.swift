// Identifies draft changes that affect a running session, keeping restart warnings separate from form rendering.
import OpenLolaCore

extension AppSettingsDraft {
    func changesRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        changesExecutionConfiguration(comparedTo: settings)
            || changesDirectPeerRuntimeConfiguration(comparedTo: settings)
            || changesWindowsLoLaRuntimeConfiguration(comparedTo: settings)
            || changesJackTripRuntimeConfiguration(comparedTo: settings)
            || changesUltraGridRuntimeConfiguration(comparedTo: settings)
    }

    private func changesExecutionConfiguration(comparedTo settings: AppSettings) -> Bool {
        [
            sessionMode != settings.sessionMode,
            executablePath != settings.executablePath,
            planPath != settings.planPath,
            supervisorReportPath != settings.supervisorReportPath,
            normalizedExecutionMode != settings.executionMode,
            requirePreflight != settings.requirePreflight,
            executionMacASSH != settings.executionMacASSH,
            executionMacBSSH != settings.executionMacBSSH,
            executionMacAWorkingDirectory != settings.executionMacAWorkingDirectory,
            executionMacBWorkingDirectory != settings.executionMacBWorkingDirectory,
            executionSSHExecutable != settings.executionSSHExecutable,
            executionSCPExecutable != settings.executionSCPExecutable
        ].contains(true)
    }

    private func changesDirectPeerRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        [
            role != settings.role,
            localPeer != settings.localPeer,
            remotePeer != settings.remotePeer,
            localHost != settings.localHost,
            remoteHost != settings.remoteHost,
            controlPort != settings.controlPort,
            remoteControlPort != settings.remoteControlPort,
            audioPort != settings.audioPort,
            videoPort != settings.videoPort,
            metricsPort != settings.metricsPort,
            outputPath != settings.outputPath,
            channelCount != settings.channelCount,
            sampleRate != settings.sampleRate,
            frames != settings.frames,
            duration != settings.duration,
            sampleFormat != settings.sampleFormat,
            audioTransport != settings.audioTransport,
            videoWidth != settings.videoWidth,
            videoHeight != settings.videoHeight,
            videoPixelFormat != settings.videoPixelFormat,
            videoCompression != settings.videoCompression,
            videoFrameRate != settings.videoFrameRate,
            videoStreamID != settings.videoStreamID,
            timeoutSeconds != settings.timeoutSeconds,
            avProfile != settings.avProfile,
            rxBufferProfile != settings.rxBufferProfile,
            preview != settings.preview
        ].contains(true)
    }

    private func changesWindowsLoLaRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        [
            windowsLoLaLocalHost != settings.windowsLoLaLocalHost,
            windowsLoLaWindowsHost != settings.windowsLoLaWindowsHost,
            windowsLoLaRole != settings.windowsLoLaRole,
            windowsLoLaControlPort != settings.windowsLoLaControlPort,
            windowsLoLaAudioPort != settings.windowsLoLaAudioPort,
            windowsLoLaVideoPort != settings.windowsLoLaVideoPort,
            windowsLoLaMediaMode != settings.windowsLoLaMediaMode,
            windowsLoLaPayloadMode != settings.windowsLoLaPayloadMode,
            windowsLoLaVideoWidth != settings.windowsLoLaVideoWidth,
            windowsLoLaVideoHeight != settings.windowsLoLaVideoHeight,
            windowsLoLaVideoFrameRate != settings.windowsLoLaVideoFrameRate,
            windowsLoLaVideoBitsPerPixel != settings.windowsLoLaVideoBitsPerPixel,
            windowsLoLaDuration != settings.windowsLoLaDuration,
            windowsLoLaOutputPath != settings.windowsLoLaOutputPath,
            windowsLoLaSampleRate != settings.windowsLoLaSampleRate,
            windowsLoLaFrames != settings.windowsLoLaFrames,
            windowsLoLaChannelCount != settings.windowsLoLaChannelCount,
            windowsLoLaCompression != settings.windowsLoLaCompression,
            windowsLoLaBayer != settings.windowsLoLaBayer
        ].contains(true)
    }

    private func changesJackTripRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        [
            jackTripLocalHost != settings.jackTripLocalHost,
            jackTripPeerHost != settings.jackTripPeerHost,
            jackTripRole != settings.jackTripRole,
            jackTripAudioPort != settings.jackTripAudioPort,
            jackTripPeerAudioPort != settings.jackTripPeerAudioPort,
            jackTripVideoPort != settings.jackTripVideoPort,
            jackTripMediaMode != settings.jackTripMediaMode,
            jackTripDuration != settings.jackTripDuration,
            jackTripOutputPath != settings.jackTripOutputPath
        ].contains(true)
    }

    private func changesUltraGridRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        [
            ultraGridLocalHost != settings.ultraGridLocalHost,
            ultraGridPeerHost != settings.ultraGridPeerHost,
            ultraGridRole != settings.ultraGridRole,
            ultraGridAudioPort != settings.ultraGridAudioPort,
            ultraGridPeerAudioPort != settings.ultraGridPeerAudioPort,
            ultraGridVideoPort != settings.ultraGridVideoPort,
            ultraGridMediaMode != settings.ultraGridMediaMode,
            ultraGridDuration != settings.ultraGridDuration,
            ultraGridOutputPath != settings.ultraGridOutputPath
        ].contains(true)
    }

    var normalizedExecutionMode: String {
        AppExecutionModeAvailability.normalized(
            DirectPeerTwoPeerRunExecutionMode(rawValue: executionMode) ?? .local
        ).rawValue
    }
}
