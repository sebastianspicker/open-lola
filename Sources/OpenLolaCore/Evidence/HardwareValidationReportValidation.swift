// Validates HardwareValidationReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension HardwareValidationReport {
    public func validate() throws {
        try validateShape()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validateShape() throws {
        try HardwareValidationValidator.requireNonEmpty(id, "id")
        try HardwareValidationValidator.requireNonEmpty(title, "title")
        try HardwareValidationValidator.requireNonEmpty(capturedAt, "capturedAt")
        try HardwareValidationValidator.requireISO8601Date(capturedAt, "capturedAt")
        try HardwareValidationValidator.requireNonEmpty(notes, "notes")
        try validateHardwareIdentity()
        try validateEvidenceRows()
        try validateRoutes()
        try validateFieldRun()
        try validatePassPlaceholderFields()
    }

    private func validateHardwareIdentity() throws {
        for field in hardwareFields() {
            try HardwareValidationValidator.requireNonEmpty(field.value, field.name)
        }
    }

    private func validateEvidenceRows() throws {
        try HardwareValidationValidator.requireNonEmpty(evidence, "evidence")
        var seen: Set<HardwareValidationLane> = []
        for row in evidence {
            guard seen.insert(row.lane).inserted else {
                throw HardwareValidationValidationError.duplicateEvidenceLane(row.lane)
            }
            try HardwareValidationValidator.requireNonEmpty(row.reportId, "evidence[\(row.lane.rawValue)].reportId")
            try HardwareValidationValidator.requireNonEmpty(row.notes, "evidence[\(row.lane.rawValue)].notes")
        }
        for lane in HardwareValidationLane.allCases where !seen.contains(lane) {
            throw HardwareValidationValidationError.missingEvidenceLane(lane)
        }
    }

    private func validateRoutes() throws {
        try HardwareValidationValidator.requireNonEmpty(routes, "routes")
        var seen: Set<UdpPcmRouteKind> = []
        for route in routes {
            guard seen.insert(route.kind).inserted else {
                throw HardwareValidationValidationError.duplicateRoute(route.kind)
            }
            try HardwareValidationValidator.requireNonEmpty(route.label, "routes[\(route.kind.rawValue)].label")
            try HardwareValidationValidator.requireNonEmpty(route.reportId, "routes[\(route.kind.rawValue)].reportId")
            try HardwareValidationValidator.requireNonEmpty(
                route.routeDescription,
                "routes[\(route.kind.rawValue)].routeDescription"
            )
            try HardwareValidationValidator.requireNonEmpty(
                route.packetCapturePoint,
                "routes[\(route.kind.rawValue)].packetCapturePoint"
            )
            try HardwareValidationValidator.requireNonEmpty(
                route.packetCaptureInterface,
                "routes[\(route.kind.rawValue)].packetCaptureInterface"
            )
            try HardwareValidationValidator.requireNonEmpty(
                route.venueConstraints,
                "routes[\(route.kind.rawValue)].venueConstraints"
            )
        }
        for route in requiredHardwareValidationRoutes() where !seen.contains(route) {
            throw HardwareValidationValidationError.missingRoute(route)
        }
    }

    private func validateFieldRun() throws {
        try HardwareValidationValidator.requireNonEmpty(fieldRun.reportId, "fieldRun.reportId")
        try HardwareValidationValidator.requireNonEmpty(fieldRun.operatorNotes, "fieldRun.operatorNotes")
        try HardwareValidationValidator.requireNonEmpty(fieldRun.routeLabels, "fieldRun.routeLabels")
        if fieldRun.durationSeconds < 0 {
            throw HardwareValidationValidationError.negativeField("fieldRun.durationSeconds")
        }
        for (index, label) in fieldRun.routeLabels.enumerated() {
            try HardwareValidationValidator.requireNonEmpty(label, "fieldRun.routeLabels[\(index)]")
        }
        let routeLabels = Set(routes.map(\.label))
        for label in fieldRun.routeLabels where !routeLabels.contains(label) {
            throw HardwareValidationValidationError.fieldRunRouteLabelWithoutRoute(label)
        }
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw HardwareValidationValidationError.passWithoutMeasuredRun
        }
        try validatePassEvidenceRows()
        try validatePassRoutes()
        try validatePassFieldRun()
        try validatePassHardwareIdentity()
    }

    private func validatePassPlaceholderFields() throws {
        guard verdict == .pass else {
            return
        }
        for field in placeholderSensitiveFields() where isHardwareValidationPlaceholder(field.value) {
            throw HardwareValidationValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func validatePassEvidenceRows() throws {
        for row in evidence {
            guard row.verdict == .pass else {
                throw HardwareValidationValidationError.passWithNonPassEvidence(row.lane, row.verdict)
            }
            guard row.measured else {
                throw HardwareValidationValidationError.passWithoutMeasuredEvidence(row.lane)
            }
            guard row.physicalEvidence else {
                throw HardwareValidationValidationError.passWithoutPhysicalEvidence(row.lane)
            }
            guard !row.synthetic else {
                throw HardwareValidationValidationError.passWithSyntheticEvidence(row.lane)
            }
        }
    }

    private func validatePassRoutes() throws {
        for route in routes {
            guard route.verdict == .pass else {
                throw HardwareValidationValidationError.passWithNonPassRoute(route.kind, route.verdict)
            }
            guard route.measured else {
                throw HardwareValidationValidationError.passWithoutMeasuredRoute(route.kind)
            }
            guard route.dscpClassification != .notTested else {
                throw HardwareValidationValidationError.passWithoutDscpClassification(route.kind)
            }
            guard route.dscpClassification != .harmful else {
                throw HardwareValidationValidationError.passWithHarmfulDscp(route.kind)
            }
        }
    }

    private func validatePassFieldRun() throws {
        try VerdictValidationPolicy.passRequires(
            fieldRun.durationSeconds + Self.minimumPassDurationToleranceSeconds >= Self.minimumPassDurationSeconds,
            HardwareValidationValidationError.passRunTooShort(
                seconds: fieldRun.durationSeconds,
                minimumSeconds: Self.minimumPassDurationSeconds
            )
        )
        guard fieldRun.fieldEvidenceSeparated else {
            throw HardwareValidationValidationError.passWithoutSeparatedFieldEvidence
        }
        guard fieldRun.fastestProfileWithinAcceptedLatency else {
            throw HardwareValidationValidationError.passWithoutFastestProfileLatencyAcceptance
        }
        guard !fieldRun.syntheticEvidenceUsedForPass else {
            throw HardwareValidationValidationError.passUsesSyntheticEvidence
        }
        guard fieldRun.machineReadableVerdict else {
            throw HardwareValidationValidationError.passWithoutMachineReadableVerdict
        }
    }

    private func validatePassHardwareIdentity() throws {
        let rmeTokens = hardwareIdentityTokens(hardware.rmeInterfaceModel)
        guard rmeTokens.contains("rme"),
              rmeTokens.contains("madi") || rmeTokens.contains("madiface") else {
            throw HardwareValidationValidationError.passWithoutRmeMadiIdentity
        }

        let videoTokens = hardwareIdentityTokens(
            [hardware.blackmagicModel, hardware.atemModel].joined(separator: " ")
        )
        let atemTokens = hardwareIdentityTokens(hardware.atemModel)
        let hasBlackmagicTarget = ["blackmagic", "decklink", "ultrastudio"].contains { videoTokens.contains($0) }
        guard hasBlackmagicTarget, atemTokens.contains("atem") else {
            throw HardwareValidationValidationError.passWithoutBlackmagicAtemIdentity
        }
    }

    private func placeholderSensitiveFields() -> [PlaceholderSensitiveField] {
        var fields = hardwareFields()
        fields.append(contentsOf: placeholderFields(
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("fieldRun.reportId", fieldRun.reportId),
            ("fieldRun.operatorNotes", fieldRun.operatorNotes),
            ("notes", notes)
        ))
        fields.append(contentsOf: placeholderFields(
            evidence,
            prefix: { _, row in "evidence[\(row.lane.rawValue)]" },
            [
                ("reportId", \.reportId),
                ("notes", \.notes)
            ]
        ))
        fields.append(contentsOf: placeholderFields(
            routes,
            prefix: { _, route in "routes[\(route.kind.rawValue)]" },
            [
                ("label", \.label),
                ("reportId", \.reportId),
                ("routeDescription", \.routeDescription),
                ("packetCapturePoint", \.packetCapturePoint),
                ("packetCaptureInterface", \.packetCaptureInterface),
                ("venueConstraints", \.venueConstraints)
            ]
        ))
        fields.append(contentsOf: placeholderIndexedFields(
            fieldRun.routeLabels,
            prefix: "fieldRun.routeLabels"
        ))
        return fields
    }

    private func hardwareFields() -> [PlaceholderSensitiveField] {
        placeholderFields(
            ("hardware.referenceRigReportId", hardware.referenceRigReportId),
            ("hardware.macOSVersion", hardware.macOSVersion),
            ("hardware.rmeInterfaceModel", hardware.rmeInterfaceModel),
            ("hardware.rmeDriverVersion", hardware.rmeDriverVersion),
            ("hardware.rmeFirmwareVersion", hardware.rmeFirmwareVersion),
            ("hardware.rmeCoreAudioInputUID", hardware.rmeCoreAudioInputUID),
            ("hardware.rmeCoreAudioOutputUID", hardware.rmeCoreAudioOutputUID),
            ("hardware.blackmagicModel", hardware.blackmagicModel),
            ("hardware.atemModel", hardware.atemModel),
            ("hardware.atemFirmwareVersion", hardware.atemFirmwareVersion),
            ("hardware.lightingBridge", hardware.lightingBridge),
            ("hardware.cablingArtifact", hardware.cablingArtifact),
            ("hardware.firmwareSnapshotArtifact", hardware.firmwareSnapshotArtifact)
        )
    }
}

private func hardwareIdentityTokens(_ value: String) -> Set<String> {
    Set(value
        .lowercased()
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init))
}

private func requiredHardwareValidationRoutes() -> [UdpPcmRouteKind] {
    UdpPcmRouteKind.allCases.filter(\.requiresHardwareValidation)
}

private func isHardwareValidationPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matchesPhysicalEvidencePlaceholder(value)
}
