// Validates RmeFastestAudioPathValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension RmeFastestAudioPathReport {
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
        try requireRmeFastestAudioPathNonEmpty(id, "id")
        try requireRmeFastestAudioPathNonEmpty(title, "title")
        try requireRmeFastestAudioPathNonEmpty(capturedAt, "capturedAt")
        try requireRmeFastestAudioPathNonEmpty(inventoryCapturedAt, "inventoryCapturedAt")
        try requireRmeFastestAudioPathNonEmpty(inventoryHostName, "inventoryHostName")
        try requireRmeFastestAudioPathNonEmpty(notes, "notes")
    }

    private func validateDeviceInventoryShape() throws {
        try requireRmeFastestAudioPathPositive(Int(rmeDevice.id), "rmeDevice.id")
        try requireRmeFastestAudioPathNonEmpty(rmeDevice.name, "rmeDevice.name")
        try requireRmeFastestAudioPathNonEmpty(rmeDevice.uid, "rmeDevice.uid")
        try requireRmeFastestAudioPathPositive(rmeDevice.inputChannelCount, "rmeDevice.inputChannelCount")
        try requireRmeFastestAudioPathPositive(rmeDevice.outputChannelCount, "rmeDevice.outputChannelCount")
        try requireRmeFastestAudioPathPositive(rmeDevice.inputStreamCount, "rmeDevice.inputStreamCount")
        try requireRmeFastestAudioPathPositive(rmeDevice.outputStreamCount, "rmeDevice.outputStreamCount")
    }

    private func validateDriverEvidenceShape() throws {
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.driverPackage, "driverEvidence.driverPackage")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.driverVersion, "driverEvidence.driverVersion")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.firmwareVersion, "driverEvidence.firmwareVersion")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.totalMixVersion, "driverEvidence.totalMixVersion")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.totalMixSnapshot, "driverEvidence.totalMixSnapshot")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.clockSource, "driverEvidence.clockSource")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.sampleRateSource, "driverEvidence.sampleRateSource")
        try requireRmeFastestAudioPathNonEmpty(driverEvidence.routingNotes, "driverEvidence.routingNotes")
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
        try validatePassLoopbackAndDevice()
        try validatePassDriverAndRoute()
        try validatePassSelectedModeFitsDevice()
        try validatePassPlaceholderSensitiveFields()
        try validatePassRequiredStableModes()
        try validatePassFastestMode()
    }

    private func validatePassLoopbackAndDevice() throws {
        guard loopbackReport.verdict == .pass else {
            throw RmeFastestAudioPathValidationError.passWithoutLoopbackPass
        }
        guard isRmeFastestAudioPathMadiDevice(rmeDevice), isRmeFastestAudioPathMadiLoopback(loopbackReport) else {
            throw RmeFastestAudioPathValidationError.passWithoutRmeMadiDevice
        }
        guard rmeDevice.inputChannelCount > 0, rmeDevice.outputChannelCount > 0 else {
            throw RmeFastestAudioPathValidationError.passWithoutFullDuplexRmeDevice
        }
    }

    private func validatePassDriverAndRoute() throws {
        try validatePassDriverMode()
        try validatePassRouting()
        try validatePassClockAndPath()
    }

    private func validatePassDriverMode() throws {
        guard driverEvidence.driverMode != .unknown else {
            throw RmeFastestAudioPathValidationError.passWithoutConcreteDriverMode
        }
        guard driverEvidence.driverMode != .classCompliant else {
            throw RmeFastestAudioPathValidationError.passWithoutDedicatedRmeDriver
        }
    }

    private func validatePassRouting() throws {
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
    }

    private func validatePassClockAndPath() throws {
        guard rmeDevice.clockDomain != nil else {
            throw RmeFastestAudioPathValidationError.passWithoutClockDomain
        }
        guard isThunderboltPerformancePath(thunderboltEvidenceFields()) else {
            throw RmeFastestAudioPathValidationError.passWithoutThunderboltRmePath
        }
        guard rmeDevice.uid == loopbackReport.device.uid else {
            throw RmeFastestAudioPathValidationError.passWithoutMatchingLoopbackDeviceUID
        }
    }

    private func validatePassSelectedModeFitsDevice() throws {
        guard supportsSampleRate(
            rmeDevice,
            loopbackReport.selectedMode.sampleRateHertz
        ) else {
            throw RmeFastestAudioPathValidationError
                .passSampleRateOutsideRanges(
                    loopbackReport.selectedMode.sampleRateHertz
                )
        }
        guard rmeDevice.candidateBufferFrames.inReportedRange.contains(
            loopbackReport.selectedMode.framesPerBuffer
        ) else {
            throw RmeFastestAudioPathValidationError
                .passBufferFramesOutsideCandidates(
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
                .passChannelCountExceedsDeviceChannels(
                    channelCount: loopbackReport.selectedMode.channelCount,
                    inputChannels: availableInputChannels,
                    outputChannels: availableOutputChannels
                )
        }
    }

    private func validatePassPlaceholderSensitiveFields() throws {
        for field in placeholderSensitiveTextFields() where isRmeFastestAudioPathPlaceholder(field.value) {
            throw RmeFastestAudioPathValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func validatePassRequiredStableModes() throws {
        for sampleRate in requiredStableSampleRatesForPass() {
            try requireSupportedStableSampleRate(sampleRate)
        }
    }

    private func validatePassFastestMode() throws {
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
        "notes"
    ]

    private func placeholderSensitiveTextFields() -> [(name: String, value: String)] {
        var fields = staticPlaceholderSensitiveTextFields()
        fields.append(contentsOf: dynamicLoopbackPlaceholderSensitiveTextFields())
        return fields
    }

    private func staticPlaceholderSensitiveTextFields() -> [(name: String, value: String)] {
        let fields: [(name: String, value: String)] = [
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
            ("notes", notes)
        ]
        precondition(
            Set(fields.map { $0.name }) == Set(Self.requiredStaticPlaceholderFieldNames),
            "RME fastest placeholder field checklist mismatch"
        )
        return fields
    }

    private func dynamicLoopbackPlaceholderSensitiveTextFields() -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = []
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
            loopbackReport.device.transportType
        ]
    }

    private func aggregateRoutingEvidence() -> String? {
        let routeFields = [
            loopbackReport.route.label,
            loopbackReport.route.topology,
            driverEvidence.routingNotes
        ]
        return routeFields.first { field in
            let normalized = field.lowercased()
            return normalized.contains("aggregate")
                || normalized.contains("multi-output")
                || normalized.contains("multi output")
        }
    }
}
