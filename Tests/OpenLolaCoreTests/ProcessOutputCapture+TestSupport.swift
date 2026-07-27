// Captures child-process output without bounded pipe buffers that can deadlock test helpers.
import Foundation

struct CapturedTestProcessOutput {
    let status: Int32
    let output: String
}

func runTestProcessCapturingCombinedOutput(
    _ process: Process,
    logPrefix: String = "open-lola-test-process"
) throws -> CapturedTestProcessOutput {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(logPrefix)-\(UUID().uuidString).log")
    _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }

    process.standardOutput = outputHandle
    process.standardError = outputHandle
    try process.run()
    process.waitUntilExit()
    try outputHandle.close()

    let data = try Data(contentsOf: outputURL)
    return CapturedTestProcessOutput(
        status: process.terminationStatus,
        output: String(data: data, encoding: .utf8) ?? ""
    )
}
