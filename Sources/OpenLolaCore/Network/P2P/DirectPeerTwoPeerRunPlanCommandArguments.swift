// Declares direct-peer session configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

extension DirectPeerTwoPeerRunPlanner {
    static func commandArguments(
        role: DirectPeerSessionManualRole,
        local: DirectPeerTwoPeerRunPlanPeer,
        remote: DirectPeerTwoPeerRunPlanPeer,
        configuration: DirectPeerTwoPeerRunPlanConfiguration,
        outputPath: String
    ) throws -> [String] {
        try commandPeerArguments(role: role, local: local, remote: remote, configuration: configuration)
            + commandAudioArguments(local: local, configuration: configuration)
            + commandVideoArguments(local: local, configuration: configuration)
            + commandRuntimeArguments(configuration: configuration, outputPath: outputPath)
    }

    private static func commandPeerArguments(
        role: DirectPeerSessionManualRole,
        local: DirectPeerTwoPeerRunPlanPeer,
        remote: DirectPeerTwoPeerRunPlanPeer,
        configuration: DirectPeerTwoPeerRunPlanConfiguration
    ) -> [String] {
        [
            configuration.executablePath, "direct-p2p-session-run",
            "--media", "audio-video",
            "--role", role.rawValue,
            "--local-peer", local.peerID,
            "--remote-peer", remote.peerID,
            "--local-host", local.host,
            "--remote-host", remote.host,
            "--control-port", "\(local.portBase)",
            "--remote-control-port", "\(remote.portBase)",
            "--audio-port", "\(local.audioPort)",
            "--video-port", "\(local.videoPort)",
            "--metrics-port", "\(local.metricsPort)"
        ]
    }

    private static func commandAudioArguments(
        local: DirectPeerTwoPeerRunPlanPeer,
        configuration: DirectPeerTwoPeerRunPlanConfiguration
    ) throws -> [String] {
        [
            "--channels", "\(configuration.channelCount)",
            "--duration-seconds", "\(configuration.durationSeconds)",
            "--input-uid", local.inputUID,
            "--output-uid", local.outputUID,
            "--sample-rate", "\(configuration.sampleRateHertz)",
            "--frames", "\(configuration.framesPerPacket)",
            "--sample-format", configuration.sampleFormat,
            "--audio-transport", configuration.audioTransport.rawValue,
            "--input-channels", try channelCSV(count: configuration.channelCount),
            "--output-channels", try channelCSV(count: configuration.channelCount)
        ]
    }

    private static func commandVideoArguments(
        local: DirectPeerTwoPeerRunPlanPeer,
        configuration: DirectPeerTwoPeerRunPlanConfiguration
    ) -> [String] {
        [
            "--video-device-id", local.videoDeviceID,
            "--video-width", "\(configuration.videoWidth)",
            "--video-height", "\(configuration.videoHeight)",
            "--video-pixel-format", configuration.videoPixelFormat,
            "--video-compression", configuration.videoCompression.rawValue,
            "--video-frame-rate", "\(configuration.videoFrameRate)",
            "--video-stream-id", "100"
        ]
    }

    private static func commandRuntimeArguments(
        configuration: DirectPeerTwoPeerRunPlanConfiguration,
        outputPath: String
    ) -> [String] {
        [
            "--av-profile", configuration.avProfile.rawValue,
            "--rx-buffer-profile", configuration.rxBufferProfile.rawValue,
            "--preview", configuration.preview.rawValue,
            "--quality-policy", DirectPeerSessionAVRunQualityPolicy.requireUsefulMedia.rawValue,
            "--timeout-seconds", "\(configuration.timeoutSeconds)",
            "--rx-proof-output", rxProofPath(for: outputPath),
            "--output", outputPath
        ]
    }

    private static func rxProofPath(for reportPath: String) -> String {
        reportPath.replacingOccurrences(of: ".json", with: "-rx-proof.json")
    }

    private static func channelCSV(count: Int) throws -> String {
        guard count > 0 else {
            throw DirectPeerTwoPeerRunPlanError.invalidPositiveInt("--channels")
        }
        return (0..<count).map(String.init).joined(separator: ",")
    }
}
