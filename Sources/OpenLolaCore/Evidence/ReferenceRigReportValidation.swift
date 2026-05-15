import Foundation

private enum ReferenceRigStableBufferTargets {
    // Primary fastest-path pass target: one 32-frame Core Audio callback block.
    static let primaryFrames = 32
    // Stretch target proves the rig can reach the lower-latency 16-frame path.
    static let stretchFrames = 16
    // Fallback target bounds accepted recovery behavior at two 32-frame blocks.
    static let fallbackFrames = 64
}

extension ReferenceRigReport {
    public func validate() throws {
        try validateIdentity()
        try validateReferenceMacs()
        try validateAudioPath()
        try validateSampleRates()
        try validateNetworkProfiles()
        try validateThresholds()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }


    private func validateIdentity() throws {
        try ReferenceRigValidator.requireNonEmpty(id, "id")
        try ReferenceRigValidator.requireNonEmpty(title, "title")
        try ReferenceRigValidator.requireNonEmpty(capturedAt, "capturedAt")
        try ReferenceRigValidator.requireNonEmpty(notes, "notes")
    }

    private func validateReferenceMacs() throws {
        try ReferenceRigValidator.requireNonEmpty(referenceMacs, "referenceMacs")

        for (index, mac) in referenceMacs.enumerated() {
            let prefix = "referenceMacs[\(index)]"
            try ReferenceRigValidator.requireNonEmpty(mac.label, "\(prefix).label")
            try ReferenceRigValidator.requireNonEmpty(mac.hostName, "\(prefix).hostName")
            try ReferenceRigValidator.requireNonEmpty(mac.modelIdentifier, "\(prefix).modelIdentifier")
            try ReferenceRigValidator.requireNonEmpty(mac.siliconGeneration, "\(prefix).siliconGeneration")
            try ReferenceRigValidator.requirePositive(mac.ramGigabytes, "\(prefix).ramGigabytes")
            try ReferenceRigValidator.requireNonEmpty(mac.macOSProductVersion, "\(prefix).macOSProductVersion")
            try ReferenceRigValidator.requireNonEmpty(mac.macOSBuild, "\(prefix).macOSBuild")
            try ReferenceRigValidator.requireNonEmpty(mac.ethernetAdapterPath, "\(prefix).ethernetAdapterPath")
            try ReferenceRigValidator.requireNonEmpty(mac.wiredInterfaceBSDName, "\(prefix).wiredInterfaceBSDName")
            try ReferenceRigValidator.requirePositive(mac.wiredInterfaceLinkSpeedMbps, "\(prefix).wiredInterfaceLinkSpeedMbps")
            try ReferenceRigValidator.requireNonEmpty(mac.power.powerSource, "\(prefix).power.powerSource")
            try ReferenceRigValidator.requireNonEmpty(mac.power.automaticSleep, "\(prefix).power.automaticSleep")
            try ReferenceRigValidator.requireNonEmpty(mac.power.displaySleep, "\(prefix).power.displaySleep")
            try ReferenceRigValidator.requireNonEmpty(mac.power.lowPowerMode, "\(prefix).power.lowPowerMode")
            try ReferenceRigValidator.requireNonEmpty(mac.power.appNapPolicy, "\(prefix).power.appNapPolicy")
        }
    }

    private func validateAudioPath() throws {
        try ReferenceRigValidator.requireNonEmpty(audioPath.interfaceModel, "audioPath.interfaceModel")
        try ReferenceRigValidator.requireNonEmpty(audioPath.connectionPath, "audioPath.connectionPath")
        try ReferenceRigValidator.requireNonEmpty(audioPath.driverPackage, "audioPath.driverPackage")
        try ReferenceRigValidator.requireNonEmpty(audioPath.driverVersion, "audioPath.driverVersion")
        try ReferenceRigValidator.requireNonEmpty(audioPath.firmwareVersion, "audioPath.firmwareVersion")
        try ReferenceRigValidator.requireNonEmpty(audioPath.driverMode, "audioPath.driverMode")
        try ReferenceRigValidator.requireNonEmpty(audioPath.totalMixVersion, "audioPath.totalMixVersion")
        try ReferenceRigValidator.requireNonEmpty(audioPath.totalMixRouteSnapshot, "audioPath.totalMixRouteSnapshot")
        try ReferenceRigValidator.requireNonEmpty(audioPath.clockSource, "audioPath.clockSource")
        try ReferenceRigValidator.requireNonEmpty(audioPath.sampleRateSource, "audioPath.sampleRateSource")
        try ReferenceRigValidator.requireNonEmpty(audioPath.madiOpticalState, "audioPath.madiOpticalState")
        try ReferenceRigValidator.requireNonEmpty(audioPath.madiCoaxState, "audioPath.madiCoaxState")
        try ReferenceRigValidator.requirePositive(audioPath.channelCount, "audioPath.channelCount")
        try validateNonEmptyStrings(audioPath.inputChannelLabels, "audioPath.inputChannelLabels")
        try validateNonEmptyStrings(audioPath.outputChannelLabels, "audioPath.outputChannelLabels")
        try ReferenceRigValidator.requireNonEmpty(audioPath.coreAudioInputUID, "audioPath.coreAudioInputUID")
        try ReferenceRigValidator.requireNonEmpty(audioPath.coreAudioOutputUID, "audioPath.coreAudioOutputUID")
        try ReferenceRigValidator.requireNonEmpty(audioPath.cableLoopDescription, "audioPath.cableLoopDescription")
        try ReferenceRigValidator.requirePositive(audioPath.currentBufferFrameSize, "audioPath.currentBufferFrameSize")
        try ReferenceRigValidator.requirePositive(
            audioPath.acceptedBufferFrameRange.minimum,
            "audioPath.acceptedBufferFrameRange.minimum"
        )
        try ReferenceRigValidator.requirePositive(
            audioPath.acceptedBufferFrameRange.maximum,
            "audioPath.acceptedBufferFrameRange.maximum"
        )
        guard audioPath.acceptedBufferFrameRange.minimum <= audioPath.acceptedBufferFrameRange.maximum else {
            throw ReferenceRigValidationError.invalidBufferFrameRange
        }
        try ReferenceRigValidator.requireNonNegative(audioPath.inputLatencyFrames, "audioPath.inputLatencyFrames")
        try ReferenceRigValidator.requireNonNegative(audioPath.outputLatencyFrames, "audioPath.outputLatencyFrames")
        try ReferenceRigValidator.requireNonNegative(audioPath.inputSafetyOffsetFrames, "audioPath.inputSafetyOffsetFrames")
        try ReferenceRigValidator.requireNonNegative(audioPath.outputSafetyOffsetFrames, "audioPath.outputSafetyOffsetFrames")
    }

    private func validateSampleRates() throws {
        try ReferenceRigValidator.requireNonEmpty(sampleRateMatrix, "sampleRateMatrix")
        let observedSampleRates = Set(sampleRateMatrix.map(\.sampleRateHertz))
        for sampleRate in [48_000, 96_000, 192_000] where !observedSampleRates.contains(sampleRate) {
            throw ReferenceRigValidationError.missingRequiredSampleRate(sampleRate)
        }

        for sampleRate in sampleRateMatrix {
            try ReferenceRigValidator.requirePositive(sampleRate.sampleRateHertz, "sampleRateMatrix.sampleRateHertz")
            try ReferenceRigValidator.requireNonEmpty(sampleRate.notes, "sampleRateMatrix.notes")
            try validatePositiveIntegers(sampleRate.requestedBufferFrameSizes, "sampleRateMatrix.requestedBufferFrameSizes")
            try validatePositiveIntegers(sampleRate.acceptedBufferFrameSizes, "sampleRateMatrix.acceptedBufferFrameSizes")

            if sampleRate.disposition == .accepted && sampleRate.acceptedBufferFrameSizes.isEmpty {
                throw ReferenceRigValidationError.acceptedSampleRateWithoutAcceptedBuffers(sampleRate.sampleRateHertz)
            }
        }
    }

    private func validateNetworkProfiles() throws {
        try ReferenceRigValidator.requireNonEmpty(networkProfiles, "networkProfiles")
        let observedTopologies = Set(networkProfiles.map(\.topology))
        for topology in ReferenceNetworkTopology.allCases where !observedTopologies.contains(topology) {
            throw ReferenceRigValidationError.missingRequiredNetworkTopology(topology)
        }

        for profile in networkProfiles {
            try validateNetworkProfile(profile)
        }
    }

    private func validateNetworkProfile(_ profile: ReferenceNetworkProfile) throws {
        let prefix = "networkProfiles[\(profile.label)]"
        try ReferenceRigValidator.requireNonEmpty(profile.label, "\(prefix).label")
        try ReferenceRigValidator.requireNonEmpty(profile.senderMacLabel, "\(prefix).senderMacLabel")
        try ReferenceRigValidator.requireNonEmpty(profile.receiverMacLabel, "\(prefix).receiverMacLabel")
        try ReferenceRigValidator.requireNonEmpty(profile.routeDescription, "\(prefix).routeDescription")
        try ReferenceRigValidator.requireNonEmpty(profile.vlanState, "\(prefix).vlanState")
        try ReferenceRigValidator.requireNonEmpty(profile.senderInterfaceName, "\(prefix).senderInterfaceName")
        try ReferenceRigValidator.requireNonEmpty(profile.receiverInterfaceName, "\(prefix).receiverInterfaceName")
        try ReferenceRigValidator.requireNonNegative(profile.linkSpeedMbps, "\(prefix).linkSpeedMbps")
        try ReferenceRigValidator.requirePositive(profile.mtu, "\(prefix).mtu")
        try ReferenceRigValidator.requireNonEmpty(profile.senderIPAddress, "\(prefix).senderIPAddress")
        try ReferenceRigValidator.requireNonEmpty(profile.receiverIPAddress, "\(prefix).receiverIPAddress")
        try ReferenceRigValidator.requireNonEmpty(profile.packetCaptureHost, "\(prefix).packetCaptureHost")
        try ReferenceRigValidator.requireNonEmpty(profile.packetCaptureInterface, "\(prefix).packetCaptureInterface")
        try ReferenceRigValidator.requireNonEmpty(profile.packetCapturePoint, "\(prefix).packetCapturePoint")
        try ReferenceRigValidator.requireNonEmpty(profile.captureFilter, "\(prefix).captureFilter")
        try validateDscp(profile.dscp, label: profile.label)
    }

    private func validateDscp(_ dscp: ReferenceDscpPolicy, label: String) throws {
        try ReferenceRigValidator.requireNonEmpty(dscp.policy, "networkProfiles[\(label)].dscp.policy")
        if let requestedValue = dscp.requestedValue {
            try requireReferenceRigDscpRange(requestedValue)
        }
        if let observedValue = dscp.observedValue {
            try requireReferenceRigDscpRange(observedValue)
        }

        if dscp.classification == .notTested {
            guard dscp.notTestedReason?.isEmpty == false else {
                throw ReferenceRigValidationError.missingDscpNotTestedReason(label)
            }
            return
        }
        guard dscp.observedValue != nil else {
            throw ReferenceRigValidationError.missingDscpObservedValue(label)
        }
    }

    private func validateThresholds() throws {
        try ReferenceRigValidator.requirePositive(thresholds.primaryStableBufferFrames, "thresholds.primaryStableBufferFrames")
        try ReferenceRigValidator.requirePositive(thresholds.stretchStableBufferFrames, "thresholds.stretchStableBufferFrames")
        try ReferenceRigValidator.requirePositive(thresholds.fallbackStableBufferFrames, "thresholds.fallbackStableBufferFrames")
        try ReferenceRigValidator.requirePositive(thresholds.callbackP99MaxMicroseconds, "thresholds.callbackP99MaxMicroseconds")
        try ReferenceRigValidator.requirePositive(thresholds.callbackMaxMicroseconds, "thresholds.callbackMaxMicroseconds")
        try ReferenceRigValidator.requireNonNegative(thresholds.allowedUnderruns, "thresholds.allowedUnderruns")
        try ReferenceRigValidator.requirePositive(thresholds.packetAgeP99MaxMicroseconds, "thresholds.packetAgeP99MaxMicroseconds")
        try ReferenceRigValidator.requirePositive(thresholds.packetAgeMaxMicroseconds, "thresholds.packetAgeMaxMicroseconds")
        try ReferenceRigValidator.requireNonNegative(thresholds.packetLossMaxPackets, "thresholds.packetLossMaxPackets")
        try ReferenceRigValidator.requireNonEmpty(thresholds.allowedVerdicts, "thresholds.allowedVerdicts")

        guard thresholds.callbackP99MaxMicroseconds <= thresholds.callbackMaxMicroseconds else {
            throw ReferenceRigValidationError.unorderedThreshold("thresholds.callback")
        }
        guard thresholds.packetAgeP99MaxMicroseconds <= thresholds.packetAgeMaxMicroseconds else {
            throw ReferenceRigValidationError.unorderedThreshold("thresholds.packetAge")
        }
    }

    private func validatePassVerdict() throws {
        guard referenceMacs.count >= 2 else {
            throw ReferenceRigValidationError.missingReferenceMacs(minimum: 2, actual: referenceMacs.count)
        }

        for field in placeholderSensitiveTextFields() where isReferenceRigPlaceholder(field.value) {
            throw ReferenceRigValidationError.passWithPlaceholderField(field.name)
        }

        let audioIdentity = "\(audioPath.interfaceModel) \(audioPath.driverPackage)".lowercased()
        guard audioIdentity.contains("rme"), audioIdentity.contains("madi") else {
            throw ReferenceRigValidationError.passWithoutRmeMadiPath
        }
        guard isThunderboltPerformancePath([audioPath.connectionPath]) else {
            throw ReferenceRigValidationError.passWithoutThunderboltRmePath
        }
        guard !isClassCompliantDriverMode(audioPath.driverMode) else {
            throw ReferenceRigValidationError.passWithoutDedicatedRmeDriver
        }
        guard audioPath.sampleRateConversion == .absent else {
            throw ReferenceRigValidationError.passWithSampleRateConversion(
                audioPath.sampleRateConversion
            )
        }

        let physicalProfiles = networkProfiles.filter { $0.topology != .singleHost }
        for profile in physicalProfiles {
            if profile.dscp.classification == .notTested {
                throw ReferenceRigValidationError.passWithoutDscpClassification(profile.label)
            }
        }

        if thresholds.builtInDevicesAllowedForPass {
            throw ReferenceRigValidationError.passAllowsBuiltInDevices
        }
        try validatePassThresholdTargets()
    }

    private func validatePassThresholdTargets() throws {
        guard thresholds.primaryStableBufferFrames == ReferenceRigStableBufferTargets.primaryFrames else {
            throw ReferenceRigValidationError.invalidThresholdTarget("thresholds.primaryStableBufferFrames")
        }
        guard thresholds.stretchStableBufferFrames == ReferenceRigStableBufferTargets.stretchFrames else {
            throw ReferenceRigValidationError.invalidThresholdTarget("thresholds.stretchStableBufferFrames")
        }
        guard thresholds.fallbackStableBufferFrames == ReferenceRigStableBufferTargets.fallbackFrames else {
            throw ReferenceRigValidationError.invalidThresholdTarget("thresholds.fallbackStableBufferFrames")
        }
    }

    private func placeholderSensitiveTextFields() -> [PlaceholderSensitiveField] {
        var fields = placeholderFields(
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("audioPath.interfaceModel", audioPath.interfaceModel),
            ("audioPath.connectionPath", audioPath.connectionPath),
            ("audioPath.driverPackage", audioPath.driverPackage),
            ("audioPath.driverVersion", audioPath.driverVersion),
            ("audioPath.firmwareVersion", audioPath.firmwareVersion),
            ("audioPath.driverMode", audioPath.driverMode),
            ("audioPath.totalMixVersion", audioPath.totalMixVersion),
            ("audioPath.totalMixRouteSnapshot", audioPath.totalMixRouteSnapshot),
            ("audioPath.clockSource", audioPath.clockSource),
            ("audioPath.sampleRateSource", audioPath.sampleRateSource),
            ("audioPath.madiOpticalState", audioPath.madiOpticalState),
            ("audioPath.madiCoaxState", audioPath.madiCoaxState),
            ("audioPath.coreAudioInputUID", audioPath.coreAudioInputUID),
            ("audioPath.coreAudioOutputUID", audioPath.coreAudioOutputUID),
            ("audioPath.cableLoopDescription", audioPath.cableLoopDescription),
            ("notes", notes)
        )

        fields.append(contentsOf: placeholderFields(
            referenceMacs,
            prefix: { index, _ in "referenceMacs[\(index)]" },
            [
                ("label", \.label),
                ("hostName", \.hostName),
                ("modelIdentifier", \.modelIdentifier),
                ("siliconGeneration", \.siliconGeneration),
                ("macOSProductVersion", \.macOSProductVersion),
                ("macOSBuild", \.macOSBuild),
                ("ethernetAdapterPath", \.ethernetAdapterPath),
                ("wiredInterfaceBSDName", \.wiredInterfaceBSDName),
                ("power.powerSource", \.power.powerSource),
                ("power.automaticSleep", \.power.automaticSleep),
                ("power.displaySleep", \.power.displaySleep),
                ("power.lowPowerMode", \.power.lowPowerMode),
                ("power.appNapPolicy", \.power.appNapPolicy),
            ]
        ))

        fields.append(contentsOf: placeholderIndexedFields(
            audioPath.inputChannelLabels,
            prefix: "audioPath.inputChannelLabels"
        ))
        fields.append(contentsOf: placeholderIndexedFields(
            audioPath.outputChannelLabels,
            prefix: "audioPath.outputChannelLabels"
        ))
        for (index, sampleRate) in sampleRateMatrix.enumerated() {
            fields.append(("sampleRateMatrix[\(index)].notes", sampleRate.notes))
        }
        fields.append(contentsOf: placeholderFields(
            networkProfiles,
            prefix: { _, profile in "networkProfiles[\(profile.label)]" },
            [
                ("label", \.label),
                ("senderMacLabel", \.senderMacLabel),
                ("receiverMacLabel", \.receiverMacLabel),
                ("routeDescription", \.routeDescription),
                ("vlanState", \.vlanState),
                ("senderInterfaceName", \.senderInterfaceName),
                ("receiverInterfaceName", \.receiverInterfaceName),
                ("senderIPAddress", \.senderIPAddress),
                ("receiverIPAddress", \.receiverIPAddress),
                ("packetCaptureHost", \.packetCaptureHost),
                ("packetCaptureInterface", \.packetCaptureInterface),
                ("packetCapturePoint", \.packetCapturePoint),
                ("captureFilter", \.captureFilter),
                ("dscp.policy", \.dscp.policy),
            ]
        ))
        for profile in networkProfiles {
            if let notTestedReason = profile.dscp.notTestedReason {
                fields.append(("networkProfiles[\(profile.label)].dscp.notTestedReason", notTestedReason))
            }
        }

        return fields
    }
}
