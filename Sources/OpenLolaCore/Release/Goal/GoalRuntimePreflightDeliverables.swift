// Coordinates release-goal execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
func preflightDeliverables(
    audio: GoalRuntimePreflightAudioProbe,
    video: GoalRuntimePreflightVideoProbe,
    signing: GoalRuntimePreflightSigningProbe
) -> [GoalRuntimePreflightDeliverable] {
    let templateCommands = Dictionary(uniqueKeysWithValues: GoalRuntimeEvidenceTemplateReport
        .template()
        .deliverables
        .map { ($0.id, $0.commandTemplates) })
    let context = GoalRuntimePreflightDeliverableContext(
        audio: audio,
        video: video,
        signing: signing,
        templateCommands: templateCommands
    )
    return coreAudioPreflightDeliverables(context)
        + networkAudioPreflightDeliverables(context)
        + videoPreflightDeliverables(context)
        + integrationPreflightDeliverables(context)
}

private struct GoalRuntimePreflightDeliverableContext {
    let audio: GoalRuntimePreflightAudioProbe
    let video: GoalRuntimePreflightVideoProbe
    let signing: GoalRuntimePreflightSigningProbe
    let templateCommands: [String: [String]]

    var audioEvidence: [String] {
        [
            "core-audio-captured: \(audio.captured)",
            "core-audio-device-count: \(audio.deviceCount)",
            "rme-madi-candidate-count: \(audio.rmeMadiCandidateCount)",
            "core-audio-error: \(audio.error ?? "none")"
        ]
    }

    var videoEvidence: [String] {
        [
            "avfoundation-captured: \(video.captured)",
            "video-device-count: \(video.deviceCount)",
            "blackmagic-atem-candidate-count: \(video.blackmagicAtemCandidateCount)",
            "camera-permission: \(video.permissionStatus.rawValue)",
            "blackmagic-sdk-status: \(video.blackmagicSdkStatus.rawValue)"
        ]
    }

    var signingEvidence: [String] {
        [
            "codesigning-command: \(signing.command)",
            "codesigning-exit-code: \(signing.exitCode)",
            "codesigning-identity-count: \(signing.identities.count)",
            "developer-id-application-identity-count: \(signing.developerIDApplicationIdentityCount)",
            "codesigning-error: \(signing.error ?? "none")"
        ]
    }

    func deliverable(
        _ id: GoalRuntimeEvidenceDeliverableID,
        _ title: String,
        _ evidence: [String],
        _ blockers: [String]
    ) -> GoalRuntimePreflightDeliverable {
        GoalRuntimePreflightDeliverable(
            id: id,
            title: title,
            verdict: .partial,
            currentHostEvidence: evidence,
            blockers: blockers,
            nextCommands: templateCommands[id.rawValue] ?? ["goal-runtime-evidence-template"]
        )
    }
}

private func coreAudioPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .twoMacRmeMadiBidirectional,
            "Two-Mac multichannel RME MADI TX/RX both directions",
            context.audioEvidence,
            rmeBlockers(context.audio) + ["two-Mac bidirectional route evidence is not attached"]
        ),
        context.deliverable(
            .receiverSideRoutingMixing,
            "Receiver-side routing/mixing",
            context.audioEvidence,
            rmeBlockers(context.audio) + ["physical receiver-side RME receive/mix evidence is not attached"]
        )
    ]
}

private func networkAudioPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .directP2PSessionUdpMedia,
            "Direct P2P session setup and UDP media path",
            ["direct-peer-route-evidence: not-attached"],
            ["two-Mac direct or campus route transcript packet capture are not attached"]
        ),
        context.deliverable(
            .audioLatencyJitterLossUnderrunsOverruns,
            "Measured audio latency, jitter, loss, underruns, overruns",
            context.audioEvidence + [
                "physical-route-report: not-attached",
                "sixty-minute-drift-plc-report: not-attached"
            ],
            rmeBlockers(context.audio) + ["accepted physical route long-run measurement reports are not attached"]
        ),
        context.deliverable(
            .rxBufferBenchmarks,
            "Configurable RX buffer modes with benchmarks",
            ["local-rx-buffer-runner: available", "same-route-physical-benchmark: not-attached"],
            ["same physical route RX buffer benchmark matrix not attached"]
        )
    ]
}

private func videoPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .blackmagicAtemVideoTxRx,
            "Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX",
            context.videoEvidence,
            videoBlockers(context.video)
        ),
        context.deliverable(
            .multiVideoRuntime,
            "Staged or working multi-video runtime",
            context.videoEvidence + ["staged-multi-video-runtime: available"],
            videoBlockers(context.video) + ["physical multi-source runtime evidence is not attached"]
        )
    ]
}

private func integrationPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .avTimingRealRuns,
            "AV timing documentation from real runs",
            ["integrated-av-report: not-attached", "e2e-benchmark-report: not-attached"],
            ["physical audio, video, control, and E2E timing reports are not attached"]
        ),
        context.deliverable(
            .oscLightingNoAudioImpact,
            "OSC/lighting integration without audio-thread impact",
            ["external-osc-peer: not-attached", "lighting-target: not-attached"],
            ["external OSC peer and isolated lighting target evidence are not attached"]
        ),
        context.deliverable(
            .packagingSigningCleanMac,
            "Packaging, signing, notarization, Gatekeeper, clean-Mac field test",
            context.signingEvidence + ["clean-mac-report: not-attached"],
            signingBlockers(context.signing) + [
                "notarization, Gatekeeper, and clean-Mac install evidence are not attached"
            ]
        )
    ]
}

private func rmeBlockers(_ audio: GoalRuntimePreflightAudioProbe) -> [String] {
    var blockers: [String] = []
    if !audio.captured {
        blockers.append("Core Audio inventory did not capture successfully")
    }
    if audio.rmeMadiCandidateCount == 0 {
        blockers.append("RME MADI device is not visible")
    }
    return blockers
}

private func videoBlockers(_ video: GoalRuntimePreflightVideoProbe) -> [String] {
    var blockers: [String] = []
    if video.permissionStatus != .authorized {
        blockers.append("camera/capture permission is \(video.permissionStatus.rawValue)")
    }
    if video.blackmagicAtemCandidateCount == 0 {
        blockers.append("Blackmagic/ATEM/DeckLink/UltraStudio device is not visible")
    }
    return blockers
}

private func signingBlockers(_ signing: GoalRuntimePreflightSigningProbe) -> [String] {
    var blockers: [String] = []
    if signing.exitCode != 0 {
        blockers.append("codesigning identity command exited \(signing.exitCode)")
    }
    if signing.developerIDApplicationIdentityCount == 0 {
        blockers.append("Developer ID Application identity is not visible")
    }
    return blockers
}
