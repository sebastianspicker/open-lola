// Validates loopback device, channel, packet, duration, and transport limits before a run can alter audio hardware.
import Foundation

private struct AudioLoopbackTransportLimits {
    let preallocatedBlockCount: Int
    let maxTransmissionUnitBytes: Int
    let maxFragmentsPerDeadline: Int
    let metadataRevision: Int
}

/// Binds `inputUID`, `outputUID`, `sampleRateHertz`, and `framesPerBuffer` before CoreAudio loopback routing starts, preventing implicit runtime defaults.
public struct AudioLoopbackRunConfiguration: Codable, Equatable, Sendable {
    public struct Devices: Sendable {
        public let inputUID: String
        public let outputUID: String

        public init(inputUID: String, outputUID: String) {
            self.inputUID = inputUID
            self.outputUID = outputUID
        }
    }

    public struct AudioFormat: Sendable {
        public let sampleRateHertz: Int
        public let framesPerBuffer: Int
        public let channelCount: Int
        public let sampleFormat: UdpPcmSampleFormat
        public let inputChannelMap: [Int]
        public let outputChannelMap: [Int]

        public init(
            sampleRateHertz: Int,
            framesPerBuffer: Int,
            channelCount: Int = 2,
            sampleFormat: UdpPcmSampleFormat = .int16LittleEndian,
            inputChannelMap: [Int]? = nil,
            outputChannelMap: [Int]? = nil
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.channelCount = channelCount
            self.sampleFormat = sampleFormat
            self.inputChannelMap = normalizedRealtimeAudioChannelMap(inputChannelMap, channelCount: channelCount)
            self.outputChannelMap = normalizedRealtimeAudioChannelMap(outputChannelMap, channelCount: channelCount)
        }
    }

    public struct Transport: Sendable {
        public let preallocatedBlockCount: Int
        public let maxTransmissionUnitBytes: Int
        public let maxFragmentsPerDeadline: Int
        public let metadataRevision: Int

        public init(
            preallocatedBlockCount: Int = 4,
            maxTransmissionUnitBytes: Int = 1_200,
            maxFragmentsPerDeadline: Int = 16,
            metadataRevision: Int = 0
        ) {
            self.preallocatedBlockCount = preallocatedBlockCount
            self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
            self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
            self.metadataRevision = metadataRevision
        }
    }

    public struct LatencyOptions: Sendable {
        public let profile: LatencyProfile?
        public let rxBufferProfile: RxBufferProfile?
        public let experimentalEightFrameOptIn: Bool
        public let warningAcknowledged: Bool

        public init(
            profile: LatencyProfile? = nil,
            rxBufferProfile: RxBufferProfile? = nil,
            experimentalEightFrameOptIn: Bool = false,
            warningAcknowledged: Bool = false
        ) {
            self.profile = profile
            self.rxBufferProfile = rxBufferProfile
            self.experimentalEightFrameOptIn = experimentalEightFrameOptIn
            self.warningAcknowledged = warningAcknowledged
        }
    }

    public struct Run: Sendable {
        public let durationSeconds: Int
        public let outputPath: String

        public init(durationSeconds: Int, outputPath: String) {
            self.durationSeconds = durationSeconds
            self.outputPath = outputPath
        }
    }

    public let inputUID: String
    public let outputUID: String
    public let sampleRateHertz: Int
    public let framesPerBuffer: Int
    public let channelCount: Int
    public let sampleFormat: UdpPcmSampleFormat
    public let inputChannelMap: [Int]
    public let outputChannelMap: [Int]
    public let preallocatedBlockCount: Int
    public let maxTransmissionUnitBytes: Int
    public let maxFragmentsPerDeadline: Int
    public let metadataRevision: Int
    public let latencyProfile: LatencyProfile
    public let rxBufferProfile: RxBufferProfile
    public let experimentalEightFrameOptIn: Bool
    public let warningAcknowledged: Bool
    public let durationSeconds: Int
    public let outputPath: String

    public init(
        devices: Devices,
        audio: AudioFormat,
        transport: Transport = Transport(),
        latency: LatencyOptions = LatencyOptions(),
        run: Run
    ) {
        let resolvedProfile = latency.profile
            ?? LatencyProfilePolicy.profile(forFramesPerBuffer: audio.framesPerBuffer)
            ?? .safeLowLatency
        let policy = LatencyProfilePolicy.policy(for: resolvedProfile)
        self.inputUID = devices.inputUID
        self.outputUID = devices.outputUID
        self.sampleRateHertz = audio.sampleRateHertz
        self.framesPerBuffer = audio.framesPerBuffer
        self.channelCount = audio.channelCount
        self.sampleFormat = audio.sampleFormat
        self.inputChannelMap = audio.inputChannelMap
        self.outputChannelMap = audio.outputChannelMap
        self.preallocatedBlockCount = transport.preallocatedBlockCount
        self.maxTransmissionUnitBytes = transport.maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = transport.maxFragmentsPerDeadline
        self.metadataRevision = transport.metadataRevision
        self.latencyProfile = resolvedProfile
        self.rxBufferProfile = latency.rxBufferProfile ?? policy.defaultRxBufferProfile
        self.experimentalEightFrameOptIn = latency.experimentalEightFrameOptIn
        self.warningAcknowledged = latency.warningAcknowledged
        self.durationSeconds = run.durationSeconds
        self.outputPath = run.outputPath
    }

    public static func parse(_ arguments: [String]) throws -> AudioLoopbackRunConfiguration {
        let allowed: Set<String> = [
            "--input-uid",
            "--output-uid",
            "--sample-rate",
            "--frames",
            "--channels",
            "--sample-format",
            "--input-channels",
            "--output-channels",
            "--preallocated-blocks",
            "--mtu",
            "--max-fragments",
            "--metadata-revision",
            "--latency-profile",
            "--rx-buffer-profile",
            "--experimental-8-frame",
            "--acknowledge-latency-warning",
            "--duration-seconds",
            "--output"
        ]
        let values = try parseArgumentValues(arguments, allowed: allowed)
        return try configuration(from: values)
    }

    private static func parseArgumentValues(
        _ arguments: [String],
        allowed: Set<String>
    ) throws -> [String: String] {
        try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
            arguments,
            allowed: allowed,
            unknown: AudioLoopbackRunConfigurationError.unknownArgument,
            duplicate: AudioLoopbackRunConfigurationError.duplicateArgument,
            missingValue: AudioLoopbackRunConfigurationError.missingValue
        )
    }

    private static func configuration(
        from values: [String: String]
    ) throws -> AudioLoopbackRunConfiguration {
        let sampleRateHertz = try requiredPositiveInteger("--sample-rate", values)
        let framesPerBuffer = try requiredPositiveInteger("--frames", values)
        let channelCount = try optionalPositiveInteger("--channels", values) ?? 2
        let sampleFormat = try audioLoopbackSampleFormat(from: values)
        let channelMaps = try channelMaps(from: values, channelCount: channelCount)
        let transport = try transportLimits(from: values)
        let profile = try latencyProfile(from: values, framesPerBuffer: framesPerBuffer)
        let policy = LatencyProfilePolicy.policy(for: profile)
        let rxBufferProfile = try parseRxBufferProfile(values["--rx-buffer-profile"])
            ?? policy.defaultRxBufferProfile
        let explicitProfileOptIn = values["--latency-profile"] != nil
        let context = LatencyValidationContext(
            profile: profile,
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            rxBufferProfile: rxBufferProfile,
            explicitProfileOptIn: explicitProfileOptIn
        )
        let latencyOptions = try validatedLatencyOptions(from: values, context: context)
        return try assembledConfiguration(
            from: values,
            context: context,
            channelMaps: channelMaps,
            transport: transport,
            latencyOptions: latencyOptions
        )
    }

    private static func assembledConfiguration(
        from values: [String: String],
        context: LatencyValidationContext,
        channelMaps: (input: [Int], output: [Int]),
        transport: AudioLoopbackTransportLimits,
        latencyOptions: (experimentalOptIn: Bool, warningAcknowledged: Bool)
    ) throws -> AudioLoopbackRunConfiguration {
        AudioLoopbackRunConfiguration(
            devices: Devices(
                inputUID: try requiredString("--input-uid", values),
                outputUID: try requiredString("--output-uid", values)
            ),
            audio: AudioFormat(
                sampleRateHertz: context.sampleRateHertz,
                framesPerBuffer: context.framesPerBuffer,
                channelCount: context.channelCount,
                sampleFormat: context.sampleFormat,
                inputChannelMap: channelMaps.input,
                outputChannelMap: channelMaps.output
            ),
            transport: Transport(
                preallocatedBlockCount: transport.preallocatedBlockCount,
                maxTransmissionUnitBytes: transport.maxTransmissionUnitBytes,
                maxFragmentsPerDeadline: transport.maxFragmentsPerDeadline,
                metadataRevision: transport.metadataRevision
            ),
            latency: LatencyOptions(
                profile: context.profile,
                rxBufferProfile: context.rxBufferProfile,
                experimentalEightFrameOptIn: latencyOptions.experimentalOptIn,
                warningAcknowledged: latencyOptions.warningAcknowledged
            ),
            run: Run(
                durationSeconds: try requiredPositiveInteger("--duration-seconds", values),
                outputPath: try requiredString("--output", values)
            )
        )
    }

    private static func channelMaps(
        from values: [String: String],
        channelCount: Int
    ) throws -> (input: [Int], output: [Int]) {
        (
            try channelMap(from: values, argument: "--input-channels", channelCount: channelCount),
            try channelMap(from: values, argument: "--output-channels", channelCount: channelCount)
        )
    }

    private struct LatencyValidationContext {
        let profile: LatencyProfile
        let sampleRateHertz: Int
        let framesPerBuffer: Int
        let channelCount: Int
        let sampleFormat: UdpPcmSampleFormat
        let rxBufferProfile: RxBufferProfile
        let explicitProfileOptIn: Bool
    }

    private static func validatedLatencyOptions(
        from values: [String: String],
        context: LatencyValidationContext
    ) throws -> (experimentalOptIn: Bool, warningAcknowledged: Bool) {
        let experimentalOptIn = try boolValue(values, argument: "--experimental-8-frame")
        let warningAcknowledged = try boolValue(values, argument: "--acknowledge-latency-warning")
        _ = try LatencyProfileSelection.validate(
            request: LatencyProfileSelectionRequest(
                profile: context.profile,
                sampleRateHertz: context.sampleRateHertz,
                framesPerBuffer: context.framesPerBuffer,
                channelCount: context.channelCount,
                sampleFormat: context.sampleFormat,
                rxBufferProfile: context.rxBufferProfile,
                optIns: LatencyProfileSelectionRequest.OptIns(
                    explicitProfile: context.explicitProfileOptIn,
                    experimentalMode: experimentalOptIn,
                    warningAcknowledged: warningAcknowledged
                )
            ),
            device: nil,
            route: nil
        )
        return (experimentalOptIn, warningAcknowledged)
    }

    private static func audioLoopbackSampleFormat(
        from values: [String: String]
    ) throws -> UdpPcmSampleFormat {
        try parseAudioLoopbackSampleFormat(values["--sample-format"])
    }

    private static func channelMap(
        from values: [String: String],
        argument: String,
        channelCount: Int
    ) throws -> [Int] {
        normalizedRealtimeAudioChannelMap(try parseAudioLoopbackChannelMap(
            values[argument],
            argument: argument,
            expectedCount: channelCount
        ), channelCount: channelCount)
    }

    private static func transportLimits(
        from values: [String: String]
    ) throws -> AudioLoopbackTransportLimits {
        AudioLoopbackTransportLimits(
            preallocatedBlockCount: try optionalPositiveInteger("--preallocated-blocks", values) ?? 4,
            maxTransmissionUnitBytes: try optionalPositiveInteger("--mtu", values) ?? 1_200,
            maxFragmentsPerDeadline: try optionalPositiveInteger("--max-fragments", values) ?? 16,
            metadataRevision: try optionalNonNegativeInteger("--metadata-revision", values) ?? 0
        )
    }

    private static func latencyProfile(
        from values: [String: String],
        framesPerBuffer: Int
    ) throws -> LatencyProfile {
        try parseLatencyProfile(values["--latency-profile"], framesPerBuffer: framesPerBuffer)
    }

    private static func boolValue(
        _ values: [String: String],
        argument: String
    ) throws -> Bool {
        try parseBool(values[argument] ?? "false", argument: argument)
    }
}

/// Reports `missingRequiredArgument`, `missingValue`, `unknownArgument`, and `duplicateArgument` failures that stop invalid CoreAudio loopback routing work before it reaches a live path.
public enum AudioLoopbackRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case negativeArgument(String)
    case invalidBool(argument: String, value: String)
    case invalidLatencyProfile(String)
    case invalidRxBufferProfile(String)
    case invalidSampleFormat(String)
    case invalidChannelMap(argument: String, value: String)
    case channelMapCountMismatch(argument: String, expected: Int, actual: Int)
}
