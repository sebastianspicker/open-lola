import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppSettings {
    var sessionMode: String { didSet { defaults.set(sessionMode, forKey: AppStorageKeys.sessionMode) } }
    var executablePath: String { didSet { defaults.set(executablePath, forKey: AppStorageKeys.executablePath) } }
    var planPath: String { didSet { defaults.set(planPath, forKey: AppStorageKeys.planPath) } }
    var supervisorReportPath: String {
        didSet { defaults.set(supervisorReportPath, forKey: AppStorageKeys.supervisorReportPath) }
    }
    var executionMode: String { didSet { defaults.set(executionMode, forKey: AppStorageKeys.executionMode) } }
    var requirePreflight: Bool { didSet { defaults.set(requirePreflight, forKey: AppStorageKeys.requirePreflight) } }
    var executionMacASSH: String { didSet { defaults.set(executionMacASSH, forKey: AppStorageKeys.executionMacASSH) } }
    var executionMacBSSH: String { didSet { defaults.set(executionMacBSSH, forKey: AppStorageKeys.executionMacBSSH) } }
    var executionMacAWorkingDirectory: String {
        didSet { defaults.set(executionMacAWorkingDirectory, forKey: AppStorageKeys.executionMacAWorkingDirectory) }
    }
    var executionMacBWorkingDirectory: String {
        didSet { defaults.set(executionMacBWorkingDirectory, forKey: AppStorageKeys.executionMacBWorkingDirectory) }
    }
    var executionSSHExecutable: String {
        didSet { defaults.set(executionSSHExecutable, forKey: AppStorageKeys.executionSSHExecutable) }
    }
    var executionSCPExecutable: String {
        didSet { defaults.set(executionSCPExecutable, forKey: AppStorageKeys.executionSCPExecutable) }
    }
    var role: String { didSet { defaults.set(role, forKey: AppStorageKeys.role) } }
    var localPeer: String { didSet { defaults.set(localPeer, forKey: AppStorageKeys.localPeer) } }
    var remotePeer: String { didSet { defaults.set(remotePeer, forKey: AppStorageKeys.remotePeer) } }
    var localHost: String { didSet { defaults.set(localHost, forKey: AppStorageKeys.localHost) } }
    var remoteHost: String { didSet { defaults.set(remoteHost, forKey: AppStorageKeys.remoteHost) } }
    var controlPort: Int { didSet { defaults.set(controlPort, forKey: AppStorageKeys.controlPort) } }
    var remoteControlPort: Int { didSet { defaults.set(remoteControlPort, forKey: AppStorageKeys.remoteControlPort) } }
    var audioPort: Int { didSet { defaults.set(audioPort, forKey: AppStorageKeys.audioPort) } }
    var videoPort: Int { didSet { defaults.set(videoPort, forKey: AppStorageKeys.videoPort) } }
    var metricsPort: Int { didSet { defaults.set(metricsPort, forKey: AppStorageKeys.metricsPort) } }
    var outputPath: String { didSet { defaults.set(outputPath, forKey: AppStorageKeys.outputPath) } }
    var channelCount: Int { didSet { defaults.set(channelCount, forKey: AppStorageKeys.channelCount) } }
    var sampleRate: Int { didSet { defaults.set(sampleRate, forKey: AppStorageKeys.sampleRate) } }
    var frames: Int { didSet { defaults.set(frames, forKey: AppStorageKeys.frames) } }
    var duration: Int { didSet { defaults.set(duration, forKey: AppStorageKeys.duration) } }
    var sampleFormat: String { didSet { defaults.set(sampleFormat, forKey: AppStorageKeys.sampleFormat) } }
    var audioTransport: String {
        didSet { defaults.set(audioTransport, forKey: AppStorageKeys.audioTransport) }
    }
    var videoWidth: Int { didSet { defaults.set(videoWidth, forKey: AppStorageKeys.videoWidth) } }
    var videoHeight: Int { didSet { defaults.set(videoHeight, forKey: AppStorageKeys.videoHeight) } }
    var videoPixelFormat: String { didSet { defaults.set(videoPixelFormat, forKey: AppStorageKeys.videoPixelFormat) } }
    var videoCompression: String { didSet { defaults.set(videoCompression, forKey: AppStorageKeys.videoCompression) } }
    var videoFrameRate: Int { didSet { defaults.set(videoFrameRate, forKey: AppStorageKeys.videoFrameRate) } }
    var videoStreamID: Int { didSet { defaults.set(videoStreamID, forKey: AppStorageKeys.videoStreamID) } }
    var timeoutSeconds: Int { didSet { defaults.set(timeoutSeconds, forKey: AppStorageKeys.timeoutSeconds) } }
    var avProfile: String { didSet { defaults.set(avProfile, forKey: AppStorageKeys.avProfile) } }
    var rxBufferProfile: String { didSet { defaults.set(rxBufferProfile, forKey: AppStorageKeys.rxBufferProfile) } }
    var preview: String { didSet { defaults.set(preview, forKey: AppStorageKeys.preview) } }
    var audioPreviewEnabled: Bool {
        didSet { defaults.set(audioPreviewEnabled, forKey: AppStorageKeys.audioPreviewEnabled) }
    }
    var videoPreviewEnabled: Bool {
        didSet { defaults.set(videoPreviewEnabled, forKey: AppStorageKeys.videoPreviewEnabled) }
    }
    var showSafeFrame: Bool { didSet { defaults.set(showSafeFrame, forKey: AppStorageKeys.showSafeFrame) } }
    var monitorGain: Double { didSet { defaults.set(monitorGain, forKey: AppStorageKeys.monitorGain) } }
    var remoteReturnBlend: Double {
        didSet { defaults.set(remoteReturnBlend, forKey: AppStorageKeys.remoteReturnBlend) }
    }
    var videoScale: Double { didSet { defaults.set(videoScale, forKey: AppStorageKeys.videoScale) } }
    var visibleStreams: Int {
        didSet { defaults.set(AppShellStoredDefaults.positivePreviewStreamValue(visibleStreams), forKey: AppStorageKeys.visibleStreams) }
    }
    var selectedVideoStream: Int {
        didSet {
            defaults.set(
                AppShellStoredDefaults.positivePreviewStreamValue(selectedVideoStream),
                forKey: AppStorageKeys.selectedVideoStream
            )
        }
    }
    var operatorPlanArtifactPath: String {
        didSet { defaults.set(operatorPlanArtifactPath, forKey: AppStorageKeys.operatorPlanArtifactPath) }
    }
    var operatorSupervisorReportPath: String {
        didSet { defaults.set(operatorSupervisorReportPath, forKey: AppStorageKeys.operatorSupervisorReportPath) }
    }
    var operatorMacASSH: String { didSet { defaults.set(operatorMacASSH, forKey: AppStorageKeys.operatorMacASSH) } }
    var operatorMacBSSH: String { didSet { defaults.set(operatorMacBSSH, forKey: AppStorageKeys.operatorMacBSSH) } }
    var windowsLoLaLocalHost: String {
        didSet { defaults.set(windowsLoLaLocalHost, forKey: AppStorageKeys.windowsLoLaLocalHost) }
    }
    var windowsLoLaWindowsHost: String {
        didSet { defaults.set(windowsLoLaWindowsHost, forKey: AppStorageKeys.windowsLoLaWindowsHost) }
    }
    var windowsLoLaRole: String { didSet { defaults.set(windowsLoLaRole, forKey: AppStorageKeys.windowsLoLaRole) } }
    var windowsLoLaControlPort: Int {
        didSet { defaults.set(windowsLoLaControlPort, forKey: AppStorageKeys.windowsLoLaControlPort) }
    }
    var windowsLoLaAudioPort: Int {
        didSet { defaults.set(windowsLoLaAudioPort, forKey: AppStorageKeys.windowsLoLaAudioPort) }
    }
    var windowsLoLaVideoPort: Int {
        didSet { defaults.set(windowsLoLaVideoPort, forKey: AppStorageKeys.windowsLoLaVideoPort) }
    }
    var windowsLoLaMediaMode: String {
        didSet { defaults.set(windowsLoLaMediaMode, forKey: AppStorageKeys.windowsLoLaMediaMode) }
    }
    var windowsLoLaPayloadMode: String {
        didSet { defaults.set(windowsLoLaPayloadMode, forKey: AppStorageKeys.windowsLoLaPayloadMode) }
    }
    var windowsLoLaVideoWidth: Int {
        didSet { defaults.set(windowsLoLaVideoWidth, forKey: AppStorageKeys.windowsLoLaVideoWidth) }
    }
    var windowsLoLaVideoHeight: Int {
        didSet { defaults.set(windowsLoLaVideoHeight, forKey: AppStorageKeys.windowsLoLaVideoHeight) }
    }
    var windowsLoLaVideoFrameRate: Int {
        didSet { defaults.set(windowsLoLaVideoFrameRate, forKey: AppStorageKeys.windowsLoLaVideoFrameRate) }
    }
    var windowsLoLaVideoBitsPerPixel: Int {
        didSet { defaults.set(windowsLoLaVideoBitsPerPixel, forKey: AppStorageKeys.windowsLoLaVideoBitsPerPixel) }
    }
    var windowsLoLaDuration: Int {
        didSet { defaults.set(windowsLoLaDuration, forKey: AppStorageKeys.windowsLoLaDuration) }
    }
    var windowsLoLaOutputPath: String {
        didSet { defaults.set(windowsLoLaOutputPath, forKey: AppStorageKeys.windowsLoLaOutputPath) }
    }
    var windowsLoLaSampleRate: Int {
        didSet { defaults.set(windowsLoLaSampleRate, forKey: AppStorageKeys.windowsLoLaSampleRate) }
    }
    var windowsLoLaFrames: Int {
        didSet { defaults.set(windowsLoLaFrames, forKey: AppStorageKeys.windowsLoLaFrames) }
    }
    var windowsLoLaChannelCount: Int {
        didSet { defaults.set(windowsLoLaChannelCount, forKey: AppStorageKeys.windowsLoLaChannelCount) }
    }
    var windowsLoLaCompression: Int {
        didSet { defaults.set(windowsLoLaCompression, forKey: AppStorageKeys.windowsLoLaCompression) }
    }
    var windowsLoLaBayer: Int {
        didSet { defaults.set(windowsLoLaBayer, forKey: AppStorageKeys.windowsLoLaBayer) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fields = AppShellStoredDefaults.directPeerCommandFields(defaults: defaults)
        let sessionMode = AppShellStoredDefaults.sessionMode(defaults: defaults)
        let windowsLoLaFields = AppShellStoredDefaults.windowsLoLaPeerFields(defaults: defaults)
        let execution = AppShellStoredDefaults.executionSettings(defaults: defaults)
        let previewDefaults = AppShellStoredDefaults.previewDefaults(defaults: defaults)

        self.sessionMode = sessionMode.rawValue
        executablePath = fields.executablePath
        planPath = execution.planPath
        supervisorReportPath = execution.supervisorReportPath
        executionMode = execution.executionMode.rawValue
        requirePreflight = execution.requirePreflight
        executionMacASSH = execution.macASSH
        executionMacBSSH = execution.macBSSH
        executionMacAWorkingDirectory = execution.macAWorkingDirectory
        executionMacBWorkingDirectory = execution.macBWorkingDirectory
        executionSSHExecutable = execution.sshExecutable
        executionSCPExecutable = execution.scpExecutable
        role = fields.role.rawValue
        localPeer = fields.localPeer
        remotePeer = fields.remotePeer
        localHost = fields.localHost
        remoteHost = fields.remoteHost
        controlPort = Int(fields.controlPort)
        remoteControlPort = Int(fields.remoteControlPort)
        audioPort = Int(fields.audioPort)
        videoPort = Int(fields.videoPort)
        metricsPort = Int(fields.metricsPort)
        outputPath = fields.outputPath
        channelCount = fields.channelCount
        sampleRate = fields.sampleRateHertz
        frames = fields.framesPerPacket
        duration = fields.durationSeconds
        sampleFormat = fields.sampleFormat
        audioTransport = fields.audioTransport.rawValue
        videoWidth = fields.videoWidth
        videoHeight = fields.videoHeight
        videoPixelFormat = fields.videoPixelFormat
        videoCompression = fields.videoCompression.rawValue
        videoFrameRate = fields.videoFrameRate
        videoStreamID = fields.videoStreamID
        timeoutSeconds = fields.timeoutSeconds
        avProfile = fields.avProfile.rawValue
        rxBufferProfile = fields.rxBufferProfile.rawValue
        preview = fields.preview.rawValue
        audioPreviewEnabled = previewDefaults.audioPreviewEnabled
        videoPreviewEnabled = previewDefaults.videoPreviewEnabled
        showSafeFrame = previewDefaults.showSafeFrame
        monitorGain = previewDefaults.monitorGain
        remoteReturnBlend = previewDefaults.remoteReturnBlend
        videoScale = previewDefaults.videoScale
        visibleStreams = previewDefaults.visibleStreams
        selectedVideoStream = previewDefaults.selectedVideoStream
        operatorPlanArtifactPath = defaults.string(forKey: AppStorageKeys.operatorPlanArtifactPath)
            ?? AppOperatorArtifactDefaults.planArtifactPath
        operatorSupervisorReportPath = defaults.string(forKey: AppStorageKeys.operatorSupervisorReportPath)
            ?? AppOperatorArtifactDefaults.supervisorReportPath
        operatorMacASSH = defaults.string(forKey: AppStorageKeys.operatorMacASSH)
            ?? AppOperatorArtifactDefaults.macASSH
        operatorMacBSSH = defaults.string(forKey: AppStorageKeys.operatorMacBSSH)
            ?? AppOperatorArtifactDefaults.macBSSH
        windowsLoLaLocalHost = windowsLoLaFields.localHost
        windowsLoLaWindowsHost = windowsLoLaFields.windowsHost
        windowsLoLaRole = windowsLoLaFields.role.rawValue
        windowsLoLaControlPort = Int(windowsLoLaFields.controlPort)
        windowsLoLaAudioPort = Int(windowsLoLaFields.audioPort)
        windowsLoLaVideoPort = Int(windowsLoLaFields.videoPort)
        windowsLoLaMediaMode = windowsLoLaFields.mediaMode.rawValue
        windowsLoLaPayloadMode = windowsLoLaFields.payloadMode.rawValue
        windowsLoLaVideoWidth = windowsLoLaFields.videoWidth
        windowsLoLaVideoHeight = windowsLoLaFields.videoHeight
        windowsLoLaVideoFrameRate = windowsLoLaFields.videoFrameRate
        windowsLoLaVideoBitsPerPixel = windowsLoLaFields.videoBitsPerPixel
        windowsLoLaDuration = windowsLoLaFields.durationSeconds
        windowsLoLaOutputPath = windowsLoLaFields.outputPath
        windowsLoLaSampleRate = windowsLoLaFields.sampleRateHertz
        windowsLoLaFrames = windowsLoLaFields.framesPerPacket
        windowsLoLaChannelCount = windowsLoLaFields.channelCount
        windowsLoLaCompression = windowsLoLaFields.compression
        windowsLoLaBayer = windowsLoLaFields.bayer
    }
}

struct AppPreviewDefaults {
    var audioPreviewEnabled: Bool
    var videoPreviewEnabled: Bool
    var showSafeFrame: Bool
    var monitorGain: Double
    var remoteReturnBlend: Double
    var videoScale: Double
    var visibleStreams: Int
    var selectedVideoStream: Int
}
