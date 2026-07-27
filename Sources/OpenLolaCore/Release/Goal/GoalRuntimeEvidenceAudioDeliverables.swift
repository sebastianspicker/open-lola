// Collects release-goal evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
func goalRuntimeEvidenceDeliverables() -> [GoalRuntimeEvidenceDeliverable] {
    audioEvidenceDeliverables()
        + networkAndVideoEvidenceDeliverables()
        + integrationAndFieldEvidenceDeliverables()
}

func audioEvidenceDeliverables() -> [GoalRuntimeEvidenceDeliverable] {
    [
        twoMacRmeMadiBidirectionalEvidence(),
        receiverSideRoutingMixingEvidence(),
        directP2PSessionUdpMediaEvidence(),
        audioLatencyEvidence(),
        rxBufferBenchmarksEvidence()
    ]
}

func twoMacRmeMadiBidirectionalEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
        id: .twoMacRmeMadiBidirectional,
        title: "Two-Mac multichannel RME MADI TX/RX both directions",
        localRunnableSurfaces: ["audio-loopback-run", "madi-full-duplex-run"],
        requiredPhysicalInputs: ["two reference Macs", "visible RME MADI input/output UIDs", "direct route addresses"],
        commandTemplates: [
            ".build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid " +
                "<rme-output-uid> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 " +
                "--output <run-dir>/m03-rme-loopback-48k-32f.json",
            ".build/debug/open-lola madi-full-duplex-run --local-peer <mac-a-peer-id> --remote-peer " +
                "<mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --port <mac-a-udp-port> " +
                "--remote-port <mac-b-udp-port> --sample-rate 48000 --frames 32 --channels 64 " +
                "--duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> " +
                "--output <run-dir>/m05-madi-full-duplex-mac-a.json",
            ".build/debug/open-lola madi-full-duplex-run --local-peer <mac-b-peer-id> --remote-peer " +
                "<mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --port <mac-b-udp-port> " +
                "--remote-port <mac-a-udp-port> --sample-rate 48000 --frames 32 --channels 64 " +
                "--duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> " +
                "--output <run-dir>/m05-madi-full-duplex-mac-b.json"
        ],
        reportPaths: [
                         "<run-dir>/m03-rme-loopback-48k-32f.json",
                         "<run-dir>/m05-madi-full-duplex-mac-a.json",
                         "<run-dir>/m05-madi-full-duplex-mac-b.json"
        ],
        validators: ["validate-loopback-report", "validate-madi-full-duplex-report"],
        passCriteria: "Both Macs must validate bidirectional 64-channel RME TX/RX with real Core Audio UIDs and " +
                          "no synthetic device labels."
    ))
}

func receiverSideRoutingMixingEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
        id: .receiverSideRoutingMixing,
        title: "Receiver-side routing/mixing",
        localRunnableSurfaces: ["madi-full-duplex-run --receiver-mix swap-stereo"],
        requiredPhysicalInputs: ["physical RME receive path", "operator-approved receiver mix"],
        commandTemplates: [
            ".build/debug/open-lola madi-full-duplex-run --receiver-mix swap-stereo --local-peer " +
                "<mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host " +
                "<mac-b-ip> --port <mac-a-udp-port> --remote-port <mac-b-udp-port> --sample-rate 48000 " +
                "--frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> " +
                "--output-uid <rme-output-uid> --output <run-dir>/m05-receiver-mix-mac-a.json"
        ],
        reportPaths: ["<run-dir>/m05-receiver-mix-mac-a.json"],
        validators: ["validate-madi-full-duplex-report"],
        passCriteria: "The report must prove receiver-local routing/mixing without destructive sender-side downmix."
    ))
}

func directP2PSessionUdpMediaEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
        id: .directP2PSessionUdpMedia,
        title: "Direct P2P session setup and UDP media path",
        localRunnableSurfaces: [
                                   "direct-p2p-two-peer-plan-run",
                                   "direct-p2p-session-run",
                                   "udp-pcm-route-run",
                                   "network-diagnostics-run"
        ],
        requiredPhysicalInputs: [
                                    "two routable Mac IPs",
                                    "packet capture point",
                                    "DSCP policy",
                                    "explicit audio/video device IDs"
        ],
        commandTemplates: directP2PSessionUdpMediaCommandTemplates(),
        reportPaths: [
                         "<run-dir>/m06-direct-p2p-av-plan.json",
                         "<run-dir>/m06-direct-p2p-av-mac-a.json",
                         "<run-dir>/m06-direct-p2p-av-mac-b.json",
                         "<run-dir>/m05-route-receiver.json",
                         "<run-dir>/m05-direct-p2p-network-diagnostics.json"
        ],
        validators: [
            "validate-direct-p2p-session-report",
            "verify-direct-p2p-session-evidence-bundle",
            "validate-route-report",
            "validate-network-diagnostics-report"
        ],
        passCriteria: "Control JSON, session agreement, UDP media, route capture, DSCP evidence, nonzero AV " +
                          "counters, and raw video receive evidence must all come from the same physical route."
    ))
}

func directP2PSessionUdpMediaCommandTemplates() -> [String] {
    [
                ".build/debug/open-lola direct-p2p-two-peer-plan-run --output " +
                    "<run-dir>/m06-direct-p2p-av-plan.json --run-dir <run-dir> --mac-a-peer <mac-a-peer-id> " +
                    "--mac-a-host <mac-a-ip> --mac-a-port-base <mac-a-port-base> --mac-a-input-uid " +
                    "<mac-a-input-uid> --mac-a-output-uid <mac-a-output-uid> --mac-a-video-device-id " +
                    "<mac-a-camera-id-or-auto> --mac-b-peer <mac-b-peer-id> --mac-b-host <mac-b-ip> " +
                    "--mac-b-port-base <mac-b-port-base> --mac-b-input-uid <mac-b-input-uid> " +
                    "--mac-b-output-uid <mac-b-output-uid> --mac-b-video-device-id <mac-b-camera-id-or-auto> " +
                    "--duration-seconds <seconds> --channels 64 --frames 32 --preview on",
                ".build/debug/open-lola direct-p2p-session-run --role responder --local-peer " +
                    "<mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host " +
                    "<mac-a-ip> --control-port <mac-b-control-port> --remote-control-port " +
                    "<mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> " +
                    "--metrics-port <mac-b-metrics-port> --channels 64 --packets <packets> --timeout-seconds " +
                    "30 --output <run-dir>/m06-direct-p2p-mac-b.json",
                ".build/debug/open-lola direct-p2p-session-run --role initiator --local-peer " +
                    "<mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host " +
                    "<mac-b-ip> --control-port <mac-a-control-port> --remote-control-port " +
                    "<mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> " +
                    "--metrics-port <mac-a-metrics-port> --channels 64 --packets <packets> --timeout-seconds " +
                    "30 --output <run-dir>/m06-direct-p2p-mac-a.json",
                ".build/debug/open-lola direct-p2p-session-run --media audio-video --role responder " +
                    "--local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> " +
                    "--remote-host <mac-a-ip> --control-port <mac-b-control-port> --remote-control-port " +
                    "<mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> " +
                    "--metrics-port <mac-b-metrics-port> --channels 64 --duration-seconds <seconds> " +
                    "--input-uid <mac-b-input-uid> --output-uid <mac-b-output-uid> --sample-rate 48000 " +
                    "--frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> " +
                    "--video-device-id <mac-b-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 " +
                    "--preview on --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-b.json",
                ".build/debug/open-lola direct-p2p-session-run --media audio-video --role initiator " +
                    "--local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> " +
                    "--remote-host <mac-b-ip> --control-port <mac-a-control-port> --remote-control-port " +
                    "<mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> " +
                    "--metrics-port <mac-a-metrics-port> --channels 64 --duration-seconds <seconds> " +
                    "--input-uid <mac-a-input-uid> --output-uid <mac-a-output-uid> --sample-rate 48000 " +
                    "--frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> " +
                    "--video-device-id <mac-a-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 101 " +
                    "--preview on --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-a.json",
                ".build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> " +
                    "--peer <sender-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 " +
                    "--duration-seconds 1800 --output <run-dir>/m05-route-receiver.json --route-kind " +
                    "directLink --capture-point <capture-point> --capture-correlated true --verdict partial",
                ".build/debug/open-lola network-diagnostics-run --peer <peer-ip> --ping-count 100 " +
                    "--max-hops 8 --output <run-dir>/m05-direct-p2p-network-diagnostics.json"
            ]
}

func audioLatencyEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
        id: .audioLatencyJitterLossUnderrunsOverruns,
        title: "Measured audio latency, jitter, loss, underruns, and overruns",
        localRunnableSurfaces: ["audio-loopback-run", "udp-pcm-route-run", "drift-plc-run", "network-diagnostics-run"],
        requiredPhysicalInputs: ["analog loopback", "accepted route report", "60-minute run window"],
        commandTemplates: [
            ".build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid " +
                "<rme-output-uid> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 " +
                "--output <run-dir>/m03-audio-latency-loopback.json",
            ".build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> " +
                "--peer <sender-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 " +
                "--duration-seconds 1800 --output <run-dir>/m05-audio-latency-route.json --route-kind " +
                "directLink --capture-point <capture-point> --capture-correlated true --verdict partial",
            ".build/debug/open-lola network-diagnostics-run --peer <peer-ip> --ping-count 100 " +
                "--max-hops 8 --output <run-dir>/m05-network-diagnostics.json",
            ".build/debug/open-lola drift-plc-run --route-report <run-dir>/m05-route-receiver.json " +
                "--duration-seconds 3600 --policy sameDeadline --artifact-assessment-completed true " +
                "--artifact-notes <artifact-notes> --output <run-dir>/m06-drift-plc-60min.json"
        ],
        reportPaths: [
                         "<run-dir>/m03-audio-latency-loopback.json",
                         "<run-dir>/m05-audio-latency-route.json",
                         "<run-dir>/m05-network-diagnostics.json",
                         "<run-dir>/m06-drift-plc-60min.json"
        ],
        validators: [
                        "validate-loopback-report",
                        "validate-route-report",
                        "validate-network-diagnostics-report",
                        "validate-drift-plc-report"
        ],
        passCriteria: "Latency, packet age, jitter, loss, underrun, overrun, and PLC counters must be measured " +
                          "on the accepted physical route."
    ))
}

func rxBufferBenchmarksEvidence() -> GoalRuntimeEvidenceDeliverable {
    evidence(GoalRuntimeEvidenceDeliverableSpec(
        id: .rxBufferBenchmarks,
        title: "Configurable RX buffer modes with benchmarks",
        localRunnableSurfaces: ["rx-buffer-benchmark-run"],
        requiredPhysicalInputs: ["same physical RME/direct route for all RX profiles"],
        commandTemplates: [
            ".build/debug/open-lola rx-buffer-benchmark-run --output " +
                "<run-dir>/m07-rx-buffer-local-benchmark.json --packets 48"
        ],
        reportPaths: ["<run-dir>/m07-rx-buffer-local-benchmark.json"],
        validators: ["validate-rx-buffer-benchmark-report"],
        passCriteria: "Direct, Small, Adaptive, and Stable/WAN rows must show explicit latency cost on the same " +
                          "measured route."
    ))
}
