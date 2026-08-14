// Executes an audio loopback run with device-state capture, bounded cleanup, and a report that exposes every restoration failure.
import COpenLolaAtomics
import CoreAudio
import Darwin
import Foundation

/// Executes a bounded audio loopback kind run and returns accountable CoreAudio loopback routing evidence.
public enum AudioLoopbackRunnerKind: String, Codable, Equatable, Sendable {
    case audioDeviceIOProc
    case auhal
}

/// Defines `blockedPreflight` and `completed` states used to make audio loopback run state decisions in CoreAudio loopback routing.
public enum AudioLoopbackRunState: String, Codable, Equatable, Sendable {
    case blockedPreflight
    case completed
}

struct AudioLoopbackSavedDeviceSettings {
    let sampleRate: Double?
    let frames: UInt32?

    init(sampleRate: Double?, frames: UInt32?) {
        self.sampleRate = sampleRate
        self.frames = frames
    }

    init(deviceID: AudioObjectID) {
        self.sampleRate = doubleProperty(
            deviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal
        )
        self.frames = uint32Property(
            deviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal
        )
    }
}

/// Reports `coreAudioStatus`, `deviceNotRunnable`, and `callbackIntervalBufferAllocationFailed` failures that stop invalid CoreAudio loopback routing work before it reaches a live path.
public enum AudioLoopbackRunError: Error, Equatable, Sendable {
    case coreAudioStatus(OSStatus, String)
    case deviceNotRunnable
    case callbackIntervalBufferAllocationFailed(Int)
}

/// Executes a bounded Core Audio loopback run and returns accountable routing evidence.
public struct CoreAudioLoopbackRunner: Sendable {
    private let destroyIOProc: @Sendable (AudioObjectID, AudioDeviceIOProcID) -> OSStatus
    private let restoreDoubleProperty: @Sendable (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        Double
    ) throws -> Void
    private let restoreUInt32Property: @Sendable (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        UInt32
    ) throws -> Void

    public init() {
        self.init(
            destroyIOProc: AudioDeviceDestroyIOProcID,
            restoreDoubleProperty: setDoubleProperty,
            restoreUInt32Property: setUInt32Property
        )
    }

    init(
        destroyIOProc: @escaping @Sendable (AudioObjectID, AudioDeviceIOProcID) -> OSStatus,
        restoreDoubleProperty: @escaping @Sendable (
            AudioObjectID,
            AudioObjectPropertySelector,
            AudioObjectPropertyScope,
            Double
        ) throws -> Void,
        restoreUInt32Property: @escaping @Sendable (
            AudioObjectID,
            AudioObjectPropertySelector,
            AudioObjectPropertyScope,
            UInt32
        ) throws -> Void
    ) {
        self.destroyIOProc = destroyIOProc
        self.restoreDoubleProperty = restoreDoubleProperty
        self.restoreUInt32Property = restoreUInt32Property
    }

    public func run(configuration: AudioLoopbackRunConfiguration) throws -> AudioLoopbackRunReport {
        let inventory = try CoreAudioInventoryReader().capture()
        let preflight = AudioLoopbackPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        )

        guard preflight.canStartIOProc, let deviceID = preflight.inputDevice?.id else {
            return makeRunReport(
                configuration: configuration,
                inventory: inventory,
                draft: AudioLoopbackRunReportDraft(
                    preflight: preflight,
                    state: .blockedPreflight,
                    ioProcResult: nil,
                    notes: "Core Audio IOProc was not started because preflight blocked the run."
                )
            )
        }

        let result = try runIOProc(
            deviceID: AudioObjectID(deviceID),
            configuration: configuration
        )
        return makeRunReport(
            configuration: configuration,
            inventory: inventory,
            draft: AudioLoopbackRunReportDraft(
                preflight: preflight,
                state: .completed,
                ioProcResult: result,
                notes: audioLoopbackCompletionNotes(
 base: "Single Core Audio IOProc run completed. This is not an M03 PASS report until "
     + "analog loopback full 16/32/64/128 matrix are measured.",
                    cleanup: result.cleanup
                )
            )
        )
    }

    private func runIOProc(
        deviceID: AudioObjectID,
        configuration: AudioLoopbackRunConfiguration
    ) throws -> AudioLoopbackIOProcResult {
        let savedSettings = AudioLoopbackSavedDeviceSettings(deviceID: deviceID)
        var ioProcID: AudioDeviceIOProcID?
        var cleanupPerformed = false
        defer {
            if !cleanupPerformed {
                _ = cleanupIOProc(
                    deviceID: deviceID,
                    ioProcID: ioProcID,
                    savedSettings: savedSettings
                )
            }
        }

        try applyLoopbackDeviceSettings(deviceID: deviceID, configuration: configuration)
        let state = try AudioLoopbackIOProcState(configuration: configuration)
        ioProcID = try createLoopbackIOProc(deviceID: deviceID, state: state)
        try runLoopbackIOProc(deviceID: deviceID, ioProcID: ioProcID, durationSeconds: configuration.durationSeconds)
        state.markStopped()
        let cleanup = cleanupIOProc(
            deviceID: deviceID,
            ioProcID: ioProcID,
            savedSettings: savedSettings
        )
        cleanupPerformed = true

        return makeIOProcResult(state: state, cleanup: cleanup)
    }

    private func applyLoopbackDeviceSettings(
        deviceID: AudioObjectID,
        configuration: AudioLoopbackRunConfiguration
    ) throws {
        try setDoubleProperty(
            deviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            Double(configuration.sampleRateHertz)
        )
        try setUInt32Property(
            deviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal,
            UInt32(configuration.framesPerBuffer)
        )
    }

    private func createLoopbackIOProc(
        deviceID: AudioObjectID,
        state: AudioLoopbackIOProcState
    ) throws -> AudioDeviceIOProcID {
        let clientData = Unmanaged.passUnretained(state).toOpaque()
        var ioProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcID(
            deviceID,
            audioLoopbackIOProc,
            clientData,
            &ioProcID
        )
        try throwLoopbackIfNeeded(status, "create AudioDeviceIOProcID")
        guard let ioProcID else {
            throw AudioLoopbackRunError.deviceNotRunnable
        }
        return ioProcID
    }

    private func runLoopbackIOProc(
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID?,
        durationSeconds: Int
    ) throws {
        guard let ioProcID else {
            throw AudioLoopbackRunError.deviceNotRunnable
        }
        var status = AudioDeviceStart(deviceID, ioProcID)
        try throwLoopbackIfNeeded(status, "start AudioDeviceIOProc")
        _ = DispatchSemaphore(value: 0).wait(
            timeout: .now() + .seconds(durationSeconds)
        )
        status = AudioDeviceStop(deviceID, ioProcID)
        try throwLoopbackIfNeeded(status, "stop AudioDeviceIOProc")
    }

    private func makeIOProcResult(
        state: AudioLoopbackIOProcState,
        cleanup: AudioLoopbackRunCleanupResult
    ) -> AudioLoopbackIOProcResult {
        AudioLoopbackIOProcResult(
            callback: state.callbackMetrics(),
            handoff: state.handoffMetrics(),
            cleanup: cleanup
        )
    }

    func cleanupIOProc(
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID?,
        savedSettings: AudioLoopbackSavedDeviceSettings
    ) -> AudioLoopbackRunCleanupResult {
        var failures: [AudioLoopbackRunCleanupFailure] = []
        if let ioProcID {
            let destroyStatus = destroyIOProc(deviceID, ioProcID)
            if destroyStatus != noErr {
                failures.append(.init(
                    operation: "destroy AudioDeviceIOProcID",
                    status: destroyStatus
                ))
            }
        }
        if let originalSampleRate = savedSettings.sampleRate {
            do {
                try restoreDoubleProperty(
                    deviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalSampleRate
                )
            } catch {
                failures.append(.init(
                    operation: "restore sample rate",
                    status: audioLoopbackStatus(from: error)
                ))
            }
        } else {
            failures.append(.init(operation: "restore sample rate", status: nil))
        }
        if let originalFrames = savedSettings.frames {
            do {
                try restoreUInt32Property(
                    deviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalFrames
                )
            } catch {
                failures.append(.init(
                    operation: "restore buffer frame size",
                    status: audioLoopbackStatus(from: error)
                ))
            }
        } else {
            failures.append(.init(operation: "restore buffer frame size", status: nil))
        }
        return AudioLoopbackRunCleanupResult(failures: failures)
    }
}
