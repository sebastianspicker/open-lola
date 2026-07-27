// Verifies that video control degrade matrix entries have existing sources, tests, and docs.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoControlDegradeMatrixEntriesHaveExistingSourcesTestsAndDocs() {
    let root = repositoryRoot

    for entry in VideoControlDegradeMatrix.entries {
        #expect(!entry.primarySourceFile.isEmpty)
        #expect(!entry.relatedTestFiles.isEmpty)
        #expect(!entry.relatedDocs.isEmpty)
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(entry.primarySourceFile).path
        ))
        for path in entry.relatedSourceFiles + entry.relatedTestFiles + entry.relatedDocs {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func videoControlDegradeMatrixCommandsAreCoveredByCLIInventory() {
    let matrixCommands = Set(VideoControlDegradeMatrix.entries.flatMap(\.relatedCommands))
    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))

    #expect(matrixCommands.isSubset(of: inventoryCommands))
    #expect(inventoryCommands.contains("video-control-degrade-matrix"))
}

@Test
func videoControlDegradeMatrixRowsAreBackedByPolicyBehaviorTests() throws {
    let rowSurfaces = Set(VideoControlDegradeMatrix.entries.map(\.surface.rawValue))
    let proofSurfaces = Set(videoControlPolicyProofs.map(\.surface.rawValue))

    #expect(rowSurfaces == proofSurfaces)
    #expect(VideoControlDegradeMatrix.entries.count == videoControlPolicyProofs.count)

    for proof in videoControlPolicyProofs {
        let row = try #require(VideoControlDegradeMatrix.entries.first {
            $0.surface == proof.surface
        })

        #expect(row.evidenceBoundary == proof.evidenceBoundary)

        let relatedTestFiles = Set(row.relatedTestFiles)
        for behaviorTest in proof.behaviorTests {
            #expect(relatedTestFiles.contains(behaviorTest.file))

            let sourceURL = repositoryRoot.appendingPathComponent(behaviorTest.file)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)

            #expect(source.contains("func \(behaviorTest.functionName)"))
            for token in behaviorTest.policyTokens {
                #expect(source.contains(token))
            }
        }
    }
}

@Test
func videoControlDegradeMatrixKeepsControlSurfacesDisarmedByDefault() throws {
    #expect(VideoControlDegradeMatrix.entries.allSatisfy { $0.audioProtected })
    #expect(VideoControlDegradeMatrix.entries.allSatisfy { !$0.destructiveControlArmedByDefault })

    let atem = try #require(VideoControlDegradeMatrix.entries.first {
        $0.surface == .atemReadOnlyControl
    })
    #expect(atem.evidenceBoundary == .readOnlyControl)
    #expect(atem.notes.contains("disarmed"))
}

@Test
func videoControlDegradeMatrixRequiresDegradeBeforeIntegratedAudioImpact() throws {
    let degradeFirstSurfaces = Set(VideoControlDegradeMatrix.entries
        .filter(\.degradeBeforeAudioLatencyRequired)
        .map(\.surface))

    #expect(degradeFirstSurfaces == [
        .videoTransport,
        .videoRenderOutput,
        .multiVideoStreams,
        .integratedAv,
        .integratedProfile
    ])

    let integratedAv = try #require(VideoControlDegradeMatrix.entries.first {
        $0.surface == .integratedAv
    })
    #expect(integratedAv.audioBaselineRequiredForPass)
    #expect(integratedAv.notes.contains("audio-only baseline first"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct VideoControlPolicyProof {
    var surface: VideoControlSurfaceKind
    var evidenceBoundary: VideoControlEvidenceBoundary
    var behaviorTests: [VideoControlBehaviorTest]
}

private struct VideoControlBehaviorTest {
    var file: String
    var functionName: String
    var policyTokens: [String]
}

private let videoControlPolicyProofs: [VideoControlPolicyProof] = [
    VideoControlPolicyProof(
        surface: .videoCapture,
        evidenceBoundary: .genericCaptureOnly,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift",
                functionName: "videoCaptureReportRejectsInvalidPassEvidence",
                policyTokens: [
                    "passWithoutProductionCaptureEvidence",
                    "passWithoutRawCaptureEvidence",
                    "passIncreasesAudioP99",
                    "passChangesAudioPlayoutTarget"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .videoTransport,
        evidenceBoundary: .frameDropDegradeFirst,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/VideoTransportReportPolicyTests.swift",
                functionName: "videoTransportReportRejectsInvalidPassEvidence",
                policyTokens: [
                    "passWithoutPreAudioDegradation",
                    "passWithoutPreAudioOrRouteDegradation",
                    "passChangesAudioRouteVerdict",
                    "passIncreasesAudioP99"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .videoRenderOutput,
        evidenceBoundary: .outputHardwareEvidence,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift",
                functionName: "receiveRenderSyntheticSmokeAndBlackmagicBoundaryRequirePhysicalEvidence",
                policyTokens: [
                    "VideoReceiveRenderSyntheticSmoke.run",
                    "passWithoutBlackmagicOutputEvidence",
                    "hasPhysicalOutputEvidence"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .multiVideoStreams,
        evidenceBoundary: .streamPriorityDrop,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift",
                functionName: "priorityDropperDropsLowerPriorityVideoFirst",
                policyTokens: [
                    "MultiVideoPriorityDropper.select",
                    "acceptedStreamIDs == [100, 101]",
                    "droppedStreamIDs == [102]"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .atemReadOnlyControl,
        evidenceBoundary: .readOnlyControl,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/OscCueReportTests.swift",
                functionName: "atemReadOnlyControlReportParserProbeAndPassPolicyStayReadOnly",
                policyTokens: [
                    "commandsArmed",
                    "armedCommandsAllowed = true",
                    "armedCommandsAllowed == false"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .oscCueControl,
        evidenceBoundary: .cueTimingNoAudioImpact,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/OscCueReportTests.swift",
                functionName: "oscCueReportValidatesCountsJitterAndRejectsInvalidPassEvidence",
                policyTokens: [
                    "passWithoutLiveUdpLoopback",
                    "passWithoutFirstExternalPeer",
                    "passIncreasesAudioP99",
                    "passWithSyntheticAudioImpact"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .lightingFixtureGate,
        evidenceBoundary: .isolatedFixtureGate,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift",
                functionName: "lightingFixtureGateBlocksUnsafeStatesAndAllowsOnlyArmedIsolatedUniverse",
                policyTokens: [
                    "networkNotIsolated",
                    "outputNotArmed",
                    "canTransmit == false"
                ]
            ),
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift",
                functionName: "lightingFixtureGateRejectsInvalidPassEvidence",
                policyTokens: [
                    "passWithoutPacketCapture",
                    "passWithoutLocalFixtureOwner",
                    "passChangesAudioPlayoutTarget"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .integratedAv,
        evidenceBoundary: .audioMasterIntegratedAv,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/IntegratedAvDegradeFirstTests.swift",
                functionName: "integratedAvReportRejectsPassWithoutVideoDegradationBeforeRouteOrAudioImpact",
                policyTokens: [
                    "videoWithoutPreAudioImpactDegradation",
                    "triggeredBeforeAudioOrRouteImpact = false"
                ]
            )
        ]
    ),
    VideoControlPolicyProof(
        surface: .integratedProfile,
        evidenceBoundary: .fastestAudioProfile,
        behaviorTests: [
            VideoControlBehaviorTest(
                file: "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift",
                functionName: "integratedProfileRejectsInvalidPassEvidence",
                policyTokens: [
                    "defaultProfileMustBeFastestAudio",
                    "audioLatencyDegradationMustBeLast",
                    "videoDisableMustPrecedeAudioLatency",
                    "passWithoutPassSubordinateEvidence"
                ]
            )
        ]
    )
]
