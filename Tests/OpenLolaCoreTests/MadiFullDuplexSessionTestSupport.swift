// Shared MADI full duplex session helpers keep multi-file test scenarios deterministic.
import Foundation
import Darwin
import Dispatch
import Testing

@testable import OpenLolaCore

func m05AudioStream(
    id: Int = 1,
    sampleRateHertz: Int = 48_000,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    channelCount: Int = 64,
    framesPerPacket: Int = 32
) -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: id, direction: .bidirectional, clockDomain: "core-audio-device:rme-madi"),
            format: .init(sampleRateHertz: sampleRateHertz, sampleFormat: sampleFormat, channelCount: channelCount, channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex),
            packet: .init(framesPerPacket: framesPerPacket, payloadType: .audioPcmV2)
        )
}

func madiFullDuplexRunArguments(omitting omittedFlag: String) -> [String] {
    let keyedArguments = [
        ("--local-peer", "mac-a"),
        ("--remote-peer", "mac-b"),
        ("--local-host", "127.0.0.1"),
        ("--remote-host", "127.0.0.1"),
        ("--port", "49500"),
        ("--sample-rate", "48000"),
        ("--frames", "32"),
        ("--channels", "2"),
        ("--duration-packets", "1"),
        ("--output", FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lola-madi-full-duplex-\(UUID().uuidString).json").path)
    ]
    return ["madi-full-duplex-run"] + keyedArguments.flatMap { flag, value in
        flag == omittedFlag ? [] : [flag, value]
    }
}

func runMadiFullDuplexCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    try runTestExecutable(try requiredMadiFullDuplexCLIURL(), arguments: arguments)
}

func requiredMadiFullDuplexCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try requiredFreshOpenLolaCLIURL(
        repositoryRoot: root,
        context: "MADI full-duplex executable behavior tests"
    )
}

func m05Peer(_ id: String) -> PeerIdentity {
    PeerIdentity(
        peerID: id,
        displayName: "M05 \(id)",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m05"
    )
}

func m05VideoStream(enabled: Bool) -> VideoStreamDescription {
    VideoStreamDescription(
        identity: .init(
            id: 100,
            direction: enabled ? .send : .disabled,
            role: enabled ? .blackmagicInput : .disabled,
            sourceLabel: enabled ? "Blackmagic input" : "video-disabled",
            payloadType: .videoRawFrameFragment
        ),
        format: .init(
            resolution: .init(width: 1_920, height: 1_080),
            frameRate: .init(numerator: 60, denominator: 1),
            pixelFormat: enabled ? .bgra8 : .disabled,
            transportFormat: enabled ? .rawFrameFragment : .disabled
        )
    )
}

func m05Mode(channelCount: Int) throws -> AudioTransportMode {
    try udpPcmV2TestMode(
        channelCount: channelCount,
        metadataRevision: 5
    )
}

func m05Packets(
    mode: AudioTransportMode,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64
) throws -> [UdpPcmV2Packet] {
    try UdpPcmV2Packetizer.packetize(
        Data(
            repeating: UInt8(sequenceNumber),
            count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
        ),
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        senderHostTimeNanoseconds: sequenceNumber + 1,
        mode: mode
    )
}

func m05SwapStereoReceiverMix(channelCount: Int) -> ReceiverMixSnapshot {
    let routes = (0..<channelCount).map { index in
        ReceiverMixRoute(
            sourceChannelIndex: index,
            destinationChannelIndex: index < 2 ? 1 - index : index,
            gainDb: 0,
            muted: false,
            pan: 0
        )
    }
    return ReceiverMixSnapshot(
        routes: routes,
        requiresDestructiveDownmix: false
    )
}

final class MadiFullDuplexReportResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<MadiFullDuplexReport, Error>?

    func store(_ result: Result<MadiFullDuplexReport, Error>) {
        lock.lock()
        storedResult = result
        lock.unlock()
    }

    func result() throws -> Result<MadiFullDuplexReport, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let storedResult else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        return storedResult
    }
}

func freeLoopbackPortPair() throws -> (UInt16, UInt16) {
    let first = try makeUdpSocket(receiveTimeoutSeconds: 1)
    let second = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer {
        close(first)
        close(second)
    }
    try bindLoopback(first, port: 0)
    try bindLoopback(second, port: 0)
    let firstPort = UInt16(bigEndian: try boundPort(first))
    let secondPort = UInt16(bigEndian: try boundPort(second))
    if firstPort == secondPort {
        throw UdpPcmRouteProbeError.bindFailed(EADDRINUSE)
    }
    return (firstPort, secondPort)
}
