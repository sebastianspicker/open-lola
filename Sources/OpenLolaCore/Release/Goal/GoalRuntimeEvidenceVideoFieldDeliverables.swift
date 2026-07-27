// Collects release-goal evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
func networkAndVideoEvidenceDeliverables() -> [GoalRuntimeEvidenceDeliverable] {
    [
        blackmagicAtemVideoTxRxEvidence(),
        multiVideoRuntimeEvidence()
    ]
}

func blackmagicAtemVideoTxRxEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
                id: .blackmagicAtemVideoTxRx,
                title: "Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX",
                localRunnableSurfaces: [
                                           "video-capture-inventory",
                                           "video-capture-run",
                                           "video-transport-run",
                                           "atem-readonly-probe"
                ],
                requiredPhysicalInputs: ["Blackmagic or ATEM device", "camera permission", "video route capture"],
                commandTemplates: [
                    ".build/debug/open-lola video-capture-inventory --output <run-dir>/m08-video-inventory.json",
                    ".build/debug/open-lola video-capture-run --device-id <blackmagic-or-atem-device-id> " +
                        "--duration-seconds 1800 --output <run-dir>/m08-video-capture.json --production-hardware " +
                        "<atem|decklink|ultrastudio|blackmagic-capture> --production-manufacturer Blackmagic " +
                        "--verdict partial",
                    ".build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port " +
                        "<video-udp-port> --duration-seconds 1800 --output <run-dir>/m09-video-transport.json " +
                        "--route-kind directWired --packet-capture-point <capture-point>",
                    ".build/debug/open-lola atem-readonly-probe --host <atem-ip> --port 9910 " +
                        "--timeout-milliseconds 250 --poll-interval-milliseconds 1000 --network-interface " +
                        "<interface-name> --same-network-as-audio true --output <run-dir>/m11-atem-readonly.json"
                ],
                reportPaths: [
                                 "<run-dir>/m08-video-inventory.json",
                                 "<run-dir>/m08-video-capture.json",
                                 "<run-dir>/m09-video-transport.json",
                                 "<run-dir>/m11-atem-readonly.json"
                ],
                validators: [
                                "validate-video-capture-inventory",
                                "validate-video-capture-report",
                                "validate-video-transport-report",
                                "validate-atem-control-report"
                ],
                passCriteria: "Capture and transport must identify real Blackmagic/ATEM hardware and show video does " +
                                  "not alter audio timing."
            ))
}

func multiVideoRuntimeEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
                id: .multiVideoRuntime,
                title: "Staged or working multi-video runtime",
                localRunnableSurfaces: ["session-capabilities", "video-transport-run"],
                requiredPhysicalInputs: ["one to four real video sources or staged physical stream plan"],
                commandTemplates: [
                    ".build/debug/open-lola session-capabilities",
                    ".build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port " +
                        "<video-udp-port> --duration-seconds 1800 --output " +
                        "<run-dir>/m09-multi-video-transport.json --stream-count <1-4> --visible-streams <n> " +
                        "--route-kind directWired --packet-capture-point <capture-point>"
                ],
                reportPaths: ["<run-dir>/m09-multi-video-transport.json"],
                validators: ["validate-video-transport-report"],
                passCriteria: "The report must prove bounded multi-stream scheduling or " +
                                  "explicitly stage the remaining physical stream count."
            ))
}

func integrationAndFieldEvidenceDeliverables() -> [GoalRuntimeEvidenceDeliverable] {
    [
        avTimingRealRunsEvidence(),
        oscLightingNoAudioImpactEvidence(),
        packagingSigningCleanMacEvidence()
    ]
}

func avTimingRealRunsEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
                id: .avTimingRealRuns,
                title: "AV timing documentation from real runs",
                localRunnableSurfaces: ["integrated-av-run", "integrated-profile-run", "e2e-benchmark-run"],
                requiredPhysicalInputs: ["accepted audio, route, video, OSC/ATEM, and lighting reports"],
                commandTemplates: [
                    ".build/debug/open-lola integrated-av-run --audio-baseline <audio-baseline-report-id> " +
                        "--video-capture on --video-transport on --video-preview off --osc-control on " +
                        "--atem-readonly <atem-ip> --duration-seconds 1800 --video-transport-report " +
                        "<run-dir>/m09-video-transport.json --output <run-dir>/m10-integrated-av.json",
                    ".build/debug/open-lola integrated-profile-run --fastest-audio <fastest-audio-report-id> " +
                        "--integrated-av <integrated-av-report-id> --lighting-control <lighting-report-id> " +
                        "--audio-only <audio-only-report-id> --audio-video <audio-video-report-id> " +
                        "--audio-control <audio-control-report-id> --audio-video-control " +
                        "<audio-video-control-report-id> --fastest-audio-report <run-dir>/audio-benchmark.json " +
                        "--integrated-av-report <run-dir>/m10-integrated-av.json --lighting-control-report " +
                        "<run-dir>/m12-lighting-gate.json --output <run-dir>/m12-integrated-profile.json",
                    ".build/debug/open-lola e2e-benchmark-run --audio-benchmark " +
                        "<run-dir>/audio-benchmark.json --integrated-av <run-dir>/m10-integrated-av.json " +
                        "--video-transport <run-dir>/m09-video-transport.json --performance-audit " +
                        "<run-dir>/performance-audit.json --duration-seconds 1800 --output " +
                        "<run-dir>/m13-e2e-benchmark.json"
                ],
                reportPaths: [
                                 "<run-dir>/m10-integrated-av.json",
                                 "<run-dir>/m12-integrated-profile.json",
                                 "<run-dir>/m13-e2e-benchmark.json"
                ],
                validators: [
                                "validate-integrated-av-report",
                                "validate-integrated-profile-report",
                                "validate-e2e-benchmark-report"
                ],
                passCriteria: "Real runs must document audio-master timing, AV offset/jitter, " +
                                  "video frame age, packet age, and degradation before audio latency changes."
            ))
}

func oscLightingNoAudioImpactEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
                id: .oscLightingNoAudioImpact,
                title: "OSC/lighting integration without audio-thread impact",
                localRunnableSurfaces: ["osc-cue-external-run", "lighting-gate-run"],
                requiredPhysicalInputs: ["external OSC peer", "isolated lighting universe", "capture point"],
                commandTemplates: [
                    ".build/debug/open-lola osc-cue-external-run --audio-baseline <audio-baseline-report-id> " +
                        "--port <local-osc-port> --count <n> --first-external-peer " +
                        "<chataigne|openStageControl|other> --external-host <peer-host> --external-port " +
                        "<peer-port> --external-available true --output <run-dir>/m11-osc-external.json",
                    ".build/debug/open-lola lighting-gate-run --audio-baseline <audio-baseline-report-id> " +
                        "--osc-cue-report <osc-report-id> --protocol <sacn|artNet> --interop-target <ola|qlcPlus> " +
                        "--universe <n> --network-mode isolatedUnicast --destination <target-ip> --port <port> " +
                        "--isolated-network true --explicitly-armed true --capture-tool <tool> --capture-point " +
                        "<capture-point> --duration-seconds <n> --output <run-dir>/m12-lighting-gate.json"
                ],
                reportPaths: ["<run-dir>/m11-osc-external.json", "<run-dir>/m12-lighting-gate.json"],
                validators: ["validate-osc-cue-report", "validate-lighting-gate-report"],
                passCriteria: "OSC and lighting reports must include audio-active comparison and prove control work " +
                                  "never runs on audio-critical threads."
            ))
}

func packagingSigningCleanMacEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
                id: .packagingSigningCleanMac,
                title: "Packaging, signing, notarization, Gatekeeper, and clean-Mac field test",
                localRunnableSurfaces: ["packaging-field-run", "field-runtime-proof-run", "field-readiness-run"],
                requiredPhysicalInputs: ["Developer ID identity", "notarytool profile", "signed package", "clean Mac"],
                commandTemplates: [
                    "security find-identity -v -p codesigning",
                    "codesign --verify --deep --strict --verbose=2 <signed-app-bundle>",
                    "xcrun notarytool submit <signed-dmg-or-zip> --keychain-profile <notarytool-profile> " +
                        "--wait --output-format json > <run-dir>/m15-notary-submit.json",
                    "xcrun stapler validate <signed-dmg-or-app>",
                    "spctl --assess --type execute --verbose=4 <signed-app-bundle>",
                    ".build/debug/open-lola packaging-field-run --integrated-report " +
                        "<run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-shell.json " +
                        "--recording-report <run-dir>/m14-recording-session.json --output-dir <run-dir>/package " +
                        "--report <run-dir>/m15-packaging-field.json",
                    ".build/debug/open-lola field-runtime-proof-run --integrated-report " +
                        "<run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-shell.json " +
                        "--recording-report <run-dir>/m14-recording-session.json --packaging-report " +
                        "<run-dir>/m15-packaging-field.json --output <run-dir>/p05-field-runtime-proof.json",
                    ".build/debug/open-lola field-readiness-run --integrated-report " +
                        "<run-dir>/m10-integrated-av.json --duration-seconds 1800 --output-dir " +
                        "<run-dir>/field-readiness"
                ],
                reportPaths: [
                                 "<run-dir>/m15-packaging-field.json",
                                 "<run-dir>/p05-field-runtime-proof.json",
                                 "<run-dir>/field-readiness"
                ],
                validators: ["validate-packaging-field-report", "validate-field-runtime-proof"],
                passCriteria: "PASS requires Developer ID signing, hardened runtime, notarization, stapled ticket, " +
                                  "Gatekeeper acceptance, and clean-Mac install/launch evidence."
            ))
}

struct GoalRuntimeEvidenceDeliverableSpec {
    var id: GoalRuntimeEvidenceDeliverableID
    var title: String
    var localRunnableSurfaces: [String]
    var requiredPhysicalInputs: [String]
    var commandTemplates: [String]
    var reportPaths: [String]
    var validators: [String]
    var passCriteria: String
}

func evidence(_ spec: GoalRuntimeEvidenceDeliverableSpec) -> GoalRuntimeEvidenceDeliverable {
    GoalRuntimeEvidenceDeliverable(
        id: spec.id,
        title: spec.title,
        currentVerdict: .partial,
        references: GoalRuntimeEvidenceDeliverableReferences(
            localRunnableSurfaces: spec.localRunnableSurfaces,
            requiredPhysicalInputs: spec.requiredPhysicalInputs,
            commandTemplates: spec.commandTemplates,
            reportPaths: spec.reportPaths,
            validators: spec.validators
        ),
        passCriteria: spec.passCriteria
    )
}
