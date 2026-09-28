// Captures hardware and audio-mode identity fields shared by measurement evidence.

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a measurement result.
public struct HardwareIdentity: Codable, Equatable, Sendable {
    public let referenceMac: String
    public let audioInterface: String
    public let osVersion: String
    public let driverVersion: String

    public init(
        referenceMac: String,
        audioInterface: String,
        osVersion: String,
        driverVersion: String
    ) {
        self.referenceMac = referenceMac
        self.audioInterface = audioInterface
        self.osVersion = osVersion
        self.driverVersion = driverVersion
    }
}

/// Captures operating mode required to validate, interpret, and reproduce a measurement result.
public struct AudioMode: Codable, Equatable, Sendable {
    public let sampleRateHertz: Int
    public let framesPerBuffer: Int
    public let channelCount: Int
    public let sampleFormat: String

    public init(
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        channelCount: Int,
        sampleFormat: String
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
    }
}
