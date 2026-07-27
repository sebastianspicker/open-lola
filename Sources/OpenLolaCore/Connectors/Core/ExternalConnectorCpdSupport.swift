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
    return value.hasPrefix("coreaudio:") ? .coreAudio : .synthetic
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
