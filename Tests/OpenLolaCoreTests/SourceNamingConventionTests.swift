import Foundation
import Testing

@testable import OpenLolaCore

@Test
func cleanRoomDesignRulesDefineHelperSupportAndUtilitySuffixes() throws {
    let namingDoc = try readSourceNamingText("docs/architecture/clean-room-design-rules.md")

    #expect(namingDoc.contains("*Helpers"))
    #expect(namingDoc.contains("validation helpers"))
    #expect(namingDoc.contains("parsing helpers"))
    #expect(namingDoc.contains("*Support"))
    #expect(namingDoc.contains("CLI argument shims"))
    #expect(namingDoc.contains("command adapters"))
    #expect(namingDoc.contains("*Utilities"))
    #expect(namingDoc.contains("not a default suffix for new source"))
}

@Test
func currentHelperAndSupportExamplesMatchDocumentedSuffixBoundary() throws {
    let namingDoc = try readSourceNamingText("docs/architecture/clean-room-design-rules.md")
    let helperExamples = [
        "PackagingFieldTestHelpers.swift",
        "RecordingSessionHelpers.swift",
        "ReferenceRigHelpers.swift",
    ]
    let supportExamples = [
        "DirectP2PSessionRunArgumentSupport.swift",
        "DirectP2PMeasuredEvidenceCommandSupport.swift",
    ]

    for helperExample in helperExamples {
        #expect(namingDoc.contains(helperExample))
    }
    for supportExample in supportExamples {
        #expect(namingDoc.contains(supportExample))
    }
}

@Test
func twoPeerPrototypeNamingIsCoveredByPublicCommandAndSchemaContracts() throws {
    let source = try readSourceNamingText(
        "Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift"
    )
    let commandNames = Set(CLICommandInventory.entries.map(\.command))
    let schema = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "DirectPeerTwoPeerPrototypeReport"
    })

    #expect(!source.contains("TODO(human):"))
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
