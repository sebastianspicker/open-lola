import Foundation

// Runtime evidence template for operator handoff. This file intentionally
// carries command/report blueprints, not measured runtime closure.
public enum GoalRuntimeEvidenceDeliverableID: String, CaseIterable, Codable, Equatable, Sendable {
    case twoMacRmeMadiBidirectional
    case receiverSideRoutingMixing
    case directP2PSessionUdpMedia
    case audioLatencyJitterLossUnderrunsOverruns
    case rxBufferBenchmarks
    case blackmagicAtemVideoTxRx
    case multiVideoRuntime
    case avTimingRealRuns
    case oscLightingNoAudioImpact
    case packagingSigningCleanMac
}

public struct GoalRuntimeEvidenceDeliverable: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var currentVerdict: MeasurementVerdict
    public var localRunnableSurfaces: [String]
    public var requiredPhysicalInputs: [String]
    public var commandTemplates: [String]
    public var reportPaths: [String]
    public var validators: [String]
    public var passCriteria: String

    public init(
        id: GoalRuntimeEvidenceDeliverableID,
        title: String,
        currentVerdict: MeasurementVerdict,
        localRunnableSurfaces: [String],
        requiredPhysicalInputs: [String],
        commandTemplates: [String],
        reportPaths: [String],
        validators: [String],
        passCriteria: String
    ) {
        self.id = id.rawValue
        self.title = title
        self.currentVerdict = currentVerdict
        self.localRunnableSurfaces = localRunnableSurfaces
        self.requiredPhysicalInputs = requiredPhysicalInputs
        self.commandTemplates = commandTemplates
        self.reportPaths = reportPaths
        self.validators = validators
        self.passCriteria = passCriteria
    }
}

public struct GoalRuntimeEvidenceTemplateSummary: Codable, Equatable, Sendable {
    public var deliverableCount: Int
    public var partialDeliverableCount: Int

    public init(deliverables: [GoalRuntimeEvidenceDeliverable]) {
        deliverableCount = deliverables.count
        partialDeliverableCount = deliverables.filter { $0.currentVerdict == .partial }.count
    }
}

public enum GoalRuntimeEvidenceTemplateValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateDeliverable(String)
    case missingDeliverable(String)
    case deliverablePassWithoutPhysicalEvidence(String)
    case summaryMismatch
}

enum GoalRuntimeEvidenceTemplateValidator: ReportPrimitiveValidating {
    typealias ValidationError = GoalRuntimeEvidenceTemplateValidationError
}

public struct GoalRuntimeEvidenceTemplateReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var sourceOfTruth: String
    public var runDirectoryTemplate: String
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var summary: GoalRuntimeEvidenceTemplateSummary
    public var deliverables: [GoalRuntimeEvidenceDeliverable]
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        goalDocument: String,
        sourceOfTruth: String,
        runDirectoryTemplate: String,
        verdict: MeasurementVerdict,
        realWorldVerdict: MeasurementVerdict,
        deliverables: [GoalRuntimeEvidenceDeliverable],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.goalDocument = goalDocument
        self.sourceOfTruth = sourceOfTruth
        self.runDirectoryTemplate = runDirectoryTemplate
        self.verdict = verdict
        self.realWorldVerdict = realWorldVerdict
        self.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: deliverables)
        self.deliverables = deliverables
        self.notes = notes
    }

    public static func template() -> GoalRuntimeEvidenceTemplateReport {
        let deliverables = goalRuntimeEvidenceDeliverables()
        return GoalRuntimeEvidenceTemplateReport(
            id: "goal-runtime-evidence-template-2026-05-05",
            title: "GOAL.md runtime evidence template",
            capturedAt: "2026-05-05T00:00:00Z",
            goalDocument: "GOAL.md",
            sourceOfTruth: "docs/implementation-handoff.md",
            runDirectoryTemplate: "/private/tmp/open-lola-real-runs/<yyyy-mm-dd>",
            verdict: .partial,
            realWorldVerdict: .partial,
            deliverables: deliverables,
            notes: "Machine-readable handoff for physical runtime evidence. Replace placeholders with measured values and keep every row PARTIAL until real hardware, route, signing, and clean-Mac reports validate."
        )
    }

    public func validate() throws {
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(id, "id")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(title, "title")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(goalDocument, "goalDocument")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(sourceOfTruth, "sourceOfTruth")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(runDirectoryTemplate, "runDirectoryTemplate")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(notes, "notes")
        guard summary == GoalRuntimeEvidenceTemplateSummary(deliverables: deliverables) else {
            throw GoalRuntimeEvidenceTemplateValidationError.summaryMismatch
        }
        try validateDeliverables()
    }

    private func validateDeliverables() throws {
        guard !deliverables.isEmpty else {
            throw GoalRuntimeEvidenceTemplateValidationError.emptyList("deliverables")
        }

        var seen = Set<String>()
        for deliverable in deliverables {
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(deliverable.id, "deliverables.id")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(deliverable.title, "deliverables.title")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(deliverable.passCriteria, "deliverables.passCriteria")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(deliverable.localRunnableSurfaces, "deliverables.localRunnableSurfaces")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(deliverable.requiredPhysicalInputs, "deliverables.requiredPhysicalInputs")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(deliverable.commandTemplates, "deliverables.commandTemplates")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(deliverable.reportPaths, "deliverables.reportPaths")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(deliverable.validators, "deliverables.validators")
            guard seen.insert(deliverable.id).inserted else {
                throw GoalRuntimeEvidenceTemplateValidationError.duplicateDeliverable(deliverable.id)
            }
            if deliverable.currentVerdict == .pass {
                throw GoalRuntimeEvidenceTemplateValidationError.deliverablePassWithoutPhysicalEvidence(deliverable.id)
            }
        }

        for id in GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue) where !seen.contains(id) {
            throw GoalRuntimeEvidenceTemplateValidationError.missingDeliverable(id)
        }
    }
}

private func goalRuntimeEvidenceDeliverables() -> [GoalRuntimeEvidenceDeliverable] {
    [
        evidence(
            .twoMacRmeMadiBidirectional,
            "Two-Mac multichannel RME MADI TX/RX both directions",
            ["audio-loopback-run", "madi-full-duplex-run"],
            ["two reference Macs", "visible RME MADI input/output UIDs", "direct route addresses"],
            [
                ".build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m03-rme-loopback-48k-32f.json",
                ".build/debug/open-lola madi-full-duplex-run --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --port <mac-a-udp-port> --remote-port <mac-b-udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --output <run-dir>/m05-madi-full-duplex-mac-a.json",
                ".build/debug/open-lola madi-full-duplex-run --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --port <mac-b-udp-port> --remote-port <mac-a-udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --output <run-dir>/m05-madi-full-duplex-mac-b.json",
            ],
            ["<run-dir>/m03-rme-loopback-48k-32f.json", "<run-dir>/m05-madi-full-duplex-mac-a.json", "<run-dir>/m05-madi-full-duplex-mac-b.json"],
            ["validate-loopback-report", "validate-madi-full-duplex-report"],
            "Both Macs must validate bidirectional 64-channel RME TX/RX with real Core Audio UIDs and no synthetic device labels."
        ),
        evidence(
            .receiverSideRoutingMixing,
            "Receiver-side routing/mixing",
            ["madi-full-duplex-run --receiver-mix swap-stereo"],
            ["physical RME receive path", "operator-approved receiver mix"],
            [
                ".build/debug/open-lola madi-full-duplex-run --receiver-mix swap-stereo --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --port <mac-a-udp-port> --remote-port <mac-b-udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --output <run-dir>/m05-receiver-mix-mac-a.json",
            ],
            ["<run-dir>/m05-receiver-mix-mac-a.json"],
            ["validate-madi-full-duplex-report"],
            "The report must prove receiver-local routing/mixing without destructive sender-side downmix."
        ),
        evidence(
            .directP2PSessionUdpMedia,
            "Direct P2P session setup and UDP media path",
            ["direct-p2p-two-peer-plan-run", "direct-p2p-session-run", "udp-pcm-route-run", "network-diagnostics-run"],
            ["two routable Mac IPs", "packet capture point", "DSCP policy", "explicit audio/video device IDs"],
            [
                ".build/debug/open-lola direct-p2p-two-peer-plan-run --output <run-dir>/m06-direct-p2p-av-plan.json --run-dir <run-dir> --mac-a-peer <mac-a-peer-id> --mac-a-host <mac-a-ip> --mac-a-port-base <mac-a-port-base> --mac-a-input-uid <mac-a-input-uid> --mac-a-output-uid <mac-a-output-uid> --mac-a-video-device-id <mac-a-camera-id-or-auto> --mac-b-peer <mac-b-peer-id> --mac-b-host <mac-b-ip> --mac-b-port-base <mac-b-port-base> --mac-b-input-uid <mac-b-input-uid> --mac-b-output-uid <mac-b-output-uid> --mac-b-video-device-id <mac-b-camera-id-or-auto> --duration-seconds <seconds> --channels 64 --frames 32 --preview on",
                ".build/debug/open-lola direct-p2p-session-run --role responder --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --control-port <mac-b-control-port> --remote-control-port <mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> --metrics-port <mac-b-metrics-port> --channels 64 --packets <packets> --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-mac-b.json",
                ".build/debug/open-lola direct-p2p-session-run --role initiator --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --control-port <mac-a-control-port> --remote-control-port <mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> --metrics-port <mac-a-metrics-port> --channels 64 --packets <packets> --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-mac-a.json",
                ".build/debug/open-lola direct-p2p-session-run --media audio-video --role responder --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --control-port <mac-b-control-port> --remote-control-port <mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> --metrics-port <mac-b-metrics-port> --channels 64 --duration-seconds <seconds> --input-uid <mac-b-input-uid> --output-uid <mac-b-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> --video-device-id <mac-b-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 --preview on --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-b.json",
                ".build/debug/open-lola direct-p2p-session-run --media audio-video --role initiator --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --control-port <mac-a-control-port> --remote-control-port <mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> --metrics-port <mac-a-metrics-port> --channels 64 --duration-seconds <seconds> --input-uid <mac-a-input-uid> --output-uid <mac-a-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> --video-device-id <mac-a-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 101 --preview on --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-a.json",
                ".build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> --peer <sender-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m05-route-receiver.json --route-kind directLink --capture-point <capture-point> --capture-correlated true --verdict partial",
                ".build/debug/open-lola network-diagnostics-run --peer <peer-ip> --ping-count 100 --max-hops 8 --output <run-dir>/m05-direct-p2p-network-diagnostics.json",
            ],
            ["<run-dir>/m06-direct-p2p-av-plan.json", "<run-dir>/m06-direct-p2p-av-mac-a.json", "<run-dir>/m06-direct-p2p-av-mac-b.json", "<run-dir>/m05-route-receiver.json", "<run-dir>/m05-direct-p2p-network-diagnostics.json"],
            [
                "validate-direct-p2p-session-report",
                "verify-direct-p2p-session-evidence-bundle",
                "validate-route-report",
                "validate-network-diagnostics-report",
            ],
            "Control JSON, session agreement, UDP media, route capture, DSCP evidence, nonzero AV counters, and raw video receive evidence must all come from the same physical route."
        ),
        evidence(
            .audioLatencyJitterLossUnderrunsOverruns,
            "Measured audio latency, jitter, loss, underruns, and overruns",
            ["audio-loopback-run", "udp-pcm-route-run", "drift-plc-run", "network-diagnostics-run"],
            ["analog loopback", "accepted route report", "60-minute run window"],
            [
                ".build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m03-audio-latency-loopback.json",
                ".build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> --peer <sender-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m05-audio-latency-route.json --route-kind directLink --capture-point <capture-point> --capture-correlated true --verdict partial",
                ".build/debug/open-lola network-diagnostics-run --peer <peer-ip> --ping-count 100 --max-hops 8 --output <run-dir>/m05-network-diagnostics.json",
                ".build/debug/open-lola drift-plc-run --route-report <run-dir>/m05-route-receiver.json --duration-seconds 3600 --policy sameDeadline --artifact-assessment-completed true --artifact-notes <artifact-notes> --output <run-dir>/m06-drift-plc-60min.json",
            ],
            ["<run-dir>/m03-audio-latency-loopback.json", "<run-dir>/m05-audio-latency-route.json", "<run-dir>/m05-network-diagnostics.json", "<run-dir>/m06-drift-plc-60min.json"],
            ["validate-loopback-report", "validate-route-report", "validate-network-diagnostics-report", "validate-drift-plc-report"],
            "Latency, packet age, jitter, loss, underrun, overrun, and PLC counters must be measured on the accepted physical route."
        ),
        evidence(
            .rxBufferBenchmarks,
            "Configurable RX buffer modes with benchmarks",
            ["rx-buffer-benchmark-run"],
            ["same physical RME/direct route for all RX profiles"],
            [
                ".build/debug/open-lola rx-buffer-benchmark-run --output <run-dir>/m07-rx-buffer-local-benchmark.json --packets 48",
            ],
            ["<run-dir>/m07-rx-buffer-local-benchmark.json"],
            ["validate-rx-buffer-benchmark-report"],
            "Direct, Small, Adaptive, and Stable/WAN rows must show explicit latency cost on the same measured route."
        ),
        evidence(
            .blackmagicAtemVideoTxRx,
            "Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX",
            ["video-capture-inventory", "video-capture-run", "video-transport-run", "atem-readonly-probe"],
            ["Blackmagic or ATEM device", "camera permission", "video route capture"],
            [
                ".build/debug/open-lola video-capture-inventory --output <run-dir>/m08-video-inventory.json",
                ".build/debug/open-lola video-capture-run --device-id <blackmagic-or-atem-device-id> --duration-seconds 1800 --output <run-dir>/m08-video-capture.json --production-hardware <atem|decklink|ultrastudio|blackmagic-capture> --production-manufacturer Blackmagic --verdict partial",
                ".build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port <video-udp-port> --duration-seconds 1800 --output <run-dir>/m09-video-transport.json --route-kind directWired --packet-capture-point <capture-point>",
                ".build/debug/open-lola atem-readonly-probe --host <atem-ip> --port 9910 --timeout-milliseconds 250 --poll-interval-milliseconds 1000 --network-interface <interface-name> --same-network-as-audio true --output <run-dir>/m11-atem-readonly.json",
            ],
            ["<run-dir>/m08-video-inventory.json", "<run-dir>/m08-video-capture.json", "<run-dir>/m09-video-transport.json", "<run-dir>/m11-atem-readonly.json"],
            ["validate-video-capture-inventory", "validate-video-capture-report", "validate-video-transport-report", "validate-atem-control-report"],
            "Capture and transport must identify real Blackmagic/ATEM hardware and show video does not alter audio timing."
        ),
        evidence(
            .multiVideoRuntime,
            "Staged or working multi-video runtime",
            ["session-capabilities", "video-transport-run"],
            ["one to four real video sources or staged physical stream plan"],
            [
                ".build/debug/open-lola session-capabilities",
                ".build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port <video-udp-port> --duration-seconds 1800 --output <run-dir>/m09-multi-video-transport.json --stream-count <1-4> --visible-streams <n> --route-kind directWired --packet-capture-point <capture-point>",
            ],
            ["<run-dir>/m09-multi-video-transport.json"],
            ["validate-video-transport-report"],
            "The report must prove bounded multi-stream scheduling or explicitly stage the remaining physical stream count."
        ),
        evidence(
            .avTimingRealRuns,
            "AV timing documentation from real runs",
            ["integrated-av-run", "integrated-profile-run", "e2e-benchmark-run"],
            ["accepted audio, route, video, OSC/ATEM, and lighting reports"],
            [
                ".build/debug/open-lola integrated-av-run --audio-baseline <audio-baseline-report-id> --video-capture on --video-transport on --video-preview off --osc-control on --atem-readonly <atem-ip> --duration-seconds 1800 --video-transport-report <run-dir>/m09-video-transport.json --output <run-dir>/m10-integrated-av.json",
                ".build/debug/open-lola integrated-profile-run --fastest-audio <fastest-audio-report-id> --integrated-av <integrated-av-report-id> --lighting-control <lighting-report-id> --audio-only <audio-only-report-id> --audio-video <audio-video-report-id> --audio-control <audio-control-report-id> --audio-video-control <audio-video-control-report-id> --fastest-audio-report <run-dir>/audio-benchmark.json --integrated-av-report <run-dir>/m10-integrated-av.json --lighting-control-report <run-dir>/m12-lighting-gate.json --output <run-dir>/m12-integrated-profile.json",
                ".build/debug/open-lola e2e-benchmark-run --audio-benchmark <run-dir>/audio-benchmark.json --integrated-av <run-dir>/m10-integrated-av.json --video-transport <run-dir>/m09-video-transport.json --performance-audit <run-dir>/performance-audit.json --duration-seconds 1800 --output <run-dir>/m13-e2e-benchmark.json",
            ],
            ["<run-dir>/m10-integrated-av.json", "<run-dir>/m12-integrated-profile.json", "<run-dir>/m13-e2e-benchmark.json"],
            ["validate-integrated-av-report", "validate-integrated-profile-report", "validate-e2e-benchmark-report"],
            "Real runs must document audio-master timing, AV offset/jitter, video frame age, packet age, and degradation before audio latency changes."
        ),
        evidence(
            .oscLightingNoAudioImpact,
            "OSC/lighting integration without audio-thread impact",
            ["osc-cue-external-run", "lighting-gate-run"],
            ["external OSC peer", "isolated lighting universe", "capture point"],
            [
                ".build/debug/open-lola osc-cue-external-run --audio-baseline <audio-baseline-report-id> --port <local-osc-port> --count <n> --first-external-peer <chataigne|openStageControl|other> --external-host <peer-host> --external-port <peer-port> --external-available true --output <run-dir>/m11-osc-external.json",
                ".build/debug/open-lola lighting-gate-run --audio-baseline <audio-baseline-report-id> --osc-cue-report <osc-report-id> --protocol <sacn|artNet> --interop-target <ola|qlcPlus> --universe <n> --network-mode isolatedUnicast --destination <target-ip> --port <port> --isolated-network true --explicitly-armed true --capture-tool <tool> --capture-point <capture-point> --duration-seconds <n> --output <run-dir>/m12-lighting-gate.json",
            ],
            ["<run-dir>/m11-osc-external.json", "<run-dir>/m12-lighting-gate.json"],
            ["validate-osc-cue-report", "validate-lighting-gate-report"],
            "OSC and lighting reports must include audio-active comparison and prove control work never runs on audio-critical threads."
        ),
        evidence(
            .packagingSigningCleanMac,
            "Packaging, signing, notarization, Gatekeeper, and clean-Mac field test",
            ["packaging-field-run", "field-runtime-proof-run", "field-readiness-run"],
            ["Developer ID identity", "notarytool profile", "signed package", "clean Mac"],
            [
                "security find-identity -v -p codesigning",
                "codesign --verify --deep --strict --verbose=2 <signed-app-bundle>",
                "xcrun notarytool submit <signed-dmg-or-zip> --keychain-profile <notarytool-profile> --wait --output-format json > <run-dir>/m15-notary-submit.json",
                "xcrun stapler validate <signed-dmg-or-app>",
                "spctl --assess --type execute --verbose=4 <signed-app-bundle>",
                ".build/debug/open-lola packaging-field-run --integrated-report <run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-shell.json --recording-report <run-dir>/m14-recording-session.json --output-dir <run-dir>/package --report <run-dir>/m15-packaging-field.json",
                ".build/debug/open-lola field-runtime-proof-run --integrated-report <run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-shell.json --recording-report <run-dir>/m14-recording-session.json --packaging-report <run-dir>/m15-packaging-field.json --output <run-dir>/p05-field-runtime-proof.json",
                ".build/debug/open-lola field-readiness-run --integrated-report <run-dir>/m10-integrated-av.json --duration-seconds 1800 --output-dir <run-dir>/field-readiness",
            ],
            ["<run-dir>/m15-packaging-field.json", "<run-dir>/p05-field-runtime-proof.json", "<run-dir>/field-readiness"],
            ["validate-packaging-field-report", "validate-field-runtime-proof"],
            "PASS requires Developer ID signing, hardened runtime, notarization, stapled ticket, Gatekeeper acceptance, and clean-Mac install/launch evidence."
        ),
    ]
}

private func evidence(
    _ id: GoalRuntimeEvidenceDeliverableID,
    _ title: String,
    _ localRunnableSurfaces: [String],
    _ requiredPhysicalInputs: [String],
    _ commandTemplates: [String],
    _ reportPaths: [String],
    _ validators: [String],
    _ passCriteria: String
) -> GoalRuntimeEvidenceDeliverable {
    GoalRuntimeEvidenceDeliverable(
        id: id,
        title: title,
        currentVerdict: .partial,
        localRunnableSurfaces: localRunnableSurfaces,
        requiredPhysicalInputs: requiredPhysicalInputs,
        commandTemplates: commandTemplates,
        reportPaths: reportPaths,
        validators: validators,
        passCriteria: passCriteria
    )
}
