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
        try requireE2ENonEmpty(id, "id")
        try requireE2ENonEmpty(title, "title")
        try requireE2ENonEmpty(capturedAt, "capturedAt")
        try requireE2EPositive(durationSeconds, "durationSeconds")
        try requireE2ENonEmpty(notes, "notes")
    }

    func validateE2EHardware() throws {
        for field in e2eHardwareFields() {
            try requireE2ENonEmpty(field.value, field.name)
        }
    }

    func validateE2EComponents() throws {
        try requireE2ENonEmpty(componentReports.audioBenchmarkReportId, "componentReports.audioBenchmarkReportId")
        try requireE2ENonEmpty(componentReports.integratedAvReportId, "componentReports.integratedAvReportId")
        try requireE2ENonEmpty(componentReports.videoTransportReportId, "componentReports.videoTransportReportId")
        try requireE2ENonEmpty(componentReports.performanceAuditReportId, "componentReports.performanceAuditReportId")
    }

    func validateE2EProfiles() throws {
        try requireE2ENonEmpty(profiles, "profiles")
        var seen: Set<E2EBenchmarkProfile> = []
        for profile in profiles {
            guard seen.insert(profile.profile).inserted else {
                throw E2EBenchmarkValidationError.duplicateProfile(profile.profile)
            }
            try requireE2ENonEmpty(profile.reportId, "profiles[\(profile.profile.rawValue)].reportId")
            try requireE2ENonEmpty(profile.notes, "profiles[\(profile.profile.rawValue)].notes")
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
        try requireE2ENonEmpty(impairments, "impairments")
        var seen: Set<E2EBenchmarkImpairmentProfile> = []
        for impairment in impairments {
            guard seen.insert(impairment.profile).inserted else {
                throw E2EBenchmarkValidationError.duplicateImpairment(impairment.profile)
            }
            try requireE2ENonEmpty(impairment.reportId, "impairments[\(impairment.profile.rawValue)].reportId")
            try requireE2ENonEmpty(impairment.notes, "impairments[\(impairment.profile.rawValue)].notes")
            try requireE2ENonNegative(impairment.injectedPackets, "impairments.injectedPackets")
            try requireE2ENonNegative(impairment.observedPackets, "impairments.observedPackets")
            try requireE2ENonNegative(impairment.recoveredPackets, "impairments.recoveredPackets")
            try requireE2ENonNegative(impairment.audioUnderruns, "impairments.audioUnderruns")
            try requireE2ENonNegative(impairment.videoDroppedFrames, "impairments.videoDroppedFrames")
        }
        for profile in E2EBenchmarkImpairmentProfile.allCases where !seen.contains(profile) {
            throw E2EBenchmarkValidationError.missingImpairment(profile)
        }
    }

    func validateE2ERecovery() throws {
        try requireE2ENonNegative(recovery.reconnectEvents, "recovery.reconnectEvents")
        try requireE2ENonNegative(recovery.reconnectP99Microseconds, "recovery.reconnectP99Microseconds")
        try requireE2ENonNegative(
            recovery.leakedRealtimeCallbacksAfterShutdown,
            "recovery.leakedRealtimeCallbacksAfterShutdown"
        )
        try requireE2ENonEmpty(recovery.recoveryReportId, "recovery.recoveryReportId")
        try requireE2ENonEmpty(recovery.shutdownReportId, "recovery.shutdownReportId")
    }

    func validateE2EThresholds() throws {
        try requireE2ENonEmpty(thresholds.methodologyDocument, "thresholds.methodologyDocument")
        try requireE2EPercent(thresholds.packetLossMaxPercent, "thresholds.packetLossMaxPercent")
        try requireE2EPercent(thresholds.cpuP99MaxPercent, "thresholds.cpuP99MaxPercent")
        try requireE2ENonNegative(
            thresholds.audioP99DeltaFromBaselineToleranceMicroseconds,
            "thresholds.audioP99DeltaFromBaselineToleranceMicroseconds"
        )
        try requireE2ENonNegative(thresholds.audioUnderrunMaxCount, "thresholds.audioUnderrunMaxCount")
        try requireE2ENonNegative(thresholds.droppedFrameMaxCount, "thresholds.droppedFrameMaxCount")
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
        guard thresholds.methodologyDocument.contains("e2e-av-benchmark-methodology.md") else {
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
    try requireE2EPositive(metrics.sampleRateHertz, "\(field).sampleRateHertz")
    try requireE2EPositive(metrics.channelCount, "\(field).channelCount")
    try requireE2EPositive(metrics.framesPerBuffer, "\(field).framesPerBuffer")
    try validateE2ECounter(metrics.callbackDuration, "\(field).callbackDuration")
    try requireE2ENonNegative(metrics.oneWayLatencyMicroseconds, "\(field).oneWayLatencyMicroseconds")
    try requireE2ENonNegative(metrics.roundTripLatencyMicroseconds, "\(field).roundTripLatencyMicroseconds")
    try validateE2EPacketAge(metrics.jitter, "\(field).jitter")
    try requireE2ENonNegative(metrics.underruns, "\(field).underruns")
    try requireE2ENonNegative(metrics.overruns, "\(field).overruns")
    try requireE2EPositive(metrics.configuredChannelCount, "\(field).configuredChannelCount")
    try requireE2EFinite(
        metrics.audioP99DeltaFromBaselineMicroseconds,
        "\(field).audioP99DeltaFromBaselineMicroseconds"
    )
}

private func validateE2EVideo(_ metrics: E2EBenchmarkVideoMetrics, field: String) throws {
    try requireE2EPositive(metrics.streamCount, "\(field).streamCount")
    try requireE2EPositive(metrics.width, "\(field).width")
    try requireE2EPositive(metrics.height, "\(field).height")
    try requireE2EPositive(metrics.frameRate, "\(field).frameRate")
    try validateE2EPacketAge(metrics.captureLatency, "\(field).captureLatency")
    try validateE2ECounter(metrics.encodePacketizationLatency, "\(field).encodePacketizationLatency")
    try validateE2EPacketAge(metrics.receiveRenderLatency, "\(field).receiveRenderLatency")
    try requireE2ENonNegative(metrics.droppedFrames, "\(field).droppedFrames")
    try requireE2ENonEmpty(metrics.blackmagicCaptureReportId, "\(field).blackmagicCaptureReportId")
    try requireE2ENonEmpty(metrics.renderOutputReportId, "\(field).renderOutputReportId")
}

private func validateE2ENetwork(_ metrics: E2EBenchmarkNetworkMetrics, field: String) throws {
    try requireE2ENonNegative(metrics.throughputMegabitsPerSecond, "\(field).throughputMegabitsPerSecond")
    try requireE2ENonNegative(metrics.lostPackets, "\(field).lostPackets")
    try requireE2ENonNegative(metrics.latePackets, "\(field).latePackets")
    try requireE2ENonNegative(metrics.reorderedPackets, "\(field).reorderedPackets")
    try requireE2ENonNegative(metrics.duplicatePackets, "\(field).duplicatePackets")
    try requireE2EPercent(metrics.packetLossPercent, "\(field).packetLossPercent")
    try validateE2EPacketAge(metrics.jitter, "\(field).jitter")
}

private func validateE2EResources(_ metrics: E2EBenchmarkResourceMetrics, field: String) throws {
    try requireE2EPercent(metrics.cpuP99Percent, "\(field).cpuP99Percent")
    try requireE2EPercent(metrics.gpuP99Percent, "\(field).gpuP99Percent")
    try requireE2ENonNegative(metrics.residentMemoryMegabytes, "\(field).residentMemoryMegabytes")
    try requireE2ENonNegative(metrics.hotPathAllocationWarnings, "\(field).hotPathAllocationWarnings")
}

private func validateE2ECounter(_ counter: PerformanceCounterSummary, _ field: String) throws {
    try requireE2ENonNegative(counter.sampleCount, "\(field).sampleCount")
    try requireE2ENonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
    try requireE2ENonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
    try requireE2ENonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
    try requireE2ENonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
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
    try requireE2ENonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
    try requireE2ENonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
    try requireE2ENonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
    try requireE2ENonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw E2EBenchmarkValidationError.unorderedCounter(field)
    }
}

private func requireE2ENonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2ENonEmpty<T>(_ value: [T], _ field: String) throws {
    try ValidationPrimitives.requireNonEmptyList(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2EPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2EPositive(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2ENonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2ENonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2EFinite(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireFinite(value, field: field, error: E2EBenchmarkValidationError.self)
}

private func requireE2EPercent(_ value: Double, _ field: String) throws {
    guard value.isFinite else {
        throw E2EBenchmarkValidationError.nonFiniteField(field)
    }
    guard value >= 0, value <= 100 else {
        throw E2EBenchmarkValidationError.percentOutOfRange(field: field, value: value)
    }
}

private func isE2EPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder", "synthetic", "not-captured", "not captured", "required"],
        exactly: ["unknown", "tbd"]
    )
}
