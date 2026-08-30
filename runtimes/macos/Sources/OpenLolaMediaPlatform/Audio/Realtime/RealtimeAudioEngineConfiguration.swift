// Defines the reusable realtime audio adapter configuration and runtime evidence contracts.
import Foundation
import OpenLolaContracts
import OpenLolaEvidenceModels


/// Identifies the measured or synthetic hardware path used by a real-time audio run.
public enum RealtimeAudioHardwarePath: String, Codable, Equatable, Sendable {
    case rmeMadi
    case builtIn
    case synthetic
    case unknown
}
/// Pairs input and output channel indices for a realtime audio engine configuration.
public struct RealtimeAudioChannelMaps: Equatable, Sendable {
    public var input: [Int]
    public var output: [Int]

    public init(input: [Int], output: [Int]) {
        self.input = input
        self.output = output
    }
}

/// Binds `inputDeviceUID`, `outputDeviceUID`, `sampleRateHertz`, and `framesPerBuffer` before the callback-driven audio path starts, preventing implicit runtime defaults.
public struct RealtimeAudioEngineConfiguration: Codable, Equatable, Sendable {
    public struct Devices: Equatable, Sendable {
        public var inputDeviceUID: String
        public var outputDeviceUID: String

        public init(inputDeviceUID: String, outputDeviceUID: String) {
            self.inputDeviceUID = inputDeviceUID
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var framesPerBuffer: Int
        public var channelCount: Int
        public var packetFormat: UdpPcmSampleFormat

        public init(
            sampleRateHertz: Int,
            framesPerBuffer: Int,
            channelCount: Int,
            packetFormat: UdpPcmSampleFormat
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.channelCount = channelCount
            self.packetFormat = packetFormat
        }
    }

    public typealias ChannelMaps = RealtimeAudioChannelMaps

    public struct Buffering: Equatable, Sendable {
        public var playoutTargetFrames: Int
        public var preallocatedBlockCount: Int
        public var rxBufferPolicy: RxBufferPolicy?

        public init(
            playoutTargetFrames: Int,
            preallocatedBlockCount: Int,
            rxBufferPolicy: RxBufferPolicy? = nil
        ) {
            self.playoutTargetFrames = playoutTargetFrames
            self.preallocatedBlockCount = preallocatedBlockCount
            self.rxBufferPolicy = rxBufferPolicy
        }
    }

 public var inputDeviceUID: String
 public var outputDeviceUID: String
 public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var channelCount: Int
    public var packetFormat: UdpPcmSampleFormat
    public var inputChannelMap: [Int]
    public var outputChannelMap: [Int]
    public var playoutTargetFrames: Int
    public var preallocatedBlockCount: Int
    public var rxBufferPolicy: RxBufferPolicy?

    public init(devices: Devices, format: Format, channelMaps: ChannelMaps, buffering: Buffering) {
        self.inputDeviceUID = devices.inputDeviceUID
        self.outputDeviceUID = devices.outputDeviceUID
        self.sampleRateHertz = format.sampleRateHertz
        self.framesPerBuffer = format.framesPerBuffer
        self.channelCount = format.channelCount
        self.packetFormat = format.packetFormat
        self.inputChannelMap = channelMaps.input
        self.outputChannelMap = channelMaps.output
        self.playoutTargetFrames = buffering.playoutTargetFrames
        self.preallocatedBlockCount = buffering.preallocatedBlockCount
        self.rxBufferPolicy = buffering.rxBufferPolicy
    }

    public var audioMode: AudioMode {
        AudioMode(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            sampleFormat: packetFormat.audioModeSampleFormat
        )
    }

    public func validateRealtimeBufferInputs() throws {
        let format = RealtimeAudioBufferValidationInput.Format(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            bytesPerSample: packetFormat.bytesPerSample
        )
        let channelMaps = RealtimeAudioBufferValidationInput.ChannelMaps(
            input: inputChannelMap,
            output: outputChannelMap
        )
        let buffering = RealtimeAudioBufferValidationInput.Buffering(
            capacityRequirement: .preallocatedBlockCount(preallocatedBlockCount),
            playoutTargetFrames: playoutTargetFrames,
            rxBufferPolicy: rxBufferPolicy
        )
        try validateRealtimeAudioBufferInput(
            RealtimeAudioBufferValidationInput(
                format: format,
                channelMaps: channelMaps,
                buffering: buffering
            )
        )
    }
}

/// Preserves `callbackOwner`, `callback`, `handoff`, and `udpSocketsPreparedBeforeStart` needed to distinguish measured the callback-driven audio path behavior from configuration claims.
public struct RealtimeAudioRuntimeEvidence: Codable, Equatable, Sendable {
    public var callbackOwner: RealtimeAudioCallbackOwner
    public var callback: EndpointCallbackMetrics
    public var handoff: RealtimeAudioHandoffMetrics
    public var udpSocketsPreparedBeforeStart: Bool
    public var reportWrittenAfterStop: Bool
    public var measuredDurationSeconds: Int

    public init(
        callbackOwner: RealtimeAudioCallbackOwner,
        callback: EndpointCallbackMetrics,
        handoff: RealtimeAudioHandoffMetrics,
        udpSocketsPreparedBeforeStart: Bool,
        reportWrittenAfterStop: Bool,
        measuredDurationSeconds: Int
    ) {
        self.callbackOwner = callbackOwner
        self.callback = callback
        self.handoff = handoff
        self.udpSocketsPreparedBeforeStart = udpSocketsPreparedBeforeStart
        self.reportWrittenAfterStop = reportWrittenAfterStop
        self.measuredDurationSeconds = measuredDurationSeconds
    }
}
