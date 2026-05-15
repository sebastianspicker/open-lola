import Foundation

public struct NativeAppShellAudioDeviceOption: Codable, Equatable, Sendable {
    public let name: String
    public let uid: String
    public let inputChannelCount: Int
    public let outputChannelCount: Int
    public let nominalSampleRateHertz: Double?
    public let currentBufferFrameSize: UInt32?

    public init(
        name: String,
        uid: String,
        inputChannelCount: Int,
        outputChannelCount: Int,
        nominalSampleRateHertz: Double?,
        currentBufferFrameSize: UInt32?
    ) {
        self.name = name
        self.uid = uid
        self.inputChannelCount = inputChannelCount
        self.outputChannelCount = outputChannelCount
        self.nominalSampleRateHertz = nominalSampleRateHertz
        self.currentBufferFrameSize = currentBufferFrameSize
    }

    public init(device: CoreAudioDeviceInventory) {
        self.init(
            name: device.name,
            uid: device.uid,
            inputChannelCount: device.inputChannelCount,
            outputChannelCount: device.outputChannelCount,
            nominalSampleRateHertz: device.nominalSampleRateHertz,
            currentBufferFrameSize: device.currentBufferFrameSize
        )
    }

    public var supportsInput: Bool {
        inputChannelCount > 0
    }

    public var supportsOutput: Bool {
        outputChannelCount > 0
    }
}

public struct NativeAppShellVideoDeviceOption: Codable, Equatable, Sendable {
    public let label: String
    public let uniqueId: String
    public let manufacturer: String
    public let transport: String
    public let sourcePolicy: AVFoundationVideoSourcePolicy
    public let formatCount: Int

    public init(
        label: String,
        uniqueId: String,
        manufacturer: String,
        transport: String,
        sourcePolicy: AVFoundationVideoSourcePolicy,
        formatCount: Int
    ) {
        self.label = label
        self.uniqueId = uniqueId
        self.manufacturer = manufacturer
        self.transport = transport
        self.sourcePolicy = sourcePolicy
        self.formatCount = formatCount
    }

    public init(device: AVFoundationVideoDeviceDescription) {
        self.init(
            label: device.label,
            uniqueId: device.uniqueId,
            manufacturer: device.manufacturer,
            transport: device.transport,
            sourcePolicy: device.sourcePolicy,
            formatCount: device.formats.count
        )
    }
}
