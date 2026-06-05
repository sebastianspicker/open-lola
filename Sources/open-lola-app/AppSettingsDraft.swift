import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppSettingsDraft {
    var sessionMode = ""
    var controlMode = ""
    var executablePath = ""
    var planPath = ""
    var supervisorReportPath = ""
    var executionMode = ""
    var requirePreflight = false
    var executionMacASSH = ""
    var executionMacBSSH = ""
    var executionMacAWorkingDirectory = ""
    var executionMacBWorkingDirectory = ""
    var executionSSHExecutable = ""
    var executionSCPExecutable = ""
    var role = ""
    var localPeer = ""
    var remotePeer = ""
    var localHost = ""
    var remoteHost = ""
    var controlPort = 0
    var remoteControlPort = 0
    var audioPort = 0
    var videoPort = 0
    var metricsPort = 0
    var outputPath = ""
    var channelCount = 0
    var sampleRate = 0
    var frames = 0
    var duration = 0
    var sampleFormat = ""
    var audioTransport = ""
    var videoWidth = 0
    var videoHeight = 0
    var videoPixelFormat = ""
    var videoCompression = ""
    var videoFrameRate = 0
    var videoStreamID = 0
    var timeoutSeconds = 0
    var avProfile = ""
    var rxBufferProfile = ""
    var preview = ""
    var audioPreviewEnabled = false
    var videoPreviewEnabled = false
    var showSafeFrame = false
    var monitorGain = 0.0
    var remoteReturnBlend = 0.0
    var videoScale = 0.0
    var visibleStreams = 0
    var selectedVideoStream = 0
    var operatorPlanArtifactPath = ""
    var operatorSupervisorReportPath = ""
    var operatorMacASSH = ""
    var operatorMacBSSH = ""
    var windowsLoLaLocalHost = ""
    var windowsLoLaWindowsHost = ""
    var windowsLoLaRole = ""
    var windowsLoLaControlPort = 0
    var windowsLoLaAudioPort = 0
    var windowsLoLaVideoPort = 0
    var windowsLoLaMediaMode = ""
    var windowsLoLaPayloadMode = ""
    var windowsLoLaVideoWidth = 0
    var windowsLoLaVideoHeight = 0
    var windowsLoLaVideoFrameRate = 0
    var windowsLoLaVideoBitsPerPixel = 0
    var windowsLoLaDuration = 0
    var windowsLoLaOutputPath = ""
    var windowsLoLaSampleRate = 0
    var windowsLoLaFrames = 0
    var windowsLoLaChannelCount = 0
    var windowsLoLaCompression = 0
    var windowsLoLaBayer = 0
    var jackTripLocalHost = ""
    var jackTripPeerHost = ""
    var jackTripRole = ""
    var jackTripAudioPort = 0
    var jackTripPeerAudioPort = 0
    var jackTripVideoPort = 0
    var jackTripMediaMode = ""
    var jackTripDuration = 0
    var jackTripOutputPath = ""
    var ultraGridLocalHost = ""
    var ultraGridPeerHost = ""
    var ultraGridRole = ""
    var ultraGridAudioPort = 0
    var ultraGridPeerAudioPort = 0
    var ultraGridVideoPort = 0
    var ultraGridMediaMode = ""
    var ultraGridDuration = 0
    var ultraGridOutputPath = ""
    var sourceFingerprint: [String] = []

    convenience init() {
        self.init(settings: AppSettings())
    }

    init(settings: AppSettings) {
        loadValues(from: settings)
        sourceFingerprint = AppSettingsDraftFingerprint.make(from: self)
    }
}

enum AppSettingsDraftCommitResult: Equatable {
    static let conflictMessage =
        "Settings changed outside this window. Reloaded current settings; review edits before saving."

    case saved
    case conflict(String)
}
