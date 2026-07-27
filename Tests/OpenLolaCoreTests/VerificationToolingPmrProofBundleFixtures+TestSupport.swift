// Shared verification tooling pmr proof bundle fixtures helpers keep related tests deterministic and focused on their contract.
import Foundation

func createPmrProofBundleFixture(at bundle: URL) throws {
    let files = [
        "pmr-04/realtime-audio-engine.json": validPmr04RealtimeAudioEngineJson,
        "pmr-04/sanitizer-result.txt": """
        ASAN: PASS
        TSAN: PASS

        """,
        "pmr-14/rx-buffer-benchmark.json": validPmr14RxBufferBenchmarkJson,
        "pmr-14/drift-plc-certification.json": validPmr14DriftCertificationJson,
        "pmr-14/direct-p2p-session.json": validPmr14DirectP2PSessionJson,
        "pmr-16/madi-full-duplex.json": validPmr16MadiFullDuplexJson,
        "pmr-16/hardware-notes.md": validPmr16HardwareNotes,
        "pmr-23/lola-media-session.json": validPmr23LoLaMediaSessionJson,
        "pmr-23/audio-loopback-run.json": validPmr23AudioLoopbackRunJson,
        "pmr-23/recording-session.json": "{}\n"
    ]
    for (relativePath, contents) in files {
        let url = bundle.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
    try FileManager.default.createDirectory(
        at: bundle.appendingPathComponent("pmr-14/direct-p2p-evidence"),
        withIntermediateDirectories: true
    )
}

let validPmr04RealtimeAudioEngineJson = """
{
  "runMode": "measured",
  "hardwarePath": "rmeMadi",
  "runArtifactPath": "private/reports/pmr-04-realtime-audio-engine.json",
  "runtime": {
    "callbackOwner": "audioDeviceIOProc",
    "udpSocketsPreparedBeforeStart": true,
    "reportWrittenAfterStop": true,
    "handoff": {
      "inputBlocks": 48,
      "outputBlocks": 48,
      "networkSendBlocks": 48,
      "networkReceiveBlocks": 48,
      "shutdownCompleted": true
    }
  }
}

"""

let weakPmr04RealtimeAudioEngineJson = """
{
  "runMode": "measured",
  "hardwarePath": "rmeMadi",
  "runArtifactPath": "private/reports/pmr-04-realtime-audio-engine.json",
  "runtime": {
    "callbackOwner": "synthetic",
    "udpSocketsPreparedBeforeStart": true,
    "reportWrittenAfterStop": true,
    "handoff": {
      "inputBlocks": 48,
      "outputBlocks": 48,
      "networkSendBlocks": 48,
      "networkReceiveBlocks": 48,
      "shutdownCompleted": true
    }
  }
}

"""

let validPmr14RxBufferBenchmarkJson = """
{
  "verdict": "pass",
  "evidenceKind": "physicalReferenceRig",
  "rows": [
    {
      "profile": "direct",
      "physicalEvidence": true,
      "fastestPassEligible": true
    }
  ]
}

"""

let validPmr14DriftCertificationJson = """
{
  "verdict": "pass",
  "runMode": "measured",
  "runArtifactPath": "private/reports/pmr-14-drift-plc-run.json",
  "lolaBaselineComparison": {
    "availability": "measured",
    "measuredOnSameHardwareAndRoute": true,
    "result": "openLolaFaster"
  }
}

"""

let validPmr14DirectP2PSessionJson = """
{
  "verdict": "pass",
  "measuredEvidence": {
    "kind": "physicalTwoPeerMacs",
    "packetCapturePath": "private/captures/pmr-14-direct-p2p.pcapng",
    "packetCapture": {
      "path": "private/captures/pmr-14-direct-p2p.pcapng",
      "captured": true
    },
    "dscp": {
      "artifact": {
        "path": "private/captures/pmr-14-dscp.json",
        "captured": true
      }
    },
    "clock": {
      "artifact": {
        "path": "private/captures/pmr-14-clock.log",
        "captured": true
      }
    }
  },
  "metrics": {
    "packetsSent": 48,
    "packetsReceived": 48,
    "packetsLost": 0,
    "audioPacketsRouted": 48,
    "recoveryEvents": 0,
    "audioPayloadsSentOnControlChannel": 0,
    "remotePacketsLost": 0,
    "remoteLatePackets": 0,
    "remoteUnderruns": 0,
    "remoteOverruns": 0
  },
  "avRuntime": {
    "runtimeMetrics": {
      "audioPayloadsSent": 48,
      "audioPayloadsQueuedForPlayout": 48,
      "audioPayloadsDroppedBeforeSend": 0,
      "audioPayloadsDroppedBeforePlayout": 0,
      "audioPayloadsDroppedByPlayoutQueue": 0,
      "audioPlayoutUnderruns": 0,
      "audioCallbackDeadlineMisses": 0,
      "audioCallbackOverruns": 0
    }
  }
}

"""

let weakPmr14DirectP2PSessionJson = """
{
  "verdict": "pass",
  "measuredEvidence": {
    "kind": "physicalTwoPeerMacs",
    "packetCapturePath": "private/captures/pmr-14-direct-p2p.pcapng",
    "packetCapture": {
      "path": "private/captures/pmr-14-direct-p2p.pcapng",
      "captured": true
    },
    "dscp": {
      "artifact": {
        "path": "private/captures/pmr-14-dscp.json",
        "captured": true
      }
    },
    "clock": {
      "artifact": {
        "path": "private/captures/pmr-14-clock.log",
        "captured": true
      }
    }
  },
  "metrics": {
    "packetsSent": 48,
    "packetsReceived": 48,
    "packetsLost": 0,
    "audioPacketsRouted": 48,
    "recoveryEvents": 0,
    "audioPayloadsSentOnControlChannel": 0
  },
  "avRuntime": {
    "runtimeMetrics": {
      "audioPayloadsSent": 48,
      "audioPayloadsQueuedForPlayout": 0,
      "audioPayloadsDroppedBeforeSend": 0,
      "audioPayloadsDroppedBeforePlayout": 0,
      "audioPayloadsDroppedByPlayoutQueue": 0,
      "audioPlayoutUnderruns": 0,
      "audioCallbackDeadlineMisses": 0,
      "audioCallbackOverruns": 0
    }
  }
}

"""

let validPmr16HardwareNotes = """
input UID: input-rme-madi-test-uid
output UID: output-rme-madi-test-uid
RME MADI
peer readiness: exchanged
teardown: completed
packet capture: private/captures/pmr-16-test.pcapng

"""

let validPmr16MadiFullDuplexJson = """
{
  "runMode": "measuredPhysical",
  "verdict": "pass",
  "localPeerID": "mac-a",
  "remotePeerID": "mac-b",
  "localEndpoint": {
    "host": "192.0.2.10",
    "port": 49500
  },
  "remoteEndpoint": {
    "host": "192.0.2.11",
    "port": 49500
  },
  "metrics": {
    "transmittedBlocks": 48,
    "transmittedFragments": 96,
    "receivedFragments": 96,
    "completedReceiveBlocks": 48,
    "renderedReceiveBlocks": 48,
    "txSenderFrameEnd": 1536,
    "rxPlayoutFrameEnd": 1536
  }
}

"""

let weakPmr16MadiFullDuplexJson = """
{
  "runMode": "measuredPhysical",
  "verdict": "pass",
  "localPeerID": "mac-a",
  "remotePeerID": "mac-b",
  "localEndpoint": {
    "host": "192.0.2.10",
    "port": 49500
  },
  "remoteEndpoint": {
    "host": "192.0.2.11",
    "port": 49500
  },
  "metrics": {
    "transmittedBlocks": 48,
    "transmittedFragments": 96,
    "receivedFragments": 96,
    "completedReceiveBlocks": 0,
    "renderedReceiveBlocks": 0,
    "txSenderFrameEnd": 1536,
    "rxPlayoutFrameEnd": 0
  }
}

"""

let validPmr23LoLaMediaSessionJson = """
{
  "role": "tx-rx",
  "realLinkTransmitted": true,
  "runtimeError": null,
  "frames": [
    {
      "stream": "audio"
    }
  ],
  "audioFrameCount": 1,
  "totalWireBytes": 1200,
  "envelopeValidatedFrameCount": 1,
  "expectedDatagramCount": 1,
  "sentBytesTotal": 1200,
  "localHost": "192.0.2.10",
  "peer": "192.0.2.11"
}

"""

let weakPmr23LoLaMediaSessionJson = """
{
  "role": "tx-rx",
  "realLinkTransmitted": true,
  "runtimeError": null,
  "frames": [
    {
      "stream": "audio"
    }
  ],
  "audioFrameCount": 1,
  "totalWireBytes": 1200,
  "envelopeValidatedFrameCount": 1,
  "expectedDatagramCount": 1,
  "sentBytesTotal": 1200,
  "localHost": "192.0.2.10",
  "peer": "127.0.0.1"
}

"""

let validPmr23AudioLoopbackRunJson = """
{
  "runnerKind": "audioDeviceIOProc",
  "state": "completed",
  "configuration": {
    "inputUID": "rme-madi-uid",
    "outputUID": "rme-madi-uid",
    "sampleRateHertz": 48000,
    "framesPerBuffer": 32,
    "channelCount": 64,
    "durationSeconds": 1800
  },
  "preflight": {
    "inputDevice": {
      "uid": "rme-madi-uid"
    },
    "outputDevice": {
      "uid": "rme-madi-uid"
    },
    "rmeMadiVisible": true,
    "sampleRateSupported": true,
    "frameSizeInReportedRange": true,
    "canStartIOProc": true,
    "blockers": []
  },
  "callback": {
    "recordedIntervalSamples": 48
  },
  "handoff": {
    "inputBlocks": 48,
    "outputBlocks": 48,
    "networkSendBlocks": 48,
    "networkReceiveBlocks": 48,
    "shutdownCompleted": true
  },
  "cleanup": {
    "failures": []
  }
}

"""

let weakPmr23AudioLoopbackRunJson = """
{
  "runnerKind": "audioDeviceIOProc",
  "state": "completed",
  "configuration": {
    "inputUID": "rme-madi-uid",
    "outputUID": "rme-madi-uid",
    "sampleRateHertz": 48000,
    "framesPerBuffer": 32,
    "channelCount": 64,
    "durationSeconds": 1800
  },
  "preflight": {
    "inputDevice": {
      "uid": "rme-madi-uid"
    },
    "outputDevice": {
      "uid": "rme-madi-uid"
    },
    "rmeMadiVisible": true,
    "sampleRateSupported": true,
    "frameSizeInReportedRange": true,
    "canStartIOProc": true,
    "blockers": []
  },
  "callback": {
    "recordedIntervalSamples": 0
  },
  "handoff": {
    "inputBlocks": 48,
    "outputBlocks": 48,
    "networkSendBlocks": 48,
    "networkReceiveBlocks": 48,
    "shutdownCompleted": true
  },
  "cleanup": {
    "failures": []
  }
}

"""
