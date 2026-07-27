// Validates SessionNegotiationVideoValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension SessionNegotiation {
    static func validateVideoStreams(
        _ streams: [VideoStreamDescription],
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        let enabledCount = streams.filter(\.isEnabled).count
        let maximumEnabledStreams = min(proposer.maxEnabledStreams, responder.maxEnabledStreams)
        if enabledCount > maximumEnabledStreams {
            throw SessionValidationError.tooManyEnabledVideoStreams(
                requested: enabledCount,
                maximum: maximumEnabledStreams
            )
        }
        for stream in streams {
            try validateVideoStream(stream, proposer: proposer, responder: responder)
        }
    }

    static func validateVideoStream(
        _ stream: VideoStreamDescription,
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        try validateVideoStreamRole(stream, proposer: proposer, responder: responder)
        guard stream.isEnabled else {
            return
        }
        try validateVideoStreamFormat(stream, proposer: proposer, responder: responder)
        try validateVideoStreamResolution(stream, proposer: proposer, responder: responder)
        try validateVideoStreamFrameRate(stream, proposer: proposer, responder: responder)
    }

    static func validateVideoStreamRole(
        _ stream: VideoStreamDescription,
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        guard proposer.supportedRoles.contains(stream.role),
              responder.supportedRoles.contains(stream.role) else {
            throw SessionValidationError.unsupportedVideoRole(stream.role)
        }
    }

    static func validateVideoStreamFormat(
        _ stream: VideoStreamDescription,
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        guard proposer.supportedPixelFormats.contains(stream.pixelFormat),
              responder.supportedPixelFormats.contains(stream.pixelFormat) else {
            throw SessionValidationError.unsupportedVideoPixelFormat(stream.pixelFormat)
        }
        guard proposer.supportedTransportFormats.contains(stream.transportFormat),
              responder.supportedTransportFormats.contains(stream.transportFormat) else {
            throw SessionValidationError.unsupportedVideoTransportFormat(stream.transportFormat)
        }
    }

    static func validateVideoStreamResolution(
        _ stream: VideoStreamDescription,
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        let maxWidth = min(proposer.maxWidth, responder.maxWidth)
        let maxHeight = min(proposer.maxHeight, responder.maxHeight)
        if stream.resolution.width > maxWidth || stream.resolution.height > maxHeight {
            throw SessionValidationError.unsupportedVideoResolution(
                width: stream.resolution.width,
                height: stream.resolution.height
            )
        }
    }

    static func validateVideoStreamFrameRate(
        _ stream: VideoStreamDescription,
        proposer: some SessionVideoCapabilityNegotiating,
        responder: some SessionVideoCapabilityNegotiating
    ) throws {
        let maxFrameRate = min(
            proposer.maxFrameRateNumerator,
            responder.maxFrameRateNumerator
        )
        guard stream.frameRate.numerator > 0,
              stream.frameRate.denominator > 0 else {
            throw SessionValidationError.unsupportedVideoFrameRate(
                numerator: stream.frameRate.numerator,
                denominator: stream.frameRate.denominator
            )
        }
        let (maximumFrameRateNumerator, overflow) = maxFrameRate.multipliedReportingOverflow(
            by: stream.frameRate.denominator
        )
        if overflow ||
            stream.frameRate.numerator > maximumFrameRateNumerator {
            throw SessionValidationError.unsupportedVideoFrameRate(
                numerator: stream.frameRate.numerator,
                denominator: stream.frameRate.denominator
            )
        }
    }
}
