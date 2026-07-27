// Maps DirectP2PSessionRunCommandSupport CLI input into core calls, keeping argument normalization outside domain services.
import Foundation
import OpenLolaCore

let directP2PPositiveIntegerBounds: [String: Int] = [
    "--packets": 1_000_000,
    "--sample-rate": 384_000,
    "--frames": 4_096,
    "--duration-seconds": 86_400,
    "--video-width": 8_192,
    "--video-height": 8_192,
    "--video-frame-rate": 240,
    "--video-stream-id": Int(UInt32.max),
    "--channels": 256,
    "--timeout-seconds": 86_400
]

func printDirectP2PSessionRunUsage() {
    let supportedOptions = directP2PSessionRunPublicArguments().sorted().joined(separator: " ")
    let directPeerUsage =
        "open-lola direct-p2p-session-run --role initiator|responder --local-peer <id> --remote-peer <id> "
        + "--local-host <ip> --remote-host <ip> --control-port <n> --remote-control-port <n> "
        + "--audio-port <n> --video-port <n> --metrics-port <n> --output <path> [--packets <n>]"
    let audioVideoUsage =
        "open-lola direct-p2p-session-run --media audio-video --role initiator|responder --local-peer <id> "
        + "--remote-peer <id> --local-host <ip> --remote-host <ip> --control-port <n> "
        + "--remote-control-port <n> --audio-port <n> --video-port <n> --metrics-port <n> --output <path> "
        + "--duration-seconds <n> --input-uid <uid> --output-uid <uid> --video-device-id <id|auto> "
        + "[--av-profile balanced|fastest] [--rx-buffer-profile direct|small|adaptive|stableWan] "
        + "[--audio-transport openlola-raw|openlola-opus-celt-ld|aes67-st2110-l24] "
        + "[--video-compression raw|jpeg-xs] [--preview on|off] "
        + "[--quality-policy structural|require-useful-media]"
    print(
        """
        Usage:
          open-lola direct-p2p-session-run --output <path> [--packets <n>]
          \(directPeerUsage)
          \(audioVideoUsage)

        Supported options:
          \(supportedOptions)
        """
    )
}

func parseDirectP2PSessionRunArguments(_ arguments: [String]) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: directP2PSessionRunAllowedArguments(),
        allowsDashPrefixedValues: false,
        unknown: { CommandError.invalidArgument("unknown \($0)") },
        duplicate: { CommandError.invalidArgument("duplicate \($0)") },
        missingValue: { CommandError.invalidArgument("missing value for \($0)") }
    )
}

func directP2PSessionRunOutputPath(_ values: [String: String]) throws -> String {
    guard let outputPath = values["--output"], !outputPath.isEmpty else {
        throw CommandError.invalidArgument("missing --output")
    }
    return outputPath
}

func directP2PReadyFileWriter(_ values: [String: String]) -> (() -> Void)? {
    guard let readyFilePath = values["--ready-file"] else {
        return nil
    }
    return {
        let readyFileURL = URL(fileURLWithPath: readyFilePath)
        do {
            try FileManager.default.createDirectory(
                at: readyFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("ready\n".utf8).write(to: readyFileURL)
        } catch {
            writeError("failed to write direct P2P readiness marker: \(error)")
        }
    }
}

func directP2PSessionMediaMode(
    _ values: [String: String]
) throws -> DirectPeerSessionMediaMode {
    guard let value = values["--media"] else {
        return .audio
    }
    guard let mode = DirectPeerSessionMediaMode(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --media")
    }
    return mode
}

func directP2PSessionRunPacketCount(
    _ values: [String: String],
    mediaMode: DirectPeerSessionMediaMode
) throws -> Int {
    if mediaMode == .audioVideo {
        if values["--packets"] != nil {
            throw CommandError.invalidArgument("--packets is not valid with --media audio-video")
        }
        return 1
    }
    guard let value = values["--packets"] else {
        return 3
    }
    guard let count = Int(value),
          count > 0,
          count <= directP2PMaximumPositiveInteger(for: "--packets") else {
        throw CommandError.invalidArgument("invalid --packets")
    }
    return count
}
