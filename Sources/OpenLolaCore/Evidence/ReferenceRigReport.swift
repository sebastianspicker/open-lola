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

public struct ReferenceMacIdentity: Equatable, Sendable {
    public var label: String
    public var hostName: String
    public var modelIdentifier: String
    public var siliconGeneration: String
    public var ramGigabytes: Int

    public init(
        label: String,
        hostName: String,
        modelIdentifier: String,
        siliconGeneration: String,
        ramGigabytes: Int
    ) {
        self.label = label
        self.hostName = hostName
        self.modelIdentifier = modelIdentifier
        self.siliconGeneration = siliconGeneration
        self.ramGigabytes = ramGigabytes
    }
}

public struct ReferenceMacOperatingSystem: Equatable, Sendable {
    public var productVersion: String
    public var build: String

    public init(productVersion: String, build: String) {
        self.productVersion = productVersion
        self.build = build
    }
}

public struct ReferenceMacWiredInterface: Equatable, Sendable {
    public var adapterPath: String
    public var bsdName: String
    public var linkSpeedMbps: Int

    public init(adapterPath: String, bsdName: String, linkSpeedMbps: Int) {
        self.adapterPath = adapterPath
        self.bsdName = bsdName
        self.linkSpeedMbps = linkSpeedMbps
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
        identity: ReferenceMacIdentity,
        operatingSystem: ReferenceMacOperatingSystem,
        wiredInterface: ReferenceMacWiredInterface,
        power: ReferenceMacPowerSettings
    ) {
        self.label = identity.label
        self.hostName = identity.hostName
        self.modelIdentifier = identity.modelIdentifier
        self.siliconGeneration = identity.siliconGeneration
        self.ramGigabytes = identity.ramGigabytes
        self.macOSProductVersion = operatingSystem.productVersion
        self.macOSBuild = operatingSystem.build
        self.ethernetAdapterPath = wiredInterface.adapterPath
        self.wiredInterfaceBSDName = wiredInterface.bsdName
        self.wiredInterfaceLinkSpeedMbps = wiredInterface.linkSpeedMbps
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

public struct ReferenceAudioInterfaceDescription: Equatable, Sendable {
    public var interfaceModel: String
    public var connectionPath: String
    public var driverPackage: String
    public var driverVersion: String
    public var firmwareVersion: String
    public var driverMode: String
    public var totalMixVersion: String
    public var totalMixRouteSnapshot: String

    public init(
        interfaceModel: String,
        connectionPath: String,
        driverPackage: String,
        driverVersion: String,
        firmwareVersion: String,
        driverMode: String,
        totalMixVersion: String,
        totalMixRouteSnapshot: String
    ) {
        self.interfaceModel = interfaceModel
        self.connectionPath = connectionPath
        self.driverPackage = driverPackage
        self.driverVersion = driverVersion
        self.firmwareVersion = firmwareVersion
        self.driverMode = driverMode
        self.totalMixVersion = totalMixVersion
        self.totalMixRouteSnapshot = totalMixRouteSnapshot
    }
}

public struct ReferenceAudioClocking: Equatable, Sendable {
    public var clockSource: String
    public var sampleRateSource: String
    public var sampleRateConversion: SampleRateConversionState
    public var madiOpticalState: String
    public var madiCoaxState: String

    public init(
        clockSource: String,
        sampleRateSource: String,
        sampleRateConversion: SampleRateConversionState,
        madiOpticalState: String,
        madiCoaxState: String
    ) {
        self.clockSource = clockSource
        self.sampleRateSource = sampleRateSource
        self.sampleRateConversion = sampleRateConversion
        self.madiOpticalState = madiOpticalState
        self.madiCoaxState = madiCoaxState
    }
}

public struct ReferenceAudioChannels: Equatable, Sendable {
    public var channelCount: Int
    public var inputChannelLabels: [String]
    public var outputChannelLabels: [String]

    public init(
        channelCount: Int,
        inputChannelLabels: [String],
        outputChannelLabels: [String]
    ) {
        self.channelCount = channelCount
        self.inputChannelLabels = inputChannelLabels
        self.outputChannelLabels = outputChannelLabels
    }
}

public struct ReferenceCoreAudioDeviceIDs: Equatable, Sendable {
    public var inputUID: String
    public var outputUID: String

    public init(inputUID: String, outputUID: String) {
        self.inputUID = inputUID
        self.outputUID = outputUID
    }
}

public struct ReferenceAudioBuffering: Equatable, Sendable {
    public var cableLoopDescription: String
    public var currentBufferFrameSize: Int
    public var acceptedBufferFrameRange: ReferenceBufferFrameRange
    public var inputLatencyFrames: Int
    public var outputLatencyFrames: Int
    public var inputSafetyOffsetFrames: Int
    public var outputSafetyOffsetFrames: Int

    public init(
        cableLoopDescription: String,
        currentBufferFrameSize: Int,
        acceptedBufferFrameRange: ReferenceBufferFrameRange,
        inputLatencyFrames: Int,
        outputLatencyFrames: Int,
        inputSafetyOffsetFrames: Int,
        outputSafetyOffsetFrames: Int
    ) {
        self.cableLoopDescription = cableLoopDescription
        self.currentBufferFrameSize = currentBufferFrameSize
        self.acceptedBufferFrameRange = acceptedBufferFrameRange
        self.inputLatencyFrames = inputLatencyFrames
        self.outputLatencyFrames = outputLatencyFrames
        self.inputSafetyOffsetFrames = inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = outputSafetyOffsetFrames
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
        interfaceDescription: ReferenceAudioInterfaceDescription,
        clocking: ReferenceAudioClocking,
        channels: ReferenceAudioChannels,
        coreAudio: ReferenceCoreAudioDeviceIDs,
        buffering: ReferenceAudioBuffering
    ) {
        self.interfaceModel = interfaceDescription.interfaceModel
        self.connectionPath = interfaceDescription.connectionPath
        self.driverPackage = interfaceDescription.driverPackage
        self.driverVersion = interfaceDescription.driverVersion
        self.firmwareVersion = interfaceDescription.firmwareVersion
        self.driverMode = interfaceDescription.driverMode
        self.totalMixVersion = interfaceDescription.totalMixVersion
        self.totalMixRouteSnapshot = interfaceDescription.totalMixRouteSnapshot
        self.clockSource = clocking.clockSource
        self.sampleRateSource = clocking.sampleRateSource
        self.sampleRateConversion = clocking.sampleRateConversion
        self.madiOpticalState = clocking.madiOpticalState
        self.madiCoaxState = clocking.madiCoaxState
        self.channelCount = channels.channelCount
        self.inputChannelLabels = channels.inputChannelLabels
        self.outputChannelLabels = channels.outputChannelLabels
        self.coreAudioInputUID = coreAudio.inputUID
        self.coreAudioOutputUID = coreAudio.outputUID
        self.cableLoopDescription = buffering.cableLoopDescription
        self.currentBufferFrameSize = buffering.currentBufferFrameSize
        self.acceptedBufferFrameRange = buffering.acceptedBufferFrameRange
        self.inputLatencyFrames = buffering.inputLatencyFrames
        self.outputLatencyFrames = buffering.outputLatencyFrames
        self.inputSafetyOffsetFrames = buffering.inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = buffering.outputSafetyOffsetFrames
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

public struct ReferenceNetworkRouteDetails: Equatable, Sendable {
    public var label: String
    public var topology: ReferenceNetworkTopology
    public var routeDescription: String
    public var vlanState: String
    public var linkSpeedMbps: Int
    public var mtu: Int

    public init(
        label: String,
        topology: ReferenceNetworkTopology,
        routeDescription: String,
        vlanState: String,
        linkSpeedMbps: Int,
        mtu: Int
    ) {
        self.label = label
        self.topology = topology
        self.routeDescription = routeDescription
        self.vlanState = vlanState
        self.linkSpeedMbps = linkSpeedMbps
        self.mtu = mtu
    }
}

public struct ReferenceNetworkEndpoints: Equatable, Sendable {
    public var senderMacLabel: String
    public var receiverMacLabel: String
    public var senderInterfaceName: String
    public var receiverInterfaceName: String
    public var senderIPAddress: String
    public var receiverIPAddress: String

    public init(
        senderMacLabel: String,
        receiverMacLabel: String,
        senderInterfaceName: String,
        receiverInterfaceName: String,
        senderIPAddress: String,
        receiverIPAddress: String
    ) {
        self.senderMacLabel = senderMacLabel
        self.receiverMacLabel = receiverMacLabel
        self.senderInterfaceName = senderInterfaceName
        self.receiverInterfaceName = receiverInterfaceName
        self.senderIPAddress = senderIPAddress
        self.receiverIPAddress = receiverIPAddress
    }
}

public struct ReferencePacketCaptureProfile: Equatable, Sendable {
    public var host: String
    public var interface: String
    public var point: String
    public var filter: String

    public init(host: String, interface: String, point: String, filter: String) {
        self.host = host
        self.interface = interface
        self.point = point
        self.filter = filter
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
        route: ReferenceNetworkRouteDetails,
        endpoints: ReferenceNetworkEndpoints,
        packetCapture: ReferencePacketCaptureProfile,
        dscp: ReferenceDscpPolicy
    ) {
        self.label = route.label
        self.topology = route.topology
        self.senderMacLabel = endpoints.senderMacLabel
        self.receiverMacLabel = endpoints.receiverMacLabel
        self.routeDescription = route.routeDescription
        self.vlanState = route.vlanState
        self.senderInterfaceName = endpoints.senderInterfaceName
        self.receiverInterfaceName = endpoints.receiverInterfaceName
        self.linkSpeedMbps = route.linkSpeedMbps
        self.mtu = route.mtu
        self.senderIPAddress = endpoints.senderIPAddress
        self.receiverIPAddress = endpoints.receiverIPAddress
        self.packetCaptureHost = packetCapture.host
        self.packetCaptureInterface = packetCapture.interface
        self.packetCapturePoint = packetCapture.point
        self.captureFilter = packetCapture.filter
        self.dscp = dscp
    }
}

public struct ReferenceRigBufferThresholds: Equatable, Sendable {
    public var primaryStableBufferFrames: Int
    public var stretchStableBufferFrames: Int
    public var fallbackStableBufferFrames: Int

    public init(
        primaryStableBufferFrames: Int,
        stretchStableBufferFrames: Int,
        fallbackStableBufferFrames: Int
    ) {
        self.primaryStableBufferFrames = primaryStableBufferFrames
        self.stretchStableBufferFrames = stretchStableBufferFrames
        self.fallbackStableBufferFrames = fallbackStableBufferFrames
    }
}

public struct ReferenceRigCallbackThresholds: Equatable, Sendable {
    public var p99MaxMicroseconds: Double
    public var maxMicroseconds: Double
    public var allowedUnderruns: Int

    public init(p99MaxMicroseconds: Double, maxMicroseconds: Double, allowedUnderruns: Int) {
        self.p99MaxMicroseconds = p99MaxMicroseconds
        self.maxMicroseconds = maxMicroseconds
        self.allowedUnderruns = allowedUnderruns
    }
}

public struct ReferenceRigPacketThresholds: Equatable, Sendable {
    public var ageP99MaxMicroseconds: Double
    public var ageMaxMicroseconds: Double
    public var lossMaxPackets: Int

    public init(ageP99MaxMicroseconds: Double, ageMaxMicroseconds: Double, lossMaxPackets: Int) {
        self.ageP99MaxMicroseconds = ageP99MaxMicroseconds
        self.ageMaxMicroseconds = ageMaxMicroseconds
        self.lossMaxPackets = lossMaxPackets
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
        buffers: ReferenceRigBufferThresholds,
        builtInDevicesAllowedForPass: Bool,
        callback: ReferenceRigCallbackThresholds,
        packet: ReferenceRigPacketThresholds,
        allowedVerdicts: [MeasurementVerdict]
    ) {
        self.primaryStableBufferFrames = buffers.primaryStableBufferFrames
        self.stretchStableBufferFrames = buffers.stretchStableBufferFrames
        self.fallbackStableBufferFrames = buffers.fallbackStableBufferFrames
        self.builtInDevicesAllowedForPass = builtInDevicesAllowedForPass
        self.callbackP99MaxMicroseconds = callback.p99MaxMicroseconds
        self.callbackMaxMicroseconds = callback.maxMicroseconds
        self.allowedUnderruns = callback.allowedUnderruns
        self.packetAgeP99MaxMicroseconds = packet.ageP99MaxMicroseconds
        self.packetAgeMaxMicroseconds = packet.ageMaxMicroseconds
        self.packetLossMaxPackets = packet.lossMaxPackets
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

public struct ReferenceRigReportMetadata: Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var notes: String

    public init(id: String, title: String, capturedAt: String, notes: String) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.notes = notes
    }
}

public struct ReferenceRigReportEvidence: Equatable, Sendable {
    public var referenceMacs: [ReferenceMacProfile]
    public var audioPath: ReferenceAudioPath
    public var sampleRateMatrix: [ReferenceSampleRateDisposition]
    public var networkProfiles: [ReferenceNetworkProfile]
    public var thresholds: ReferenceRigThresholds

    public init(
        referenceMacs: [ReferenceMacProfile],
        audioPath: ReferenceAudioPath,
        sampleRateMatrix: [ReferenceSampleRateDisposition],
        networkProfiles: [ReferenceNetworkProfile],
        thresholds: ReferenceRigThresholds
    ) {
        self.referenceMacs = referenceMacs
        self.audioPath = audioPath
        self.sampleRateMatrix = sampleRateMatrix
        self.networkProfiles = networkProfiles
        self.thresholds = thresholds
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
        metadata: ReferenceRigReportMetadata,
        evidence: ReferenceRigReportEvidence,
        verdict: MeasurementVerdict
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.referenceMacs = evidence.referenceMacs
        self.audioPath = evidence.audioPath
        self.sampleRateMatrix = evidence.sampleRateMatrix
        self.networkProfiles = evidence.networkProfiles
        self.thresholds = evidence.thresholds
        self.verdict = verdict
        self.notes = metadata.notes
    }
}
