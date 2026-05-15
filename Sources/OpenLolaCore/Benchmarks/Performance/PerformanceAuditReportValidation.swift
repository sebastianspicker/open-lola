import Foundation

enum PerformanceAuditValidator: ReportValidationProtocol {
    typealias ValidationError = PerformanceAuditValidationError
}

extension PerformanceAuditReport {
    public func validate() throws {
        try validateShape()
        try validatePassVerdict()
    }

    private func validateShape() throws {
        try PerformanceAuditValidator.requireNonEmpty(id, "id")
        try PerformanceAuditValidator.requireNonEmpty(title, "title")
        try PerformanceAuditValidator.requireNonEmpty(capturedAt, "capturedAt")
        try PerformanceAuditValidator.requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try PerformanceAuditValidator.requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try PerformanceAuditValidator.requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try PerformanceAuditValidator.requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try validate(processContext)
        try validate(appleSiliconPolicy)
        try PerformanceAuditValidator.requireNonEmpty(sourceReportIds, "sourceReportIds")
        try validateHotPaths()
        try validateCopyAudit()
        try validateWorkerAssignments()
        try validate(counters, field: "counters")
        try validateAccelerationDecisions()
        try validateProfileReports()
        try PerformanceAuditValidator.requireNonEmpty(notes, "notes")
    }

    private func validate(_ context: PerformanceProcessContext) throws {
        try PerformanceAuditValidator.requireNonEmpty(context.machineModel, "processContext.machineModel")
        try PerformanceAuditValidator.requireNonEmpty(context.chipName, "processContext.chipName")
        try PerformanceAuditValidator.requireNonEmpty(context.osVersion, "processContext.osVersion")
        try PerformanceAuditValidator.requireNonEmpty(context.processName, "processContext.processName")
        try PerformanceAuditValidator.requireNonEmpty(context.thermalState, "processContext.thermalState")
        try PerformanceAuditValidator.requireNonEmpty(context.powerMode, "processContext.powerMode")
    }

    private func validate(_ policy: AppleSiliconRuntimePolicy) throws {
        try PerformanceAuditValidator.requireNonEmpty(policy.notes, "appleSiliconPolicy.notes")
    }

    private func validateHotPaths() throws {
        try PerformanceAuditValidator.requireNonEmpty(hotPaths, "hotPaths")
        var seen: Set<PerformanceHotPathSurface> = []
        for hotPath in hotPaths {
            guard seen.insert(hotPath.surface).inserted else {
                throw PerformanceAuditValidationError.duplicateHotPath(hotPath.surface)
            }
            try PerformanceAuditValidator.requireNonNegative(hotPath.allocationWarnings, "hotPaths.allocationWarnings")
            try PerformanceAuditValidator.requireNonNegative(hotPath.blockingIOWarnings, "hotPaths.blockingIOWarnings")
            try PerformanceAuditValidator.requireNonNegative(hotPath.loggingWarnings, "hotPaths.loggingWarnings")
            try PerformanceAuditValidator.requireNonNegative(hotPath.lockWarnings, "hotPaths.lockWarnings")
            try PerformanceAuditValidator.requireNonEmpty(hotPath.notes, "hotPaths.notes")
        }
    }

    private func validateCopyAudit() throws {
        try PerformanceAuditValidator.requireNonEmpty(copyAudit, "copyAudit")
        for copy in copyAudit {
            try PerformanceAuditValidator.requireNonEmpty(copy.id, "copyAudit.id")
            try PerformanceAuditValidator.requireNonNegative(copy.byteCountPerUnit, "copyAudit.byteCountPerUnit")
            try PerformanceAuditValidator.requireNonNegative(copy.copiesPerUnit, "copyAudit.copiesPerUnit")
            if let measuredCostMicroseconds = copy.measuredCostMicroseconds {
                try PerformanceAuditValidator.requireNonNegative(
                    measuredCostMicroseconds,
                    "copyAudit.measuredCostMicroseconds"
                )
            }
        }
    }

    private func validateWorkerAssignments() throws {
        try PerformanceAuditValidator.requireNonEmpty(workerAssignments, "workerAssignments")
        var seen: Set<PerformanceWorkerRole> = []
        for worker in workerAssignments {
            guard seen.insert(worker.role).inserted else {
                throw PerformanceAuditValidationError.duplicateWorkerRole(worker.role)
            }
            try PerformanceAuditValidator.requireNonEmpty(worker.queueLabel, "workerAssignments.queueLabel")
            try PerformanceAuditValidator.requireNonEmpty(worker.notes, "workerAssignments.notes")
        }
    }

    private func validateAccelerationDecisions() throws {
        try PerformanceAuditValidator.requireNonEmpty(accelerationDecisions, "accelerationDecisions")
        var seen: Set<PerformanceAccelerationOption> = []
        for decision in accelerationDecisions {
            guard seen.insert(decision.option).inserted else {
                throw PerformanceAuditValidationError.duplicateAccelerationOption(decision.option)
            }
            if let rawBaselineReportId = decision.rawBaselineReportId {
                try PerformanceAuditValidator.requireNonEmpty(
                    rawBaselineReportId,
                    "accelerationDecisions.rawBaselineReportId"
                )
            }
            if let measuredCostMicroseconds = decision.measuredCostMicroseconds {
                try PerformanceAuditValidator.requireNonNegative(
                    measuredCostMicroseconds,
                    "accelerationDecisions.measuredCostMicroseconds"
                )
            }
            try PerformanceAuditValidator.requireNonEmpty(decision.notes, "accelerationDecisions.notes")
        }
    }

    private func validateProfileReports() throws {
        try PerformanceAuditValidator.requireNonEmpty(profileReports, "profileReports")
        var seen: Set<PerformanceSettingsTier> = []
        for profile in profileReports {
            guard seen.insert(profile.settingsTier).inserted else {
                throw PerformanceAuditValidationError.duplicateSettingsTier(profile.settingsTier)
            }
            try PerformanceAuditValidator.requireNonEmpty(profile.reportId, "profileReports.reportId")
            try validate(profile.counters, field: "profileReports.counters")
            try PerformanceAuditValidator.requireNonEmpty(profile.notes, "profileReports.notes")
        }
    }

    private func validate(_ counters: PerformanceAuditCounters, field: String) throws {
        try validate(counters.callbackDuration, field: "\(field).callbackDuration")
        try validate(counters.packetizationDuration, field: "\(field).packetizationDuration")
        try validate(counters.depacketizationDuration, field: "\(field).depacketizationDuration")
        try validatePacketAge(counters.videoFrameAge, field: "\(field).videoFrameAge")
        try PerformanceAuditValidator.requireNonNegative(counters.ringOccupancyBlocks, "\(field).ringOccupancyBlocks")
        try PerformanceAuditValidator.requireNonNegative(counters.ringDropCount, "\(field).ringDropCount")
        try PerformanceAuditValidator.requireNonNegative(counters.queueDepthPackets, "\(field).queueDepthPackets")
        try PerformanceAuditValidator.requireNonNegative(counters.videoQueueDepthFrames, "\(field).videoQueueDepthFrames")
        try PerformanceAuditValidator.requireNonNegative(counters.audioDropCount, "\(field).audioDropCount")
        try PerformanceAuditValidator.requireNonNegative(counters.allocationWarningCount, "\(field).allocationWarningCount")
        try PerformanceAuditValidator.requireNonNegative(
            counters.memoryBandwidthMegabytesPerSecond,
            "\(field).memoryBandwidthMegabytesPerSecond"
        )
    }

    private func validate(_ counter: PerformanceCounterSummary, field: String) throws {
        try PerformanceAuditValidator.requirePositive(counter.sampleCount, "\(field).sampleCount")
        try PerformanceAuditValidator.requireNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
        try PerformanceAuditValidator.requireNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
        try PerformanceAuditValidator.requireNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
        try PerformanceAuditValidator.requireNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
        try PerformanceAuditValidator.requireNonNegative(counter.invalidSampleCount, "\(field).invalidSampleCount")
        guard counter.invalidSampleCount == 0 else {
            throw PerformanceAuditValidationError.invalidCounterSamples(
                field: field,
                count: counter.invalidSampleCount
            )
        }
        guard timingPercentilesAreOrdered(
            p50: counter.p50Microseconds,
            p95: counter.p95Microseconds,
            p99: counter.p99Microseconds,
            max: counter.maxMicroseconds
        ) else {
            throw PerformanceAuditValidationError.unorderedCounter(field)
        }
    }

    private func validatePacketAge(_ age: UdpPcmPacketAgeMetrics, field: String) throws {
        try PerformanceAuditValidator.requireNonNegative(age.p50Microseconds, "\(field).p50Microseconds")
        try PerformanceAuditValidator.requireNonNegative(age.p95Microseconds, "\(field).p95Microseconds")
        try PerformanceAuditValidator.requireNonNegative(age.p99Microseconds, "\(field).p99Microseconds")
        try PerformanceAuditValidator.requireNonNegative(age.maxMicroseconds, "\(field).maxMicroseconds")
        guard timingPercentilesAreOrdered(
            p50: age.p50Microseconds,
            p95: age.p95Microseconds,
            p99: age.p99Microseconds,
            max: age.maxMicroseconds
        ) else {
            throw PerformanceAuditValidationError.unorderedPacketAge(field)
        }
    }

    private func validatePassVerdict() throws {
        try PerformanceAuditValidator.validateVerdictPass(verdict) {
            guard runMode == .measured else {
                throw PerformanceAuditValidationError.passWithoutMeasuredRun
            }
            guard evidenceKind == .physicalAppleSiliconRig,
                  processContext.chipName.localizedCaseInsensitiveContains("Apple") else {
                throw PerformanceAuditValidationError.passWithoutPhysicalRig
            }
            try validatePassHotPaths()
            try validatePassAppleSiliconPolicy()
            try validatePassWorkers()
            try validatePassCopyAudit()
            try validatePassCounters()
            try validatePassAcceleration()
            try validatePassProfiles()
        }
    }

    private func validatePassHotPaths() throws {
        for surface in PerformanceHotPathSurface.allCases
            where !hotPaths.contains(where: { $0.surface == surface }) {
            throw PerformanceAuditValidationError.passWithoutRequiredHotPath(surface)
        }
        for surface in [
            PerformanceHotPathSurface.audioCallback,
            .audioPacketHandoff,
            .audioPacketization,
            .audioDepacketization,
        ] {
            let hotPath = hotPaths.first { $0.surface == surface }
            guard let hotPath else {
                throw PerformanceAuditValidationError.passWithoutRequiredHotPath(surface)
            }
            try validatePassRealtimeSurface(hotPath)
        }
    }

    private func validatePassRealtimeSurface(_ hotPath: PerformanceHotPathAudit) throws {
        if hotPath.allocationWarnings > 0 {
            throw PerformanceAuditValidationError.passWithRealtimeViolation(
                surface: hotPath.surface,
                field: "allocationWarnings"
            )
        }
        if hotPath.blockingIOWarnings > 0 {
            throw PerformanceAuditValidationError.passWithRealtimeViolation(
                surface: hotPath.surface,
                field: "blockingIOWarnings"
            )
        }
        if hotPath.loggingWarnings > 0 {
            throw PerformanceAuditValidationError.passWithRealtimeViolation(
                surface: hotPath.surface,
                field: "loggingWarnings"
            )
        }
        if hotPath.lockWarnings > 0 {
            throw PerformanceAuditValidationError.passWithRealtimeViolation(
                surface: hotPath.surface,
                field: "lockWarnings"
            )
        }
        if !hotPath.usesMonotonicClock {
            throw PerformanceAuditValidationError.passWithRealtimeViolation(
                surface: hotPath.surface,
                field: "usesMonotonicClock"
            )
        }
        if hotPath.dynamicConfigurationAfterStart {
            throw PerformanceAuditValidationError.passWithDynamicConfiguration(hotPath.surface)
        }
    }

    private func validatePassAppleSiliconPolicy() throws {
        let requiredFlags: [(Bool, String)] = [
            (appleSiliconPolicy.nativeArm64Process, "nativeArm64Process"),
            (!appleSiliconPolicy.rosettaTranslated, "rosettaTranslated"),
            (appleSiliconPolicy.usesQoSInsteadOfCorePinning, "usesQoSInsteadOfCorePinning"),
            (appleSiliconPolicy.keepsAudioOnDeviceCallback, "keepsAudioOnDeviceCallback"),
            (appleSiliconPolicy.usesUnifiedMemoryLowCopyVideoPath, "usesUnifiedMemoryLowCopyVideoPath"),
            (appleSiliconPolicy.avoidsCPUGPUReadbackRoundTrip, "avoidsCPUGPUReadbackRoundTrip"),
            (appleSiliconPolicy.promotesAccelerationOnlyAfterRawBaseline, "promotesAccelerationOnlyAfterRawBaseline"),
        ]
        for flag in requiredFlags where !flag.0 {
            throw PerformanceAuditValidationError.passWithAppleSiliconPolicyViolation(flag.1)
        }
        if processContext.thermalState.localizedCaseInsensitiveContains("critical") {
            throw PerformanceAuditValidationError.passWithAppleSiliconPolicyViolation("thermalState")
        }
        if processContext.powerMode.localizedCaseInsensitiveContains("low power") {
            throw PerformanceAuditValidationError.passWithAppleSiliconPolicyViolation("powerMode")
        }
    }

    private func validatePassWorkers() throws {
        for role in PerformanceWorkerRole.allCases {
            guard let worker = workerAssignments.first(where: { $0.role == role }) else {
                throw PerformanceAuditValidationError.passWithAudioBlockingWorker(role)
            }
            try validatePassWorker(worker)
        }
    }

    private func validatePassWorker(_ worker: PerformanceWorkerAssignment) throws {
        if let expected = expectedPerformanceQoS[worker.role], worker.qos != expected {
            throw PerformanceAuditValidationError.passWithWrongWorkerQoS(
                role: worker.role,
                expected: expected,
                actual: worker.qos
            )
        }
        if worker.canBlockAudioCriticalQueue {
            throw PerformanceAuditValidationError.passWithAudioBlockingWorker(worker.role)
        }
        if worker.role != .audioCallback && !worker.isolatedFromAudioCallback {
            throw PerformanceAuditValidationError.passWithAudioBlockingWorker(worker.role)
        }
    }

    private func validatePassCopyAudit() throws {
        for copy in copyAudit where !copy.removed {
            if copy.documentation.isEmpty {
                throw PerformanceAuditValidationError.passWithUndocumentedCopy(copy.id)
            }
            if copy.measuredCostMicroseconds == nil {
                throw PerformanceAuditValidationError.passWithUnmeasuredCopy(copy.id)
            }
            if copy.avoidable {
                throw PerformanceAuditValidationError.passWithAvoidableCopyRemaining(copy.id)
            }
        }
    }

    private func validatePassCounters() throws {
        try PerformanceAuditValidator.validateThreshold(
            value: counters.ringDropCount,
            max: 0,
            error: PerformanceAuditValidationError.passWithCounterWarning("ringDropCount")
        )
        try PerformanceAuditValidator.validateThreshold(
            value: counters.audioDropCount,
            max: 0,
            error: PerformanceAuditValidationError.passWithCounterWarning("audioDropCount")
        )
        try PerformanceAuditValidator.validateThreshold(
            value: counters.allocationWarningCount,
            max: 0,
            error: PerformanceAuditValidationError.passWithCounterWarning("allocationWarningCount")
        )
    }

    private func validatePassAcceleration() throws {
        for option in PerformanceAccelerationOption.allCases
            where !accelerationDecisions.contains(where: { $0.option == option }) {
            throw PerformanceAuditValidationError.passWithoutAccelerationOption(option)
        }
        for decision in accelerationDecisions {
            if decision.option != .rawLowCopyBaseline,
               decision.rawBaselineReportId?.isEmpty != false {
                throw PerformanceAuditValidationError.passWithoutRawBaseline(decision.option)
            }
            if decision.benchmarked, decision.measuredCostMicroseconds == nil {
                throw PerformanceAuditValidationError.passWithUnmeasuredCopy(decision.option.rawValue)
            }
        }
    }

    private func validatePassProfiles() throws {
        for tier in PerformanceSettingsTier.allCases {
            guard let profile = profileReports.first(where: { $0.settingsTier == tier }) else {
                throw PerformanceAuditValidationError.passWithoutSettingsTier(tier)
            }
            guard profile.verdict == .pass,
                  profile.measured,
                  profile.physicalEvidence else {
                throw PerformanceAuditValidationError.passWithoutProfilePhysicalEvidence(tier)
            }
        }
        for sessionProfile in requiredPerformanceSessionProfiles
            where !profileReports.contains(where: { $0.sessionProfile == sessionProfile }) {
            throw PerformanceAuditValidationError.passWithoutSettingsTier(.experimental)
        }
    }
}

private let expectedPerformanceQoS: [PerformanceWorkerRole: PerformanceWorkerQoS] = [
    .audioCallback: .realtimeDeviceOwned,
    .audioNetworkTx: .userInteractive,
    .audioNetworkRx: .userInteractive,
    .videoCapture: .userInitiated,
    .videoEncodePacketize: .userInitiated,
    .videoReceiveRender: .userInitiated,
    .controlSession: .utility,
    .observability: .utility,
    .ui: .main,
]

private let requiredPerformanceSessionProfiles: [SessionLatencyProfile] = [
    .directAudioFirst,
    .balancedAV,
    .multiVideoPerformance,
]
