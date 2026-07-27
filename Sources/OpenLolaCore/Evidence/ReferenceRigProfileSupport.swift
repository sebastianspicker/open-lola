// Declares measurement evidence configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Captures acceptance policy required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures structured result required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures execution profile required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures execution profile required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures acceptance thresholds required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures acceptance thresholds required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures acceptance thresholds required to validate, interpret, and reproduce a reference-rig result.
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

/// Captures acceptance thresholds required to validate, interpret, and reproduce a reference-rig result.
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

/// Describes failures that prevent reference-rig inputs or evidence from satisfying the required validation invariants.
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
