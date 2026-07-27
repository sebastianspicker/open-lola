// Defines persisted application settings, giving storage and runtime setup one stable configuration shape.
import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults; let app = AppShellStoredDefaults.self; let def = defaults
        let fld = app.directPeerCommandFields(defaults: def); let ses = app.sessionMode(defaults: def).rawValue
        let ctl = app.controlMode(defaults: def).rawValue; let win = app.windowsLoLaPeerFields(defaults: def)
        let jac = app.jackTripPeerFields(defaults: def); let ult = app.ultraGridPeerFields(defaults: def)
        let exe = app.executionSettings(defaults: def); let prv = app.previewDefaults(defaults: def)
        self.sessionMode = ses; self.controlMode = ctl; executablePath = fld.executablePath
        planPath = exe.planPath; supervisorReportPath = exe.supervisorReportPath
        (requirePreflight, executionMode) =
            (exe.requirePreflight, AppExecutionModeAvailability.normalized(exe.executionMode).rawValue)
        executionMacASSH = exe.macASSH; executionMacBSSH = exe.macBSSH; executionSSHExecutable = exe.sshExecutable
        (executionMacAWorkingDirectory, executionMacBWorkingDirectory) =
            (exe.macAWorkingDirectory, exe.macBWorkingDirectory)
        executionSCPExecutable = exe.scpExecutable; (role, localPeer, remotePeer, localHost, remoteHost, outputPath) =
            (fld.role.rawValue, fld.localPeer, fld.remotePeer, fld.localHost, fld.remoteHost, fld.outputPath)
        (controlPort, remoteControlPort, audioPort) =
            (Int(fld.controlPort), Int(fld.remoteControlPort), Int(fld.audioPort))
        (videoPort, metricsPort) = (Int(fld.videoPort), Int(fld.metricsPort))
        channelCount = fld.channelCount; sampleRate = fld.sampleRateHertz; frames = fld.framesPerPacket
        duration = fld.durationSeconds; sampleFormat = fld.sampleFormat; audioTransport = fld.audioTransport.rawValue
        (videoWidth, videoHeight, videoPixelFormat, videoCompression, videoFrameRate) =
            (fld.videoWidth, fld.videoHeight, fld.videoPixelFormat, fld.videoCompression.rawValue, fld.videoFrameRate)
        videoStreamID = fld.videoStreamID; timeoutSeconds = fld.timeoutSeconds; avProfile = fld.avProfile.rawValue
        rxBufferProfile = fld.rxBufferProfile.rawValue; preview = fld.preview.rawValue
        (audioPreviewEnabled, videoPreviewEnabled, showSafeFrame) =
            (prv.audioPreviewEnabled, prv.videoPreviewEnabled, prv.showSafeFrame)
        (monitorGain, remoteReturnBlend, videoScale, visibleStreams, selectedVideoStream) =
            (prv.monitorGain, prv.remoteReturnBlend, prv.videoScale, prv.visibleStreams, prv.selectedVideoStream)
        (operatorPlanArtifactPath, operatorSupervisorReportPath) = Self.opPaths(defaults)
        (operatorMacASSH, operatorMacBSSH) = Self.opHosts(defaults)
        (windowsLoLaLocalHost, windowsLoLaWindowsHost, windowsLoLaRole) =
            (win.localHost, win.windowsHost, win.role.rawValue)
        (windowsLoLaControlPort, windowsLoLaAudioPort, windowsLoLaVideoPort) =
            (Int(win.controlPort), Int(win.audioPort), Int(win.videoPort))
        (windowsLoLaMediaMode, windowsLoLaPayloadMode, windowsLoLaVideoWidth, windowsLoLaVideoHeight) =
            (win.mediaMode.rawValue, win.payloadMode.rawValue, win.videoWidth, win.videoHeight)
        (windowsLoLaVideoFrameRate, windowsLoLaVideoBitsPerPixel, windowsLoLaDuration, windowsLoLaOutputPath) =
            (win.videoFrameRate, win.videoBitsPerPixel, win.durationSeconds, win.outputPath)
        (windowsLoLaSampleRate, windowsLoLaFrames, windowsLoLaChannelCount, windowsLoLaCompression) =
            (win.sampleRateHertz, win.framesPerPacket, win.channelCount, win.compression)
        windowsLoLaBayer = win.bayer; (jackTripLocalHost, jackTripPeerHost, jackTripRole, jackTripAudioPort) =
            (jac.localHost, jac.peerHost, jac.role.rawValue, Int(jac.audioPort))
        (jackTripPeerAudioPort, jackTripVideoPort, jackTripMediaMode, jackTripDuration) =
            (Int(jac.peerAudioPort), Int(jac.videoPort), jac.mediaMode.rawValue, jac.durationSeconds)
        (jackTripOutputPath, ultraGridLocalHost, ultraGridPeerHost, ultraGridRole) =
            (jac.outputPath, ult.localHost, ult.peerHost, ult.role.rawValue)
        ultraGridAudioPort = Int(ult.audioPort); ultraGridPeerAudioPort = Int(ult.peerAudioPort)
        ultraGridVideoPort = Int(ult.videoPort); ultraGridMediaMode = ult.mediaMode.rawValue
        ultraGridDuration = ult.durationSeconds; ultraGridOutputPathStorage = ult.outputPath
    }

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
        didSet {
            defaults.set(
                AppShellStoredDefaults.positivePreviewStreamValue(visibleStreams),
                forKey: AppStorageKeys.visibleStreams
            )
        }
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
    var jackTripLocalHost: String {
        didSet { defaults.set(jackTripLocalHost, forKey: AppStorageKeys.jackTripLocalHost) }
    }
    var jackTripPeerHost: String {
        didSet { defaults.set(jackTripPeerHost, forKey: AppStorageKeys.jackTripPeerHost) }
    }
    var jackTripRole: String { didSet { defaults.set(jackTripRole, forKey: AppStorageKeys.jackTripRole) } }
    var jackTripAudioPort: Int {
        didSet { defaults.set(jackTripAudioPort, forKey: AppStorageKeys.jackTripAudioPort) }
    }
    var jackTripPeerAudioPort: Int {
        didSet { defaults.set(jackTripPeerAudioPort, forKey: AppStorageKeys.jackTripPeerAudioPort) }
    }
    var jackTripVideoPort: Int {
        didSet { defaults.set(jackTripVideoPort, forKey: AppStorageKeys.jackTripVideoPort) }
    }
    var jackTripMediaMode: String {
        didSet { defaults.set(jackTripMediaMode, forKey: AppStorageKeys.jackTripMediaMode) }
    }
    var jackTripDuration: Int {
        didSet { defaults.set(jackTripDuration, forKey: AppStorageKeys.jackTripDuration) }
    }
    var jackTripOutputPath: String {
        didSet { defaults.set(jackTripOutputPath, forKey: AppStorageKeys.jackTripOutputPath) }
    }
    var ultraGridLocalHost: String {
        didSet { defaults.set(ultraGridLocalHost, forKey: AppStorageKeys.ultraGridLocalHost) }
    }
    var ultraGridPeerHost: String {
        didSet { defaults.set(ultraGridPeerHost, forKey: AppStorageKeys.ultraGridPeerHost) }
    }
    var ultraGridRole: String { didSet { defaults.set(ultraGridRole, forKey: AppStorageKeys.ultraGridRole) } }
    var ultraGridAudioPort: Int {
        didSet { defaults.set(ultraGridAudioPort, forKey: AppStorageKeys.ultraGridAudioPort) }
    }
    var ultraGridPeerAudioPort: Int {
        didSet { defaults.set(ultraGridPeerAudioPort, forKey: AppStorageKeys.ultraGridPeerAudioPort) }
    }
    var ultraGridVideoPort: Int {
        didSet { defaults.set(ultraGridVideoPort, forKey: AppStorageKeys.ultraGridVideoPort) }
    }
    var ultraGridMediaMode: String {
        didSet { defaults.set(ultraGridMediaMode, forKey: AppStorageKeys.ultraGridMediaMode) }
    }
    var ultraGridDuration: Int {
        didSet { defaults.set(ultraGridDuration, forKey: AppStorageKeys.ultraGridDuration) }
    }

    private var ultraGridOutputPathStorage: String

    var ultraGridOutputPath: String {
        get { ultraGridOutputPathStorage }
        set {
            ultraGridOutputPathStorage = newValue
            defaults.set(newValue, forKey: AppStorageKeys.ultraGridOutputPath)
        }
    }
}

extension AppSettings {
 private static func opPaths(_ defaults: UserDefaults) -> (String, String) {
 (
 defaults.string(forKey: AppStorageKeys.operatorPlanArtifactPath)
 ?? AppOperatorArtifactDefaults.planArtifactPath,
 defaults.string(forKey: AppStorageKeys.operatorSupervisorReportPath)
 ?? AppOperatorArtifactDefaults.supervisorReportPath
 )
 }

 private static func opHosts(_ defaults: UserDefaults) -> (String, String) {
 (
 defaults.string(forKey: AppStorageKeys.operatorMacASSH) ?? AppOperatorArtifactDefaults.macASSH,
 defaults.string(forKey: AppStorageKeys.operatorMacBSSH) ?? AppOperatorArtifactDefaults.macBSSH
 )
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
