/// Declares the capability-validation protocol inherited by audio and video negotiators, keeping shared session checks independent of either media-specific capability set.
public protocol SessionCapabilityValidating {
    func validateForSessionCapabilities() throws
}

/// Requires conformers to honor the stated operations for session audio capability negotiating.
public protocol SessionAudioCapabilityNegotiating: SessionCapabilityValidating {
    var supportedProtocolVersions: [AudioTransportProtocolVersion] { get }
    var supportedPayloadTypes: [SessionPayloadType] { get }
    var supportedAudioTransports: [DirectPeerSessionAudioTransport] { get }
    var channelSet: AudioChannelSet { get }
    var sampleRatesHertz: [Int] { get }
    var framesPerPacketOptions: [Int] { get }
    var sampleFormats: [UdpPcmSampleFormat] { get }
}

public extension SessionAudioCapabilityNegotiating {
    var supportedAudioTransports: [DirectPeerSessionAudioTransport] { [.openLolaRaw] }
}

/// Requires conformers to honor the stated operations for session video capability negotiating.
public protocol SessionVideoCapabilityNegotiating: SessionCapabilityValidating {
    var supportedRoles: [VideoStreamRole] { get }
    var supportedPixelFormats: [VideoPixelFormat] { get }
    var supportedTransportFormats: [VideoTransportFormat] { get }
    var maxWidth: Int { get }
    var maxHeight: Int { get }
    var maxFrameRateNumerator: Int { get }
    var maxEnabledStreams: Int { get }
}
