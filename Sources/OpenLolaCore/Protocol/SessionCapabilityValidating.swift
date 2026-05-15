public protocol SessionCapabilityValidating {
    func validateForSessionCapabilities() throws
}

public protocol SessionAudioCapabilityNegotiating: SessionCapabilityValidating {
    var supportedProtocolVersions: [AudioTransportProtocolVersion] { get }
    var supportedPayloadTypes: [SessionPayloadType] { get }
    var channelSet: AudioChannelSet { get }
    var sampleRatesHertz: [Int] { get }
    var framesPerPacketOptions: [Int] { get }
    var sampleFormats: [UdpPcmSampleFormat] { get }
}

public protocol SessionVideoCapabilityNegotiating: SessionCapabilityValidating {
    var supportedRoles: [VideoStreamRole] { get }
    var supportedPixelFormats: [VideoPixelFormat] { get }
    var supportedTransportFormats: [VideoTransportFormat] { get }
    var maxWidth: Int { get }
    var maxHeight: Int { get }
    var maxFrameRateNumerator: Int { get }
    var maxEnabledStreams: Int { get }
}
