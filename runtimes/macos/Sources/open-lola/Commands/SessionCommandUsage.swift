// Prints the --help text for the session commands that take flags but previously rejected help requests.

func printDirectP2PTwoPeerPlanRunUsage() {
    print(
        """
        Usage: open-lola direct-p2p-two-peer-plan-run --output <plan.json> --run-dir <dir> \
        --duration-seconds <n> [options]

        Writes a responder-first two-peer run plan. Mac A is the initiator, Mac B the responder.
        Nothing is launched; pass the plan to mac-to-mac-connection-preflight-run and
        direct-p2p-two-peer-local-run.

        Required:
          --output <path>             plan report to write
          --run-dir <dir>             directory that will hold the peer reports
          --duration-seconds <n>      media duration of each peer
          --mac-a-peer <id>           Mac A peer id
          --mac-a-host <ipv4>         Mac A address
          --mac-a-port-base <port>    Mac A control port (audio, video, metrics use +1, +2, +3)
          --mac-a-input-uid <uid>     Mac A input device UID (see: open-lola device-inventory)
          --mac-a-output-uid <uid>    Mac A output device UID
          --mac-a-video-device-id <id|auto>
          --mac-b-peer, --mac-b-host, --mac-b-port-base, --mac-b-input-uid, --mac-b-output-uid,
          --mac-b-video-device-id     the same five values for Mac B

        Options (defaults in brackets):
          --executable <path>         open-lola path written into the plan [open-lola]
          --channels <n> [64]  --sample-rate <hz> [48000]  --frames <n> [32]
          --sample-format <fmt> [float32]  --audio-transport <name>  --audio-compression <name>
          --video-width <n> [1280]  --video-height <n> [720]  --video-frame-rate <n> [30]
          --video-pixel-format <fmt> [bgra8]  --video-compression <raw|jpeg-xs>
          --av-profile <balanced|fastest>  --rx-buffer-profile <name>  --preview <on|off>
          --timeout-seconds <n> [30]
        """
    )
}

func printMacToMacConnectionPreflightRunUsage() {
    print(
        """
        Usage: open-lola mac-to-mac-connection-preflight-run --plan <plan.json> --output <report.json> \
        [options]
           or: open-lola mac-to-mac-connection-preflight-run --local-peer-id <id> --remote-peer-id <id> \
        --peer <ip> --output <report.json> [options]

        Checks connectivity to the remote peer (ping and traceroute) and writes the preflight report.
        direct-p2p-two-peer-local-run --execute true requires a report with verdict PASS that was
        created with --plan. Without --nat-route-report the report is PASS only for a peer directly on a
        subnet of this Mac with lossless ping and a one-hop (or unavailable) traceroute.

        Required:
          --output <path>                 report to write
          --plan <plan.json>              bind the report to a two-peer plan; peer ids and the remote
                                          host come from the plan
          (without --plan) --local-peer-id <id>  --remote-peer-id <id>  --peer <ip>

        Options (defaults in brackets):
          --ping-count <n> [3]  --max-hops <n> [8]
          --nat-route-report <path>           NAT-friendly route report (nat-friendly-route-run);
                                              must have verdict PASS for a PASS preflight
          --route-certification-report <path> optional Mac-to-Mac route certification report
        """
    )
}

func printDirectP2PTwoPeerLocalRunUsage() {
    print(
        """
        Usage: open-lola direct-p2p-two-peer-local-run --plan <plan.json> --output <report.json> \
        [--execute true --connection-preflight-report <preflight.json>] [options]

        Supervises both peers of a plan. DRY RUN BY DEFAULT: without --execute true nothing is
        launched and a PARTIAL supervisor report is written. With --execute true the responder is
        started first, then the initiator.

        Required:
          --plan <plan.json>                  from direct-p2p-two-peer-plan-run
          --output <path>                     supervisor report to write

        Options (defaults in brackets):
          --execute <true|false> [false]      true launches both peers
          --connection-preflight-report <path>  required with --execute true unless
                                              --require-preflight false; PASS report from
                                              mac-to-mac-connection-preflight-run --plan
          --executable <path>                 open-lola binary for both peers [plan value]
          --readiness-delay-ms <n> [300]      wait for the responder ready file (1-60000)
          --execution-mode <local|ssh> [local]
          --require-preflight <true|false> [true]  false skips the connection preflight for a run
                                              where both peers run on this Mac (--execution-mode
                                              local); such a run is never PASS
          SSH mode (requires --ssh-fallback-explicit true and --ssh-fallback-reason):
            --mac-a-ssh <target>  --mac-b-ssh <target>
            --mac-a-executable <path>  --mac-b-executable <path>
            --mac-a-workdir <dir>  --mac-b-workdir <dir>
            --ssh-executable <path> [/usr/bin/ssh]  --scp-executable <path> [/usr/bin/scp]
            --ssh-fallback-explicit <true|false>  --ssh-fallback-reason <text>
        """
    )
}

func printExternalConnectorSessionRunUsage() {
    print(
        """
        Usage: open-lola external-connector-session-run --connector <lola|ultragrid|jacktrip> \
        --role <tx|rx|tx-rx> --output <report.json> [options]

        Runs a LoLa, UltraGrid (mvtp) or JackTrip connector session.
        DRY RUN BY DEFAULT: --dry-run defaults to true, which only writes a PARTIAL plan report and
        launches nothing. Pass --dry-run false to run a live session. --duration-seconds defaults
        to 1.

        Required:
          --connector <lola|mvtp-ultragrid|ultragrid|jacktrip>
          --role <tx|rx|tx-rx>
          --output <path>

        Also needed: --peer <ip>, the remote peer the connector initiates toward (LoLa tx and tx-rx
        reject a missing peer).

        Common options (defaults in brackets):
          --dry-run <true|false> [true]   --duration-seconds <n> [1]   --local-host <ip> [0.0.0.0]
          --executable <path>  --video-executable <path>
          --media <audio|video|audio-video>  --control-transport <udp|tcp>
          --control-port <n> [lola 7000]  --audio-port <n> [lola 19788]  --peer-audio-port <n>
          --video-port <n> [lola 19798]
          --channels <n> [2]  --sample-rate <hz>  --frames <n>
          --video-width <n> [1920, lola 1280]  --video-height <n> [1080, lola 720]
          --video-fps <n> [30, lola 60]  --video-bpp <n> [24, lola 8]
          --lola-video-payload <name>  --video-compression <n>  --video-bayer <n>
          --audio-capture <device>  --audio-playback <device>  --video-capture <device>  --video-display <device>
          --session-id <n> [1]  --media-packets <n> [1]  --full-duplex <true|false> [true]
          --duration-bounded-runtime <true|false>   (ultragrid and jacktrip only)

        LoLa control side: --lola-control-side <initiator|responder>  [tx and tx-rx initiate, rx responds]
          initiator matches the Rust station's `listen` peer; responder matches its `connect` peer.
        LoLa RX video: --video-display appkit decodes and shows received GREY, Bayer (as grey), RGB or JPEG frames.

        LoLa raw-link options: --raw-link-interface <if>  --source-mac <mac>  --destination-mac <mac>

        UltraGrid options: --ultragrid-topology  --ultragrid-topology-role  --ultragrid-audio-payload-type
          --ultragrid-video-payload-type  --ultragrid-fec  --ultragrid-encryption
          --ultragrid-encryption-passphrase  --ultragrid-control  --ultragrid-control-command (repeatable)

        JackTrip options: --jacktrip-queue-depth  --jacktrip-redundancy  --jacktrip-bit-resolution
          --jacktrip-audio-backend  --jacktrip-topology  --jacktrip-topology-role  --jacktrip-hub-patch
          --jacktrip-hub-tcp-handshake  --jacktrip-remote-client-name  --jacktrip-header
          --jacktrip-transport  --jacktrip-plugin  --jacktrip-payload-encoding
        """
    )
}
