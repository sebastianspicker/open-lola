// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines the finite structured result values recorded by reference-rig artifacts for deterministic validation and report interpretation.
public enum ReferenceNetworkTopology: String, CaseIterable, Codable, Equatable, Sendable {
    case singleHost
    case directWired
    case dedicatedSwitch
    case campus
}

/// Defines the finite structured result values recorded by reference-rig artifacts for deterministic validation and report interpretation.
public enum ReferenceSampleRateDispositionState: String, Codable, Equatable, Sendable {
    case accepted
    case rejected
    case notTested
}

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
public struct ReferenceMacOperatingSystem: Equatable, Sendable {
    public var productVersion: String
    public var build: String

    public init(productVersion: String, build: String) {
        self.productVersion = productVersion
        self.build = build
    }
}

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures execution profile required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
public struct ReferenceBufferFrameRange: Codable, Equatable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
public struct ReferenceCoreAudioDeviceIDs: Equatable, Sendable {
    public var inputUID: String
    public var outputUID: String

    public init(inputUID: String, outputUID: String) {
        self.inputUID = inputUID
        self.outputUID = outputUID
    }
}

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures report contents required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures report contents required to validate, interpret, and reproduce a reference-rig result.
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
