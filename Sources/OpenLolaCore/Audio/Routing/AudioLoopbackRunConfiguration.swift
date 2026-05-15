import Foundation

public struct AudioLoopbackRunConfiguration: Codable, Equatable, Sendable {
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
        inputUID: String,
        outputUID: String,
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        channelCount: Int = 2,
        sampleFormat: UdpPcmSampleFormat = .int16LittleEndian,
        inputChannelMap: [Int]? = nil,
        outputChannelMap: [Int]? = nil,
        preallocatedBlockCount: Int = 4,
        maxTransmissionUnitBytes: Int = 1_200,
        maxFragmentsPerDeadline: Int = 16,
        metadataRevision: Int = 0,
        latencyProfile: LatencyProfile? = nil,
        rxBufferProfile: RxBufferProfile? = nil,
        experimentalEightFrameOptIn: Bool = false,
        warningAcknowledged: Bool = false,
        durationSeconds: Int,
        outputPath: String
    ) {
        let resolvedProfile = latencyProfile
            ?? LatencyProfilePolicy.profile(forFramesPerBuffer: framesPerBuffer)
            ?? .safeLowLatency
        let policy = LatencyProfilePolicy.policy(for: resolvedProfile)
        self.inputUID = inputUID
        self.outputUID = outputUID
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.inputChannelMap = normalizedRealtimeAudioChannelMap(inputChannelMap, channelCount: channelCount)
        self.outputChannelMap = normalizedRealtimeAudioChannelMap(outputChannelMap, channelCount: channelCount)
        self.preallocatedBlockCount = preallocatedBlockCount
        self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
        self.metadataRevision = metadataRevision
        self.latencyProfile = resolvedProfile
        self.rxBufferProfile = rxBufferProfile ?? policy.defaultRxBufferProfile
        self.experimentalEightFrameOptIn = experimentalEightFrameOptIn
        self.warningAcknowledged = warningAcknowledged
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
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
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw AudioLoopbackRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw AudioLoopbackRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw AudioLoopbackRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }
        return values
    }

    private static func configuration(
        from values: [String: String]
    ) throws -> AudioLoopbackRunConfiguration {
        let sampleRateHertz = try requiredPositiveInteger("--sample-rate", values)
        let framesPerBuffer = try requiredPositiveInteger("--frames", values)
        let channelCount = try optionalPositiveInteger("--channels", values) ?? 2
        let sampleFormat = try audioLoopbackSampleFormat(from: values)
        let inputChannelMap = try channelMap(
            from: values,
            argument: "--input-channels",
            channelCount: channelCount
        )
        let outputChannelMap = try channelMap(
            from: values,
            argument: "--output-channels",
            channelCount: channelCount
        )
        let transport = try transportLimits(from: values)
        let profile = try latencyProfile(from: values, framesPerBuffer: framesPerBuffer)
        let policy = LatencyProfilePolicy.policy(for: profile)
        let rxBufferProfile = try parseRxBufferProfile(values["--rx-buffer-profile"])
            ?? policy.defaultRxBufferProfile
        let explicitProfileOptIn = values["--latency-profile"] != nil
        let experimentalOptIn = try boolValue(values, argument: "--experimental-8-frame")
        let warningAcknowledged = try boolValue(values, argument: "--acknowledge-latency-warning")
        _ = try LatencyProfileSelection.validate(
            request: LatencyProfileSelectionRequest(
                profile: profile,
                sampleRateHertz: sampleRateHertz,
                framesPerBuffer: framesPerBuffer,
                channelCount: channelCount,
                sampleFormat: sampleFormat,
                rxBufferProfile: rxBufferProfile,
                explicitOptIn: explicitProfileOptIn,
                experimentalOptIn: experimentalOptIn,
                warningAcknowledged: warningAcknowledged
            ),
            device: nil,
            route: nil
        )

        return AudioLoopbackRunConfiguration(
            inputUID: try requiredString("--input-uid", values),
            outputUID: try requiredString("--output-uid", values),
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            inputChannelMap: inputChannelMap,
            outputChannelMap: outputChannelMap,
            preallocatedBlockCount: transport.preallocatedBlockCount,
            maxTransmissionUnitBytes: transport.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: transport.maxFragmentsPerDeadline,
            metadataRevision: transport.metadataRevision,
            latencyProfile: profile,
            rxBufferProfile: rxBufferProfile,
            experimentalEightFrameOptIn: experimentalOptIn,
            warningAcknowledged: warningAcknowledged,
            durationSeconds: try requiredPositiveInteger("--duration-seconds", values),
            outputPath: try requiredString("--output", values)
        )
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
    ) throws -> (
        preallocatedBlockCount: Int,
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        metadataRevision: Int
    ) {
        (
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
