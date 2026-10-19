import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Shares small connector mechanics that otherwise duplicate launch, capture, topology, and cleanup behavior.
import Foundation

enum ExternalConnectorAudioCaptureSource {
    case synthetic
    case fixture(Data)
    case coreAudio
}

func parseExternalConnectorAudioCaptureSource(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> ExternalConnectorAudioCaptureSource {
    guard let value = configuration.audioCapture else {
        return .synthetic
    }
    if value.hasPrefix("fixture:") {
        return .fixture(try parseFixtureBytes(value, field: "audioCapture"))
    }
    // Plain `coreaudio` (UltraGrid's own default) stays synthetic: the in-process Core Audio
    // bridge needs an explicit device UID and has no system-default-device mode.
    return value.hasPrefix("coreaudio:") ? .coreAudio : .synthetic
}

/// Returns the warning for an in-process audio source that silently falls back to synthetic, or nil when the choice was explicit.
func externalConnectorAudioCaptureFallbackWarning(_ configuration: ExternalConnectorSessionConfiguration) -> String? {
    guard configuration.mediaMode.hasAudio else { return nil }
    let accepted = "accepted forms: synthetic, fixture:<hex>, coreaudio:<device-uid>"
    guard let value = configuration.audioCapture else {
        return "WARNING: --audio-capture was not given; the in-process audio source is SYNTHETIC (\(accepted))."
    }
    if value == "synthetic" || value.hasPrefix("fixture:") || value.hasPrefix("coreaudio:") { return nil }
    return "WARNING: --audio-capture \(value) is not handled in-process; the in-process audio source is SYNTHETIC (\(accepted))."
}

/// Returns the warning for an in-process video source that silently falls back to synthetic, or nil when the choice was explicit.
func externalConnectorVideoCaptureFallbackWarning(_ configuration: ExternalConnectorSessionConfiguration) -> String? {
    guard configuration.mediaMode.hasVideo, configuration.lolaVideoPayload != .avFoundationRaw8 else { return nil }
    let accepted = "accepted forms: synthetic, fixture:<hex>, avfoundation:<device>, avfoundation-raw8, auto"
    guard let value = configuration.videoCapture else {
        return "WARNING: --video-capture was not given; the in-process video source is SYNTHETIC (\(accepted))."
    }
    if value == "synthetic" || value == "avfoundation-raw8" || value == "auto"
        || value.hasPrefix("fixture:") || value.hasPrefix("avfoundation:") { return nil }
    return "WARNING: --video-capture \(value) is not handled in-process; the in-process video source is SYNTHETIC (\(accepted))."
}

/// Writes media fallback warnings to stderr and returns them as text to append to the report notes.
func announceExternalConnectorMediaFallbackWarnings(_ warnings: [String]) -> String {
    for warning in warnings {
        FileHandle.standardError.write(Data((warning + "\n").utf8))
    }
    return warnings.map { " " + $0 }.joined()
}

struct ExternalConnectorLaunchExecutionDetails {
    let launchKind: ExternalConnectorLaunchKind
    let arguments: [String]
    let auxiliaryProcesses: [ExternalConnectorAuxiliaryProcessPlan]

    init(
        launchKind: ExternalConnectorLaunchKind,
        arguments: [String],
        auxiliaryProcesses: [ExternalConnectorAuxiliaryProcessPlan] = []
    ) {
        self.launchKind = launchKind
        self.arguments = arguments
        self.auxiliaryProcesses = auxiliaryProcesses
    }
}

struct ExternalConnectorLaunchPlanDetails {
    let execution: ExternalConnectorLaunchExecutionDetails
    let mediaProfile: ExternalConnectorMediaProfile
    let protocolFacts: [String]
    let sourceReferences: [String]
    let evidenceBoundary: String
}

func makeExternalConnectorLaunchPlan(
    configuration: ExternalConnectorSessionConfiguration,
    details: ExternalConnectorLaunchPlanDetails
) -> ExternalConnectorLaunchPlan {
    ExternalConnectorLaunchPlan(
        connector: configuration.connector,
        role: configuration.role,
        launchKind: details.execution.launchKind,
        executable: nil,
        arguments: details.execution.arguments,
        auxiliaryProcesses: details.execution.auxiliaryProcesses,
        peer: configuration.peer,
        localHost: configuration.localHost,
        controlPort: configuration.controlPort,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        mediaProfile: details.mediaProfile,
        channels: configuration.channels,
        sampleRateHertz: configuration.sampleRateHertz,
        framesPerPacket: configuration.framesPerPacket,
        protocolFacts: details.protocolFacts,
        sourceReferences: details.sourceReferences,
        evidenceBoundary: details.evidenceBoundary
    )
}

struct ExternalConnectorTopologyValidationInput {
    let localHost: String
    let peer: String
    let peerRequired: Bool
    let notes: String
    let fieldPrefix: String
    let requiresDirectRole: Bool
    let isDirectRole: Bool
    let invalidRoleError: String
    let rejectsDirectRole: Bool
    let directRoleError: String
}

func validateExternalConnectorTopology(
    _ input: ExternalConnectorTopologyValidationInput
) throws {
    try requireExternalConnectorSessionNonEmpty(input.localHost, "\(input.fieldPrefix).localHost")
    try requireExternalConnectorSessionNonEmpty(input.notes, "\(input.fieldPrefix).notes")
    if input.peerRequired {
        try requireExternalConnectorSessionNonEmpty(input.peer, "\(input.fieldPrefix).peer")
    }
    guard !input.requiresDirectRole || input.isDirectRole else {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(input.invalidRoleError)
    }
    guard !input.rejectsDirectRole || !input.isDirectRole else {
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(input.directRoleError)
    }
}

protocol ExternalConnectorLifecycle: AnyObject {
    func stop()
}

final class ExternalConnectorLifecycleLease {
    private let lock = NSLock()
    private var stop: (() -> Void)?

    init(_ lifecycle: (any ExternalConnectorLifecycle)?) {
        stop = lifecycle.map { lifecycle in { lifecycle.stop() } }
    }

    func finish() {
        lock.lock()
        let stop = self.stop
        self.stop = nil
        lock.unlock()
        stop?()
    }

    deinit { finish() }
}

func transmitExternalConnectorDatagrams<Datagram>(
    _ datagrams: [Datagram],
    localHost: String,
    peer: String,
    transmitGenerated: (
        String,
        String,
        (_ emit: (Datagram) throws -> Void) throws -> Void
    ) throws -> Int
) throws -> Int {
    try transmitGenerated(localHost, peer) { emit in
        for datagram in datagrams {
            try emit(datagram)
        }
    }
}
