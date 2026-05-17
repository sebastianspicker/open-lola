import Foundation

public enum ReferenceNetworkTopology: String, CaseIterable, Codable, Equatable, Sendable {
    case singleHost
    case directWired
    case dedicatedSwitch
    case campus
}

public enum ReferenceSampleRateDispositionState: String, Codable, Equatable, Sendable {
    case accepted
    case rejected
    case notTested
}

public struct ReferenceMacPowerSettings: Codable, Equatable, Sendable {
    public var powerSource: String
    public var automaticSleep: String
    public var displaySleep: String
    public var lowPowerMode: String
    public var appNapPolicy: String

    public init(
        powerSource: String,
        automaticSleep: String,
        displaySleep: String,
        lowPowerMode: String,
        appNapPolicy: String
    ) {
        self.powerSource = powerSource
        self.automaticSleep = automaticSleep
        self.displaySleep = displaySleep
        self.lowPowerMode = lowPowerMode
        self.appNapPolicy = appNapPolicy
    }
}

public struct ReferenceMacProfile: Codable, Equatable, Sendable {
    public var label: String
    public var hostName: String
    public var modelIdentifier: String
    public var siliconGeneration: String
    public var ramGigabytes: Int
    public var macOSProductVersion: String
    public var macOSBuild: String
    public var ethernetAdapterPath: String
    public var wiredInterfaceBSDName: String
    public var wiredInterfaceLinkSpeedMbps: Int
    public var power: ReferenceMacPowerSettings

    public init(
        label: String,
        hostName: String,
        modelIdentifier: String,
        siliconGeneration: String,
        ramGigabytes: Int,
        macOSProductVersion: String,
        macOSBuild: String,
        ethernetAdapterPath: String,
        wiredInterfaceBSDName: String,
        wiredInterfaceLinkSpeedMbps: Int,
        power: ReferenceMacPowerSettings
    ) {
        self.label = label
        self.hostName = hostName
        self.modelIdentifier = modelIdentifier
        self.siliconGeneration = siliconGeneration
        self.ramGigabytes = ramGigabytes
        self.macOSProductVersion = macOSProductVersion
        self.macOSBuild = macOSBuild
        self.ethernetAdapterPath = ethernetAdapterPath
        self.wiredInterfaceBSDName = wiredInterfaceBSDName
        self.wiredInterfaceLinkSpeedMbps = wiredInterfaceLinkSpeedMbps
        self.power = power
    }
}

public struct ReferenceBufferFrameRange: Codable, Equatable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct ReferenceAudioPath: Codable, Equatable, Sendable {
    public var interfaceModel: String
    public var connectionPath: String
    public var driverPackage: String
    public var driverVersion: String
    public var firmwareVersion: String
    public var driverMode: String
    public var totalMixVersion: String
    public var totalMixRouteSnapshot: String
    public var clockSource: String
    public var sampleRateSource: String
    public var sampleRateConversion: SampleRateConversionState
    public var madiOpticalState: String
    public var madiCoaxState: String
    public var channelCount: Int
    public var inputChannelLabels: [String]
    public var outputChannelLabels: [String]
    public var coreAudioInputUID: String
    public var coreAudioOutputUID: String
    public var cableLoopDescription: String
    public var currentBufferFrameSize: Int
    public var acceptedBufferFrameRange: ReferenceBufferFrameRange
    public var inputLatencyFrames: Int
    public var outputLatencyFrames: Int
    public var inputSafetyOffsetFrames: Int
    public var outputSafetyOffsetFrames: Int

    public init(
        interfaceModel: String,
        connectionPath: String,
        driverPackage: String,
        driverVersion: String,
        firmwareVersion: String,
        driverMode: String,
        totalMixVersion: String,
        totalMixRouteSnapshot: String,
        clockSource: String,
        sampleRateSource: String,
        sampleRateConversion: SampleRateConversionState,
        madiOpticalState: String,
        madiCoaxState: String,
        channelCount: Int,
        inputChannelLabels: [String],
        outputChannelLabels: [String],
        coreAudioInputUID: String,
        coreAudioOutputUID: String,
        cableLoopDescription: String,
        currentBufferFrameSize: Int,
        acceptedBufferFrameRange: ReferenceBufferFrameRange,
        inputLatencyFrames: Int,
        outputLatencyFrames: Int,
        inputSafetyOffsetFrames: Int,
        outputSafetyOffsetFrames: Int
    ) {
        self.interfaceModel = interfaceModel
        self.connectionPath = connectionPath
        self.driverPackage = driverPackage
        self.driverVersion = driverVersion
        self.firmwareVersion = firmwareVersion
        self.driverMode = driverMode
        self.totalMixVersion = totalMixVersion
        self.totalMixRouteSnapshot = totalMixRouteSnapshot
        self.clockSource = clockSource
        self.sampleRateSource = sampleRateSource
        self.sampleRateConversion = sampleRateConversion
        self.madiOpticalState = madiOpticalState
        self.madiCoaxState = madiCoaxState
        self.channelCount = channelCount
        self.inputChannelLabels = inputChannelLabels
        self.outputChannelLabels = outputChannelLabels
        self.coreAudioInputUID = coreAudioInputUID
        self.coreAudioOutputUID = coreAudioOutputUID
        self.cableLoopDescription = cableLoopDescription
        self.currentBufferFrameSize = currentBufferFrameSize
        self.acceptedBufferFrameRange = acceptedBufferFrameRange
        self.inputLatencyFrames = inputLatencyFrames
        self.outputLatencyFrames = outputLatencyFrames
        self.inputSafetyOffsetFrames = inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = outputSafetyOffsetFrames
    }
}

public struct ReferenceSampleRateDisposition: Codable, Equatable, Sendable {
    public var sampleRateHertz: Int
    public var disposition: ReferenceSampleRateDispositionState
    public var requestedBufferFrameSizes: [Int]
    public var acceptedBufferFrameSizes: [Int]
    public var notes: String

    public init(
        sampleRateHertz: Int,
        disposition: ReferenceSampleRateDispositionState,
        requestedBufferFrameSizes: [Int],
        acceptedBufferFrameSizes: [Int],
        notes: String
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.disposition = disposition
        self.requestedBufferFrameSizes = requestedBufferFrameSizes
        self.acceptedBufferFrameSizes = acceptedBufferFrameSizes
        self.notes = notes
    }
}

public struct ReferenceDscpPolicy: Codable, Equatable, Sendable {
    public var requestedValue: Int?
    public var observedValue: Int?
    public var classification: UdpPcmDscpClassification
    public var policy: String
    public var notTestedReason: String?

    public init(
        requestedValue: Int?,
        observedValue: Int?,
        classification: UdpPcmDscpClassification,
        policy: String,
        notTestedReason: String?
    ) {
        self.requestedValue = requestedValue
        self.observedValue = observedValue
        self.classification = classification
        self.policy = policy
        self.notTestedReason = notTestedReason
    }
}

public struct ReferenceNetworkProfile: Codable, Equatable, Sendable {
    public var label: String
    public var topology: ReferenceNetworkTopology
    public var senderMacLabel: String
    public var receiverMacLabel: String
    public var routeDescription: String
    public var vlanState: String
    public var senderInterfaceName: String
    public var receiverInterfaceName: String
    public var linkSpeedMbps: Int
    public var mtu: Int
    public var senderIPAddress: String
    public var receiverIPAddress: String
    public var packetCaptureHost: String
    public var packetCaptureInterface: String
    public var packetCapturePoint: String
    public var captureFilter: String
    public var dscp: ReferenceDscpPolicy

    public init(
        label: String,
        topology: ReferenceNetworkTopology,
        senderMacLabel: String,
        receiverMacLabel: String,
        routeDescription: String,
        vlanState: String,
        senderInterfaceName: String,
        receiverInterfaceName: String,
        linkSpeedMbps: Int,
        mtu: Int,
        senderIPAddress: String,
        receiverIPAddress: String,
        packetCaptureHost: String,
        packetCaptureInterface: String,
        packetCapturePoint: String,
        captureFilter: String,
        dscp: ReferenceDscpPolicy
    ) {
        self.label = label
        self.topology = topology
        self.senderMacLabel = senderMacLabel
        self.receiverMacLabel = receiverMacLabel
        self.routeDescription = routeDescription
        self.vlanState = vlanState
        self.senderInterfaceName = senderInterfaceName
        self.receiverInterfaceName = receiverInterfaceName
        self.linkSpeedMbps = linkSpeedMbps
        self.mtu = mtu
        self.senderIPAddress = senderIPAddress
        self.receiverIPAddress = receiverIPAddress
        self.packetCaptureHost = packetCaptureHost
        self.packetCaptureInterface = packetCaptureInterface
        self.packetCapturePoint = packetCapturePoint
        self.captureFilter = captureFilter
        self.dscp = dscp
    }
}

public struct ReferenceRigThresholds: Codable, Equatable, Sendable {
    public var primaryStableBufferFrames: Int
    public var stretchStableBufferFrames: Int
    public var fallbackStableBufferFrames: Int
    public var builtInDevicesAllowedForPass: Bool
    public var callbackP99MaxMicroseconds: Double
    public var callbackMaxMicroseconds: Double
    public var allowedUnderruns: Int
    public var packetAgeP99MaxMicroseconds: Double
    public var packetAgeMaxMicroseconds: Double
    public var packetLossMaxPackets: Int
    public var allowedVerdicts: [MeasurementVerdict]

    public init(
        primaryStableBufferFrames: Int,
        stretchStableBufferFrames: Int,
        fallbackStableBufferFrames: Int,
        builtInDevicesAllowedForPass: Bool,
        callbackP99MaxMicroseconds: Double,
        callbackMaxMicroseconds: Double,
        allowedUnderruns: Int,
        packetAgeP99MaxMicroseconds: Double,
        packetAgeMaxMicroseconds: Double,
        packetLossMaxPackets: Int,
        allowedVerdicts: [MeasurementVerdict]
    ) {
        self.primaryStableBufferFrames = primaryStableBufferFrames
        self.stretchStableBufferFrames = stretchStableBufferFrames
        self.fallbackStableBufferFrames = fallbackStableBufferFrames
        self.builtInDevicesAllowedForPass = builtInDevicesAllowedForPass
        self.callbackP99MaxMicroseconds = callbackP99MaxMicroseconds
        self.callbackMaxMicroseconds = callbackMaxMicroseconds
        self.allowedUnderruns = allowedUnderruns
        self.packetAgeP99MaxMicroseconds = packetAgeP99MaxMicroseconds
        self.packetAgeMaxMicroseconds = packetAgeMaxMicroseconds
        self.packetLossMaxPackets = packetLossMaxPackets
        self.allowedVerdicts = allowedVerdicts
    }
}

public enum ReferenceRigValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationMalformedFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError {
    case emptyField(String)
    case malformedField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case emptyCollection(String)
    case invalidBufferFrameRange
    case acceptedSampleRateWithoutAcceptedBuffers(Int)
    case missingRequiredSampleRate(Int)
    case missingRequiredNetworkTopology(ReferenceNetworkTopology)
    case invalidDscpValue(Int)
    case missingDscpObservedValue(String)
    case missingDscpNotTestedReason(String)
    case unorderedThreshold(String)
    case invalidThresholdTarget(String)
    case missingReferenceMacs(minimum: Int, actual: Int)
    case passWithPlaceholderField(String)
    case passWithoutRmeMadiPath
    case passWithoutThunderboltRmePath
    case passWithoutDedicatedRmeDriver
    case passWithSampleRateConversion(SampleRateConversionState)
    case passWithoutDscpClassification(String)
    case passAllowsBuiltInDevices
}

extension ReferenceRigValidationError: ValidationEmptyListError {
    static func emptyList(_ field: String) -> ReferenceRigValidationError {
        .emptyCollection(field)
    }
}

public struct ReferenceRigReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var referenceMacs: [ReferenceMacProfile]
    public var audioPath: ReferenceAudioPath
    public var sampleRateMatrix: [ReferenceSampleRateDisposition]
    public var networkProfiles: [ReferenceNetworkProfile]
    public var thresholds: ReferenceRigThresholds
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        referenceMacs: [ReferenceMacProfile],
        audioPath: ReferenceAudioPath,
        sampleRateMatrix: [ReferenceSampleRateDisposition],
        networkProfiles: [ReferenceNetworkProfile],
        thresholds: ReferenceRigThresholds,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.referenceMacs = referenceMacs
        self.audioPath = audioPath
        self.sampleRateMatrix = sampleRateMatrix
        self.networkProfiles = networkProfiles
        self.thresholds = thresholds
        self.verdict = verdict
        self.notes = notes
    }
}
