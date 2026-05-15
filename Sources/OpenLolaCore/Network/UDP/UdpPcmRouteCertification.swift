import Darwin
import Dispatch
import Foundation

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

public enum UdpPcmDscpClassification: String, Codable, Equatable, Sendable {
    case honored
    case rewritten
    case ignored
    case harmful
    case notTested
}

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

public struct UdpPcmPacketAgeMetrics: Codable, Equatable, Sendable {
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double

    public init(
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double
    ) {
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
    }
}

public struct UdpPcmRouteMetrics: Codable, Equatable, Sendable {
    public var packetsSent: Int
    public var packetsReceived: Int
    public var lostPackets: Int
    public var latePackets: Int
    public var reorderedPackets: Int
    public var duplicatePackets: Int
    public var packetAge: UdpPcmPacketAgeMetrics
    public var callbackP99Microseconds: Double?
    public var callbackMaxMicroseconds: Double?
    public var jitterP99Microseconds: Double
    public var playoutTargetMicroseconds: Double
    public var hiddenPlayoutGrowthDetected: Bool
    public var rxBuffer: RxBufferRuntimeSnapshot?

    public init(
        packetsSent: Int,
        packetsReceived: Int,
        lostPackets: Int,
        latePackets: Int,
        reorderedPackets: Int,
        duplicatePackets: Int,
        packetAge: UdpPcmPacketAgeMetrics,
        callbackP99Microseconds: Double? = nil,
        callbackMaxMicroseconds: Double? = nil,
        jitterP99Microseconds: Double,
        playoutTargetMicroseconds: Double,
        hiddenPlayoutGrowthDetected: Bool,
        rxBuffer: RxBufferRuntimeSnapshot? = nil
    ) {
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.lostPackets = lostPackets
        self.latePackets = latePackets
        self.reorderedPackets = reorderedPackets
        self.duplicatePackets = duplicatePackets
        self.packetAge = packetAge
        self.callbackP99Microseconds = callbackP99Microseconds
        self.callbackMaxMicroseconds = callbackMaxMicroseconds
        self.jitterP99Microseconds = jitterP99Microseconds
        self.playoutTargetMicroseconds = playoutTargetMicroseconds
        self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
        self.rxBuffer = rxBuffer
    }
}

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
    case passWithLossOrLatePackets
    case passWithDuplicateOrReorderedPackets
    case passWithHiddenPlayoutGrowth
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
    case passWithHarmfulDscp
    case passWithPlaceholderField(String)
}

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

    public init(
        id: String,
        title: String,
        capturedAt: String,
        route: RouteIdentity,
        routeKind: UdpPcmRouteKind,
        sender: UdpPcmRouteEndpoint,
        receiver: UdpPcmRouteEndpoint,
        packetMode: UdpPcmPacketMode,
        measuredDurationSeconds: Int? = nil,
        network: UdpPcmNetworkProfile,
        metrics: UdpPcmRouteMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.route = route
        self.routeKind = routeKind
        self.sender = sender
        self.receiver = receiver
        self.packetMode = packetMode
        self.measuredDurationSeconds = measuredDurationSeconds
        self.network = network
        self.metrics = metrics
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> UdpPcmRouteReport {
        try JSONDecoder().decode(UdpPcmRouteReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validatePacketMode()
        try validateNetwork()
        try validateMetrics()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireRouteNonEmpty(id, "id")
        try requireRouteNonEmpty(title, "title")
        try requireRouteNonEmpty(capturedAt, "capturedAt")
        try requireRouteNonEmpty(route.label, "route.label")
        try requireRouteNonEmpty(route.topology, "route.topology")
        try requireRouteNonEmpty(sender.label, "sender.label")
        try requireRouteNonEmpty(sender.hostName, "sender.hostName")
        try requireRouteNonEmpty(sender.interfaceName, "sender.interfaceName")
        try requireRouteNonEmpty(sender.ipAddress, "sender.ipAddress")
        try requireRouteNonEmpty(receiver.label, "receiver.label")
        try requireRouteNonEmpty(receiver.hostName, "receiver.hostName")
        try requireRouteNonEmpty(receiver.interfaceName, "receiver.interfaceName")
        try requireRouteNonEmpty(receiver.ipAddress, "receiver.ipAddress")
        try requireRouteNonEmpty(notes, "notes")
    }

    private func validatePacketMode() throws {
        try requireRoutePositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try requireRoutePositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try requireRoutePositive(packetMode.channelCount, "packetMode.channelCount")
    }

    private func validateNetwork() throws {
        try requireRouteNonEmpty(network.vlan, "network.vlan")
        try requireRouteNonEmpty(network.multicastPolicy, "network.multicastPolicy")
        try requireRouteNonEmpty(network.packetCapture.notes, "network.packetCapture.notes")
        if let point = network.packetCapture.point {
            try requireRouteNonEmpty(point, "network.packetCapture.point")
        }
        if let linkRateMbps = network.linkRateMbps {
            try requireRoutePositive(linkRateMbps, "network.linkRateMbps")
        }
        try validateDscp(network.dscp)
    }

    private func validateDscp(_ dscp: UdpPcmDscpObservation) throws {
        if let requested = dscp.requested {
            try requireDscpRange(requested)
        }
        if let observed = dscp.observed {
            try requireDscpRange(observed)
        }

        if dscp.classification == .notTested {
            guard dscp.notTestedReason?.isEmpty == false else {
                throw UdpPcmRouteValidationError.missingDscpNotTestedReason
            }
            return
        }

        guard dscp.observed != nil else {
            throw UdpPcmRouteValidationError.missingDscpObservedValue
        }
    }

    private func validateMetrics() throws {
        if let measuredDurationSeconds {
            try requireRoutePositive(measuredDurationSeconds, "measuredDurationSeconds")
        }
        try requireRoutePositive(metrics.packetsSent, "metrics.packetsSent")
        try requireRouteNonNegative(metrics.packetsReceived, "metrics.packetsReceived")
        try requireRouteNonNegative(metrics.lostPackets, "metrics.lostPackets")
        try requireRouteNonNegative(metrics.latePackets, "metrics.latePackets")
        try requireRouteNonNegative(metrics.reorderedPackets, "metrics.reorderedPackets")
        try requireRouteNonNegative(metrics.duplicatePackets, "metrics.duplicatePackets")
        try requireRouteNonNegative(metrics.packetAge.p50Microseconds, "metrics.packetAge.p50Microseconds")
        try requireRouteNonNegative(metrics.packetAge.p95Microseconds, "metrics.packetAge.p95Microseconds")
        try requireRouteNonNegative(metrics.packetAge.p99Microseconds, "metrics.packetAge.p99Microseconds")
        try requireRouteNonNegative(metrics.packetAge.maxMicroseconds, "metrics.packetAge.maxMicroseconds")
        if let callbackP99Microseconds = metrics.callbackP99Microseconds {
            try requireRouteNonNegative(callbackP99Microseconds, "metrics.callbackP99Microseconds")
        }
        if let callbackMaxMicroseconds = metrics.callbackMaxMicroseconds {
            try requireRouteNonNegative(callbackMaxMicroseconds, "metrics.callbackMaxMicroseconds")
        }
        try requireRouteNonNegative(metrics.jitterP99Microseconds, "metrics.jitterP99Microseconds")
        try requireRoutePositive(metrics.playoutTargetMicroseconds, "metrics.playoutTargetMicroseconds")
        try metrics.rxBuffer?.validate()

        guard metrics.packetAge.p50Microseconds <= metrics.packetAge.p95Microseconds,
              metrics.packetAge.p95Microseconds <= metrics.packetAge.p99Microseconds,
              metrics.packetAge.p99Microseconds <= metrics.packetAge.maxMicroseconds else {
            throw UdpPcmRouteValidationError.unorderedPacketAge
        }
        if let callbackP99Microseconds = metrics.callbackP99Microseconds,
           let callbackMaxMicroseconds = metrics.callbackMaxMicroseconds,
           callbackP99Microseconds > callbackMaxMicroseconds {
            throw UdpPcmRouteValidationError.unorderedPacketAge
        }

        let expectedLost = max(0, metrics.packetsSent - metrics.packetsReceived)
        if metrics.lostPackets != expectedLost {
            throw UdpPcmRouteValidationError.packetAccountingMismatch(
                expectedLost: expectedLost,
                actualLost: metrics.lostPackets
            )
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard routeKind != .localhostSmoke else {
            throw UdpPcmRouteValidationError.passWithNonPhysicalRoute(routeKind)
        }
        guard let measuredDurationSeconds else {
            throw UdpPcmRouteValidationError.passWithoutMeasuredDuration
        }
        let expectedPackets = expectedPacketCount(
            durationSeconds: measuredDurationSeconds,
            packetMode: packetMode
        )
        guard metrics.packetsSent == expectedPackets else {
            throw UdpPcmRouteValidationError.passWithDurationPacketCountMismatch(
                expected: expectedPackets,
                actual: metrics.packetsSent
            )
        }
        for field in documentationIPAddressFields()
            where isDocumentationIPAddress(field.value) {
            throw UdpPcmRouteValidationError.passWithDocumentationIPAddress(field.name)
        }
        guard network.packetCapture.receiverCorrelation == true else {
            throw UdpPcmRouteValidationError.passWithoutPacketCaptureCorrelation
        }
        if network.dscp.classification == .notTested {
            throw UdpPcmRouteValidationError.passWithoutDscpClassification
        }
        let expectedPlayoutTarget = playoutTargetMicroseconds(packetMode)
        if !nearlyEqualMicroseconds(metrics.playoutTargetMicroseconds, expectedPlayoutTarget) {
            throw UdpPcmRouteValidationError.passWithBufferedPlayoutTarget(
                actualMicroseconds: metrics.playoutTargetMicroseconds,
                expectedMicroseconds: expectedPlayoutTarget
            )
        }
        if metrics.packetAge.maxMicroseconds > metrics.playoutTargetMicroseconds {
            throw UdpPcmRouteValidationError.passPacketAgeExceedsTarget(
                maxMicroseconds: metrics.packetAge.maxMicroseconds,
                targetMicroseconds: metrics.playoutTargetMicroseconds
            )
        }
        if metrics.lostPackets > 0 || metrics.latePackets > 0 {
            throw UdpPcmRouteValidationError.passWithLossOrLatePackets
        }
        if metrics.duplicatePackets > 0 || metrics.reorderedPackets > 0 {
            throw UdpPcmRouteValidationError.passWithDuplicateOrReorderedPackets
        }
        if metrics.hiddenPlayoutGrowthDetected {
            throw UdpPcmRouteValidationError.passWithHiddenPlayoutGrowth
        }
        if let rxBuffer = metrics.rxBuffer {
            guard rxBuffer.policy.fastestAudioPassEligible else {
                throw UdpPcmRouteValidationError.passWithFastestIneligibleRxBuffer(
                    rxBuffer.policy.profile
                )
            }
            guard !rxBuffer.hiddenGrowthDetected else {
                throw UdpPcmRouteValidationError.passWithHiddenPlayoutGrowth
            }
        }
        if network.dscp.classification == .harmful {
            throw UdpPcmRouteValidationError.passWithHarmfulDscp
        }
        for field in placeholderSensitiveFields() where isRoutePlaceholder(field.value) {
            throw UdpPcmRouteValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func documentationIPAddressFields() -> [(name: String, value: String)] {
        [
            ("sender.ipAddress", sender.ipAddress),
            ("receiver.ipAddress", receiver.ipAddress),
        ]
    }

    private func placeholderSensitiveFields() -> [(name: String, value: String)] {
        [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("route.label", route.label),
            ("route.topology", route.topology),
            ("sender.label", sender.label),
            ("sender.hostName", sender.hostName),
            ("sender.interfaceName", sender.interfaceName),
            ("sender.ipAddress", sender.ipAddress),
            ("receiver.label", receiver.label),
            ("receiver.hostName", receiver.hostName),
            ("receiver.interfaceName", receiver.interfaceName),
            ("receiver.ipAddress", receiver.ipAddress),
            ("network.vlan", network.vlan),
            ("network.multicastPolicy", network.multicastPolicy),
            ("network.packetCapture.point", network.packetCapture.point ?? ""),
            ("network.packetCapture.notes", network.packetCapture.notes),
            ("notes", notes),
        ]
    }
}
