import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appExecutionCommandPreviewRequiresVerifiedExecutable() throws {
    let missingExecutable = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-missing-preview-\(UUID().uuidString)")
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = missingExecutable.path
    let controller = AppExecutionController()

    do {
        _ = try controller.executionCommand(
            executablePath: missingExecutable.path,
            operatorSurface: surface,
            dryRun: true
        ).get()
        Issue.record("Expected command preview to require a verified executable path")
    } catch {
        #expect(String(describing: error).contains("Executable path unavailable"))
    }

    controller.dryRun(executablePath: missingExecutable.path)

    #expect(controller.phase == .failedToStart)
    #expect(controller.status == "Run failed to start.")
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.lastReport?.command.isEmpty == true)
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
}

@MainActor
@Test
func appStartArmedReportsFailureBeforeRunIntentIsSet() throws {
    let missingExecutable = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-missing-start-\(UUID().uuidString)")
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = missingExecutable.path
    var commandIntent = surface.commandIntent
    let controller = AppExecutionController()
    controller.armedForExecution = true

    let started = controller.startArmed(operatorSurface: surface)
    if started {
        commandIntent = .runRequested
    } else {
        commandIntent = .idle
    }

    #expect(!started)
    #expect(commandIntent == .idle)
    #expect(controller.phase == .failedToStart)
    #expect(controller.status == "Run failed to start.")
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
}

@Test
func appExecutionLogSnapshotPreservesPreviousRunBeforeTruncation() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-log-snapshot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let currentLog = directory.appendingPathComponent("execution-stdout.log")
    let previousLog = directory.appendingPathComponent("previous-execution-stdout.log")
    try Data("first run\n".utf8).write(to: currentLog)

    let copied = try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
        sourcePath: currentLog.path,
        previousPath: previousLog.path
    )

    #expect(copied)
    #expect(try String(contentsOf: previousLog, encoding: .utf8) == "first run\n")

    try Data().write(to: currentLog)
    let copiedEmptyLog = try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
        sourcePath: currentLog.path,
        previousPath: previousLog.path
    )

    #expect(!copiedEmptyLog)
    #expect(try String(contentsOf: previousLog, encoding: .utf8) == "first run\n")
}

@MainActor
@Test
func appExecutionEvidenceRingPreservesLastThreeSnapshotsBeforeClearing() {
    let controller = AppExecutionController()

    controller.archiveCurrentEvidenceForNextRun()
    #expect(controller.previousRunEvidence.isEmpty)

    for index in 1...4 {
        controller.lastCommand = ["open-lola", "run-\(index)"]
        controller.status = "Run \(index) failed."
        controller.phase = .runFailed
        controller.lastExitCode = index
        controller.lastValidationExitCode = index + 10
        controller.lastValidationResult = .failed
        controller.lastError = "failure \(index)"
        controller.errorLog = ["failure \(index)"]
        controller.archiveCurrentEvidenceForNextRun()
    }

    #expect(controller.previousRunEvidence.count == 3)
    #expect(controller.previousRunEvidence.map(\.exitCode) == [4, 3, 2])
    #expect(controller.previousRunEvidence.first?.lastError == "failure 4")
    #expect(controller.previousRunEvidence.first?.commandLine.contains("run-4") == true)
}
