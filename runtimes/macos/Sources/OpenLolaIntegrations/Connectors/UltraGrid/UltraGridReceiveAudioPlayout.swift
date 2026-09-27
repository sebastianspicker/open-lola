import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Bridges validated UltraGrid PT21 PCM into the shared Core Audio playout sink.
import Foundation

/// Delivers decoded UltraGrid PCM to the sole receive-side playout graph.
public protocol UltraGridReceiveAudioPlayout: AnyObject, Sendable {
    func start() throws
    func stop()
    func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome
}

extension UltraGridCompatibilityRunner {
    static func liveAudioPlayout(
        configuration: ExternalConnectorSessionConfiguration,
        receiver: any UltraGridCompatibilityMediaReceiving,
        injected: (any UltraGridReceiveAudioPlayout)?
    ) throws -> (any UltraGridReceiveAudioPlayout)? {
        if let injected { return injected }
        guard !configuration.dryRun, configuration.role.receives, configuration.mediaMode.hasAudio,
              receiver is UltraGridSocketMediaReceiver else {
            return nil
        }
        guard let playback = configuration.audioPlayback else {
            throw ExternalConnectorSessionError.missingRequiredArgument(
                "--audio-playback coreaudio:<device-uid>"
            )
        }
        let prefix = "coreaudio:"
        guard playback.hasPrefix(prefix), playback.count > prefix.count else {
            throw ExternalConnectorSessionError.invalidProcessArgument("audioPlayback", playback)
        }
        return try ExternalConnectorCoreAudioReceivePlayout(
            configuration: configuration,
            outputDeviceUID: String(playback.dropFirst(prefix.count)),
            unsupportedSampleRateMode: "ultragrid-coreaudio-playback-sample-rate"
        )
    }
}
