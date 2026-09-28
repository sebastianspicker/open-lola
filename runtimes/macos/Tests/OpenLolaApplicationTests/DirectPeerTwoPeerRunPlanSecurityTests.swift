// Verifies direct-peer plans validate remote targets before constructing commands.
import Foundation
import OpenLolaApplication
import Testing

@Test func twoPeerPlanRejectsTraversalAndDuplicatePeerIDs() throws {
    var traversal = makeTwoPeerPlan(peerA: "../../target", peerB: "mac-b")
    #expect(throws: DirectPeerTwoPeerRunPlanError.invalidPeerID("../../target")) {
        try traversal.validate()
    }

    traversal.commands[0].peerID = "mac-a"
    traversal.reportReferences[0].peerID = "mac-a"
    traversal.commands[1].peerID = "mac-a"
    traversal.reportReferences[1].peerID = "mac-a"
    #expect(throws: DirectPeerTwoPeerRunPlanError.duplicatePeerID("mac-a")) {
        try traversal.validate()
    }
}

@Test func remoteArtifactPathsAreRestrictedBeforeBuildingScpSource() throws {
    let source = try DirectPeerTwoPeerRunPathPolicy.scpSourceArgument(
        remoteTarget: "operator@studio.example",
        remotePath: "/var/tmp/open-lola/report.json"
    )
    #expect(source == "operator@studio.example:'/var/tmp/open-lola/report.json'")

    for path in [
        "relative/report.json", "/tmp/../report.json", "/tmp//report.json", "/tmp/report/", "/tmp/report:other",
        "/tmp/$(touch marker)", "/tmp/`touch marker`", "/tmp/report name",
        "/tmp/'report'", "/tmp/report\\name"
    ] {
        #expect(throws: DirectPeerTwoPeerRunPlanError.unsafeArtifactPath(path)) {
            try DirectPeerTwoPeerRunPathPolicy.validateRemoteArtifactPath(path)
        }
    }
}

@Test func localScpArtifactSymlinkIsRejectedWithoutChangingVictim() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let victim = directory.appendingPathComponent("victim")
    let destination = directory.appendingPathComponent("collected-report.json")
    try Data("unchanged".utf8).write(to: victim)
    try FileManager.default.createSymbolicLink(atPath: destination.path, withDestinationPath: victim.path)

    #expect(throws: DirectPeerTwoPeerRunPlanError.unsafeArtifactPath(destination.path)) {
        try DirectPeerTwoPeerRunPathPolicy.validateLocalArtifactDestination(destination.path)
    }
    #expect(try Data(contentsOf: victim) == Data("unchanged".utf8))
}

private func makeTwoPeerPlan(peerA: String, peerB: String) -> DirectPeerTwoPeerRunPlanReport {
    let commands = [
        DirectPeerTwoPeerRunCommand(
            peerID: peerA,
            role: .initiator,
            outputReportPath: "/private/tmp/\(peerA)-report.json",
            arguments: ["open-lola", "direct-p2p-session-run"]
        ),
        DirectPeerTwoPeerRunCommand(
            peerID: peerB,
            role: .responder,
            outputReportPath: "/private/tmp/\(peerB)-report.json",
            arguments: ["open-lola", "direct-p2p-session-run"]
        )
    ]
    return DirectPeerTwoPeerRunPlanReport(
        id: "security-test",
        capturedAt: "2026-09-08T00:00:00Z",
        runDirectory: "/private/tmp/open-lola-security-test",
        commands: commands,
        reportReferences: commands.map { .init(peerID: $0.peerID, path: $0.outputReportPath) },
        evidenceGates: ["test"],
        verdict: .partial,
        notes: "test"
    )
}
