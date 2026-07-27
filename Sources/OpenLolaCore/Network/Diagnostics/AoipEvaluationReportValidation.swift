// Validates AoipEvaluationReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension AoipEvaluationReport {
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
            ptp.lockState
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
            switchProfile.schedule
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
            endpoint.profileName
        ]
        if fields.contains(where: isUnknown) || endpoint.bufferFrames <= 0 {
            throw AoipEvaluationValidationError.passWithUnknownEndpointBuffer(prefix)
        }
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
