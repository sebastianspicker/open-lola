import Foundation
import Testing

@testable import OpenLolaCore

@Test
func boundedPipeCaptureLimitsOutputPrefixBytes() throws {
    let pipe = Pipe()
    let capture = BoundedPipeCapture(pipe: pipe, limit: 4)

    pipe.fileHandleForWriting.write(Data("abcdef".utf8))
    capture.closeWriteHandle()

    #expect(capture.prefix() == "abcd")
}

@Test
func boundedPipeCaptureCharacterModePreservesExternalConnectorPrefixLimit() throws {
    let pipe = Pipe()
    let capture = BoundedPipeCapture(pipe: pipe, limit: 4, mode: .characters)

    pipe.fileHandleForWriting.write(Data("external-output".utf8))
    capture.closeWriteHandle()

    #expect(capture.prefix() == "exte")
}

@Test
func boundedPipeCapturePrefixIsIdempotentAfterDrain() throws {
    let pipe = Pipe()
    let capture = BoundedPipeCapture(pipe: pipe, limit: 8)

    pipe.fileHandleForWriting.write(Data("once-only".utf8))
    capture.closeWriteHandle()

    let first = capture.prefix()
    let second = capture.prefix()

    #expect(first == "once-onl")
    #expect(second == first)
}
