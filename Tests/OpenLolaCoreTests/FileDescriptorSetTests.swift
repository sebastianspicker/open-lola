import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fileDescriptorSetSetsAndReadsBoundaryBits() throws {
    var set = fd_set()
    openLolaFDZero(&set)

    for descriptor in [0, 1, 31, 32, 63, 1_023] {
        try openLolaFDSet(Int32(descriptor), set: &set)
        #expect(try openLolaFDIsSet(Int32(descriptor), set: &set))
    }
}

@Test
func fileDescriptorSetZeroClearsSetBits() throws {
    var set = fd_set()
    openLolaFDZero(&set)

    try openLolaFDSet(31, set: &set)
    try openLolaFDSet(32, set: &set)
    #expect(try openLolaFDIsSet(31, set: &set))
    #expect(try openLolaFDIsSet(32, set: &set))

    openLolaFDZero(&set)

    #expect(!(try openLolaFDIsSet(31, set: &set)))
    #expect(!(try openLolaFDIsSet(32, set: &set)))
}

@Test
func fileDescriptorSetRejectsOverflowBoundaries() {
    #expect(!openLolaFileDescriptorFitsFDSet(-1))
    #expect(openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE - 1)))
    #expect(!openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE)))
    #expect(openLolaFDSetWordCapacity() == Int(FD_SETSIZE) / (MemoryLayout<Int32>.size * 8))

    var set = fd_set()
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaRequireFileDescriptorFitsFDSet(-1, context: "test")
    }
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaRequireFileDescriptorFitsFDSet(Int32(FD_SETSIZE), context: "test")
    }
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaFDSet(Int32(FD_SETSIZE), set: &set)
    }
    #expect(throws: ExternalConnectorSessionError.self) {
        _ = try openLolaFDIsSet(Int32(FD_SETSIZE), set: &set)
    }
}

@Test
func fileDescriptorSetRebindingHasExplicitCapacityAndAlignmentChecks() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/OpenLolaCore/Support/FileDescriptorSet.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(source.contains("precondition(intOffset >= 0 && intOffset < wordCapacity"))
    #expect(source.contains("MemoryLayout.size(ofValue: pointer.pointee) >= requiredBytes"))
    #expect(source.contains("MemoryLayout<Int32>.alignment"))
    #expect(source.contains("withMemoryRebound(to: Int32.self, capacity: wordCapacity)"))
}
