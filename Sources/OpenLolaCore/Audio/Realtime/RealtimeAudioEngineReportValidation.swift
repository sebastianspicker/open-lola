import Foundation

extension RealtimeAudioEngineReport {
    public func validate() throws {
        try validateIdentity()
        try validateConfiguration()
        try validateRuntime()
        try sourceRmeFastestAudioReport?.validate()
        try sourceRouteCertificationReport?.validate()
        try validatePassVerdict()
    }


    private func validateIdentity() throws {
        try RealtimeAudioEngineValidator.requireNonEmpty(id, "id")
        try RealtimeAudioEngineValidator.requireNonEmpty(title, "title")
        try RealtimeAudioEngineValidator.requireNonEmpty(capturedAt, "capturedAt")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try RealtimeAudioEngineValidator.requireNonEmpty(notes, "notes")
    }

    private func validateConfiguration() throws {
        try RealtimeAudioEngineValidator.requireNonEmpty(configuration.inputDeviceUID, "configuration.inputDeviceUID")
        try RealtimeAudioEngineValidator.requireNonEmpty(configuration.outputDeviceUID, "configuration.outputDeviceUID")
        try RealtimeAudioEngineValidator.requirePositive(configuration.sampleRateHertz, "configuration.sampleRateHertz")
        try RealtimeAudioEngineValidator.requirePositive(configuration.framesPerBuffer, "configuration.framesPerBuffer")
        try RealtimeAudioEngineValidator.requirePositive(configuration.channelCount, "configuration.channelCount")
        try RealtimeAudioEngineValidator.requireNonNegative(configuration.playoutTargetFrames, "configuration.playoutTargetFrames")
        try RealtimeAudioEngineValidator.requirePositive(
            configuration.preallocatedBlockCount,
            "configuration.preallocatedBlockCount"
        )
        if let rxBufferPolicy = configuration.rxBufferPolicy {
            try rxBufferPolicy.validate()
            guard rxBufferPolicy.targetFrames == configuration.playoutTargetFrames else {
                throw RealtimeAudioEngineValidationError.rxBufferPlayoutTargetMismatch(
                    policyFrames: rxBufferPolicy.targetFrames,
                    configurationFrames: configuration.playoutTargetFrames
                )
            }
        }
        try validateChannelMap(configuration.inputChannelMap, "configuration.inputChannelMap")
        try validateChannelMap(configuration.outputChannelMap, "configuration.outputChannelMap")
    }

    private func validateChannelMap(_ channelMap: [Int], _ field: String) throws {
        guard !channelMap.isEmpty else {
            throw RealtimeAudioEngineValidationError.emptyChannelMap(field)
        }
        guard channelMap.count == configuration.channelCount else {
            throw RealtimeAudioEngineValidationError.channelMapCountMismatch(
                field: field,
                expected: configuration.channelCount,
                actual: channelMap.count
            )
        }
        for index in channelMap {
            try RealtimeAudioEngineValidator.requireNonNegative(index, field)
        }
    }

    private func validateRuntime() throws {
        try validateCallback(runtime.callback)
        try validateHandoff(runtime.handoff)
        try RealtimeAudioEngineValidator.requirePositive(runtime.measuredDurationSeconds, "runtime.measuredDurationSeconds")
    }

    private func validateCallback(_ callback: EndpointCallbackMetrics) throws {
        try RealtimeAudioEngineValidator.requireNonNegative(callback.p50Microseconds, "runtime.callback.p50Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.p95Microseconds, "runtime.callback.p95Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.p99Microseconds, "runtime.callback.p99Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.maxMicroseconds, "runtime.callback.maxMicroseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.missedDeadlines, "runtime.callback.missedDeadlines")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.underruns, "runtime.callback.underruns")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.overruns, "runtime.callback.overruns")
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.recordedIntervalSamples,
            "runtime.callback.recordedIntervalSamples"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.droppedIntervalSamples,
            "runtime.callback.droppedIntervalSamples"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.hostTimeConversionFailures,
            "runtime.callback.hostTimeConversionFailures"
        )
        guard callback.p50Microseconds <= callback.p95Microseconds,
              callback.p95Microseconds <= callback.p99Microseconds,
              callback.p99Microseconds <= callback.maxMicroseconds else {
            throw RealtimeAudioEngineValidationError.unorderedCallbackMetrics
        }
    }

    private func validateHandoff(_ handoff: RealtimeAudioHandoffMetrics) throws {
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.inputBlocks, "runtime.handoff.inputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.outputBlocks, "runtime.handoff.outputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.networkSendBlocks, "runtime.handoff.networkSendBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.networkReceiveBlocks, "runtime.handoff.networkReceiveBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.droppedInputBlocks, "runtime.handoff.droppedInputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.droppedNetworkBlocks, "runtime.handoff.droppedNetworkBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.outputUnderrunBlocks, "runtime.handoff.outputUnderrunBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.callbackOverrunBlocks, "runtime.handoff.callbackOverrunBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.latePackets, "runtime.handoff.latePackets")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.maximumBufferedBlocks, "runtime.handoff.maximumBufferedBlocks")
        try RealtimeAudioEngineValidator.requirePositive(handoff.ringCapacityBlocks, "runtime.handoff.ringCapacityBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.fullCaptureRingBlocks, "runtime.handoff.fullCaptureRingBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.invalidInputBlocks, "runtime.handoff.invalidInputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.directInputBlocks, "runtime.handoff.directInputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.remappedInputBlocks, "runtime.handoff.remappedInputBlocks")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.packetFragmentCount, "runtime.handoff.packetFragmentCount")
        try RealtimeAudioEngineValidator.requireNonNegative(handoff.allocationWarnings, "runtime.handoff.allocationWarnings")
        try RealtimeAudioEngineValidator.requireNonNegative(
            handoff.maximumCaptureRingOccupancyBlocks,
            "runtime.handoff.maximumCaptureRingOccupancyBlocks"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            handoff.maximumPlayoutQueueDepthBlocks,
            "runtime.handoff.maximumPlayoutQueueDepthBlocks"
        )
        try validatePerformanceCounter(
            handoff.packetizationDuration,
            "runtime.handoff.packetizationDuration"
        )
        try validatePerformanceCounter(
            handoff.depacketizationDuration,
            "runtime.handoff.depacketizationDuration"
        )
        try handoff.rxBuffer?.validate()
    }

    private func validatePerformanceCounter(
        _ counter: PerformanceCounterSummary,
        _ field: String
    ) throws {
        try RealtimeAudioEngineValidator.requireNonNegative(counter.sampleCount, "\(field).sampleCount")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
        guard counter.p50Microseconds <= counter.p95Microseconds,
              counter.p95Microseconds <= counter.p99Microseconds,
              counter.p99Microseconds <= counter.maxMicroseconds else {
            throw RealtimeAudioEngineValidationError.unorderedPerformanceCounter(field)
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw RealtimeAudioEngineValidationError.passWithoutMeasuredRun
        }
        guard hardwarePath == .rmeMadi, isRealtimeRmeMadi(hardware.audioInterface) else {
            throw RealtimeAudioEngineValidationError.passWithoutRmeMadiPath
        }
        guard configuration.inputDeviceUID == configuration.outputDeviceUID else {
            throw RealtimeAudioEngineValidationError.passWithMismatchedInputOutputUID
        }
        guard let sourceRmeFastestAudioReport,
              sourceRmeFastestAudioReport.verdict == .pass else {
            throw RealtimeAudioEngineValidationError.passWithoutAcceptedRmeFastestAudioReport
        }
        guard let sourceRouteCertificationReport,
              sourceRouteCertificationReport.verdict == .pass else {
            throw RealtimeAudioEngineValidationError.passWithoutAcceptedRouteCertification
        }
        guard rmeModeMatchesConfiguration(sourceRmeFastestAudioReport.loopbackReport.selectedMode) else {
            throw RealtimeAudioEngineValidationError.passWithRmeModeMismatch
        }
        guard routeModeMatchesConfiguration(sourceRouteCertificationReport.packetMode) else {
            throw RealtimeAudioEngineValidationError.passWithRouteModeMismatch
        }
        guard sourceRouteCertificationReport.sourceRealtimeEngineReportId == id else {
            throw RealtimeAudioEngineValidationError.passWithRouteSourceMismatch(
                expected: id,
                actual: sourceRouteCertificationReport.sourceRealtimeEngineReportId
            )
        }
        if let rxBufferPolicy = configuration.rxBufferPolicy,
           !rxBufferPolicy.fastestAudioPassEligible {
            throw RealtimeAudioEngineValidationError.passWithFastestIneligibleRxBuffer(
                rxBufferPolicy.profile
            )
        }
        guard configuration.playoutTargetFrames == 0
                || configuration.playoutTargetFrames == configuration.framesPerBuffer else {
            throw RealtimeAudioEngineValidationError.passWithBufferedPlayoutTarget(
                playoutTargetFrames: configuration.playoutTargetFrames,
                framesPerBuffer: configuration.framesPerBuffer
            )
        }
        try validatePassRxBufferPolicy()
        guard runtime.handoff.ringCapacityBlocks == configuration.preallocatedBlockCount else {
            throw RealtimeAudioEngineValidationError.passWithRingCapacityMismatch(
                configured: configuration.preallocatedBlockCount,
                actual: runtime.handoff.ringCapacityBlocks
            )
        }
        guard runArtifactPath?.isEmpty == false else {
            throw RealtimeAudioEngineValidationError.passWithoutRunArtifactPath
        }
        for field in placeholderSensitiveFields() where isRealtimePlaceholder(field.value) {
            throw RealtimeAudioEngineValidationError.passWithPlaceholderField(field.name)
        }
        guard runtime.callbackOwner != .synthetic else {
            throw RealtimeAudioEngineValidationError.passWithSyntheticCallbackOwner
        }
        if let violation = safety.firstViolation {
            throw RealtimeAudioEngineValidationError.passWithCallbackSafetyViolation(violation)
        }
        guard runtime.callback.missedDeadlines == 0,
              runtime.callback.underruns == 0,
              runtime.callback.overruns == 0 else {
            throw RealtimeAudioEngineValidationError.passWithCallbackDeadlineMisses
        }
        guard runtime.handoff.droppedInputBlocks == 0,
              runtime.handoff.droppedNetworkBlocks == 0,
              runtime.handoff.outputUnderrunBlocks == 0,
              runtime.handoff.callbackOverrunBlocks == 0,
              runtime.handoff.latePackets == 0,
              runtime.handoff.fullCaptureRingBlocks == 0,
              runtime.handoff.invalidInputBlocks == 0,
              runtime.handoff.allocationWarnings == 0 else {
            throw RealtimeAudioEngineValidationError.passWithHandoffDropsOrUnderruns
        }
        guard runtime.handoff.maximumBufferedBlocks <= runtime.handoff.ringCapacityBlocks else {
            throw RealtimeAudioEngineValidationError.passWithUnboundedHandoff
        }
        guard !runtime.handoff.hiddenPlayoutGrowthDetected else {
            throw RealtimeAudioEngineValidationError.passWithHiddenPlayoutGrowth
        }
        guard runtime.handoff.shutdownCompleted else {
            throw RealtimeAudioEngineValidationError.passWithoutShutdown
        }
        guard runtime.udpSocketsPreparedBeforeStart else {
            throw RealtimeAudioEngineValidationError.passWithoutUdpPreparedBeforeStart
        }
        guard runtime.reportWrittenAfterStop else {
            throw RealtimeAudioEngineValidationError.passWithReportWritingBeforeStop
        }
        guard runtime.handoff.inputBlocks > 0,
              runtime.handoff.outputBlocks > 0,
              runtime.handoff.networkSendBlocks > 0,
              runtime.handoff.networkReceiveBlocks > 0 else {
            throw RealtimeAudioEngineValidationError.passWithoutPacketHandoff
        }
        guard runtime.handoff.inputBlocks == runtime.handoff.outputBlocks,
              runtime.handoff.inputBlocks == runtime.handoff.networkSendBlocks,
              runtime.handoff.inputBlocks == runtime.handoff.networkReceiveBlocks else {
            throw RealtimeAudioEngineValidationError.passWithPacketHandoffMismatch
        }
        let periodMicroseconds = callbackPeriodMicroseconds
        guard runtime.callback.maxMicroseconds <= periodMicroseconds else {
            throw RealtimeAudioEngineValidationError.passCallbackExceededPeriod(
                maxMicroseconds: runtime.callback.maxMicroseconds,
                periodMicroseconds: periodMicroseconds
            )
        }
    }

    private func validatePassRxBufferPolicy() throws {
        let explicitConfigured = configuration.rxBufferPolicy
        let configured = try explicitConfigured ?? defaultDirectRxBufferPolicy()
        let observed = runtime.handoff.rxBuffer

        if observed == nil {
            throw RealtimeAudioEngineValidationError.passWithoutRuntimeRxBufferSnapshot(
                configured.profile
            )
        }
        if let observed, explicitConfigured != nil, configured != observed.policy {
            throw RealtimeAudioEngineValidationError.rxBufferRuntimePolicyMismatch(
                configured: configured.profile,
                observed: observed.policy.profile
            )
        }
        if let observed, !observed.policy.fastestAudioPassEligible {
                throw RealtimeAudioEngineValidationError.passWithFastestIneligibleRxBuffer(
                    observed.policy.profile
                )
            }
        if !configured.fastestAudioPassEligible {
            throw RealtimeAudioEngineValidationError.passWithFastestIneligibleRxBuffer(
                configured.profile
            )
        }
        if let observed {
            guard observed.currentTargetFrames == configuration.playoutTargetFrames else {
                throw RealtimeAudioEngineValidationError.rxBufferPlayoutTargetMismatch(
                    policyFrames: observed.currentTargetFrames,
                    configurationFrames: configuration.playoutTargetFrames
                )
            }
            guard observed.maximumObservedTargetFrames <= observed.policy.maximumTargetFrames,
                  observed.maximumObservedBufferedPackets <= observed.policy.maximumTargetPackets,
                  !observed.hiddenGrowthDetected else {
                throw RealtimeAudioEngineValidationError.passWithHiddenPlayoutGrowth
            }
        }
    }

    private func defaultDirectRxBufferPolicy() throws -> RxBufferPolicy {
        try RealtimeAudioEngineValidator.requirePositive(configuration.framesPerBuffer, "configuration.framesPerBuffer")
        let targetPackets = configuration.playoutTargetFrames / configuration.framesPerBuffer
        return try RxBufferPolicy.direct(
            framesPerPacket: configuration.framesPerBuffer,
            sampleRateHertz: configuration.sampleRateHertz,
            targetPackets: targetPackets
        )
    }

    private var callbackPeriodMicroseconds: Double {
        (Double(configuration.framesPerBuffer) / Double(configuration.sampleRateHertz))
            * 1_000_000
    }

    private func rmeModeMatchesConfiguration(_ mode: AudioMode) -> Bool {
        mode.sampleRateHertz == configuration.sampleRateHertz
            && mode.framesPerBuffer == configuration.framesPerBuffer
            && mode.channelCount == configuration.channelCount
    }

    private func routeModeMatchesConfiguration(_ mode: UdpPcmPacketMode) -> Bool {
        mode.sampleRateHertz == configuration.sampleRateHertz
            && mode.framesPerPacket == configuration.framesPerBuffer
            && mode.channelCount == configuration.channelCount
            && mode.sampleFormat == configuration.packetFormat
    }

    private static let requiredStaticPlaceholderFieldNames = [
        "id",
        "title",
        "capturedAt",
        "hardware.referenceMac",
        "hardware.audioInterface",
        "hardware.osVersion",
        "hardware.driverVersion",
        "configuration.inputDeviceUID",
        "configuration.outputDeviceUID",
        "runArtifactPath",
        "notes",
    ]

    private func placeholderSensitiveFields() -> [(name: String, value: String)] {
        let staticFields: [(name: String, value: String)] = [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("hardware.referenceMac", hardware.referenceMac),
            ("hardware.audioInterface", hardware.audioInterface),
            ("hardware.osVersion", hardware.osVersion),
            ("hardware.driverVersion", hardware.driverVersion),
            ("configuration.inputDeviceUID", configuration.inputDeviceUID),
            ("configuration.outputDeviceUID", configuration.outputDeviceUID),
            ("runArtifactPath", runArtifactPath ?? ""),
            ("notes", notes),
        ]
        precondition(
            Set(staticFields.map { $0.name }) == Set(Self.requiredStaticPlaceholderFieldNames),
            "Realtime audio engine placeholder field checklist mismatch"
        )
        return staticFields
    }
}
