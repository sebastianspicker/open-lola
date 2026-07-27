// Maps DirectP2PSessionRunArgumentSupport CLI input into core calls, keeping argument normalization outside domain services.
func directP2PSessionRunAllowedArguments() -> Set<String> {
    Set([
        "--media", "--output", "--packets", "--duration-seconds",
        "--role", "--local-peer", "--remote-peer", "--local-host", "--remote-host",
        "--control-port", "--remote-control-port", "--audio-port", "--video-port", "--metrics-port",
        "--channels", "--audio-device-uid", "--input-uid", "--output-uid",
        "--av-profile", "--rx-buffer-profile", "--preview", "--quality-policy",
        "--audio-transport", "--audio-compression", "--video-compression",
        "--aoip-sdp-output", "--aoip-sdp-input",
        "--sample-rate", "--frames", "--sample-format", "--input-channels", "--output-channels",
        "--video-device-id", "--video-width", "--video-height", "--video-pixel-format",
        "--video-frame-rate", "--video-stream-id", "--dscp", "--timeout-seconds",
        "--verdict", "--measured-evidence-kind", "--source-peer-label", "--receiver-peer-label",
        "--route-label", "--packet-capture-path", "--packet-capture-artifact-path",
        "--packet-capture-artifact-captured", "--packet-capture-sha256",
        "--dscp-observation", "--dscp-observed", "--dscp-classification", "--dscp-capture-point",
        "--dscp-artifact-path", "--dscp-artifact-captured", "--dscp-artifact-sha256",
        "--clock-sync-summary", "--clock-source", "--clock-method", "--clock-max-offset-microseconds",
        "--clock-artifact-path", "--clock-artifact-captured", "--clock-artifact-sha256",
        "--raw-video-receive-evidence", "--measured-duration-seconds",
        "--fastest-baseline-report-id", "--fastest-baseline-report-path",
        "--fastest-baseline-comparison-path", "--fastest-baseline-audio-p99-us",
        "--fastest-av-audio-p99-us", "--fastest-audio-latency-equal",
        "--fastest-rx-buffer-equal", "--fastest-loss-jitter-equal",
        "--rx-proof-output", "--auto-evidence-output", "--ready-file"
    ])
}

func directP2PSessionRunPublicArguments() -> Set<String> {
    directP2PSessionRunAllowedArguments().subtracting(["--audio-compression"])
}
