import Foundation

public enum LightingFixtureGateRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public struct LightingFixtureGateReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: LightingFixtureGateRunMode
    public var standards: [LightingProtocolStandardEvidence]
    public var workflow: LightingCueWorkflowEvidence?
    public var policy: LightingSafetyPolicy
    public var probe: LightingProbeReport
    public var fixtureMetadata: LightingFixtureMetadataPolicy
    public var audioImpact: LightingAudioImpactMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: LightingFixtureGateRunMode = .synthetic,
        standards: [LightingProtocolStandardEvidence],
        workflow: LightingCueWorkflowEvidence? = nil,
        policy: LightingSafetyPolicy,
        probe: LightingProbeReport,
        fixtureMetadata: LightingFixtureMetadataPolicy,
        audioImpact: LightingAudioImpactMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.standards = standards
        self.workflow = workflow
        self.policy = policy
        self.probe = probe
        self.fixtureMetadata = fixtureMetadata
        self.audioImpact = audioImpact
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> LightingFixtureGateReport {
        try JSONDecoder().decode(LightingFixtureGateReport.self, from: data)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case capturedAt
        case runMode
        case standards
        case workflow
        case policy
        case probe
        case fixtureMetadata
        case audioImpact
        case verdict
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.capturedAt = try container.decode(String.self, forKey: .capturedAt)
        self.runMode = try container.decodeIfPresent(LightingFixtureGateRunMode.self, forKey: .runMode) ?? .synthetic
        self.standards = try container.decode([LightingProtocolStandardEvidence].self, forKey: .standards)
        self.workflow = try container.decodeIfPresent(LightingCueWorkflowEvidence.self, forKey: .workflow)
        self.policy = try container.decode(LightingSafetyPolicy.self, forKey: .policy)
        self.probe = try container.decode(LightingProbeReport.self, forKey: .probe)
        self.fixtureMetadata = try container.decode(LightingFixtureMetadataPolicy.self, forKey: .fixtureMetadata)
        self.audioImpact = try container.decode(LightingAudioImpactMetrics.self, forKey: .audioImpact)
        self.verdict = try container.decode(MeasurementVerdict.self, forKey: .verdict)
        self.notes = try container.decode(String.self, forKey: .notes)
    }

    public func validate() throws {
        try validateIdentity()
        try validateStandards()
        try validateWorkflow()
        try validatePolicy()
        try validateProbe()
        try validateFixtureMetadata()
        try validateAudioImpact()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireLightingNonEmpty(id, "id")
        try requireLightingNonEmpty(title, "title")
        try requireLightingNonEmpty(capturedAt, "capturedAt")
        try requireLightingNonEmpty(notes, "notes")
    }

    private func validateStandards() throws {
        try requireLightingList(standards, "standards")
        for standard in standards {
            try requireLightingNonEmpty(standard.document, "standards.document")
            try requireLightingNonEmpty(standard.sourceURL, "standards.sourceURL")
            try requireLightingNonEmpty(standard.licenseDisposition, "standards.licenseDisposition")
        }
        for protocolName in [LightingControlProtocol.sacn, .artNet]
            where !standards.contains(where: { $0.protocolName == protocolName }) {
            throw LightingFixtureGateValidationError.missingStandard(protocolName)
        }
    }

    private func validateWorkflow() throws {
        guard let workflow else {
            return
        }
        try requireLightingNonEmpty(workflow.notes, "workflow.notes")
    }

    private func validatePolicy() throws {
        try requireLightingNonEmpty(policy.failurePolicy.notes, "policy.failurePolicy.notes")
        try requireLightingList(policy.allowedUniverses, "policy.allowedUniverses")
        for universe in policy.allowedUniverses {
            try requireLightingPositive(universe.universe, "policy.allowedUniverses.universe")
            try requireLightingNonEmpty(universe.destinationAddress, "policy.allowedUniverses.destinationAddress")
            try requireLightingPositive(universe.port, "policy.allowedUniverses.port")
            try requireLightingPositive(universe.maxRefreshRateHertz, "policy.allowedUniverses.maxRefreshRateHertz")
        }
    }

    private func validateProbe() throws {
        try requireLightingNonNegative(probe.durationSeconds, "probe.durationSeconds")
        try validateRequest(probe.request, "probe.request")
        let dmx = probe.dmx
        try requireLightingPositive(dmx.channelCount, "probe.dmx.channelCount")
        try requireLightingNonNegative(dmx.changedChannels, "probe.dmx.changedChannels")
        if dmx.minLevel < 0 || dmx.minLevel > 255 {
            throw LightingFixtureGateValidationError.valueOutOfRange(field: "probe.dmx.minLevel", value: dmx.minLevel)
        }
        if dmx.maxLevel < 0 || dmx.maxLevel > 255 {
            throw LightingFixtureGateValidationError.valueOutOfRange(field: "probe.dmx.maxLevel", value: dmx.maxLevel)
        }
        guard dmx.minLevel <= dmx.maxLevel else {
            throw LightingFixtureGateValidationError.invalidDmxLevelRange(
                minLevel: dmx.minLevel,
                maxLevel: dmx.maxLevel
            )
        }
        try validatePacketCapture(probe.packetCapture)
    }

    private func validateRequest(_ request: LightingOutputRequest, _ field: String) throws {
        try requireLightingPositive(request.universe, "\(field).universe")
        try requireLightingNonEmpty(request.destinationAddress, "\(field).destinationAddress")
        try requireLightingPositive(request.port, "\(field).port")
    }

    private func validatePacketCapture(_ packetCapture: LightingPacketCaptureReport) throws {
        try requireLightingNonEmpty(packetCapture.tool, "probe.packetCapture.tool")
        try requireLightingNonEmpty(packetCapture.capturePoint, "probe.packetCapture.capturePoint")
        try requireLightingNonNegative(packetCapture.packetCount, "probe.packetCapture.packetCount")
        try requireLightingNonNegative(packetCapture.broadcastPackets, "probe.packetCapture.broadcastPackets")
        try requireLightingNonNegative(packetCapture.multicastPackets, "probe.packetCapture.multicastPackets")
        try requireLightingNonEmpty(packetCapture.captureArtifact, "probe.packetCapture.captureArtifact")
        try requireLightingNonEmpty(packetCapture.notes, "probe.packetCapture.notes")
        for universe in packetCapture.universesObserved {
            try requireLightingPositive(universe, "probe.packetCapture.universesObserved")
        }
        if packetCapture.captured && packetCapture.packetCount <= 0 {
            throw LightingFixtureGateValidationError.packetCaptureAccountingMismatch
        }
    }

    private func validateFixtureMetadata() throws {
        try requireLightingNonEmpty(fixtureMetadata.source, "fixtureMetadata.source")
    }

    private func validateAudioImpact() throws {
        try requireLightingNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try requireLightingNonNegative(
            audioImpact.lightingCallbackP99Microseconds,
            "audioImpact.lightingCallbackP99Microseconds"
        )
        try requireLightingNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try requireLightingNonNegative(
            audioImpact.lightingCallbackMaxMicroseconds,
            "audioImpact.lightingCallbackMaxMicroseconds"
        )
        try requireLightingPositive(audioImpact.baselinePlayoutTargetFrames, "audioImpact.baselinePlayoutTargetFrames")
        try requireLightingPositive(audioImpact.lightingPlayoutTargetFrames, "audioImpact.lightingPlayoutTargetFrames")
        try requireLightingNonNegative(audioImpact.underruns, "audioImpact.underruns")
        if let baselineReportId = audioImpact.baselineReportId {
            try requireLightingNonEmpty(baselineReportId, "audioImpact.baselineReportId")
        }
        guard audioImpact.baselineCallbackP99Microseconds <= audioImpact.baselineCallbackMaxMicroseconds else {
            throw LightingFixtureGateValidationError.unorderedAudioCallbackMetrics("baseline")
        }
        guard audioImpact.lightingCallbackP99Microseconds <= audioImpact.lightingCallbackMaxMicroseconds else {
            throw LightingFixtureGateValidationError.unorderedAudioCallbackMetrics("lighting")
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        for standard in standards where standard.status != .reviewed {
            throw LightingFixtureGateValidationError.passWithoutReviewedStandards(standard.protocolName)
        }
        if probe.request.networkMode.isBroadcast && !policy.broadcastAllowed {
            throw LightingFixtureGateValidationError.passWithBlockedGate(.broadcastNotAllowed)
        }
        if probe.request.networkMode.isMulticast && !policy.multicastAllowed {
            throw LightingFixtureGateValidationError.passWithBlockedGate(.multicastNotAllowed)
        }
        let decision = policy.decision(for: probe.request)
        guard decision.canTransmit else {
            throw LightingFixtureGateValidationError.passWithBlockedGate(
                decision.reason ?? .requestNotAllowed
            )
        }
        guard policy.failurePolicy.isComplete else {
            throw LightingFixtureGateValidationError.passWithoutFailurePolicy
        }
        guard probe.packetCapture.captured, probe.packetCapture.packetCount > 0 else {
            throw LightingFixtureGateValidationError.passWithoutPacketCapture
        }
        guard Set(probe.packetCapture.universesObserved) == Set([probe.request.universe]) else {
            throw LightingFixtureGateValidationError.passWithoutOneUniverseCapture
        }
        guard probe.dmx.maxLevel > 0 else {
            throw LightingFixtureGateValidationError.passWithoutDmxOutputActivity
        }
        if probe.packetCapture.broadcastPackets > 0 && !policy.broadcastAllowed {
            throw LightingFixtureGateValidationError.passWithBlockedGate(.broadcastNotAllowed)
        }
        if fixtureMetadata.realtimeLookupAllowed {
            throw LightingFixtureGateValidationError.passAllowsRealtimeFixtureLookup
        }
        if audioImpact.lightingCallbackP99Microseconds > audioImpact.baselineCallbackP99Microseconds {
            throw LightingFixtureGateValidationError.passIncreasesAudioP99(
                baseline: audioImpact.baselineCallbackP99Microseconds,
                lighting: audioImpact.lightingCallbackP99Microseconds
            )
        }
        if audioImpact.lightingCallbackMaxMicroseconds > audioImpact.baselineCallbackMaxMicroseconds {
            throw LightingFixtureGateValidationError.passIncreasesAudioMax(
                baseline: audioImpact.baselineCallbackMaxMicroseconds,
                lighting: audioImpact.lightingCallbackMaxMicroseconds
            )
        }
        if audioImpact.lightingPlayoutTargetFrames != audioImpact.baselinePlayoutTargetFrames {
            throw LightingFixtureGateValidationError.passChangesAudioPlayoutTarget(
                baseline: audioImpact.baselinePlayoutTargetFrames,
                lighting: audioImpact.lightingPlayoutTargetFrames
            )
        }
        if audioImpact.underruns > 0 {
            throw LightingFixtureGateValidationError.passWithUnderruns(audioImpact.underruns)
        }
        if audioImpact.hiddenAudioImpactDetected {
            throw LightingFixtureGateValidationError.passWithHiddenAudioImpact
        }
        guard let workflow else {
            throw LightingFixtureGateValidationError.passWithoutCueWorkflow
        }
        try requireLightingPassWorkflowText(
            workflow.oscCueReportId,
            field: "workflow.oscCueReportId",
            missing: .passWithoutOscCueReport
        )
        guard workflow.localFixtureOwner != .none else {
            throw LightingFixtureGateValidationError.passWithoutLocalFixtureOwner
        }
        guard workflow.localFixtureOwner == probe.interopTarget else {
            throw LightingFixtureGateValidationError.passWithFixtureOwnerMismatch(
                expected: probe.interopTarget,
                actual: workflow.localFixtureOwner
            )
        }
        if workflow.directFixtureStreamingOnPerformanceLink {
            throw LightingFixtureGateValidationError.passWithDirectFixtureStreamingOnPerformanceLink
        }
        try requireLightingPassWorkflowText(
            workflow.notes,
            field: "workflow.notes",
            missing: .emptyField("workflow.notes")
        )
    }
}
