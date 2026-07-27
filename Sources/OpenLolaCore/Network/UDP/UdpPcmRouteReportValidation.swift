// Validates UdpPcmRouteReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension UdpPcmRouteReport {
    public func validate() throws {
        try validateIdentity()
        try validatePacketMode()
        try validateNetwork()
        try validateMetrics()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireRouteNonEmpty(id, "id")
        try requireRouteNonEmpty(title, "title")
        try requireRouteNonEmpty(capturedAt, "capturedAt")
        try requireRouteNonEmpty(route.label, "route.label")
        try requireRouteNonEmpty(route.topology, "route.topology")
        try requireRouteNonEmpty(sender.label, "sender.label")
        try requireRouteNonEmpty(sender.hostName, "sender.hostName")
        try requireRouteNonEmpty(sender.interfaceName, "sender.interfaceName")
        try requireRouteNonEmpty(sender.ipAddress, "sender.ipAddress")
        try requireRouteNonEmpty(receiver.label, "receiver.label")
        try requireRouteNonEmpty(receiver.hostName, "receiver.hostName")
        try requireRouteNonEmpty(receiver.interfaceName, "receiver.interfaceName")
        try requireRouteNonEmpty(receiver.ipAddress, "receiver.ipAddress")
        try requireRouteNonEmpty(notes, "notes")
    }

    private func validatePacketMode() throws {
        try requireRoutePositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try requireRoutePositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try requireRoutePositive(packetMode.channelCount, "packetMode.channelCount")
    }

    private func validateNetwork() throws {
        try requireRouteNonEmpty(network.vlan, "network.vlan")
        try requireRouteNonEmpty(network.multicastPolicy, "network.multicastPolicy")
        try requireRouteNonEmpty(network.packetCapture.notes, "network.packetCapture.notes")
        if let point = network.packetCapture.point {
            try requireRouteNonEmpty(point, "network.packetCapture.point")
        }
        if let linkRateMbps = network.linkRateMbps {
            try requireRoutePositive(linkRateMbps, "network.linkRateMbps")
        }
        try validateDscp(network.dscp)
    }

    private func validateDscp(_ dscp: UdpPcmDscpObservation) throws {
        if let requested = dscp.requested {
            try requireDscpRange(requested)
        }
        if let observed = dscp.observed {
            try requireDscpRange(observed)
        }

        if dscp.classification == .notTested {
            guard dscp.notTestedReason?.isEmpty == false else {
                throw UdpPcmRouteValidationError.missingDscpNotTestedReason
            }
            return
        }

        guard dscp.observed != nil else {
            throw UdpPcmRouteValidationError.missingDscpObservedValue
        }
    }

    private func validateMetrics() throws {
        if let measuredDurationSeconds {
            try requireRoutePositive(measuredDurationSeconds, "measuredDurationSeconds")
        }
        try requireRoutePositive(metrics.packetsSent, "metrics.packetsSent")
        try requireRouteNonNegative(metrics.packetsReceived, "metrics.packetsReceived")
        try requireRouteNonNegative(metrics.lostPackets, "metrics.lostPackets")
        try requireRouteNonNegative(metrics.latePackets, "metrics.latePackets")
        try requireRouteNonNegative(metrics.reorderedPackets, "metrics.reorderedPackets")
        try requireRouteNonNegative(metrics.duplicatePackets, "metrics.duplicatePackets")
        try requireRouteNonNegative(metrics.receiveErrors, "metrics.receiveErrors")
        try requireRouteNonNegative(metrics.packetAge.p50Microseconds, "metrics.packetAge.p50Microseconds")
        try requireRouteNonNegative(metrics.packetAge.p95Microseconds, "metrics.packetAge.p95Microseconds")
        try requireRouteNonNegative(metrics.packetAge.p99Microseconds, "metrics.packetAge.p99Microseconds")
        try requireRouteNonNegative(metrics.packetAge.maxMicroseconds, "metrics.packetAge.maxMicroseconds")
        if let callbackP99Microseconds = metrics.callbackP99Microseconds {
            try requireRouteNonNegative(callbackP99Microseconds, "metrics.callbackP99Microseconds")
        }
        if let callbackMaxMicroseconds = metrics.callbackMaxMicroseconds {
            try requireRouteNonNegative(callbackMaxMicroseconds, "metrics.callbackMaxMicroseconds")
        }
        try requireRouteNonNegative(metrics.jitterP99Microseconds, "metrics.jitterP99Microseconds")
        try requireRoutePositive(metrics.playoutTargetMicroseconds, "metrics.playoutTargetMicroseconds")
        try metrics.rxBuffer?.validate()

        guard metrics.packetAge.p50Microseconds <= metrics.packetAge.p95Microseconds,
              metrics.packetAge.p95Microseconds <= metrics.packetAge.p99Microseconds,
              metrics.packetAge.p99Microseconds <= metrics.packetAge.maxMicroseconds else {
            throw UdpPcmRouteValidationError.unorderedPacketAge
        }
        if let callbackP99Microseconds = metrics.callbackP99Microseconds,
           let callbackMaxMicroseconds = metrics.callbackMaxMicroseconds,
           callbackP99Microseconds > callbackMaxMicroseconds {
            throw UdpPcmRouteValidationError.unorderedPacketAge
        }

        let uniquePacketsReceived = max(0, metrics.packetsReceived - metrics.duplicatePackets)
        let expectedLost = max(0, metrics.packetsSent - uniquePacketsReceived)
        if metrics.lostPackets != expectedLost {
            throw UdpPcmRouteValidationError.packetAccountingMismatch(
                expectedLost: expectedLost,
                actualLost: metrics.lostPackets
            )
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        try validatePassRouteAndPacketCount()
        try validatePassNetworkEvidence()
        try validatePassPlayoutTiming()
        try validatePassPacketHealth()
        try validatePassRxBuffer()
        try validatePassDscpSafety()
        try validatePassPlaceholderFields()
    }

    private func validatePassRouteAndPacketCount() throws {
        guard routeKind != .localhostSmoke else {
            throw UdpPcmRouteValidationError.passWithNonPhysicalRoute(routeKind)
        }
        guard let measuredDurationSeconds else {
            throw UdpPcmRouteValidationError.passWithoutMeasuredDuration
        }
        let expectedPackets = expectedPacketCount(
            durationSeconds: measuredDurationSeconds,
            packetMode: packetMode
        )
        guard metrics.packetsSent == expectedPackets else {
            throw UdpPcmRouteValidationError.passWithDurationPacketCountMismatch(
                expected: expectedPackets,
                actual: metrics.packetsSent
            )
        }
    }

    private func validatePassNetworkEvidence() throws {
        for field in documentationIPAddressFields()
            where isDocumentationIPAddress(field.value) {
            throw UdpPcmRouteValidationError.passWithDocumentationIPAddress(field.name)
        }
        guard network.packetCapture.receiverCorrelation == true else {
            throw UdpPcmRouteValidationError.passWithoutPacketCaptureCorrelation
        }
        if network.dscp.classification == .notTested {
            throw UdpPcmRouteValidationError.passWithoutDscpClassification
        }
    }

    private func validatePassPlayoutTiming() throws {
        let expectedPlayoutTarget = playoutTargetMicroseconds(packetMode)
        if !nearlyEqualMicroseconds(metrics.playoutTargetMicroseconds, expectedPlayoutTarget) {
            throw UdpPcmRouteValidationError.passWithBufferedPlayoutTarget(
                actualMicroseconds: metrics.playoutTargetMicroseconds,
                expectedMicroseconds: expectedPlayoutTarget
            )
        }
        if metrics.packetAge.maxMicroseconds > metrics.playoutTargetMicroseconds {
            throw UdpPcmRouteValidationError.passPacketAgeExceedsTarget(
                maxMicroseconds: metrics.packetAge.maxMicroseconds,
                targetMicroseconds: metrics.playoutTargetMicroseconds
            )
        }
    }

    private func validatePassPacketHealth() throws {
        if metrics.packetsReceived <= 0 {
            throw UdpPcmRouteValidationError.passWithoutReceivedPackets
        }
        if metrics.receiveErrors > 0 {
            throw UdpPcmRouteValidationError.passWithReceiveErrors
        }
        if metrics.lostPackets > 0 || metrics.latePackets > 0 {
            throw UdpPcmRouteValidationError.passWithLossOrLatePackets
        }
        if metrics.duplicatePackets > 0 || metrics.reorderedPackets > 0 {
            throw UdpPcmRouteValidationError.passWithDuplicateOrReorderedPackets
        }
        if metrics.hiddenPlayoutGrowthDetected {
            throw UdpPcmRouteValidationError.passWithHiddenPlayoutGrowth
        }
    }

    private func validatePassRxBuffer() throws {
        if let rxBuffer = metrics.rxBuffer {
            guard rxBuffer.policy.fastestAudioPassEligible else {
                throw UdpPcmRouteValidationError.passWithFastestIneligibleRxBuffer(
                    rxBuffer.policy.profile
                )
            }
            guard !rxBuffer.hiddenGrowthDetected else {
                throw UdpPcmRouteValidationError.passWithHiddenPlayoutGrowth
            }
        }
    }

    private func validatePassDscpSafety() throws {
        if network.dscp.classification == .harmful {
            throw UdpPcmRouteValidationError.passWithHarmfulDscp
        }
    }

    private func validatePassPlaceholderFields() throws {
        for field in placeholderSensitiveFields() where isRoutePlaceholder(field.value) {
            throw UdpPcmRouteValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func documentationIPAddressFields() -> [(name: String, value: String)] {
        [
            ("sender.ipAddress", sender.ipAddress),
            ("receiver.ipAddress", receiver.ipAddress)
        ]
    }

    private func placeholderSensitiveFields() -> [(name: String, value: String)] {
        [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("route.label", route.label),
            ("route.topology", route.topology),
            ("sender.label", sender.label),
            ("sender.hostName", sender.hostName),
            ("sender.interfaceName", sender.interfaceName),
            ("sender.ipAddress", sender.ipAddress),
            ("receiver.label", receiver.label),
            ("receiver.hostName", receiver.hostName),
            ("receiver.interfaceName", receiver.interfaceName),
            ("receiver.ipAddress", receiver.ipAddress),
            ("network.vlan", network.vlan),
            ("network.multicastPolicy", network.multicastPolicy),
            ("network.packetCapture.point", network.packetCapture.point ?? ""),
            ("network.packetCapture.notes", network.packetCapture.notes),
            ("notes", notes)
        ]
    }
}
