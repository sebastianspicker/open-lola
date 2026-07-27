// Manages FileDescriptorSet resource handling, keeping file-descriptor and process lifetime details out of calling workflows.
import Darwin

func openLolaFDZero(_ set: inout fd_set) {
    set = fd_set()
}

func openLolaFileDescriptorFitsFDSet(_ descriptor: Int32) -> Bool {
    descriptor >= 0 && descriptor < Int32(FD_SETSIZE)
}

func openLolaRequireFileDescriptorFitsFDSet(_ descriptor: Int32, context: String) throws {
    guard openLolaFileDescriptorFitsFDSet(descriptor) else {
        throw ExternalConnectorSessionError.socketFailed(
            "\(context) descriptor \(descriptor) exceeds FD_SETSIZE \(FD_SETSIZE)"
        )
    }
}

// swiftlint:disable:next identifier_name
func openLolaFDSet(_ fd: Int32, set: inout fd_set) throws {
    try openLolaWithFDSetWord(fd, set: &set) { words, intOffset, bitOffset in
        words[intOffset] |= 1 << bitOffset
    }
}

// swiftlint:disable:next identifier_name
func openLolaFDIsSet(_ fd: Int32, set: inout fd_set) throws -> Bool {
    try openLolaWithFDSetWord(fd, set: &set) { words, intOffset, bitOffset in
        (words[intOffset] & (1 << bitOffset)) != 0
    }
}

func openLolaFDSetWordCapacity() -> Int {
    Int(FD_SETSIZE) / openLolaFDSetBitsPerWord
}

private let openLolaFDSetBitsPerWord = MemoryLayout<Int32>.size * 8

private func openLolaWithFDSetWord<Result>(
    _ fileDescriptor: Int32,
    set: inout fd_set,
    _ body: (UnsafeMutablePointer<Int32>, Int, Int32) -> Result
) throws -> Result {
try openLolaRequireFileDescriptorFitsFDSet(fileDescriptor, context: "fd_set")
    let wordCapacity = openLolaFDSetWordCapacity()
let intOffset = Int(fileDescriptor) / openLolaFDSetBitsPerWord
let bitOffset = Int32(Int(fileDescriptor) % openLolaFDSetBitsPerWord)
    precondition(intOffset >= 0 && intOffset < wordCapacity, "fd_set word offset exceeds rebound capacity")
    return withUnsafeMutablePointer(to: &set.fds_bits) { pointer in
        let requiredBytes = wordCapacity * MemoryLayout<Int32>.stride
        precondition(
            MemoryLayout.size(ofValue: pointer.pointee) >= requiredBytes,
            "fd_set storage is smaller than FD_SETSIZE word capacity"
        )
        precondition(
            Int(bitPattern: UnsafeRawPointer(pointer)) % MemoryLayout<Int32>.alignment == 0,
            "fd_set storage is not aligned for Int32 rebinding"
        )
        return pointer.withMemoryRebound(to: Int32.self, capacity: wordCapacity) {
            body($0, intOffset, bitOffset)
        }
    }
}
