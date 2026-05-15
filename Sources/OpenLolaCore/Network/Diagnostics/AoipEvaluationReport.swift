import Foundation

public enum AoipMode: String, Codable, Equatable, Sendable {
    case directUdpPcm
    case avb
    case tsn
    case aes67
    case ravenna
    case dante

    public var requiresPtpProfile: Bool {
        self != .directUdpPcm
    }
}

public enum AoipUsage: String, Codable, Equatable, Sendable {
    case deferred
    case interop
    case optionalFastestLocalMode
    case defaultReplacement
}

public struct AoipPtpProfile: Codable, Equatable, Sendable {
    public var version: String
    public var profile: String
    public var domain: String
    public var masterClockId: String
    public var lockState: String

    public init(
        version: String,
        profile: String,
        domain: String,
        masterClockId: String,
        lockState: String
    ) {
        self.version = version
        self.profile = profile
        self.domain = domain
        self.masterClockId = masterClockId
        self.lockState = lockState
    }
}

public struct AoipEndpointProfile: Codable, Equatable, Sendable {
    public var vendor: String
    public var model: String
    public var firmwareVersion: String
    public var profileName: String
    public var bufferFrames: Int

    public init(
        vendor: String,
        model: String,
        firmwareVersion: String,
        profileName: String,
        bufferFrames: Int
    ) {
        self.vendor = vendor
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.profileName = profileName
        self.bufferFrames = bufferFrames
    }
}

public struct AoipEndpointPair: Codable, Equatable, Sendable {
    public var sender: AoipEndpointProfile
    public var receiver: AoipEndpointProfile

    public init(sender: AoipEndpointProfile, receiver: AoipEndpointProfile) {
        self.sender = sender
        self.receiver = receiver
    }
}

public struct AoipSwitchProfile: Codable, Equatable, Sendable {
    public var model: String
    public var firmwareVersion: String
    public var linkRateMbps: Int
    public var trafficClass: String
    public var streamReservation: String
    public var schedule: String

    public init(
        model: String,
        firmwareVersion: String,
        linkRateMbps: Int,
        trafficClass: String,
        streamReservation: String,
        schedule: String
    ) {
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.linkRateMbps = linkRateMbps
        self.trafficClass = trafficClass
        self.streamReservation = streamReservation
        self.schedule = schedule
    }
}

public struct AoipProfileEvidence: Codable, Equatable, Sendable {
    public var standardsRead: [String]
    public var vendorProfilesRead: [String]

    public init(standardsRead: [String], vendorProfilesRead: [String]) {
        self.standardsRead = standardsRead
        self.vendorProfilesRead = vendorProfilesRead
    }
}

public struct AoipBaselineComparison: Codable, Equatable, Sendable {
    public var directUdpPcmRouteReportId: String
    public var directUdpPcmVerdict: MeasurementVerdict
    public var measuredOnSamePath: Bool
    public var directUdpPcmP99Microseconds: Double
    public var evaluatedModeP99Microseconds: Double?
    public var notes: String

    public init(
        directUdpPcmRouteReportId: String,
        directUdpPcmVerdict: MeasurementVerdict,
        measuredOnSamePath: Bool,
        directUdpPcmP99Microseconds: Double,
        evaluatedModeP99Microseconds: Double?,
        notes: String
    ) {
        self.directUdpPcmRouteReportId = directUdpPcmRouteReportId
        self.directUdpPcmVerdict = directUdpPcmVerdict
        self.measuredOnSamePath = measuredOnSamePath
        self.directUdpPcmP99Microseconds = directUdpPcmP99Microseconds
        self.evaluatedModeP99Microseconds = evaluatedModeP99Microseconds
        self.notes = notes
    }
}

public struct AoipStressReport: Codable, Equatable, Sendable {
    public var measured: Bool
    public var competingTrafficProfile: String
    public var packetAge: UdpPcmPacketAgeMetrics
    public var packetLoss: Int
    public var recoveryBehavior: String
    public var notes: String

    public init(
        measured: Bool,
        competingTrafficProfile: String,
        packetAge: UdpPcmPacketAgeMetrics,
        packetLoss: Int,
        recoveryBehavior: String,
        notes: String
    ) {
        self.measured = measured
        self.competingTrafficProfile = competingTrafficProfile
        self.packetAge = packetAge
        self.packetLoss = packetLoss
        self.recoveryBehavior = recoveryBehavior
        self.notes = notes
    }
}

public enum AoipEvaluationValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedPacketAge
    case missingPtpField(String)
    case passWithoutLockedPtp
    case passWithoutSamePathBaseline
    case passWithoutMeasuredStress
    case passWithoutEvaluatedModeMetric
    case passWithoutMeasuredSuperiority(
        evaluatedP99Microseconds: Double,
        baselineP99Microseconds: Double
    )
    case defaultReplacementNotAllowed
    case passWithNonPassBaseline(MeasurementVerdict)
    case passWithUndocumentedSwitchProfile(String)
    case passWithUnknownEndpointBuffer(String)
}

public struct AoipEvaluationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var mode: AoipMode
    public var usage: AoipUsage
    public var route: RouteIdentity
    public var ptp: AoipPtpProfile
    public var switchProfile: AoipSwitchProfile
    public var endpoint: AoipEndpointPair
    public var profileEvidence: AoipProfileEvidence
    public var baselineComparison: AoipBaselineComparison
    public var stress: AoipStressReport
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        mode: AoipMode,
        usage: AoipUsage,
        route: RouteIdentity,
        ptp: AoipPtpProfile,
        switchProfile: AoipSwitchProfile,
        endpoint: AoipEndpointPair,
        profileEvidence: AoipProfileEvidence,
        baselineComparison: AoipBaselineComparison,
        stress: AoipStressReport,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.mode = mode
        self.usage = usage
        self.route = route
        self.ptp = ptp
        self.switchProfile = switchProfile
        self.endpoint = endpoint
        self.profileEvidence = profileEvidence
        self.baselineComparison = baselineComparison
        self.stress = stress
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> AoipEvaluationReport {
        try JSONDecoder().decode(AoipEvaluationReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validatePtp()
        try validateSwitch()
        try validateEndpoint(endpoint.sender, "endpoint.sender")
        try validateEndpoint(endpoint.receiver, "endpoint.receiver")
        try validateProfileEvidence()
        try validateBaselineComparison()
        try validateStress()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireAoipNonEmpty(id, "id")
        try requireAoipNonEmpty(title, "title")
        try requireAoipNonEmpty(capturedAt, "capturedAt")
        try requireAoipNonEmpty(route.label, "route.label")
        try requireAoipNonEmpty(route.topology, "route.topology")
        try requireAoipNonEmpty(notes, "notes")
    }

    private func validatePtp() throws {
        guard mode.requiresPtpProfile else {
            return
        }
        try requirePtpNonEmpty(ptp.version, "ptp.version")
        try requirePtpNonEmpty(ptp.profile, "ptp.profile")
        try requirePtpNonEmpty(ptp.domain, "ptp.domain")
        try requirePtpNonEmpty(ptp.masterClockId, "ptp.masterClockId")
        try requirePtpNonEmpty(ptp.lockState, "ptp.lockState")
    }

    private func validateSwitch() throws {
        try requireAoipNonEmpty(switchProfile.model, "switchProfile.model")
        try requireAoipNonEmpty(switchProfile.firmwareVersion, "switchProfile.firmwareVersion")
        try requireAoipNonNegative(switchProfile.linkRateMbps, "switchProfile.linkRateMbps")
        try requireAoipNonEmpty(switchProfile.trafficClass, "switchProfile.trafficClass")
        try requireAoipNonEmpty(switchProfile.streamReservation, "switchProfile.streamReservation")
        try requireAoipNonEmpty(switchProfile.schedule, "switchProfile.schedule")
    }

    private func validateEndpoint(_ endpoint: AoipEndpointProfile, _ prefix: String) throws {
        try requireAoipNonEmpty(endpoint.vendor, "\(prefix).vendor")
        try requireAoipNonEmpty(endpoint.model, "\(prefix).model")
        try requireAoipNonEmpty(endpoint.firmwareVersion, "\(prefix).firmwareVersion")
        try requireAoipNonEmpty(endpoint.profileName, "\(prefix).profileName")
        try requireAoipNonNegative(endpoint.bufferFrames, "\(prefix).bufferFrames")
    }

    private func validateProfileEvidence() throws {
        try requireAoipList(profileEvidence.standardsRead, "profileEvidence.standardsRead")
        try requireAoipList(profileEvidence.vendorProfilesRead, "profileEvidence.vendorProfilesRead")
    }

    private func validateBaselineComparison() throws {
        try requireAoipNonEmpty(
            baselineComparison.directUdpPcmRouteReportId,
            "baselineComparison.directUdpPcmRouteReportId"
        )
        try requireAoipNonNegative(
            baselineComparison.directUdpPcmP99Microseconds,
            "baselineComparison.directUdpPcmP99Microseconds"
        )
        if let evaluated = baselineComparison.evaluatedModeP99Microseconds {
            try requireAoipNonNegative(
                evaluated,
                "baselineComparison.evaluatedModeP99Microseconds"
            )
        }
        try requireAoipNonEmpty(baselineComparison.notes, "baselineComparison.notes")
    }

    private func validateStress() throws {
        try requireAoipNonEmpty(stress.competingTrafficProfile, "stress.competingTrafficProfile")
        try requireAoipNonEmpty(stress.recoveryBehavior, "stress.recoveryBehavior")
        try requireAoipNonEmpty(stress.notes, "stress.notes")
        try requireAoipNonNegative(stress.packetLoss, "stress.packetLoss")
        try requirePacketAge(stress.packetAge)
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        if usage == .defaultReplacement {
            throw AoipEvaluationValidationError.defaultReplacementNotAllowed
        }
        guard baselineComparison.directUdpPcmVerdict == .pass else {
            throw AoipEvaluationValidationError.passWithNonPassBaseline(
                baselineComparison.directUdpPcmVerdict
            )
        }
        guard baselineComparison.measuredOnSamePath else {
            throw AoipEvaluationValidationError.passWithoutSamePathBaseline
        }
        guard stress.measured else {
            throw AoipEvaluationValidationError.passWithoutMeasuredStress
        }
        guard let evaluated = baselineComparison.evaluatedModeP99Microseconds else {
            throw AoipEvaluationValidationError.passWithoutEvaluatedModeMetric
        }
        if evaluated >= baselineComparison.directUdpPcmP99Microseconds {
            throw AoipEvaluationValidationError.passWithoutMeasuredSuperiority(
                evaluatedP99Microseconds: evaluated,
                baselineP99Microseconds: baselineComparison.directUdpPcmP99Microseconds
            )
        }

        try requireDocumentedPtpForPass()
        try requireDocumentedSwitchForPass()
        try requireDocumentedEndpointForPass(endpoint.sender, "endpoint.sender")
        try requireDocumentedEndpointForPass(endpoint.receiver, "endpoint.receiver")
    }

    private func requireDocumentedPtpForPass() throws {
        guard mode.requiresPtpProfile else {
            return
        }
        let fields = [
            ptp.version,
            ptp.profile,
            ptp.domain,
            ptp.masterClockId,
            ptp.lockState,
        ]
        if fields.contains(where: isUnknown) || ptp.lockState != "locked" {
            throw AoipEvaluationValidationError.passWithoutLockedPtp
        }
    }

    private func requireDocumentedSwitchForPass() throws {
        if switchProfile.linkRateMbps <= 0 {
            throw AoipEvaluationValidationError.passWithUndocumentedSwitchProfile(
                "switchProfile.linkRateMbps"
            )
        }
        let fields = [
            switchProfile.model,
            switchProfile.firmwareVersion,
            switchProfile.trafficClass,
            switchProfile.streamReservation,
            switchProfile.schedule,
        ]
        if fields.contains(where: isUnknown) {
            throw AoipEvaluationValidationError.passWithUndocumentedSwitchProfile(
                "switchProfile"
            )
        }
    }

    private func requireDocumentedEndpointForPass(
        _ endpoint: AoipEndpointProfile,
        _ prefix: String
    ) throws {
        let fields = [
            endpoint.vendor,
            endpoint.model,
            endpoint.firmwareVersion,
            endpoint.profileName,
        ]
        if fields.contains(where: isUnknown) || endpoint.bufferFrames <= 0 {
            throw AoipEvaluationValidationError.passWithUnknownEndpointBuffer(prefix)
        }
    }
}

public enum AoipSyntheticSmoke {
    public static func run() -> AoipEvaluationReport {
        AoipEvaluationReport(
            id: "m07-avb-synthetic-smoke",
            title: "Synthetic M07 AVB partial evaluation",
            capturedAt: "2026-05-02T00:00:00Z",
            mode: .avb,
            usage: .deferred,
            route: RouteIdentity(
                label: "synthetic-avb",
                topology: "deterministic-source-validation"
            ),
            ptp: AoipPtpProfile(
                version: "unknown",
                profile: "unknown",
                domain: "unknown",
                masterClockId: "unknown",
                lockState: "notTested"
            ),
            switchProfile: AoipSwitchProfile(
                model: "unknown",
                firmwareVersion: "unknown",
                linkRateMbps: 0,
                trafficClass: "unknown",
                streamReservation: "unknown",
                schedule: "unknown"
            ),
            endpoint: AoipEndpointPair(
                sender: AoipEndpointProfile(
                    vendor: "unknown",
                    model: "unknown",
                    firmwareVersion: "unknown",
                    profileName: "none",
                    bufferFrames: 0
                ),
                receiver: AoipEndpointProfile(
                    vendor: "unknown",
                    model: "unknown",
                    firmwareVersion: "unknown",
                    profileName: "none",
                    bufferFrames: 0
                )
            ),
            profileEvidence: AoipProfileEvidence(
                standardsRead: [
                    "IEEE 802.1 AVB family requirements pending full profile access",
                ],
                vendorProfilesRead: [
                    "none",
                ]
            ),
            baselineComparison: AoipBaselineComparison(
                directUdpPcmRouteReportId: "m05-direct-link-pass-fixture",
                directUdpPcmVerdict: .pass,
                measuredOnSamePath: false,
                directUdpPcmP99Microseconds: 240,
                evaluatedModeP99Microseconds: nil,
                notes: "Synthetic source-validation report; no AVB endpoint measurement."
            ),
            stress: AoipStressReport(
                measured: false,
                competingTrafficProfile: "not-run",
                packetAge: UdpPcmPacketAgeMetrics(
                    p50Microseconds: 0,
                    p95Microseconds: 0,
                    p99Microseconds: 0,
                    maxMicroseconds: 0
                ),
                packetLoss: 0,
                recoveryBehavior: "not-tested",
                notes: "No WCRT-style stress case was run."
            ),
            verdict: .partial,
            notes: "Synthetic source validation only; real M07 requires AoIP hardware, PTP, and WCRT evidence."
        )
    }
}

private func requireAoipNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw AoipEvaluationValidationError.emptyField(field)
    }
}

private func requirePtpNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw AoipEvaluationValidationError.missingPtpField(field)
    }
}

private func requireAoipList(_ values: [String], _ field: String) throws {
    guard !values.isEmpty else {
        throw AoipEvaluationValidationError.emptyList(field)
    }
    for value in values {
        try requireAoipNonEmpty(value, field)
    }
}

private func requireAoipNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw AoipEvaluationValidationError.negativeField(field)
    }
}

private func requireAoipNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw AoipEvaluationValidationError.negativeField(field)
    }
    try requireAoipFinite(value, field)
}

private func requireAoipFinite(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw AoipEvaluationValidationError.nonFiniteField(field)
    }
}

private func requirePacketAge(_ packetAge: UdpPcmPacketAgeMetrics) throws {
    try requireAoipNonNegative(packetAge.p50Microseconds, "stress.packetAge.p50Microseconds")
    try requireAoipNonNegative(packetAge.p95Microseconds, "stress.packetAge.p95Microseconds")
    try requireAoipNonNegative(packetAge.p99Microseconds, "stress.packetAge.p99Microseconds")
    try requireAoipNonNegative(packetAge.maxMicroseconds, "stress.packetAge.maxMicroseconds")

    guard packetAge.p50Microseconds <= packetAge.p95Microseconds,
          packetAge.p95Microseconds <= packetAge.p99Microseconds,
          packetAge.p99Microseconds <= packetAge.maxMicroseconds else {
        throw AoipEvaluationValidationError.unorderedPacketAge
    }
}

private func isUnknown(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [],
        exactly: ["unknown", "none", "not-tested", "notrun", "not-run"],
        emptyIsPlaceholder: false
    )
}
