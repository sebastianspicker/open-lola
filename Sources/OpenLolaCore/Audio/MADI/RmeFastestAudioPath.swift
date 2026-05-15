import Foundation

public enum RmeMadiDriverMode: String, Codable, Equatable, Sendable {
    case driverKit
    case kernelExtension
    case classCompliant
    case unknown
}

public struct RmeMadiDriverEvidence: Codable, Equatable, Sendable {
    public var driverPackage: String
    public var driverVersion: String
    public var firmwareVersion: String
    public var driverMode: RmeMadiDriverMode
    public var totalMixVersion: String
    public var totalMixSnapshot: String
    public var clockSource: String
    public var sampleRateSource: String
    public var sampleRateConversion: SampleRateConversionState
    public var routingNotes: String

    public init(
        driverPackage: String,
        driverVersion: String,
        firmwareVersion: String,
        driverMode: RmeMadiDriverMode,
        totalMixVersion: String,
        totalMixSnapshot: String,
        clockSource: String,
        sampleRateSource: String,
        sampleRateConversion: SampleRateConversionState,
        routingNotes: String
    ) {
        self.driverPackage = driverPackage
        self.driverVersion = driverVersion
        self.firmwareVersion = firmwareVersion
        self.driverMode = driverMode
        self.totalMixVersion = totalMixVersion
        self.totalMixSnapshot = totalMixSnapshot
        self.clockSource = clockSource
        self.sampleRateSource = sampleRateSource
        self.sampleRateConversion = sampleRateConversion
        self.routingNotes = routingNotes
    }
}

public enum RmeFastestAudioPathValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case missingRequiredSampleRate(Int)
    case missingRequiredFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case passWithPlaceholderField(String)
    case passWithoutRmeMadiDevice
    case passWithoutFullDuplexRmeDevice
    case passWithoutConcreteDriverMode
    case passWithoutDedicatedRmeDriver
    case passWithAggregateDevice
    case passWithAggregateRouting(String)
    case passWithSampleRateConversion(SampleRateConversionState)
    case passWithoutClockDomain
    case passSelectedSampleRateOutsideInventoryRanges(Int)
    case passSelectedBufferFramesOutsideInventoryCandidates(Int)
    case passSelectedChannelCountExceedsDeviceChannels(
        channelCount: Int,
        inputChannels: Int,
        outputChannels: Int
    )
    case passWithoutThunderboltRmePath
    case passWithoutLoopbackPass
    case passWithoutMatchingLoopbackDeviceUID
    case passWithoutSupportedSampleRate(Int)
    case passWithoutAcceptedStableMode(sampleRateHertz: Int)
    case passSelectedModeIsNotFastestStable(selected: AudioMode, fastest: AudioMode)
}

public struct RmeFastestAudioPathReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var inventoryCapturedAt: String
    public var inventoryHostName: String
    public var rmeDevice: CoreAudioDeviceInventory
    public var driverEvidence: RmeMadiDriverEvidence
    public var loopbackReport: EndpointLoopbackReport
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        inventoryCapturedAt: String,
        inventoryHostName: String,
        rmeDevice: CoreAudioDeviceInventory,
        driverEvidence: RmeMadiDriverEvidence,
        loopbackReport: EndpointLoopbackReport,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.inventoryCapturedAt = inventoryCapturedAt
        self.inventoryHostName = inventoryHostName
        self.rmeDevice = rmeDevice
        self.driverEvidence = driverEvidence
        self.loopbackReport = loopbackReport
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> RmeFastestAudioPathReport {
        try JSONDecoder().decode(RmeFastestAudioPathReport.self, from: data)
    }

    public var fastestStableMode: AudioMode? {
        stableAcceptedModesWithLoopback()
            .min { lhs, rhs in
                let leftLatency = lhs.result.loopback?.correctedOneWayMilliseconds ?? .infinity
                let rightLatency = rhs.result.loopback?.correctedOneWayMilliseconds ?? .infinity
                if leftLatency == rightLatency {
                    return lhs.result.mode.framesPerBuffer < rhs.result.mode.framesPerBuffer
                }
                return leftLatency < rightLatency
            }?
            .result.mode
    }

    public func validate() throws {
        try validateIdentity()
        try validateDeviceInventoryShape()
        try validateDriverEvidenceShape()
        try validateLoopbackMatrixShape()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireRmeFastestNonEmpty(id, "id")
        try requireRmeFastestNonEmpty(title, "title")
        try requireRmeFastestNonEmpty(capturedAt, "capturedAt")
        try requireRmeFastestNonEmpty(inventoryCapturedAt, "inventoryCapturedAt")
        try requireRmeFastestNonEmpty(inventoryHostName, "inventoryHostName")
        try requireRmeFastestNonEmpty(notes, "notes")
    }

    private func validateDeviceInventoryShape() throws {
        try requireRmeFastestPositive(Int(rmeDevice.id), "rmeDevice.id")
        try requireRmeFastestNonEmpty(rmeDevice.name, "rmeDevice.name")
        try requireRmeFastestNonEmpty(rmeDevice.uid, "rmeDevice.uid")
        try requireRmeFastestPositive(rmeDevice.inputChannelCount, "rmeDevice.inputChannelCount")
        try requireRmeFastestPositive(rmeDevice.outputChannelCount, "rmeDevice.outputChannelCount")
        try requireRmeFastestPositive(rmeDevice.inputStreamCount, "rmeDevice.inputStreamCount")
        try requireRmeFastestPositive(rmeDevice.outputStreamCount, "rmeDevice.outputStreamCount")
    }

    private func validateDriverEvidenceShape() throws {
        try requireRmeFastestNonEmpty(driverEvidence.driverPackage, "driverEvidence.driverPackage")
        try requireRmeFastestNonEmpty(driverEvidence.driverVersion, "driverEvidence.driverVersion")
        try requireRmeFastestNonEmpty(driverEvidence.firmwareVersion, "driverEvidence.firmwareVersion")
        try requireRmeFastestNonEmpty(driverEvidence.totalMixVersion, "driverEvidence.totalMixVersion")
        try requireRmeFastestNonEmpty(driverEvidence.totalMixSnapshot, "driverEvidence.totalMixSnapshot")
        try requireRmeFastestNonEmpty(driverEvidence.clockSource, "driverEvidence.clockSource")
        try requireRmeFastestNonEmpty(driverEvidence.sampleRateSource, "driverEvidence.sampleRateSource")
        try requireRmeFastestNonEmpty(driverEvidence.routingNotes, "driverEvidence.routingNotes")
    }

    private func validateLoopbackMatrixShape() throws {
        for sampleRate in EndpointLoopbackReport.requiredSampleRates {
            guard let result = loopbackReport.sampleRates.first(where: {
                $0.sampleRateHertz == sampleRate
            }) else {
                throw RmeFastestAudioPathValidationError.missingRequiredSampleRate(sampleRate)
            }
            if result.supported {
                let frameSizes = Set(result.modeResults.map(\.mode.framesPerBuffer))
                for frameSize in EndpointLoopbackReport.requiredFrameSizes
                    where !frameSizes.contains(frameSize) {
                    throw RmeFastestAudioPathValidationError.missingRequiredFrameSize(
                        sampleRateHertz: sampleRate,
                        framesPerBuffer: frameSize
                    )
                }
            }
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }

        try loopbackReport.validate()

        guard loopbackReport.verdict == .pass else {
            throw RmeFastestAudioPathValidationError.passWithoutLoopbackPass
        }
        guard isRmeMadiDevice(rmeDevice), isRmeMadiLoopback(loopbackReport) else {
            throw RmeFastestAudioPathValidationError.passWithoutRmeMadiDevice
        }
        guard rmeDevice.inputChannelCount > 0, rmeDevice.outputChannelCount > 0 else {
            throw RmeFastestAudioPathValidationError.passWithoutFullDuplexRmeDevice
        }
        guard driverEvidence.driverMode != .unknown else {
            throw RmeFastestAudioPathValidationError.passWithoutConcreteDriverMode
        }
        guard driverEvidence.driverMode != .classCompliant else {
            throw RmeFastestAudioPathValidationError.passWithoutDedicatedRmeDriver
        }
        guard !rmeDevice.isAggregate else {
            throw RmeFastestAudioPathValidationError.passWithAggregateDevice
        }
        if let aggregateRoute = aggregateRoutingEvidence() {
            throw RmeFastestAudioPathValidationError.passWithAggregateRouting(aggregateRoute)
        }
        guard driverEvidence.sampleRateConversion == .absent else {
            throw RmeFastestAudioPathValidationError.passWithSampleRateConversion(
                driverEvidence.sampleRateConversion
            )
        }
        guard rmeDevice.clockDomain != nil else {
            throw RmeFastestAudioPathValidationError.passWithoutClockDomain
        }
        guard isThunderboltPerformancePath(thunderboltEvidenceFields()) else {
            throw RmeFastestAudioPathValidationError.passWithoutThunderboltRmePath
        }
        guard rmeDevice.uid == loopbackReport.device.uid else {
            throw RmeFastestAudioPathValidationError.passWithoutMatchingLoopbackDeviceUID
        }
        guard supportsSampleRate(
            rmeDevice,
            loopbackReport.selectedMode.sampleRateHertz
        ) else {
            throw RmeFastestAudioPathValidationError
                .passSelectedSampleRateOutsideInventoryRanges(
                    loopbackReport.selectedMode.sampleRateHertz
                )
        }
        guard rmeDevice.candidateBufferFrames.inReportedRange.contains(
            loopbackReport.selectedMode.framesPerBuffer
        ) else {
            throw RmeFastestAudioPathValidationError
                .passSelectedBufferFramesOutsideInventoryCandidates(
                    loopbackReport.selectedMode.framesPerBuffer
                )
        }
        let availableInputChannels = min(
            rmeDevice.inputChannelCount,
            rmeDevice.inputChannelLayout.totalChannelCount
        )
        let availableOutputChannels = min(
            rmeDevice.outputChannelCount,
            rmeDevice.outputChannelLayout.totalChannelCount
        )
        let minimumDeviceChannels = min(availableInputChannels, availableOutputChannels)
        guard loopbackReport.selectedMode.channelCount <= minimumDeviceChannels else {
            throw RmeFastestAudioPathValidationError
                .passSelectedChannelCountExceedsDeviceChannels(
                    channelCount: loopbackReport.selectedMode.channelCount,
                    inputChannels: availableInputChannels,
                    outputChannels: availableOutputChannels
                )
        }

        for field in placeholderSensitiveTextFields() where isRmeFastestPlaceholder(field.value) {
            throw RmeFastestAudioPathValidationError.passWithPlaceholderField(field.name)
        }

        for sampleRate in requiredStableSampleRatesForPass() {
            try requireSupportedStableSampleRate(sampleRate)
        }

        guard let fastestStableMode else {
            throw RmeFastestAudioPathValidationError.passWithoutAcceptedStableMode(
                sampleRateHertz: loopbackReport.selectedMode.sampleRateHertz
            )
        }
        guard fastestStableMode == loopbackReport.selectedMode else {
            throw RmeFastestAudioPathValidationError.passSelectedModeIsNotFastestStable(
                selected: loopbackReport.selectedMode,
                fastest: fastestStableMode
            )
        }
    }

    private func requireSupportedStableSampleRate(_ sampleRateHertz: Int) throws {
        guard let sampleRate = loopbackReport.sampleRates.first(where: {
            $0.sampleRateHertz == sampleRateHertz
        }), sampleRate.supported else {
            throw RmeFastestAudioPathValidationError.passWithoutSupportedSampleRate(sampleRateHertz)
        }

        let hasStableAcceptedMode = sampleRate.modeResults.contains { result in
            result.accepted && result.stable && result.loopback?.hiddenBufferGrowthDetected == false
        }
        guard hasStableAcceptedMode else {
            throw RmeFastestAudioPathValidationError.passWithoutAcceptedStableMode(
                sampleRateHertz: sampleRateHertz
            )
        }
    }

    private func requiredStableSampleRatesForPass() -> [Int] {
        Array(Set([48_000, 96_000] + loopbackReport.sampleRates.compactMap { sampleRate in
            sampleRate.supported ? sampleRate.sampleRateHertz : nil
        })).sorted()
    }

    private func stableAcceptedModesWithLoopback() -> [
        (sampleRate: SampleRateLoopbackResult, result: EndpointModeResult)
    ] {
        loopbackReport.sampleRates.flatMap { sampleRate in
            sampleRate.modeResults.compactMap { result in
                guard result.accepted,
                      result.stable,
                      result.loopback != nil,
                      result.loopback?.hiddenBufferGrowthDetected == false else {
                    return nil
                }
                return (sampleRate, result)
            }
        }
    }

    private static let requiredStaticPlaceholderFieldNames = [
        "id",
        "title",
        "capturedAt",
        "inventoryCapturedAt",
        "inventoryHostName",
        "rmeDevice.name",
        "rmeDevice.uid",
        "rmeDevice.manufacturer",
        "rmeDevice.transportType",
        "driverEvidence.driverPackage",
        "driverEvidence.driverVersion",
        "driverEvidence.firmwareVersion",
        "driverEvidence.totalMixVersion",
        "driverEvidence.totalMixSnapshot",
        "driverEvidence.clockSource",
        "driverEvidence.sampleRateSource",
        "driverEvidence.routingNotes",
        "loopbackReport.id",
        "loopbackReport.title",
        "loopbackReport.hardware.referenceMac",
        "loopbackReport.hardware.audioInterface",
        "loopbackReport.hardware.osVersion",
        "loopbackReport.hardware.driverVersion",
        "loopbackReport.device.name",
        "loopbackReport.device.uid",
        "loopbackReport.device.transportType",
        "notes",
    ]

    private func placeholderSensitiveTextFields() -> [(name: String, value: String)] {
        let staticFields: [(name: String, value: String)] = [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("inventoryCapturedAt", inventoryCapturedAt),
            ("inventoryHostName", inventoryHostName),
            ("rmeDevice.name", rmeDevice.name),
            ("rmeDevice.uid", rmeDevice.uid),
            ("rmeDevice.manufacturer", rmeDevice.manufacturer ?? ""),
            ("rmeDevice.transportType", rmeDevice.transportType ?? ""),
            ("driverEvidence.driverPackage", driverEvidence.driverPackage),
            ("driverEvidence.driverVersion", driverEvidence.driverVersion),
            ("driverEvidence.firmwareVersion", driverEvidence.firmwareVersion),
            ("driverEvidence.totalMixVersion", driverEvidence.totalMixVersion),
            ("driverEvidence.totalMixSnapshot", driverEvidence.totalMixSnapshot),
            ("driverEvidence.clockSource", driverEvidence.clockSource),
            ("driverEvidence.sampleRateSource", driverEvidence.sampleRateSource),
            ("driverEvidence.routingNotes", driverEvidence.routingNotes),
            ("loopbackReport.id", loopbackReport.id),
            ("loopbackReport.title", loopbackReport.title),
            ("loopbackReport.hardware.referenceMac", loopbackReport.hardware.referenceMac),
            ("loopbackReport.hardware.audioInterface", loopbackReport.hardware.audioInterface),
            ("loopbackReport.hardware.osVersion", loopbackReport.hardware.osVersion),
            ("loopbackReport.hardware.driverVersion", loopbackReport.hardware.driverVersion),
            ("loopbackReport.device.name", loopbackReport.device.name),
            ("loopbackReport.device.uid", loopbackReport.device.uid),
            ("loopbackReport.device.transportType", loopbackReport.device.transportType),
            ("notes", notes),
        ]
        precondition(
            Set(staticFields.map { $0.name }) == Set(Self.requiredStaticPlaceholderFieldNames),
            "RME fastest placeholder field checklist mismatch"
        )
        var fields = staticFields
        for (sampleRateIndex, sampleRate) in loopbackReport.sampleRates.enumerated() {
            if let unsupportedReason = sampleRate.unsupportedReason {
                fields.append((
                    "loopbackReport.sampleRates[\(sampleRateIndex)].unsupportedReason",
                    unsupportedReason
                ))
            }
            for (modeIndex, mode) in sampleRate.modeResults.enumerated() {
                if let rejectionReason = mode.rejectionReason {
                    fields.append((
                        "loopbackReport.sampleRates[\(sampleRateIndex)].modeResults[\(modeIndex)].rejectionReason",
                        rejectionReason
                    ))
                }
                fields.append((
                    "loopbackReport.sampleRates[\(sampleRateIndex)].modeResults[\(modeIndex)].notes",
                    mode.notes
                ))
            }
        }
        return fields
    }

    private func thunderboltEvidenceFields() -> [String] {
        [
            rmeDevice.name,
            rmeDevice.uid,
            rmeDevice.manufacturer ?? "",
            rmeDevice.transportType ?? "",
            driverEvidence.driverPackage,
            driverEvidence.routingNotes,
            loopbackReport.hardware.audioInterface,
            loopbackReport.hardware.driverVersion,
            loopbackReport.device.name,
            loopbackReport.device.transportType,
        ]
    }

    private func aggregateRoutingEvidence() -> String? {
        let routeFields = [
            loopbackReport.route.label,
            loopbackReport.route.topology,
            driverEvidence.routingNotes,
        ]
        return routeFields.first { field in
            let normalized = field.lowercased()
            return normalized.contains("aggregate")
                || normalized.contains("multi-output")
                || normalized.contains("multi output")
        }
    }
}

private func requireRmeFastestNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: RmeFastestAudioPathValidationError.self)
}

private func requireRmeFastestPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: RmeFastestAudioPathValidationError.self)
}

private func isRmeMadiDevice(_ device: CoreAudioDeviceInventory) -> Bool {
    let searchable = [
        device.name,
        device.uid,
        device.manufacturer ?? ""
    ].joined(separator: " ").lowercased()
    return searchable.contains("rme") && searchable.contains("madi")
}

private func isRmeMadiLoopback(_ report: EndpointLoopbackReport) -> Bool {
    let searchable = [
        report.hardware.audioInterface,
        report.device.name,
        report.device.uid
    ].joined(separator: " ").lowercased()
    return searchable.contains("rme") && searchable.contains("madi")
}

private func isRmeFastestPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder"],
        exactly: ["unknown", "tbd"]
    )
}
