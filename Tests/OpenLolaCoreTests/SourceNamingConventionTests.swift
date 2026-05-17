import Foundation
import Testing

@testable import OpenLolaCore

@Test
func cleanRoomNamingPolicyAndTwoPeerPrototypeSurfaceStayDocumented() throws {
    let namingDoc = try readSourceNamingText("docs/clean-room-design-rules.md")

    #expect(namingDoc.contains("*Helpers"))
    #expect(namingDoc.contains("validation helpers"))
    #expect(namingDoc.contains("parsing helpers"))
    #expect(namingDoc.contains("*Support"))
    #expect(namingDoc.contains("CLI argument shims"))
    #expect(namingDoc.contains("command adapters"))
    #expect(namingDoc.contains("*Utilities"))
    #expect(namingDoc.contains("not a default suffix for new source"))
    for helperExample in [
        "PackagingFieldTestHelpers.swift",
        "RecordingSessionHelpers.swift",
        "ReferenceRigHelpers.swift",
    ] {
        #expect(namingDoc.contains(helperExample))
    }
    for supportExample in [
        "DirectP2PSessionRunArgumentSupport.swift",
        "DirectP2PMeasuredEvidenceCommandSupport.swift",
    ] {
        #expect(namingDoc.contains(supportExample))
    }

    let commandNames = Set(CLICommandInventory.entries.map(\.command))
    let schema = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "DirectPeerTwoPeerPrototypeReport"
    })

    #expect(commandNames.contains("direct-p2p-two-peer-prototype-report"))
    #expect(commandNames.contains("validate-direct-p2p-two-peer-prototype-report"))
    #expect(schema.schemaFamily == "direct P2P two-peer prototype")
    #expect(schema.validatorCommands == ["validate-direct-p2p-two-peer-prototype-report"])
    #expect(schema.evidenceClass == .measured)
}

private func readSourceNamingText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
