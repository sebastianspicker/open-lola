import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppSettings {
    var sessionMode: String { didSet { defaults.set(sessionMode, forKey: AppStorageKeys.sessionMode) } }
    var controlMode: String { didSet { defaults.set(controlMode, forKey: AppStorageKeys.controlMode) } }
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
        let controlMode = AppShellStoredDefaults.controlMode(defaults: defaults)
        let windowsLoLaFields = AppShellStoredDefaults.windowsLoLaPeerFields(defaults: defaults)
        let execution = AppShellStoredDefaults.executionSettings(defaults: defaults)
        let previewDefaults = AppShellStoredDefaults.previewDefaults(defaults: defaults)

        self.sessionMode = sessionMode.rawValue
        self.controlMode = controlMode.rawValue
        executablePath = fields.executablePath
        planPath = execution.planPath
        supervisorReportPath = execution.supervisorReportPath
        executionMode = AppExecutionModeAvailability.normalized(execution.executionMode).rawValue
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

@MainActor
@Observable
final class AppSettingsDraft {
    var sessionMode: String
    var controlMode: String
    var executablePath: String
    var planPath: String
    var supervisorReportPath: String
    var executionMode: String
    var requirePreflight: Bool
    var executionMacASSH: String
    var executionMacBSSH: String
    var executionMacAWorkingDirectory: String
    var executionMacBWorkingDirectory: String
    var executionSSHExecutable: String
    var executionSCPExecutable: String
    var role: String
    var localPeer: String
    var remotePeer: String
    var localHost: String
    var remoteHost: String
    var controlPort: Int
    var remoteControlPort: Int
    var audioPort: Int
    var videoPort: Int
    var metricsPort: Int
    var outputPath: String
    var channelCount: Int
    var sampleRate: Int
    var frames: Int
    var duration: Int
    var sampleFormat: String
    var audioTransport: String
    var videoWidth: Int
    var videoHeight: Int
    var videoPixelFormat: String
    var videoCompression: String
    var videoFrameRate: Int
    var videoStreamID: Int
    var timeoutSeconds: Int
    var avProfile: String
    var rxBufferProfile: String
    var preview: String
    var audioPreviewEnabled: Bool
    var videoPreviewEnabled: Bool
    var showSafeFrame: Bool
    var monitorGain: Double
    var remoteReturnBlend: Double
    var videoScale: Double
    var visibleStreams: Int
    var selectedVideoStream: Int
    var operatorPlanArtifactPath: String
    var operatorSupervisorReportPath: String
    var operatorMacASSH: String
    var operatorMacBSSH: String
    var windowsLoLaLocalHost: String
    var windowsLoLaWindowsHost: String
    var windowsLoLaRole: String
    var windowsLoLaControlPort: Int
    var windowsLoLaAudioPort: Int
    var windowsLoLaVideoPort: Int
    var windowsLoLaMediaMode: String
    var windowsLoLaPayloadMode: String
    var windowsLoLaVideoWidth: Int
    var windowsLoLaVideoHeight: Int
    var windowsLoLaVideoFrameRate: Int
    var windowsLoLaVideoBitsPerPixel: Int
    var windowsLoLaDuration: Int
    var windowsLoLaOutputPath: String
    var windowsLoLaSampleRate: Int
    var windowsLoLaFrames: Int
    var windowsLoLaChannelCount: Int
    var windowsLoLaCompression: Int
    var windowsLoLaBayer: Int
    private var sourceFingerprint: [String]

    convenience init() {
        self.init(settings: AppSettings())
    }

    init(settings: AppSettings) {
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
        audioPreviewEnabled = settings.audioPreviewEnabled
        videoPreviewEnabled = settings.videoPreviewEnabled
        showSafeFrame = settings.showSafeFrame
        monitorGain = settings.monitorGain
        remoteReturnBlend = settings.remoteReturnBlend
        videoScale = settings.videoScale
        visibleStreams = settings.visibleStreams
        selectedVideoStream = settings.selectedVideoStream
        operatorPlanArtifactPath = settings.operatorPlanArtifactPath
        operatorSupervisorReportPath = settings.operatorSupervisorReportPath
        operatorMacASSH = settings.operatorMacASSH
        operatorMacBSSH = settings.operatorMacBSSH
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
        sourceFingerprint = []
        sourceFingerprint = AppSettingsDraftFingerprint.make(from: self)
    }

    func load(from settings: AppSettings) {
        let next = AppSettingsDraft(settings: settings)
        copy(from: next)
        sourceFingerprint = next.sourceFingerprint
    }

    @discardableResult
    func commit(
        to settings: AppSettings,
        operatorSurface: inout NativeAppShellOperatorPrototypeState,
        executionController: AppExecutionController,
        previewState: AppPreviewReceiverState
    ) -> AppSettingsDraftCommitResult {
        guard !hasSourceConflict(comparedTo: settings) else {
            load(from: settings)
            return .conflict(AppSettingsDraftCommitResult.conflictMessage)
        }
        let runtimeConfigurationChanged = changesRuntimeConfiguration(comparedTo: settings)
        apply(to: settings)
        apply(to: &operatorSurface)
        apply(to: &executionController.settings)
        apply(to: previewState)
        if runtimeConfigurationChanged {
            executionController.invalidateRuntimeEvidenceAfterConfigurationChange()
        }
        sourceFingerprint = AppSettingsDraft(settings: settings).sourceFingerprint
        return .saved
    }

    func hasSourceConflict(comparedTo settings: AppSettings) -> Bool {
        AppSettingsDraft(settings: settings).sourceFingerprint != sourceFingerprint
    }

    private func changesRuntimeConfiguration(comparedTo settings: AppSettings) -> Bool {
        sessionMode != settings.sessionMode
            || executablePath != settings.executablePath
            || planPath != settings.planPath
            || supervisorReportPath != settings.supervisorReportPath
            || normalizedExecutionMode != settings.executionMode
            || requirePreflight != settings.requirePreflight
            || executionMacASSH != settings.executionMacASSH
            || executionMacBSSH != settings.executionMacBSSH
            || executionMacAWorkingDirectory != settings.executionMacAWorkingDirectory
            || executionMacBWorkingDirectory != settings.executionMacBWorkingDirectory
            || executionSSHExecutable != settings.executionSSHExecutable
            || executionSCPExecutable != settings.executionSCPExecutable
            || role != settings.role
            || localPeer != settings.localPeer
            || remotePeer != settings.remotePeer
            || localHost != settings.localHost
            || remoteHost != settings.remoteHost
            || controlPort != settings.controlPort
            || remoteControlPort != settings.remoteControlPort
            || audioPort != settings.audioPort
            || videoPort != settings.videoPort
            || metricsPort != settings.metricsPort
            || outputPath != settings.outputPath
            || channelCount != settings.channelCount
            || sampleRate != settings.sampleRate
            || frames != settings.frames
            || duration != settings.duration
            || sampleFormat != settings.sampleFormat
            || audioTransport != settings.audioTransport
            || videoWidth != settings.videoWidth
            || videoHeight != settings.videoHeight
            || videoPixelFormat != settings.videoPixelFormat
            || videoCompression != settings.videoCompression
            || videoFrameRate != settings.videoFrameRate
            || videoStreamID != settings.videoStreamID
            || timeoutSeconds != settings.timeoutSeconds
            || avProfile != settings.avProfile
            || rxBufferProfile != settings.rxBufferProfile
            || preview != settings.preview
            || windowsLoLaLocalHost != settings.windowsLoLaLocalHost
            || windowsLoLaWindowsHost != settings.windowsLoLaWindowsHost
            || windowsLoLaRole != settings.windowsLoLaRole
            || windowsLoLaControlPort != settings.windowsLoLaControlPort
            || windowsLoLaAudioPort != settings.windowsLoLaAudioPort
            || windowsLoLaVideoPort != settings.windowsLoLaVideoPort
            || windowsLoLaMediaMode != settings.windowsLoLaMediaMode
            || windowsLoLaPayloadMode != settings.windowsLoLaPayloadMode
            || windowsLoLaVideoWidth != settings.windowsLoLaVideoWidth
            || windowsLoLaVideoHeight != settings.windowsLoLaVideoHeight
            || windowsLoLaVideoFrameRate != settings.windowsLoLaVideoFrameRate
            || windowsLoLaVideoBitsPerPixel != settings.windowsLoLaVideoBitsPerPixel
            || windowsLoLaDuration != settings.windowsLoLaDuration
            || windowsLoLaOutputPath != settings.windowsLoLaOutputPath
            || windowsLoLaSampleRate != settings.windowsLoLaSampleRate
            || windowsLoLaFrames != settings.windowsLoLaFrames
            || windowsLoLaChannelCount != settings.windowsLoLaChannelCount
            || windowsLoLaCompression != settings.windowsLoLaCompression
            || windowsLoLaBayer != settings.windowsLoLaBayer
    }

    private var normalizedExecutionMode: String {
        AppExecutionModeAvailability.normalized(
            DirectPeerTwoPeerRunExecutionMode(rawValue: executionMode) ?? .local
        ).rawValue
    }

    private func apply(to settings: AppSettings) {
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
        settings.audioPreviewEnabled = audioPreviewEnabled
        settings.videoPreviewEnabled = videoPreviewEnabled
        settings.showSafeFrame = showSafeFrame
        settings.monitorGain = monitorGain
        settings.remoteReturnBlend = remoteReturnBlend
        settings.videoScale = videoScale
        settings.visibleStreams = visibleStreams
        settings.selectedVideoStream = selectedVideoStream
        settings.operatorPlanArtifactPath = operatorPlanArtifactPath
        settings.operatorSupervisorReportPath = operatorSupervisorReportPath
        settings.operatorMacASSH = operatorMacASSH
        settings.operatorMacBSSH = operatorMacBSSH
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

    private func apply(to operatorSurface: inout NativeAppShellOperatorPrototypeState) {
        operatorSurface.sessionMode = NativeAppShellSessionMode(rawValue: sessionMode) ?? .directMacPeer
        operatorSurface.controlMode = NativeAppShellControlMode(rawValue: controlMode) ?? .normal
        operatorSurface.directPeerCommandFields.executablePath = executablePath
        operatorSurface.windowsLoLaPeerFields.executablePath = executablePath
        operatorSurface.directPeerCommandFields.role = DirectPeerSessionManualRole(rawValue: role) ?? .initiator
        operatorSurface.directPeerCommandFields.localPeer = localPeer
        operatorSurface.directPeerCommandFields.remotePeer = remotePeer
        operatorSurface.directPeerCommandFields.localHost = localHost
        operatorSurface.directPeerCommandFields.remoteHost = remoteHost
        operatorSurface.directPeerCommandFields.controlPort = uint16(controlPort)
        operatorSurface.directPeerCommandFields.remoteControlPort = uint16(remoteControlPort)
        operatorSurface.directPeerCommandFields.audioPort = uint16(audioPort)
        operatorSurface.directPeerCommandFields.videoPort = uint16(videoPort)
        operatorSurface.directPeerCommandFields.metricsPort = uint16(metricsPort)
        operatorSurface.directPeerCommandFields.outputPath = outputPath
        operatorSurface.directPeerCommandFields.channelCount = positive(channelCount)
        operatorSurface.directPeerCommandFields.sampleRateHertz = positive(sampleRate)
        operatorSurface.directPeerCommandFields.framesPerPacket = positive(frames)
        operatorSurface.directPeerCommandFields.durationSeconds = positive(duration)
        operatorSurface.directPeerCommandFields.sampleFormat = sampleFormat
        operatorSurface.directPeerCommandFields.audioTransport =
            DirectPeerSessionAudioTransport(rawValue: audioTransport) ?? .openLolaRaw
        operatorSurface.directPeerCommandFields.videoWidth = positive(videoWidth)
        operatorSurface.directPeerCommandFields.videoHeight = positive(videoHeight)
        operatorSurface.directPeerCommandFields.videoPixelFormat = videoPixelFormat
        operatorSurface.directPeerCommandFields.videoCompression =
            DirectPeerSessionVideoCompression(rawValue: videoCompression) ?? .jpegXS
        operatorSurface.directPeerCommandFields.videoFrameRate = positive(videoFrameRate)
        operatorSurface.directPeerCommandFields.videoStreamID = positive(videoStreamID)
        operatorSurface.directPeerCommandFields.timeoutSeconds = positive(timeoutSeconds)
        operatorSurface.directPeerCommandFields.avProfile = DirectPeerSessionAVProfile(rawValue: avProfile) ?? .fastest
        operatorSurface.directPeerCommandFields.rxBufferProfile =
            RxBufferProfile(rawValue: rxBufferProfile) ?? operatorSurface.directPeerCommandFields.avProfile.defaultRXBufferProfile
        operatorSurface.directPeerCommandFields.preview = DirectPeerSessionPreviewMode(rawValue: preview) ?? .on
        operatorSurface.windowsLoLaPeerFields.localHost = windowsLoLaLocalHost
        operatorSurface.windowsLoLaPeerFields.windowsHost = windowsLoLaWindowsHost
        operatorSurface.windowsLoLaPeerFields.role = ExternalConnectorSessionRole(rawValue: windowsLoLaRole) ?? .txRx
        operatorSurface.windowsLoLaPeerFields.controlPort = uint16(windowsLoLaControlPort)
        operatorSurface.windowsLoLaPeerFields.audioPort = uint16(windowsLoLaAudioPort)
        operatorSurface.windowsLoLaPeerFields.videoPort = uint16(windowsLoLaVideoPort)
        operatorSurface.windowsLoLaPeerFields.mediaMode =
            ExternalConnectorMediaMode(rawValue: windowsLoLaMediaMode) ?? .audioVideo
        operatorSurface.windowsLoLaPeerFields.payloadMode =
            LoLaVideoPayloadKind(rawValue: windowsLoLaPayloadMode) ?? .generated
        operatorSurface.windowsLoLaPeerFields.videoWidth = positive(windowsLoLaVideoWidth)
        operatorSurface.windowsLoLaPeerFields.videoHeight = positive(windowsLoLaVideoHeight)
        operatorSurface.windowsLoLaPeerFields.videoFrameRate = positive(windowsLoLaVideoFrameRate)
        operatorSurface.windowsLoLaPeerFields.videoBitsPerPixel = positive(windowsLoLaVideoBitsPerPixel)
        operatorSurface.windowsLoLaPeerFields.durationSeconds = positive(windowsLoLaDuration)
        operatorSurface.windowsLoLaPeerFields.outputPath = windowsLoLaOutputPath
        operatorSurface.windowsLoLaPeerFields.sampleRateHertz = positive(windowsLoLaSampleRate)
        operatorSurface.windowsLoLaPeerFields.framesPerPacket = positive(windowsLoLaFrames)
        operatorSurface.windowsLoLaPeerFields.channelCount = positive(windowsLoLaChannelCount)
        operatorSurface.windowsLoLaPeerFields.compression = nonNegative(windowsLoLaCompression)
        operatorSurface.windowsLoLaPeerFields.bayer = nonNegative(windowsLoLaBayer)
    }

    private func apply(to settings: inout NativeAppShellExecutionSettings) {
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

    private func apply(to previewState: AppPreviewReceiverState) {
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

    private func copy(from draft: AppSettingsDraft) {
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
        audioPreviewEnabled = draft.audioPreviewEnabled
        videoPreviewEnabled = draft.videoPreviewEnabled
        showSafeFrame = draft.showSafeFrame
        monitorGain = draft.monitorGain
        remoteReturnBlend = draft.remoteReturnBlend
        videoScale = draft.videoScale
        visibleStreams = draft.visibleStreams
        selectedVideoStream = draft.selectedVideoStream
        operatorPlanArtifactPath = draft.operatorPlanArtifactPath
        operatorSupervisorReportPath = draft.operatorSupervisorReportPath
        operatorMacASSH = draft.operatorMacASSH
        operatorMacBSSH = draft.operatorMacBSSH
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

    private func positive(_ value: Int) -> Int { max(1, value) }
    private func nonNegative(_ value: Int) -> Int { max(0, value) }
    private func uint16(_ value: Int) -> UInt16 {
        UInt16(clamping: nonNegative(value))
    }
}

enum AppSettingsDraftCommitResult: Equatable {
    static let conflictMessage = "Settings changed outside this window. Reloaded current settings; review edits before saving."

    case saved
    case conflict(String)
}

@MainActor
enum AppSettingsDraftFingerprint {
    static func make(from draft: AppSettingsDraft) -> [String] {
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
            draft.executionSCPExecutable,
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
            draft.preview,
            String(draft.audioPreviewEnabled),
            String(draft.videoPreviewEnabled),
            String(draft.showSafeFrame),
            String(draft.monitorGain),
            String(draft.remoteReturnBlend),
            String(draft.videoScale),
            String(draft.visibleStreams),
            String(draft.selectedVideoStream),
            draft.operatorPlanArtifactPath,
            draft.operatorSupervisorReportPath,
            draft.operatorMacASSH,
            draft.operatorMacBSSH,
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
            String(draft.windowsLoLaBayer),
        ]
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
