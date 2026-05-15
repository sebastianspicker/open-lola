import Foundation

public typealias HardwareValidationRunMode = MeasurementMethodology

public enum HardwareValidationLane: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case referenceRig
    case rmeFastestAudio
    case videoPath
    case atemReadOnlyControl
    case lightingControlBridge
    case integratedProfile
    case fieldRun
}

public struct HardwareValidationHardwareIdentity: Codable, Equatable, Sendable {
    public var referenceRigReportId: String
    public var macOSVersion: String
    public var rmeInterfaceModel: String
    public var rmeDriverVersion: String
    public var rmeFirmwareVersion: String
    public var rmeCoreAudioInputUID: String
    public var rmeCoreAudioOutputUID: String
    public var blackmagicModel: String
    public var atemModel: String
    public var atemFirmwareVersion: String
    public var lightingBridge: String
    public var cablingArtifact: String
    public var firmwareSnapshotArtifact: String

    public init(
        referenceRigReportId: String,
        macOSVersion: String,
        rmeInterfaceModel: String,
        rmeDriverVersion: String,
        rmeFirmwareVersion: String,
        rmeCoreAudioInputUID: String,
        rmeCoreAudioOutputUID: String,
        blackmagicModel: String,
        atemModel: String,
        atemFirmwareVersion: String,
        lightingBridge: String,
        cablingArtifact: String,
        firmwareSnapshotArtifact: String
    ) {
        self.referenceRigReportId = referenceRigReportId
        self.macOSVersion = macOSVersion
        self.rmeInterfaceModel = rmeInterfaceModel
        self.rmeDriverVersion = rmeDriverVersion
        self.rmeFirmwareVersion = rmeFirmwareVersion
        self.rmeCoreAudioInputUID = rmeCoreAudioInputUID
        self.rmeCoreAudioOutputUID = rmeCoreAudioOutputUID
        self.blackmagicModel = blackmagicModel
        self.atemModel = atemModel
        self.atemFirmwareVersion = atemFirmwareVersion
        self.lightingBridge = lightingBridge
        self.cablingArtifact = cablingArtifact
        self.firmwareSnapshotArtifact = firmwareSnapshotArtifact
    }
}

public struct HardwareValidationEvidence: Codable, Equatable, Sendable {
    public var lane: HardwareValidationLane
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalEvidence: Bool
    public var synthetic: Bool
    public var notes: String

    public init(
        lane: HardwareValidationLane,
        reportId: String,
        verdict: MeasurementVerdict,
        measured: Bool,
        physicalEvidence: Bool,
        synthetic: Bool,
        notes: String
    ) {
        self.lane = lane
        self.reportId = reportId
        self.verdict = verdict
        self.measured = measured
        self.physicalEvidence = physicalEvidence
        self.synthetic = synthetic
        self.notes = notes
    }
}

public struct HardwareValidationRouteEvidence: Codable, Equatable, Sendable {
    public var kind: UdpPcmRouteKind
    public var label: String
    public var reportId: String
    public var routeDescription: String
    public var packetCapturePoint: String
    public var packetCaptureInterface: String
    public var dscpClassification: UdpPcmDscpClassification
    public var venueConstraints: String
    public var measured: Bool
    public var verdict: MeasurementVerdict

    public init(
        kind: UdpPcmRouteKind,
        label: String,
        reportId: String,
        routeDescription: String,
        packetCapturePoint: String,
        packetCaptureInterface: String,
        dscpClassification: UdpPcmDscpClassification,
        venueConstraints: String,
        measured: Bool,
        verdict: MeasurementVerdict
    ) {
        self.kind = kind
        self.label = label
        self.reportId = reportId
        self.routeDescription = routeDescription
        self.packetCapturePoint = packetCapturePoint
        self.packetCaptureInterface = packetCaptureInterface
        self.dscpClassification = dscpClassification
        self.venueConstraints = venueConstraints
        self.measured = measured
        self.verdict = verdict
    }
}

public struct HardwareValidationFieldRunEvidence: Codable, Equatable, Sendable {
    public var reportId: String
    public var durationSeconds: Double
    public var routeLabels: [String]
    public var fieldEvidenceSeparated: Bool
    public var fastestProfileWithinAcceptedLatency: Bool
    public var syntheticEvidenceUsedForPass: Bool
    public var machineReadableVerdict: Bool
    public var operatorNotes: String

    public init(
        reportId: String,
        durationSeconds: Double,
        routeLabels: [String],
        fieldEvidenceSeparated: Bool,
        fastestProfileWithinAcceptedLatency: Bool,
        syntheticEvidenceUsedForPass: Bool,
        machineReadableVerdict: Bool,
        operatorNotes: String
    ) {
        self.reportId = reportId
        self.durationSeconds = durationSeconds
        self.routeLabels = routeLabels
        self.fieldEvidenceSeparated = fieldEvidenceSeparated
        self.fastestProfileWithinAcceptedLatency = fastestProfileWithinAcceptedLatency
        self.syntheticEvidenceUsedForPass = syntheticEvidenceUsedForPass
        self.machineReadableVerdict = machineReadableVerdict
        self.operatorNotes = operatorNotes
    }
}

public enum HardwareValidationValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNegativeFieldError,
    ValidationNonPositiveFieldError {
    case emptyField(String)
    case emptyList(String)
    case negativeField(String)
    case nonPositiveField(String)
    case duplicateEvidenceLane(HardwareValidationLane)
    case missingEvidenceLane(HardwareValidationLane)
    case duplicateRoute(UdpPcmRouteKind)
    case missingRoute(UdpPcmRouteKind)
    case passWithoutMeasuredRun
    case passWithNonPassEvidence(HardwareValidationLane, MeasurementVerdict)
    case passWithoutMeasuredEvidence(HardwareValidationLane)
    case passWithoutPhysicalEvidence(HardwareValidationLane)
    case passWithSyntheticEvidence(HardwareValidationLane)
    case passWithNonPassRoute(UdpPcmRouteKind, MeasurementVerdict)
    case passWithoutMeasuredRoute(UdpPcmRouteKind)
    case passWithoutDscpClassification(UdpPcmRouteKind)
    case passWithHarmfulDscp(UdpPcmRouteKind)
    case passRunTooShort(seconds: Double, minimumSeconds: Double)
    case passWithoutSeparatedFieldEvidence
    case passWithoutFastestProfileLatencyAcceptance
    case passUsesSyntheticEvidence
    case passWithoutMachineReadableVerdict
    case passWithPlaceholderField(String)
    case fieldRunRouteLabelWithoutRoute(String)
    case passWithoutRmeMadiIdentity
    case passWithoutBlackmagicAtemIdentity
}

enum HardwareValidationValidator: ReportPrimitiveValidating {
    typealias ValidationError = HardwareValidationValidationError
}

public struct HardwareValidationReport: ReportMetadataArtifact, PrettyJSONCodable, Equatable, Sendable {
    public static let minimumPassDurationSeconds = VerdictValidationPolicy.hardwareValidationMinimumPassDurationSeconds
    static let minimumPassDurationToleranceSeconds = 0.001

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: HardwareValidationRunMode
    public var hardware: HardwareValidationHardwareIdentity
    public var evidence: [HardwareValidationEvidence]
    public var routes: [HardwareValidationRouteEvidence]
    public var fieldRun: HardwareValidationFieldRunEvidence
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: HardwareValidationRunMode,
        hardware: HardwareValidationHardwareIdentity,
        evidence: [HardwareValidationEvidence],
        routes: [HardwareValidationRouteEvidence],
        fieldRun: HardwareValidationFieldRunEvidence,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.hardware = hardware
        self.evidence = evidence
        self.routes = routes
        self.fieldRun = fieldRun
        self.verdict = verdict
        self.notes = notes
    }

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
                ("notes", \.notes),
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
                ("venueConstraints", \.venueConstraints),
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
