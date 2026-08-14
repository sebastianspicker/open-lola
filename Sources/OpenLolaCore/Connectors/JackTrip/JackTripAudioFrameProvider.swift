// Defines JackTrip audio frame providers and their session lifecycle.
import Dispatch
import Foundation

/// Requires conformers to interleavedInt16PCM operations for JackTrip audio frame providing.
public protocol JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport { get }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data
}

public extension JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "injected-fixture",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Injected deterministic JackTrip audio provider."
        )
    }

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        guard deadlineNanoseconds == nil else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-full-duplex-provider-without-deadline"
            )
        }
        return try interleavedInt16PCM(sequenceNumber: sequenceNumber, channels: channels, frames: frames)
    }
}

/// Defines the validated fields for JackTrip synthetic audio frame provider.
public struct JackTripSyntheticAudioFrameProvider: JackTripAudioFrameProviding {
    public init() {}

    public var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Generated interleaved Int16 PCM for JackTrip DEFAULT packetization."
        )
    }

    public func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(channels * frames * MemoryLayout<Int16>.size)
        for frame in 0..<frames {
            for channel in 0..<channels {
                let sample = Int16(clamping: ((sequenceNumber + frame + channel) % 127) - 63)
                data.append(UInt8(truncatingIfNeeded: sample))
                data.append(UInt8(truncatingIfNeeded: sample >> 8))
            }
        }
        return data
    }

    public func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        if let deadlineNanoseconds,
           DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip exchange deadline expired before audio capture"
            )
        }
        return try interleavedInt16PCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            frames: frames
        )
    }
}

protocol JackTripAudioProviderLifecycle: ExternalConnectorLifecycle {
    func start() throws
}

final class JackTripSessionAudioFrameProvider: JackTripAudioFrameProviding, JackTripAudioProviderLifecycle {
    private enum Source {
        case synthetic
        case fixture(Data)
        case coreAudio
        case jackGraph
    }

    private let configuration: ExternalConnectorSessionConfiguration
    private let source: Source
    private let report: ExternalConnectorMediaProviderReport
    private var audioBridge: LoLaCoreAudioLiveBridge?

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        self.configuration = configuration
        self.source = try Self.source(configuration)
        self.report = Self.providerReport(source)
    }

    var providerReport: ExternalConnectorMediaProviderReport { report }

    func start() throws {
        if case .coreAudio = source {
            audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            guard let audioBridge else {
                throw ExternalConnectorSessionError.missingRequiredArgument("--audio-capture coreaudio:<device-uid>")
            }
            try audioBridge.start()
        }
        if case .jackGraph = source {
            if !configuration.dryRun {
                throw ExternalConnectorSessionError.processLaunchFailed(
                    "jack-graph-backend requires a measured JACK graph capture provider in this environment"
                )
            }
        }
    }

    func stop() {
        audioBridge?.stop()
        audioBridge = nil
    }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        try interleavedInt16PCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            frames: frames,
            deadlineNanoseconds: nil
        )
    }

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        switch source {
        case .synthetic:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        case let .fixture(data):
            return repeatedFixtureData(
                data,
                byteCount: max(1, channels * frames * MemoryLayout<Int16>.size)
            )
        case .coreAudio:
            guard let audioBridge else {
                throw ExternalConnectorSessionError.socketFailed("Core Audio JackTrip provider was not started")
            }
            let captureDeadline = deadlineNanoseconds.map(DispatchTime.init(uptimeNanoseconds:))
                ?? (.now() + .seconds(1))
            guard DispatchTime.now() < captureDeadline else {
                throw ExternalConnectorSessionError.socketFailed(
                    "JackTrip exchange deadline expired before Core Audio capture"
                )
            }
            if let payload = try audioBridge.nextLoLaAudioPayload(
                until: captureDeadline
            ) {
                return payload
            }
            throw ExternalConnectorSessionError.socketFailed(
                "Core Audio capture produced no JackTrip audio payload before timeout"
            )
        case .jackGraph:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        }
    }

    private static func source(_ configuration: ExternalConnectorSessionConfiguration) throws -> Source {
        if configuration.jackTrip.audioBackend == .jackGraph {
            return .jackGraph
        }
        switch try parseExternalConnectorAudioCaptureSource(configuration) {
        case .synthetic:
            return .synthetic
        case let .fixture(data):
            return .fixture(data)
        case .coreAudio:
            return .coreAudio
        }
    }

    private static func providerReport(_ source: Source) -> ExternalConnectorMediaProviderReport {
        let audioSource: String
        let evidence: [ExternalConnectorEvidenceClass]
        switch source {
        case .synthetic:
            audioSource = "synthetic"
            evidence = [.synthetic]
        case .fixture:
            audioSource = "fixture"
            evidence = [.synthetic]
        case .coreAudio:
            audioSource = "coreaudio-live"
            evidence = [.liveDevice]
        case .jackGraph:
            audioSource = "jack-graph-backend"
            evidence = [.synthetic]
        }
        let notes = switch source {
        case .jackGraph:
            "JACK graph backend selected. Dry runs use deterministic local frames; "
                + "measured runs require local JACK graph capture evidence."
        default:
            "JackTrip public session audio provider selection for DEFAULT UDP packetization."
        }
        return ExternalConnectorMediaProviderReport(
            audioSource: audioSource,
            videoSource: "not-applicable",
            observedEvidenceClasses: evidence,
            notes: notes
        )
    }
}
