import Foundation
import Testing

@testable import OpenLolaCore

@Test
func managedProcessRunnerRunsProcessToExitAndCapturesOutput() throws {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-\(UUID().uuidString).txt")
    defer {
        try? FileManager.default.removeItem(at: outputURL)
    }

    let exitCode = try ManagedProcessRunner.runToExit(
        executable: "/bin/echo",
        arguments: ["managed-process-ok"],
        standardOutputPath: outputURL.path
    )

    #expect(exitCode == 0)
    #expect(try String(contentsOf: outputURL, encoding: .utf8) == "managed-process-ok\n")
}

@Test
func appAndTwoPeerSupervisorUseManagedProcessRunner() throws {
    let appController = try readRepositoryText("Sources/open-lola-app/AppExecutionController.swift")
    let supervisor = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift"
    )
    let runner = try readRepositoryText("Sources/OpenLolaCore/Support/ManagedProcessRunner.swift")

    #expect(!containsDirectProcessConstruction(appController))
    #expect(!containsDirectProcessConstruction(supervisor))
    #expect(appController.contains("ManagedProcessRunner.start"))
    #expect(supervisor.contains("ManagedProcessRunner.start"))
    #expect(supervisor.contains("ManagedProcessRunner.terminate"))
    #expect(supervisor.contains("ManagedProcessRunner.runToExit"))
    #expect(runner.contains("let process = Process()"))
}

private func containsDirectProcessConstruction(_ text: String) -> Bool {
    text.split(separator: "\n").contains { line in
        line.contains("= Process()")
    }
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
