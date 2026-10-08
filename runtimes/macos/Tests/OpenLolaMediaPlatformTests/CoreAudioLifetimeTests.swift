// Exercises HAL registration ownership and late callbacks without opening physical audio devices.
import CoreAudio
import COpenLolaAtomics
import Dispatch
import Foundation
import XCTest
@testable import OpenLolaMediaPlatform

final class CoreAudioLifetimeTests: XCTestCase {
    func testFailedDestructionKeepsLateCallbacksSafeWithoutRetainingGraph() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let owner = WeakLifetimeReference(graph)
        let storage = WeakLifetimeReference(graph?.callbackState)
        let driver = LifetimeTestDriver()
        driver.stopStatus = kAudioHardwareUnspecifiedError
        driver.destroyStatus = kAudioHardwareUnspecifiedError
        try driver.register(graph!, role: "input", callback: directPeerRealtimeAudioIOProc)
        let pointer = try XCTUnwrap(graph?.inputIOProcClientData)
        graph = nil
        XCTAssertNil(owner.value, "The HAL registration must never retain the graph")
        XCTAssertNotNil(storage.value, "A registered IOProc must still own all callback storage")
        XCTAssertEqual(try Self.runCallback(directPeerRealtimeAudioIOProc, pointer: pointer), [0, 0, 0, 0])
        XCTAssertEqual(storage.value.map { open_lola_atomic_u64_load(&$0.capturedInputBlocks) }, 0)
        // The fake driver finally unregisters, balancing its one registration retain.
        releaseRegistration(pointer)
        XCTAssertNil(storage.value)
    }

    func testInFlightCallbackOutlivesOwnerAfterQuiescenceTimeout() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let owner = WeakLifetimeReference(graph)
        let storage = WeakLifetimeReference(graph?.callbackState)
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        graph?.setHostTimeConversionForTesting { _ in
            entered.signal()
            _ = resume.wait(timeout: .now() + 5)
            return 7
        }
        let driver = LifetimeTestDriver()
        try driver.register(graph!, role: "input", callback: directPeerRealtimeAudioInputIOProc)
        let registration = LifetimeTestPointer(try XCTUnwrap(graph?.inputIOProcClientData))
        DispatchQueue.global().async {
            defer { finished.signal() }
            _ = try? CoreAudioLifetimeTests.runCallback(directPeerRealtimeAudioInputIOProc, pointer: registration.value)
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 2), .success)
        graph = nil
        XCTAssertNil(owner.value)
        XCTAssertEqual(driver.destroyCalls, 0, "An active callback prevents unregister/release")
        XCTAssertNotNil(storage.value)
        resume.signal()
        XCTAssertEqual(finished.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(storage.value.map { open_lola_atomic_u64_load(&$0.capturedInputBlocks) }, 1, "In-flight work still has valid rings and scratch")
        releaseRegistration(registration.value)
        XCTAssertNil(storage.value)
    }

    func testDestroyFailureCanBeRetriedAndReleasesStorageOnce() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let storage = WeakLifetimeReference(graph?.callbackState)
        let driver = LifetimeTestDriver()
        driver.destroyStatus = kAudioHardwareUnspecifiedError
        try driver.register(graph!, role: "output", callback: directPeerRealtimeAudioOutputIOProc)
        XCTAssertFalse(graph!.stop().succeeded)
        XCTAssertNotNil(graph?.outputIOProcClientData)
        XCTAssertEqual(graph?.captureInjectedPayload(Data(repeating: 0, count: 16), hostTimeNanoseconds: 0), .invalid)
        driver.destroyStatus = noErr
        XCTAssertTrue(graph!.stop().succeeded)
        XCTAssertNil(graph?.outputIOProcClientData)
        XCTAssertTrue(graph!.stop().succeeded)
        XCTAssertEqual(driver.destroyCalls, 2)
        graph = nil
        XCTAssertNil(storage.value)
    }

    func testSplitRegistrationRetainsStorageUntilBothAreDestroyed() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let storage = WeakLifetimeReference(graph?.callbackState)
        let driver = LifetimeTestDriver()
        try driver.register(graph!, role: "input", callback: directPeerRealtimeAudioInputIOProc)
        try driver.register(graph!, role: "output", callback: directPeerRealtimeAudioOutputIOProc)
        let outputPointer = try XCTUnwrap(graph?.outputIOProcClientData)
        graph?.destroyIOProcForTesting = { device, _ in device == 1 ? noErr : kAudioHardwareUnspecifiedError }
        XCTAssertFalse(graph!.stop().succeeded)
        XCTAssertNil(graph?.inputIOProcClientData)
        XCTAssertNotNil(graph?.outputIOProcClientData)
        graph = nil
        XCTAssertNotNil(storage.value)
        XCTAssertEqual(try Self.runCallback(directPeerRealtimeAudioOutputIOProc, pointer: outputPointer), [0, 0, 0, 0])
        releaseRegistration(outputPointer)
        XCTAssertNil(storage.value)
    }

    func testStopFailureWithSuccessfulDestroyDoesNotLeakStorage() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let storage = WeakLifetimeReference(graph?.callbackState)
        let driver = LifetimeTestDriver()
        driver.stopStatus = kAudioHardwareUnspecifiedError
        try driver.register(graph!, role: "input", callback: directPeerRealtimeAudioInputIOProc)
        XCTAssertFalse(graph!.stop().succeeded)
        XCTAssertNil(graph?.inputIOProcClientData)
        graph = nil
        XCTAssertNil(storage.value)
    }

    func testStartFailurePreservesRegistrationForCleanupRetry() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let storage = WeakLifetimeReference(graph?.callbackState)
        let driver = LifetimeTestDriver()
        driver.startStatus = kAudioHardwareUnspecifiedError
        driver.destroyStatus = kAudioHardwareUnspecifiedError
        XCTAssertThrowsError(try driver.register(graph!, role: "input", callback: directPeerRealtimeAudioInputIOProc))
        XCTAssertNotNil(graph?.inputIOProcID)
        XCTAssertNotNil(graph?.inputIOProcClientData)
        XCTAssertFalse(graph!.stop().succeeded)
        driver.destroyStatus = noErr
        XCTAssertTrue(graph!.stop().succeeded)
        graph = nil
        XCTAssertNil(storage.value)
    }

    func testCreateFailureBalancesRegistrationRetain() throws {
        var graph: DirectPeerRealtimeAudioGraph? = try makeGraph()
        let storage = WeakLifetimeReference(graph?.callbackState)
        graph?.createIOProcForTesting = { _, _, _, _ in kAudioHardwareUnspecifiedError }
        XCTAssertThrowsError(try graph!.makeAndStartIOProc(deviceID: 1, ioProc: directPeerRealtimeAudioIOProc, role: "input"))
        XCTAssertNil(graph?.inputIOProcClientData)
        graph = nil
        XCTAssertNil(storage.value)
    }

    private func makeGraph() throws -> DirectPeerRealtimeAudioGraph {
        try DirectPeerRealtimeAudioGraph(configuration: .init(
            devices: .init(audioDeviceUID: "synthetic"),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 2, channelCount: 2, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: [0, 1], output: [0, 1])
        ))
    }

    private func releaseRegistration(_ pointer: UnsafeMutableRawPointer) {
        Unmanaged<DirectPeerRealtimeAudioCallbackState>.fromOpaque(pointer).release()
    }

    private static func runCallback(_ callback: AudioDeviceIOProc, pointer: UnsafeMutableRawPointer) throws -> [Float] {
        var samples: [Float] = [1, 2, 3, 4]
        var output = [Float](repeating: -1, count: 4)
        var time = AudioTimeStamp()
        time.mHostTime = 7
        time.mFlags = .hostTimeValid
        let status = samples.withUnsafeMutableBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var inputList = AudioBufferList(mNumberBuffers: 1, mBuffers: .init(
                    mNumberChannels: 2, mDataByteSize: UInt32(inputBytes.count), mData: inputBytes.baseAddress
                ))
                var outputList = AudioBufferList(mNumberBuffers: 1, mBuffers: .init(
                    mNumberChannels: 2, mDataByteSize: UInt32(outputBytes.count), mData: outputBytes.baseAddress
                ))
                return withUnsafePointer(to: &time) { timestamp in
                    callback(1, timestamp, &inputList, timestamp, &outputList, timestamp, pointer)
                }
            }
        }
        XCTAssertEqual(status, noErr)
        return output
    }
}

private final class LifetimeTestPointer: @unchecked Sendable {
    let value: UnsafeMutableRawPointer
    init(_ value: UnsafeMutableRawPointer) { self.value = value }
}

private final class LifetimeTestDriver {
    var stopStatus: OSStatus = noErr
    var destroyStatus: OSStatus = noErr
    var startStatus: OSStatus = noErr
    var destroyCalls = 0

    func register(_ graph: DirectPeerRealtimeAudioGraph, role: String, callback: AudioDeviceIOProc) throws {
        graph.createIOProcForTesting = { _, callback, _, result in
            result.pointee = callback
            return noErr
        }
        graph.startDeviceForTesting = { [self] _, _ in startStatus }
        graph.stopDeviceForTesting = { [self] _, _ in stopStatus }
        graph.destroyIOProcForTesting = { [self] _, _ in
            destroyCalls += 1
            return destroyStatus
        }
        let device: AudioObjectID = role == "input" ? 1 : 2
        if role == "input" { graph.inputDeviceID = device } else { graph.outputDeviceID = device }
        graph.setIOProcRunningForTesting(true)
        _ = try graph.makeAndStartIOProc(deviceID: device, ioProc: callback, role: role)
    }
}

private final class WeakLifetimeReference<Value: AnyObject> {
    weak var value: Value?
    init(_ value: Value?) { self.value = value }
}
