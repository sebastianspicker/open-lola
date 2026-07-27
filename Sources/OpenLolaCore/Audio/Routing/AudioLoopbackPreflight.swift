// Performs AudioLoopbackPreflight readiness checks before a run, keeping start-blocking conditions out of the runtime loop.
import Foundation

private struct AudioLoopbackPreflightDeviceSelection {
    let inputDevice: CoreAudioDeviceInventory?
    let outputDevice: CoreAudioDeviceInventory?
    let rmeMadiVisible: Bool

    init(
        configuration: AudioLoopbackRunConfiguration,
        inventory: CoreAudioInventoryReport
    ) {
        self.inputDevice = inventory.devices.first { $0.uid == configuration.inputUID }
        self.outputDevice = inventory.devices.first { $0.uid == configuration.outputUID }
        self.rmeMadiVisible = inventory.devices.contains { isAudioLoopbackRmeMadiDevice($0) }
    }
}

/// Records `inputDevice`, `outputDevice`, `rmeMadiVisible`, and `sampleRateSupported` before loopback routing claims it can start safely.
public struct AudioLoopbackPreflight: Codable, Equatable, Sendable {
    public let inputDevice: CoreAudioDeviceInventory?
    public let outputDevice: CoreAudioDeviceInventory?
    public let rmeMadiVisible: Bool
    public let sampleRateSupported: Bool
    public let frameSizeInReportedRange: Bool
    public let canStartIOProc: Bool
    public let blockers: [String]

    public init(
        inputDevice: CoreAudioDeviceInventory?,
        outputDevice: CoreAudioDeviceInventory?,
        rmeMadiVisible: Bool,
        sampleRateSupported: Bool,
        frameSizeInReportedRange: Bool,
        canStartIOProc: Bool,
        blockers: [String]
    ) {
        self.inputDevice = inputDevice
        self.outputDevice = outputDevice
        self.rmeMadiVisible = rmeMadiVisible
        self.sampleRateSupported = sampleRateSupported
        self.frameSizeInReportedRange = frameSizeInReportedRange
        self.canStartIOProc = canStartIOProc
        self.blockers = blockers
    }

    public static func evaluate(
        configuration: AudioLoopbackRunConfiguration,
        inventory: CoreAudioInventoryReport
    ) -> AudioLoopbackPreflight {
        let devices = AudioLoopbackPreflightDeviceSelection(
            configuration: configuration,
            inventory: inventory
        )
        let sampleRateSupported = Self.sampleRateSupported(
            configuration: configuration,
            devices: devices
        )
        let frameSizeInReportedRange = Self.frameSizeInReportedRange(
            configuration: configuration,
            devices: devices
        )
        let blockers = Self.blockers(
            configuration: configuration,
            devices: devices
        )

        return AudioLoopbackPreflight(
            inputDevice: devices.inputDevice,
            outputDevice: devices.outputDevice,
            rmeMadiVisible: devices.rmeMadiVisible,
            sampleRateSupported: sampleRateSupported,
            frameSizeInReportedRange: frameSizeInReportedRange,
            canStartIOProc: blockers.isEmpty,
            blockers: blockers
        )
    }

    private static func sampleRateSupported(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> Bool {
        devices.inputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true && devices.outputDevice.map {
            supportsSampleRate($0, configuration.sampleRateHertz)
        } == true
    }

    private static func frameSizeInReportedRange(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> Bool {
        devices.inputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true && devices.outputDevice.map {
            supportsFrameSize($0, configuration.framesPerBuffer)
        } == true
    }

    private static func blockers(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> [String] {
        deviceSelectionBlockers(configuration: configuration, devices: devices)
            + rmePolicyBlockers(devices: devices)
            + sampleRateBlockers(configuration: configuration, devices: devices)
            + frameSizeBlockers(configuration: configuration, devices: devices)
            + latencyProfileBlockers(configuration: configuration)
    }

    private static func deviceSelectionBlockers(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> [String] {
        var blockers: [String] = []
        if devices.inputDevice == nil {
            blockers.append("input UID not found")
        }
        if devices.outputDevice == nil {
            blockers.append("output UID not found")
        }
        if configuration.inputUID != configuration.outputUID {
            blockers.append("separate input/output devices require a same-device full-duplex RME path")
        }
        if devices.inputDevice?.inputChannelCount ?? 0 <= 0 {
            blockers.append("input device has no input channels")
        }
        if devices.outputDevice?.outputChannelCount ?? 0 <= 0 {
            blockers.append("output device has no output channels")
        }
        if let inputDevice = devices.inputDevice,
           !channelMapFits(configuration.inputChannelMap, available: inputDevice.inputChannelCount) {
            blockers.append("requested input channel map exceeds input device channels")
        }
        if let outputDevice = devices.outputDevice,
           !channelMapFits(configuration.outputChannelMap, available: outputDevice.outputChannelCount) {
            blockers.append("requested output channel map exceeds output device channels")
        }
        return blockers
    }

    private static func rmePolicyBlockers(
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> [String] {
        var blockers: [String] = []
        if !devices.rmeMadiVisible {
            blockers.append("RME MADI device is not visible")
        }
        if let inputDevice = devices.inputDevice, !isAudioLoopbackRmeMadiDevice(inputDevice) {
            blockers.append("input device is not RME MADI")
        }
        if let outputDevice = devices.outputDevice, !isAudioLoopbackRmeMadiDevice(outputDevice) {
            blockers.append("output device is not RME MADI")
        }
        return blockers
    }

    private static func sampleRateBlockers(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> [String] {
        var blockers: [String] = []
        if let inputDevice = devices.inputDevice,
           !supportsSampleRate(inputDevice, configuration.sampleRateHertz) {
            blockers.append("requested sample rate is outside reported input range")
        }
        if let outputDevice = devices.outputDevice,
           !supportsSampleRate(outputDevice, configuration.sampleRateHertz) {
            blockers.append("requested sample rate is outside reported output range")
        }
        return blockers
    }

    private static func frameSizeBlockers(
        configuration: AudioLoopbackRunConfiguration,
        devices: AudioLoopbackPreflightDeviceSelection
    ) -> [String] {
        var blockers: [String] = []
        if let inputDevice = devices.inputDevice,
           !supportsFrameSize(inputDevice, configuration.framesPerBuffer) {
            blockers.append("requested frame size is outside reported input range")
        }
        if let outputDevice = devices.outputDevice,
           !supportsFrameSize(outputDevice, configuration.framesPerBuffer) {
            blockers.append("requested frame size is outside reported output range")
        }
        return blockers
    }

    private static func latencyProfileBlockers(
        configuration: AudioLoopbackRunConfiguration
    ) -> [String] {
        if configuration.latencyProfile == .extremeLowLatency8,
           !configuration.experimentalEightFrameOptIn {
            return ["8-frame experimental profile requires explicit opt-in"]
        }
        return []
    }
}
