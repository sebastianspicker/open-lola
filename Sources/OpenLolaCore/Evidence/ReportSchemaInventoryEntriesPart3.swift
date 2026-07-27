// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension ReportSchemaInventory {
    static let entriesPart3: [ReportSchemaInventoryEntry] = [
        schema(.init(
            name: "NativeAppShellSurfaceProbeReport",
            family: "macOS app shell surface",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift",
            validationFiles: [],
            validatorCommands: ["validate-native-app-shell-surface-probe-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "C11 source-level SwiftUI surface probe; PASS remains blocked until a launched app window" +
                    " is observed and recorded."
        )),
        schema(.init(
            name: "RecordingSessionArtifactReport",
            family: "recording session artifacts",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift",
            validationFiles: [],
            validatorCommands: ["validate-recording-session-report"],
            fixtureGroup: "RecordingSessionArtifacts",
            syntheticSmokeCommand: "recording-session-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Opt-in raw audio/video artifact entries are validated separately; PASS still requires" +
                    " side-lane artifact writing without realtime file I/O, hidden playout growth, or missing" +
                    " physical recording evidence."
        )),
        schema(.init(
            name: "PackagingFieldTestReport",
            family: "packaging field test",
            evidenceClass: .cleanMac,
            sourceFile: "Sources/OpenLolaCore/Release/PackagingFieldTest.swift",
            validationFiles: ["Sources/OpenLolaCore/Release/PackagingFieldTestValidation.swift"],
            validatorCommands: ["validate-packaging-field-report"],
            fixtureGroup: "PackagingFieldTests",
            syntheticSmokeCommand: "packaging-field-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires Developer ID, notarization, stapled ticket, Gatekeeper, package hashes," +
                    " and clean-Mac install evidence."
        )),
        schema(.init(
            name: "FieldReadyRuntimeProofReport",
            family: "field-ready runtime proof",
            evidenceClass: .cleanMac,
            sourceFile: "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift",
            validationFiles: ["Sources/OpenLolaCore/Release/FieldReadyRuntimeProofValidation.swift"],
            validatorCommands: ["validate-field-runtime-proof"],
            fixtureGroup: "FieldReadyRuntimeProofs",
            syntheticSmokeCommand: "field-runtime-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires signed app runtime, Gatekeeper distribution, clean-Mac target, RME" +
                    " visibility, ATEM status, and CLI report-writing evidence."
        )),
        schema(.init(
            name: "LoLaParityDeferredLedgerReport",
            family: "LoLa parity deferred ledger",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift",
            validationFiles: [],
            validatorCommands: ["validate-lola-parity-deferred-ledger"],
            fixtureGroup: "LoLaParityDeferredLedgers",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Ledger documents deferred compatibility features and blocks PASS with native-default or" +
                    " latency-risk changes."
        )),
        schema(.init(
            name: "ExternalConnectorReport",
            family: "external connector source contracts",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-report"],
            fixtureGroup: "ExternalConnectorReports",
            syntheticSmokeCommand: "external-connector-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Code-only connector report. LoLa includes recovered control grammar, outer" +
                    " Ethernet/IPv4/UDP wire framing, little-endian media bodies, normal fragments, audio" +
                    " block sizing, video prelude-plus-fragment packetization, and passive capture media" +
                    " classification; real-world connector interoperability remains PARTIAL until measured" +
                    " external endpoint evidence exists."
        )),
        schema(.init(
            name: "ExternalConnectorSessionReport",
            family: "external connector TX/RX session",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift",
            validationFiles: [
                            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift",
                            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift"
            ],
            validatorCommands: ["validate-external-connector-session-report"],
            fixtureGroup: "ExternalConnectorSessionReports",
            syntheticSmokeCommand: nil,
            relatedTestFiles: [
                            "Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift",
                            "Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift",
                            "Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift"
            ],
            passRequiresMeasuredEvidence: false,
            notes:
                "Protocol-aware TX/RX launch reports for LoLa numeric-SID status-check and quick-connect" +
                    " ACK control over UDP or TCP, advertised-host preflight notes, post-control LoLa UDP" +
                    " socket media TX/RX, optional LoLa raw-link media TX/RX wiring, static media-envelope" +
                    " facts, outer Ethernet/IPv4/UDP wire-frame codec, visible auxiliary control messages," +
                    " native UltraGrid provider/sink evidence, native JackTrip provider/sink evidence" +
                    " including 8/16/24/32-bit DEFAULT PCM and explicit coreaudio/jack-graph backend" +
                    " selection, JackTrip-plus-auxiliary-UltraGrid AV mode, and structured FAIL reports for" +
                    " early clean, unsupported backend, or non-zero external process exits. PASS remains" +
                    " blocked until measured external endpoint evidence exists."
        )),
        schema(.init(
            name: "ExternalConnectorConnectionPlanReport",
            family: "external connector bidirectional connection plan",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-connection-plan"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Builds explicit bidirectional endpoint commands with concrete run-directory outputs," +
                    " exact shell-command validation, connector-scoped executable preflight commands," +
                    " peer-specific LoLa raw-link tuples, and JackTrip P2P server/client endpoints. It is an" +
                    " executable handoff plan, not interoperability proof."
        )),
        schema(.init(
            name: "ExternalConnectorNmpPlanReport",
            family: "external connector universal NMP A/V plan",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-nmp-plan"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Builds one machine-readable LoLa, MVTP/UltraGrid, and JackTrip A/V connection-plan" +
                    " bundle with connector-scoped preflights, endpoint commands, and LoLa-only raw-link" +
                    " interface/MAC propagation. Raw-link NMP inputs are rejected unless LoLa is selected. It" +
                    " is a universal handoff artifact, not interoperability proof."
        )),
        schema(.init(
            name: "ExternalConnectorNmpPreflightReport",
            family: "external connector universal NMP preflight",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-nmp-preflight"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Runs every connector-scoped executable preflight embedded in an NMP A/V plan and" +
                    " aggregates host readiness before endpoint attempts. It is not endpoint interoperability" +
                    " proof."
        )),
        schema(.init(
            name: "ExternalConnectorNmpEndpointRunReport",
            family: "external connector universal NMP endpoint run",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-nmp-endpoint-run"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Consumes an NMP A/V plan and runs each selected connector's local or remote side" +
                    " endpoint session through the existing connector runners, with an optional dry-run" +
                    " override and optional preflight report so discovered UltraGrid/JackTrip executables are" +
                    " reused. It is not bidirectional endpoint interoperability proof."
        )),
        schema(.init(
            name: "ExternalConnectorNmpWorkflowReport",
            family: "external connector universal NMP workflow",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-nmp-workflow"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Single-command NMP workflow that builds the universal A/V plan, runs connector-scoped" +
                    " executable preflight, runs each selected connector's endpoint-side TX/RX pair" +
                    " concurrently, and emits all subordinate reports. It is not bidirectional endpoint" +
                    " interoperability proof."
        )),
        schema(.init(
            name: "ExternalConnectorExecutablePreflightReport",
            family: "external connector executable preflight",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift",
            validationFiles: [],
            validatorCommands: ["validate-external-connector-executable-preflight-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Checks local executable identity for connector-scoped external reference tools such as" +
                    " UltraGrid uv and JackTrip binaries so PATH collisions such as Python uv are reported" +
                    " before parity/helper endpoint attempts. It is host readiness evidence, not" +
                    " interoperability proof."
        )),
        schema(.init(
            name: "LoLaCompatibilityCaptureReport",
            family: "LoLa passive capture decoder",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift",
            validationFiles: ["Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift"],
            validatorCommands: ["validate-lola-capture-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Passive pcap/pcapng decoder for LoLa control/audio/video evidence. It validates capture" +
                    " structure, default ports, recovered control message names, audio fragments, video" +
                    " preludes, video fragments, MJPEG candidates, malformed fragments, and unknown payloads" +
                    " without claiming real-world interoperability."
        )),
        schema(.init(
            name: "LoLaCompatibilityPacketFixtureReport",
            family: "LoLa synthetic packet fixture generator",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift",
            validationFiles: ["Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift"],
            validatorCommands: ["validate-lola-packet-fixture-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Generates open-lola-owned synthetic Ethernet/IPv4/UDP LoLa packet fixtures with" +
                    " recovered audio fragments and video prelude/fragment datagrams, then decodes optional" +
                    " classic pcap files through the passive capture decoder. It is not Windows LoLa capture" +
                    " evidence."
        ))
    ]
}
