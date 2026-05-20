import Foundation

public extension E2EBenchmarkReport {
    func validate() throws {
        try validateE2EIdentity()
        try validateE2EHardware()
        try validateE2EComponents()
        try validateE2EProfiles()
        try validateE2EImpairments()
        try validateE2ERecovery()
        try validateE2EThresholds()
        try validateE2EPassVerdict()
    }
}

private extension E2EBenchmarkReport {
    func validateE2EIdentity() throws {
        try E2EBenchmarkValidator.requireNonEmpty(id, "id")
        try E2EBenchmarkValidator.requireNonEmpty(title, "title")
        try E2EBenchmarkValidator.requireNonEmpty(capturedAt, "capturedAt")
        try E2EBenchmarkValidator.requirePositive(durationSeconds, "durationSeconds")
        try E2EBenchmarkValidator.requireNonEmpty(notes, "notes")
    }

    func validateE2EHardware() throws {
        for field in e2eHardwareFields() {
            try E2EBenchmarkValidator.requireNonEmpty(field.value, field.name)
        }
    }

    func validateE2EComponents() throws {
        try E2EBenchmarkValidator.requireNonEmpty(componentReports.audioBenchmarkReportId, "componentReports.audioBenchmarkReportId")
        try E2EBenchmarkValidator.requireNonEmpty(componentReports.integratedAvReportId, "componentReports.integratedAvReportId")
        try E2EBenchmarkValidator.requireNonEmpty(componentReports.videoTransportReportId, "componentReports.videoTransportReportId")
        try E2EBenchmarkValidator.requireNonEmpty(componentReports.performanceAuditReportId, "componentReports.performanceAuditReportId")
    }

    func validateE2EProfiles() throws {
        try E2EBenchmarkValidator.requireNonEmpty(profiles, "profiles")
        var seen: Set<E2EBenchmarkProfile> = []
        for profile in profiles {
            guard seen.insert(profile.profile).inserted else {
                throw E2EBenchmarkValidationError.duplicateProfile(profile.profile)
            }
            try E2EBenchmarkValidator.requireNonEmpty(profile.reportId, "profiles[\(profile.profile.rawValue)].reportId")
            try E2EBenchmarkValidator.requireNonEmpty(profile.notes, "profiles[\(profile.profile.rawValue)].notes")
            try validateE2EAudio(profile.audio, field: "profiles[\(profile.profile.rawValue)].audio")
            if let video = profile.video {
                try validateE2EVideo(video, field: "profiles[\(profile.profile.rawValue)].video")
            }
            try validateE2ENetwork(profile.network, field: "profiles[\(profile.profile.rawValue)].network")
            try validateE2EResources(profile.resources, field: "profiles[\(profile.profile.rawValue)].resources")
        }
        for profile in E2EBenchmarkProfile.allCases where !seen.contains(profile) {
            throw E2EBenchmarkValidationError.missingProfile(profile)
        }
    }

    func validateE2EImpairments() throws {
        try E2EBenchmarkValidator.requireNonEmpty(impairments, "impairments")
        var seen: Set<E2EBenchmarkImpairmentProfile> = []
        for impairment in impairments {
            guard seen.insert(impairment.profile).inserted else {
                throw E2EBenchmarkValidationError.duplicateImpairment(impairment.profile)
            }
            try E2EBenchmarkValidator.requireNonEmpty(impairment.reportId, "impairments[\(impairment.profile.rawValue)].reportId")
            try E2EBenchmarkValidator.requireNonEmpty(impairment.notes, "impairments[\(impairment.profile.rawValue)].notes")
            try E2EBenchmarkValidator.requireNonNegative(impairment.injectedPackets, "impairments.injectedPackets")
            try E2EBenchmarkValidator.requireNonNegative(impairment.observedPackets, "impairments.observedPackets")
            try E2EBenchmarkValidator.requireNonNegative(impairment.recoveredPackets, "impairments.recoveredPackets")
            try E2EBenchmarkValidator.requireNonNegative(impairment.audioUnderruns, "impairments.audioUnderruns")
            try E2EBenchmarkValidator.requireNonNegative(impairment.videoDroppedFrames, "impairments.videoDroppedFrames")
        }
        for profile in E2EBenchmarkImpairmentProfile.allCases where !seen.contains(profile) {
            throw E2EBenchmarkValidationError.missingImpairment(profile)
        }
    }

    func validateE2ERecovery() throws {
        try E2EBenchmarkValidator.requireNonNegative(recovery.reconnectEvents, "recovery.reconnectEvents")
        try E2EBenchmarkValidator.requireNonNegative(recovery.reconnectP99Microseconds, "recovery.reconnectP99Microseconds")
        try E2EBenchmarkValidator.requireNonNegative(
            recovery.leakedRealtimeCallbacksAfterShutdown,
            "recovery.leakedRealtimeCallbacksAfterShutdown"
        )
        try E2EBenchmarkValidator.requireNonEmpty(recovery.recoveryReportId, "recovery.recoveryReportId")
        try E2EBenchmarkValidator.requireNonEmpty(recovery.shutdownReportId, "recovery.shutdownReportId")
    }

    func validateE2EThresholds() throws {
        try E2EBenchmarkValidator.requireNonEmpty(thresholds.methodologyDocument, "thresholds.methodologyDocument")
        try E2EBenchmarkValidator.requirePercent(thresholds.packetLossMaxPercent, "thresholds.packetLossMaxPercent")
        try E2EBenchmarkValidator.requirePercent(thresholds.cpuP99MaxPercent, "thresholds.cpuP99MaxPercent")
        try E2EBenchmarkValidator.requireNonNegative(
            thresholds.audioP99DeltaFromBaselineToleranceMicroseconds,
            "thresholds.audioP99DeltaFromBaselineToleranceMicroseconds"
        )
        try E2EBenchmarkValidator.requireNonNegative(thresholds.audioUnderrunMaxCount, "thresholds.audioUnderrunMaxCount")
        try E2EBenchmarkValidator.requireNonNegative(thresholds.droppedFrameMaxCount, "thresholds.droppedFrameMaxCount")
    }

    func validateE2EPassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw E2EBenchmarkValidationError.passWithoutMeasuredRun
        }
        guard evidenceKind == .physicalTwoPeerRig else {
            throw E2EBenchmarkValidationError.passWithoutPhysicalTwoPeerEvidence
        }
        guard thresholds.methodologyDocument.contains("benchmark-e2e-av.md") else {
            throw E2EBenchmarkValidationError.passWithoutMethodologyReference(
                thresholds.methodologyDocument
            )
        }
        try validateE2EPassHardware()
        try validateE2EPassProfiles()
        try validateE2EPassImpairments()
        try validateE2EPassRecovery()
    }

    func validateE2EPassHardware() throws {
        for field in e2eHardwareFields() where isE2EPlaceholder(field.value) {
            throw E2EBenchmarkValidationError.passWithPlaceholderField(field.name)
        }
    }

    func validateE2EPassProfiles() throws {
        for profile in profiles {
            guard profile.verdict == .pass else {
                throw E2EBenchmarkValidationError.passWithNonPassProfile(profile.profile, profile.verdict)
            }
            guard profile.measured else {
                throw E2EBenchmarkValidationError.passWithoutMeasuredProfile(profile.profile)
            }
            guard profile.physicalEvidence else {
                throw E2EBenchmarkValidationError.passWithoutPhysicalProfile(profile.profile)
            }
            if profile.profile != .audioOnlyDirect {
                guard let video = profile.video else {
                    throw E2EBenchmarkValidationError.passWithoutVideoMetrics(profile.profile)
                }
                if profile.profile == .audioMultiVideoDirect, video.streamCount < 2 {
                    throw E2EBenchmarkValidationError.passWithoutMultiVideoStreamCount(video.streamCount)
                }
                if profile.audio.audioP99DeltaFromBaselineMicroseconds
                    > thresholds.audioP99DeltaFromBaselineToleranceMicroseconds {
                    throw E2EBenchmarkValidationError.passWithVideoAudioImpact(profile.profile)
                }
                if video.droppedFrames > thresholds.droppedFrameMaxCount {
                    throw E2EBenchmarkValidationError.passExceedsDroppedFrames(
                        profile: profile.profile,
                        value: video.droppedFrames,
                        threshold: thresholds.droppedFrameMaxCount
                    )
                }
            }
            if profile.audio.underruns > thresholds.audioUnderrunMaxCount {
                throw E2EBenchmarkValidationError.passWithAudioUnderruns(
                    profile.profile,
                    profile.audio.underruns
                )
            }
            if profile.audio.hiddenBufferGrowthDetected {
                throw E2EBenchmarkValidationError.passWithHiddenAudioBufferGrowth(profile.profile)
            }
            if profile.network.packetLossPercent > thresholds.packetLossMaxPercent {
                throw E2EBenchmarkValidationError.passExceedsPacketLoss(
                    profile: profile.profile,
                    value: profile.network.packetLossPercent,
                    threshold: thresholds.packetLossMaxPercent
                )
            }
            if profile.resources.cpuP99Percent > thresholds.cpuP99MaxPercent {
                throw E2EBenchmarkValidationError.passExceedsCpu(
                    profile: profile.profile,
                    value: profile.resources.cpuP99Percent,
                    threshold: thresholds.cpuP99MaxPercent
                )
            }
        }
    }

    func validateE2EPassImpairments() throws {
        for impairment in impairments {
            guard impairment.verdict == .pass else {
                throw E2EBenchmarkValidationError.passWithNonPassImpairment(
                    impairment.profile,
                    impairment.verdict
                )
            }
            guard impairment.measured else {
                throw E2EBenchmarkValidationError.passWithoutMeasuredImpairment(impairment.profile)
            }
        }
    }

    func validateE2EPassRecovery() throws {
        guard recovery.reconnectEvents > 0 else {
            throw E2EBenchmarkValidationError.passWithoutRecoveryEvent
        }
        guard recovery.cleanShutdownObserved else {
            throw E2EBenchmarkValidationError.passWithoutCleanShutdown
        }
        guard recovery.leakedRealtimeCallbacksAfterShutdown == 0 else {
            throw E2EBenchmarkValidationError.passWithLeakedCallbacks(
                recovery.leakedRealtimeCallbacksAfterShutdown
            )
        }
    }

    func e2eHardwareFields() -> [(name: String, value: String)] {
        [
            ("hardware.sourcePeer.peerId", hardware.sourcePeer.peerId),
            ("hardware.sourcePeer.machineModel", hardware.sourcePeer.machineModel),
            ("hardware.sourcePeer.chipName", hardware.sourcePeer.chipName),
            ("hardware.sourcePeer.osVersion", hardware.sourcePeer.osVersion),
            ("hardware.sourcePeer.audioInterface", hardware.sourcePeer.audioInterface),
            ("hardware.sourcePeer.audioDeviceUID", hardware.sourcePeer.audioDeviceUID),
            ("hardware.sourcePeer.videoDevice", hardware.sourcePeer.videoDevice),
            ("hardware.sourcePeer.networkInterface", hardware.sourcePeer.networkInterface),
            ("hardware.receiverPeer.peerId", hardware.receiverPeer.peerId),
            ("hardware.receiverPeer.machineModel", hardware.receiverPeer.machineModel),
            ("hardware.receiverPeer.chipName", hardware.receiverPeer.chipName),
            ("hardware.receiverPeer.osVersion", hardware.receiverPeer.osVersion),
            ("hardware.receiverPeer.audioInterface", hardware.receiverPeer.audioInterface),
            ("hardware.receiverPeer.audioDeviceUID", hardware.receiverPeer.audioDeviceUID),
            ("hardware.receiverPeer.videoDevice", hardware.receiverPeer.videoDevice),
            ("hardware.receiverPeer.networkInterface", hardware.receiverPeer.networkInterface),
            ("hardware.rmeMadiIdentity", hardware.rmeMadiIdentity),
            ("hardware.blackmagicIdentity", hardware.blackmagicIdentity),
            ("hardware.routeLabel", hardware.routeLabel),
            ("hardware.networkTopology", hardware.networkTopology),
            ("hardware.packetCapturePoint", hardware.packetCapturePoint),
            ("hardware.clockAlignmentMethod", hardware.clockAlignmentMethod),
        ]
    }
}

private func validateE2EAudio(_ metrics: E2EBenchmarkAudioMetrics, field: String) throws {
    try E2EBenchmarkValidator.requirePositive(metrics.sampleRateHertz, "\(field).sampleRateHertz")
    try E2EBenchmarkValidator.requirePositive(metrics.channelCount, "\(field).channelCount")
    try E2EBenchmarkValidator.requirePositive(metrics.framesPerBuffer, "\(field).framesPerBuffer")
    try validateE2ECounter(metrics.callbackDuration, "\(field).callbackDuration")
    try E2EBenchmarkValidator.requireNonNegative(metrics.oneWayLatencyMicroseconds, "\(field).oneWayLatencyMicroseconds")
    try E2EBenchmarkValidator.requireNonNegative(metrics.roundTripLatencyMicroseconds, "\(field).roundTripLatencyMicroseconds")
    try validateE2EPacketAge(metrics.jitter, "\(field).jitter")
    try E2EBenchmarkValidator.requireNonNegative(metrics.underruns, "\(field).underruns")
    try E2EBenchmarkValidator.requireNonNegative(metrics.overruns, "\(field).overruns")
    try E2EBenchmarkValidator.requirePositive(metrics.configuredChannelCount, "\(field).configuredChannelCount")
    try E2EBenchmarkValidator.requireFinite(
        metrics.audioP99DeltaFromBaselineMicroseconds,
        "\(field).audioP99DeltaFromBaselineMicroseconds"
    )
}

private func validateE2EVideo(_ metrics: E2EBenchmarkVideoMetrics, field: String) throws {
    try E2EBenchmarkValidator.requirePositive(metrics.streamCount, "\(field).streamCount")
    try E2EBenchmarkValidator.requirePositive(metrics.width, "\(field).width")
    try E2EBenchmarkValidator.requirePositive(metrics.height, "\(field).height")
    try E2EBenchmarkValidator.requirePositive(metrics.frameRate, "\(field).frameRate")
    try validateE2EPacketAge(metrics.captureLatency, "\(field).captureLatency")
    try validateE2ECounter(metrics.encodePacketizationLatency, "\(field).encodePacketizationLatency")
    try validateE2EPacketAge(metrics.receiveRenderLatency, "\(field).receiveRenderLatency")
    try E2EBenchmarkValidator.requireNonNegative(metrics.droppedFrames, "\(field).droppedFrames")
    try E2EBenchmarkValidator.requireNonEmpty(metrics.blackmagicCaptureReportId, "\(field).blackmagicCaptureReportId")
    try E2EBenchmarkValidator.requireNonEmpty(metrics.renderOutputReportId, "\(field).renderOutputReportId")
}

private func validateE2ENetwork(_ metrics: E2EBenchmarkNetworkMetrics, field: String) throws {
    try E2EBenchmarkValidator.requireNonNegative(metrics.throughputMegabitsPerSecond, "\(field).throughputMegabitsPerSecond")
    try E2EBenchmarkValidator.requireNonNegative(metrics.lostPackets, "\(field).lostPackets")
    try E2EBenchmarkValidator.requireNonNegative(metrics.latePackets, "\(field).latePackets")
    try E2EBenchmarkValidator.requireNonNegative(metrics.reorderedPackets, "\(field).reorderedPackets")
    try E2EBenchmarkValidator.requireNonNegative(metrics.duplicatePackets, "\(field).duplicatePackets")
    try E2EBenchmarkValidator.requirePercent(metrics.packetLossPercent, "\(field).packetLossPercent")
    try validateE2EPacketAge(metrics.jitter, "\(field).jitter")
}

private func validateE2EResources(_ metrics: E2EBenchmarkResourceMetrics, field: String) throws {
    try E2EBenchmarkValidator.requirePercent(metrics.cpuP99Percent, "\(field).cpuP99Percent")
    try E2EBenchmarkValidator.requirePercent(metrics.gpuP99Percent, "\(field).gpuP99Percent")
    try E2EBenchmarkValidator.requireNonNegative(metrics.residentMemoryMegabytes, "\(field).residentMemoryMegabytes")
    try E2EBenchmarkValidator.requireNonNegative(metrics.hotPathAllocationWarnings, "\(field).hotPathAllocationWarnings")
}

private func validateE2ECounter(_ counter: PerformanceCounterSummary, _ field: String) throws {
    try E2EBenchmarkValidator.requireNonNegative(counter.sampleCount, "\(field).sampleCount")
    try E2EBenchmarkValidator.requireNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: counter.p50Microseconds,
        p95: counter.p95Microseconds,
        p99: counter.p99Microseconds,
        max: counter.maxMicroseconds
    ) else {
        throw E2EBenchmarkValidationError.unorderedCounter(field)
    }
}

private func validateE2EPacketAge(_ metrics: UdpPcmPacketAgeMetrics, _ field: String) throws {
    try E2EBenchmarkValidator.requireNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
    try E2EBenchmarkValidator.requireNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw E2EBenchmarkValidationError.unorderedCounter(field)
    }
}

private enum E2EBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = E2EBenchmarkValidationError
}

private func isE2EPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder", "synthetic", "not-captured", "not captured", "required"],
        exactly: ["unknown", "tbd"]
    )
}
