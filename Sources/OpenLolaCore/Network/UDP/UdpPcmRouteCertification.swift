// Validates UdpPcmRouteCertification acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Darwin
import Dispatch
import Foundation

/// Classifies the route environment represented by UDP PCM certification evidence.
public enum UdpPcmRouteKind: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case localhostSmoke
    case directLink
    case dedicatedSwitch
    case campusPath
}

extension UdpPcmRouteKind {
    var requiresHardwareValidation: Bool {
        switch self {
        case .localhostSmoke:
            false
        case .directLink, .dedicatedSwitch, .campusPath:
            true
        }
    }
}

/// Classifies an observed DSCP marking against the requested audio priority.
public enum UdpPcmDscpClassification: String, Codable, Equatable, Sendable {
    case honored
    case rewritten
    case ignored
    case harmful
    case notTested
}

/// Describes UdpPcmRouteEndpoint values used to plan and verify UDP media transport.
public struct UdpPcmRouteEndpoint: Codable, Equatable, Sendable {
    public var label: String
    public var hostName: String
    public var interfaceName: String
    public var ipAddress: String

    public init(
        label: String,
        hostName: String,
        interfaceName: String,
        ipAddress: String
    ) {
        self.label = label
        self.hostName = hostName
        self.interfaceName = interfaceName
        self.ipAddress = ipAddress
    }
}

/// Represents UdpPcmPacketMode values used by UDP media transport.
public struct UdpPcmPacketMode: Codable, Equatable, Sendable {
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat

    public var payloadByteCount: Int {
        framesPerPacket * channelCount * sampleFormat.bytesPerSample
    }

    public init(
        sampleRateHertz: Int,
        framesPerPacket: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
    }
}

/// Represents UdpPcmDscpObservation values used by UDP media transport.
public struct UdpPcmDscpObservation: Codable, Equatable, Sendable {
    public var requested: Int?
    public var observed: Int?
    public var classification: UdpPcmDscpClassification
    public var notTestedReason: String?

    public init(
        requested: Int?,
        observed: Int?,
        classification: UdpPcmDscpClassification,
        notTestedReason: String?
    ) {
        self.requested = requested
        self.observed = observed
        self.classification = classification
        self.notTestedReason = notTestedReason
    }
}

/// Represents UdpPcmPacketCapture values used by UDP media transport.
public struct UdpPcmPacketCapture: Codable, Equatable, Sendable {
    public var point: String?
    public var receiverCorrelation: Bool?
    public var notes: String

    public init(point: String?, receiverCorrelation: Bool?, notes: String) {
        self.point = point
        self.receiverCorrelation = receiverCorrelation
        self.notes = notes
    }
}

/// Represents UdpPcmNetworkProfile values used by UDP media transport.
public struct UdpPcmNetworkProfile: Codable, Equatable, Sendable {
    public var linkRateMbps: Int?
    public var vlan: String
    public var multicastPolicy: String
    public var dscp: UdpPcmDscpObservation
    public var packetCapture: UdpPcmPacketCapture

    public init(
        linkRateMbps: Int?,
        vlan: String,
        multicastPolicy: String,
        dscp: UdpPcmDscpObservation,
        packetCapture: UdpPcmPacketCapture
    ) {
        self.linkRateMbps = linkRateMbps
        self.vlan = vlan
        self.multicastPolicy = multicastPolicy
        self.dscp = dscp
        self.packetCapture = packetCapture
    }
}

/// Represents the UdpPcmRouteMetrics produced by UDP media transport without exposing its execution state.
public struct UdpPcmRouteMetrics: Codable, Equatable, Sendable {
    public var packetsSent: Int
    public var packetsReceived: Int
    public var lostPackets: Int
    public var latePackets: Int
    public var reorderedPackets: Int
    public var duplicatePackets: Int
    public var receiveErrors: Int
    public var packetAge: UdpPcmPacketAgeMetrics
    public var callbackP99Microseconds: Double?
    public var callbackMaxMicroseconds: Double?
    public var jitterP99Microseconds: Double
    public var playoutTargetMicroseconds: Double
    public var hiddenPlayoutGrowthDetected: Bool
    public var rxBuffer: RxBufferRuntimeSnapshot?

    public struct Delivery: Equatable, Sendable {
        public var packetsSent: Int
        public var packetsReceived: Int
        public var lostPackets: Int
        public var latePackets: Int
        public var reorderedPackets: Int
        public var duplicatePackets: Int
        public var receiveErrors: Int

        public init(
            packetsSent: Int,
            packetsReceived: Int,
            lostPackets: Int,
            latePackets: Int,
            reorderedPackets: Int,
            duplicatePackets: Int,
            receiveErrors: Int = 0
        ) {
            self.packetsSent = packetsSent
            self.packetsReceived = packetsReceived
            self.lostPackets = lostPackets
            self.latePackets = latePackets
            self.reorderedPackets = reorderedPackets
            self.duplicatePackets = duplicatePackets
            self.receiveErrors = receiveErrors
        }
    }

    public struct Timing: Equatable, Sendable {
        public var packetAge: UdpPcmPacketAgeMetrics
        public var callbackP99Microseconds: Double?
        public var callbackMaxMicroseconds: Double?
        public var jitterP99Microseconds: Double
        public var playoutTargetMicroseconds: Double

        public init(
            packetAge: UdpPcmPacketAgeMetrics,
            callbackP99Microseconds: Double? = nil,
            callbackMaxMicroseconds: Double? = nil,
            jitterP99Microseconds: Double,
            playoutTargetMicroseconds: Double
        ) {
            self.packetAge = packetAge
            self.callbackP99Microseconds = callbackP99Microseconds
            self.callbackMaxMicroseconds = callbackMaxMicroseconds
            self.jitterP99Microseconds = jitterP99Microseconds
            self.playoutTargetMicroseconds = playoutTargetMicroseconds
        }
    }

    public init(
        delivery: Delivery,
        timing: Timing,
        hiddenPlayoutGrowthDetected: Bool,
        rxBuffer: RxBufferRuntimeSnapshot? = nil
    ) {
        packetsSent = delivery.packetsSent
        packetsReceived = delivery.packetsReceived
        lostPackets = delivery.lostPackets
        latePackets = delivery.latePackets
        reorderedPackets = delivery.reorderedPackets
        duplicatePackets = delivery.duplicatePackets
        receiveErrors = delivery.receiveErrors
        packetAge = timing.packetAge
        callbackP99Microseconds = timing.callbackP99Microseconds
        callbackMaxMicroseconds = timing.callbackMaxMicroseconds
        jitterP99Microseconds = timing.jitterP99Microseconds
        playoutTargetMicroseconds = timing.playoutTargetMicroseconds
        self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
        self.rxBuffer = rxBuffer
    }

    private enum CodingKeys: String, CodingKey {
        case packetsSent
        case packetsReceived
        case lostPackets
        case latePackets
        case reorderedPackets
        case duplicatePackets
        case receiveErrors
        case packetAge
        case callbackP99Microseconds
        case callbackMaxMicroseconds
        case jitterP99Microseconds
        case playoutTargetMicroseconds
        case hiddenPlayoutGrowthDetected
        case rxBuffer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsSent = try container.decode(Int.self, forKey: .packetsSent)
        packetsReceived = try container.decode(Int.self, forKey: .packetsReceived)
        lostPackets = try container.decode(Int.self, forKey: .lostPackets)
        latePackets = try container.decode(Int.self, forKey: .latePackets)
        reorderedPackets = try container.decode(Int.self, forKey: .reorderedPackets)
        duplicatePackets = try container.decode(Int.self, forKey: .duplicatePackets)
        receiveErrors = try container.decodeIfPresent(Int.self, forKey: .receiveErrors) ?? 0
        packetAge = try container.decode(UdpPcmPacketAgeMetrics.self, forKey: .packetAge)
        callbackP99Microseconds = try container.decodeIfPresent(Double.self, forKey: .callbackP99Microseconds)
        callbackMaxMicroseconds = try container.decodeIfPresent(Double.self, forKey: .callbackMaxMicroseconds)
        jitterP99Microseconds = try container.decode(Double.self, forKey: .jitterP99Microseconds)
        playoutTargetMicroseconds = try container.decode(Double.self, forKey: .playoutTargetMicroseconds)
        hiddenPlayoutGrowthDetected = try container.decode(Bool.self, forKey: .hiddenPlayoutGrowthDetected)
        rxBuffer = try container.decodeIfPresent(RxBufferRuntimeSnapshot.self, forKey: .rxBuffer)
    }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmRouteValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case unorderedPacketAge
    case invalidDscpValue(Int)
    case missingDscpNotTestedReason
    case missingDscpObservedValue
    case packetAccountingMismatch(expectedLost: Int, actualLost: Int)
    case passWithNonPhysicalRoute(UdpPcmRouteKind)
    case passWithoutMeasuredDuration
    case passWithDurationPacketCountMismatch(expected: Int, actual: Int)
    case passWithDocumentationIPAddress(String)
    case passWithoutPacketCaptureCorrelation
    case passWithoutDscpClassification
    case passWithBufferedPlayoutTarget(actualMicroseconds: Double, expectedMicroseconds: Double)
    case passPacketAgeExceedsTarget(maxMicroseconds: Double, targetMicroseconds: Double)
    case passWithoutReceivedPackets
    case passWithReceiveErrors
    case passWithLossOrLatePackets
    case passWithDuplicateOrReorderedPackets
    case passWithHiddenPlayoutGrowth
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
    case passWithHarmfulDscp
    case passWithPlaceholderField(String)
}

/// Captures UdpPcmRouteReport evidence in a stable form for validation and serialized reporting.
public struct UdpPcmRouteReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var route: RouteIdentity
    public var routeKind: UdpPcmRouteKind
    public var sender: UdpPcmRouteEndpoint
    public var receiver: UdpPcmRouteEndpoint
    public var packetMode: UdpPcmPacketMode
    public var measuredDurationSeconds: Int?
    public var network: UdpPcmNetworkProfile
    public var metrics: UdpPcmRouteMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var route: RouteIdentity
        public var routeKind: UdpPcmRouteKind

        public init(
            id: String,
            title: String,
            capturedAt: String,
            route: RouteIdentity,
            routeKind: UdpPcmRouteKind
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.route = route
            self.routeKind = routeKind
        }
    }

    public struct Endpoints: Equatable, Sendable {
        public var sender: UdpPcmRouteEndpoint
        public var receiver: UdpPcmRouteEndpoint

        public init(sender: UdpPcmRouteEndpoint, receiver: UdpPcmRouteEndpoint) {
            self.sender = sender
            self.receiver = receiver
        }
    }

    public struct Measurement: Equatable, Sendable {
        public var packetMode: UdpPcmPacketMode
        public var measuredDurationSeconds: Int?
        public var network: UdpPcmNetworkProfile
        public var metrics: UdpPcmRouteMetrics

        public init(
            packetMode: UdpPcmPacketMode,
            measuredDurationSeconds: Int? = nil,
            network: UdpPcmNetworkProfile,
            metrics: UdpPcmRouteMetrics
        ) {
            self.packetMode = packetMode
            self.measuredDurationSeconds = measuredDurationSeconds
            self.network = network
            self.metrics = metrics
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public init(
        identity: Identity,
        endpoints: Endpoints,
        measurement: Measurement,
        outcome: Outcome
    ) {
        id = identity.id
        title = identity.title
        capturedAt = identity.capturedAt
        route = identity.route
        routeKind = identity.routeKind
        sender = endpoints.sender
        receiver = endpoints.receiver
        packetMode = measurement.packetMode
        measuredDurationSeconds = measurement.measuredDurationSeconds
        network = measurement.network
        metrics = measurement.metrics
        verdict = outcome.verdict
        notes = outcome.notes
    }

    public static func decode(from data: Data) throws -> UdpPcmRouteReport {
        try JSONDecoder().decode(UdpPcmRouteReport.self, from: data)
    }
}
