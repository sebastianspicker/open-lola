// Defines closure evidence linking the audio baseline to the integrated AV run and required gate.
import Foundation
import OpenLolaContracts

/// Records the evidence and outcome for integrated proof evidence.
public struct IntegratedProofEvidence: Codable, Equatable, Sendable {
    public var closureGate: IntegratedClosureGate
    public var audioOnlyBaselineFirst: Bool
    public var audioOnlyBaselineReportId: String
    public var integratedRunReportId: String
    public var audioRoutePacketCapturePoint: String?
    public var rmeAudioDeviceVisible: Bool
    public var rmeAudioDeviceUid: String
    public var videoCaptureEnabled: Bool
    public var videoCaptureReportId: String?
    public var videoTransportEnabled: Bool
    public var videoTransportReportId: String?
    public var videoTransportPacketCapturePoint: String?
    public var videoPreviewEnabled: Bool
    public var videoPreviewReportId: String?
    public var oscPollingEnabled: Bool
    public var oscControlReportId: String
    public var atemReadOnlyPollingEnabled: Bool
    public var atemControlReportId: String
    public var atemArmedCommandsAllowed: Bool
    public var baselineRouteVerdict: MeasurementVerdict
    public var integratedRouteVerdict: MeasurementVerdict

    public struct Identity: Equatable, Sendable {
        public var closureGate: IntegratedClosureGate
        public var audioOnlyBaselineFirst: Bool
        public var audioOnlyBaselineReportId: String
        public var integratedRunReportId: String

        public init(
            closureGate: IntegratedClosureGate,
            audioOnlyBaselineFirst: Bool,
            audioOnlyBaselineReportId: String,
            integratedRunReportId: String
        ) {
            self.closureGate = closureGate
            self.audioOnlyBaselineFirst = audioOnlyBaselineFirst
            self.audioOnlyBaselineReportId = audioOnlyBaselineReportId
            self.integratedRunReportId = integratedRunReportId
        }
    }

    public struct AudioRoute: Equatable, Sendable {
        public var packetCapturePoint: String?
        public var rmeAudioDeviceVisible: Bool
        public var rmeAudioDeviceUid: String
        public var baselineRouteVerdict: MeasurementVerdict
        public var integratedRouteVerdict: MeasurementVerdict

        public init(
            packetCapturePoint: String? = nil,
            rmeAudioDeviceVisible: Bool,
            rmeAudioDeviceUid: String,
            baselineRouteVerdict: MeasurementVerdict,
            integratedRouteVerdict: MeasurementVerdict
        ) {
            self.packetCapturePoint = packetCapturePoint
            self.rmeAudioDeviceVisible = rmeAudioDeviceVisible
            self.rmeAudioDeviceUid = rmeAudioDeviceUid
            self.baselineRouteVerdict = baselineRouteVerdict
            self.integratedRouteVerdict = integratedRouteVerdict
        }
    }

    public struct VideoEvidence: Equatable, Sendable {
        public var captureEnabled: Bool
        public var captureReportId: String?
        public var transportEnabled: Bool
        public var transportReportId: String?
        public var transportPacketCapturePoint: String?
        public var previewEnabled: Bool
        public var previewReportId: String?

        public init(
            captureEnabled: Bool,
            captureReportId: String? = nil,
            transportEnabled: Bool,
            transportReportId: String? = nil,
            transportPacketCapturePoint: String? = nil,
            previewEnabled: Bool,
            previewReportId: String? = nil
        ) {
            self.captureEnabled = captureEnabled
            self.captureReportId = captureReportId
            self.transportEnabled = transportEnabled
            self.transportReportId = transportReportId
            self.transportPacketCapturePoint = transportPacketCapturePoint
            self.previewEnabled = previewEnabled
            self.previewReportId = previewReportId
        }
    }

    public struct ControlEvidence: Equatable, Sendable {
        public var oscPollingEnabled: Bool
        public var oscControlReportId: String
        public var atemReadOnlyPollingEnabled: Bool
        public var atemControlReportId: String
        public var atemArmedCommandsAllowed: Bool

        public init(
            oscPollingEnabled: Bool,
            oscControlReportId: String,
            atemReadOnlyPollingEnabled: Bool,
            atemControlReportId: String,
            atemArmedCommandsAllowed: Bool
        ) {
            self.oscPollingEnabled = oscPollingEnabled
            self.oscControlReportId = oscControlReportId
            self.atemReadOnlyPollingEnabled = atemReadOnlyPollingEnabled
            self.atemControlReportId = atemControlReportId
            self.atemArmedCommandsAllowed = atemArmedCommandsAllowed
        }
    }

    public init(
        identity: Identity,
        audioRoute: AudioRoute,
        video: VideoEvidence,
        control: ControlEvidence
    ) {
        self.closureGate = identity.closureGate
        self.audioOnlyBaselineFirst = identity.audioOnlyBaselineFirst
        self.audioOnlyBaselineReportId = identity.audioOnlyBaselineReportId
        self.integratedRunReportId = identity.integratedRunReportId
        self.audioRoutePacketCapturePoint = audioRoute.packetCapturePoint
        self.rmeAudioDeviceVisible = audioRoute.rmeAudioDeviceVisible
        self.rmeAudioDeviceUid = audioRoute.rmeAudioDeviceUid
        self.videoCaptureEnabled = video.captureEnabled
        self.videoCaptureReportId = video.captureReportId
        self.videoTransportEnabled = video.transportEnabled
        self.videoTransportReportId = video.transportReportId
        self.videoTransportPacketCapturePoint = video.transportPacketCapturePoint
        self.videoPreviewEnabled = video.previewEnabled
        self.videoPreviewReportId = video.previewReportId
        self.oscPollingEnabled = control.oscPollingEnabled
        self.oscControlReportId = control.oscControlReportId
        self.atemReadOnlyPollingEnabled = control.atemReadOnlyPollingEnabled
        self.atemControlReportId = control.atemControlReportId
        self.atemArmedCommandsAllowed = control.atemArmedCommandsAllowed
        self.baselineRouteVerdict = audioRoute.baselineRouteVerdict
        self.integratedRouteVerdict = audioRoute.integratedRouteVerdict
    }
}
