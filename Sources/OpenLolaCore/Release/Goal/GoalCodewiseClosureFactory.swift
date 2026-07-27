// Combines both requirement tables into the canonical codewise-closure report so summary counts cannot diverge from catalog rows.
import Foundation

extension GoalCodewiseClosureReport {
public static func codewiseClosure() -> GoalCodewiseClosureReport {
        let requirements = goalCodewiseRequirements()
        return GoalCodewiseClosureReport(
            identity: GoalCodewiseClosureReport.Identity(
                id: "goal-codewise-closure-2026-05-05",
                title: "GOAL.md codewise closure",
                capturedAt: "2026-05-05T00:00:00Z",
                goalDocument: "GOAL.md"
            ),
            verdicts: GoalCodewiseClosureReport.Verdicts(codewise: .pass, realWorld: .partial),
            evidence: GoalCodewiseClosureReport.Evidence(
                requirements: requirements,
                requiredDocumentationAreas: GoalCodewiseDocumentationArea.required,
                assumptions: [
                    "Codewise closure means the required source, validation, CLI, and documentation surfaces exist.",
                    "Physical two-Mac, RME MADI, Blackmagic/ATEM, lighting, signing, notarization, and " +
                        "clean-Mac evidence remains outside this source-level report."
                ]
            ),
            notes: "All GOAL.md source, documentation, validation, and CLI surfaces are represented " +
                       "codewise; physical evidence remains explicit."
        )
    }
}

private func goalCodewiseRequirements() -> [GoalCodewiseRequirement] {
    goalCodewiseRequirementTablePart1 + goalCodewiseRequirementTablePart2
}
