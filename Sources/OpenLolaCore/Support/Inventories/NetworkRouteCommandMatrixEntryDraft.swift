// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

struct NetworkRouteCommandMatrixEntryDraft {
    var command: String
    var kind: CLICommandKind
    var ownerSourceFile: String
    var parser: String
    var outputReport: String
    var routeMode: NetworkRouteMode
    var evidenceBoundary: NetworkRouteEvidenceBoundary
    var canContributeToFastestDirectEvidence: Bool
    var representativeCommand: String
    var relatedSourceFiles: [String]
    var relatedTestFiles: [String]
    var notes: String
}

func entry(_ draft: NetworkRouteCommandMatrixEntryDraft) -> NetworkRouteCommandMatrixEntry {
    NetworkRouteCommandMatrixEntry(
        command: NetworkRouteCommandMatrixEntry.Command(
            name: draft.command,
            kind: draft.kind,
            ownerSourceFile: draft.ownerSourceFile,
            parser: draft.parser,
            outputReport: draft.outputReport
        ),
        route: NetworkRouteCommandMatrixEntry.Route(
            mode: draft.routeMode,
            evidenceBoundary: draft.evidenceBoundary,
            canContributeToFastestDirectEvidence: draft.canContributeToFastestDirectEvidence
        ),
        references: NetworkRouteCommandMatrixEntry.References(
            representativeCommand: draft.representativeCommand,
            sourceFiles: draft.relatedSourceFiles,
            testFiles: draft.relatedTestFiles,
            notes: draft.notes
        )
    )
}
