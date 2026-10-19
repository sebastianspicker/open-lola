// Renders AppCoreAudioInputMeterTap in the operator UI, keeping presentation and user affordances separate from execution state.
import CoreAudio
import Foundation
import OpenLolaCore
import os

final class AppCoreAudioInputMeterTap: @unchecked Sendable {
    /// Callback-visible storage; each IOProc registration holds its own retain so late callbacks stay valid.
    private let state = AppCoreAudioInputMeterCallbackState()
    private var lock = os_unfair_lock_s()
    private var deviceID: AudioObjectID?
    private var ioProcID: AudioDeviceIOProcID?
    private var inputSampleFormat: AppCoreAudioInputMeterSampleFormat?

    deinit {
        stop()
    }

    func start(inputUID: String) throws {
        stop()
        let report = try CoreAudioInventoryReader().capture()
        guard let device = report.devices.first(where: { $0.uid == inputUID && $0.inputChannelCount > 0 }) else {
            throw AppCoreAudioInputMeterError.inputDeviceUnavailable(inputUID)
        }
        let selectedDeviceID = AudioObjectID(device.id)
        let selectedSampleFormat = try Self.inputSampleFormat(for: selectedDeviceID)
        var createdIOProcID: AudioDeviceIOProcID?
        var status = AudioDeviceCreateIOProcID(
            selectedDeviceID,
            appCoreAudioInputMeterIOProc,
            state.retainedRegistration(),
            &createdIOProcID
        )
        guard status == noErr, let createdIOProcID else {
            // No registration exists, so the retain taken for it is returned here.
            state.releaseRegistration()
            try throwAudioMeterStatusIfNeeded(status, "create AudioDeviceIOProcID")
            throw AppCoreAudioInputMeterError.ioProcUnavailable
        }
        os_unfair_lock_lock(&lock)
        deviceID = selectedDeviceID
        ioProcID = createdIOProcID
        inputSampleFormat = selectedSampleFormat
        os_unfair_lock_unlock(&lock)
        state.setActive(true, canReadFloat32: selectedSampleFormat == .float32)
        status = AudioDeviceStart(selectedDeviceID, createdIOProcID)
        if status != noErr {
            state.setActive(false, canReadFloat32: false)
            os_unfair_lock_lock(&lock)
            deviceID = nil
            ioProcID = nil
            inputSampleFormat = nil
            os_unfair_lock_unlock(&lock)
            destroyRegistration(deviceID: selectedDeviceID, ioProcID: createdIOProcID)
        }
        try throwAudioMeterStatusIfNeeded(status, "start AudioDeviceIOProc")
    }

    func stop() {
        state.setActive(false, canReadFloat32: false)
        os_unfair_lock_lock(&lock)
        let currentDeviceID = deviceID
        let currentIOProcID = ioProcID
        self.deviceID = nil
        self.ioProcID = nil
        inputSampleFormat = nil
        os_unfair_lock_unlock(&lock)
        if let currentDeviceID, let currentIOProcID {
            AudioDeviceStop(currentDeviceID, currentIOProcID)
            destroyRegistration(deviceID: currentDeviceID, ioProcID: currentIOProcID)
        }
        state.clearLevels()
    }

    /// Releases the registration retain only once the HAL confirms the IOProc is gone; a failed destroy keeps the state alive.
    private func destroyRegistration(deviceID: AudioObjectID, ioProcID: AudioDeviceIOProcID) {
        if AudioDeviceDestroyIOProcID(deviceID, ioProcID) == noErr {
            state.releaseRegistration()
        }
    }

    func snapshot(gain: Double) -> [Double] {
        state.snapshot(gain: gain)
    }

    private static func inputSampleFormat(for deviceID: AudioObjectID) throws -> AppCoreAudioInputMeterSampleFormat {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var byteCount = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
        try throwAudioMeterStatusIfNeeded(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &byteCount, &format),
            "read input stream format"
        )
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32,
              format.mBytesPerFrame >= UInt32(MemoryLayout<Float32>.stride),
              (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else {
            throw AppCoreAudioInputMeterError.unsupportedInputFormat(audioMeterFormatDescription(format))
        }
        return .float32
    }
}

enum AppCoreAudioInputMeterError: Error, Equatable {
    case inputDeviceUnavailable(String)
    case ioProcUnavailable
    case unsupportedInputFormat(String)
    case coreAudioStatus(OSStatus, String)
}

private enum AppCoreAudioInputMeterSampleFormat: Equatable {
    case float32
}

private func throwAudioMeterStatusIfNeeded(_ status: OSStatus, _ operation: String) throws {
    if status != noErr {
        throw AppCoreAudioInputMeterError.coreAudioStatus(
            status,
            "\(operation): \(audioMeterStatusDescription(status))"
        )
    }
}

private func audioMeterStatusDescription(_ status: OSStatus) -> String {
    if status == kAudioHardwareUnsupportedOperationError {
        return "unsupported CoreAudio operation"
    }
    return "CoreAudio OSStatus \(status)"
}

private func audioMeterFormatDescription(_ format: AudioStreamBasicDescription) -> String {
    "formatID=\(format.mFormatID), flags=\(format.mFormatFlags), bits=\(format.mBitsPerChannel), "
        + "bytesPerFrame=\(format.mBytesPerFrame)"
}
