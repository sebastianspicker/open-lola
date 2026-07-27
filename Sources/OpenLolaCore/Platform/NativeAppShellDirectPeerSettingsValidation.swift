// Validates NativeAppShellDirectPeerSettingsValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

public extension NativeAppShellDirectPeerCommandFields {
    func validateAppSettings() throws {
        try requireCommandText(executablePath, "executablePath")
        try requireCommandText(localPeer, "localPeer")
        try requireCommandText(remotePeer, "remotePeer")
        try requireCommandText(localHost, "localHost")
        try requireCommandText(remoteHost, "remoteHost")
        try requireCommandText(outputPath, "outputPath")
        try requireCommandText(sampleFormat, "sampleFormat")
        try requireCommandText(videoPixelFormat, "videoPixelFormat")
        try requireAllowedCommandText(
            audioTransport.rawValue,
            field: "audioTransport",
            allowed: ["openlola-raw", "openlola-opus-celt-ld", "aes67-st2110-l24"]
        )
        try requireAllowedCommandText(videoCompression.rawValue, field: "videoCompression", allowed: ["raw", "jpeg-xs"])
        try requirePositiveCommandValue(durationSeconds, "durationSeconds")
        try requirePositiveCommandValue(channelCount, "channelCount")
        try requirePositiveCommandValue(sampleRateHertz, "sampleRateHertz")
        try requirePositiveCommandValue(framesPerPacket, "framesPerPacket")
        try requireUInt32CommandValue(framesPerPacket, "framesPerPacket")
        try requirePositiveCommandValue(videoWidth, "videoWidth")
        try requirePositiveCommandValue(videoHeight, "videoHeight")
        try requirePositiveCommandValue(videoFrameRate, "videoFrameRate")
        try requirePositiveCommandValue(videoStreamID, "videoStreamID")
        try requirePositiveCommandValue(timeoutSeconds, "timeoutSeconds")
        try validateSharedMediaShape()
        _ = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: avProfile,
            rxBufferProfile: rxBufferProfile,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz
        )
        try validateSharedNetworkShape()
    }

    private func validateSharedMediaShape() throws {
        do {
            try DirectPeerSessionAVMediaShape(
                audioTransport: audioTransport,
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket,
                sampleFormatText: sampleFormat,
                channelCount: channelCount,
                videoPixelFormatText: videoPixelFormat
            ).validate()
        } catch DirectPeerSessionAVMediaShapeError.invalidSampleFormat {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sampleFormat")
        } catch DirectPeerSessionAVMediaShapeError.invalidVideoPixelFormat {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("videoPixelFormat")
        } catch DirectPeerSessionAVMediaShapeError.invalidAudioTransportShape {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("audioTransport")
        } catch {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("audioTransport")
        }
    }

    private func validateSharedNetworkShape() throws {
        do {
            try DirectPeerManualNetworkShape(
                localHost: localHost,
                remoteHost: remoteHost,
                ports: DirectPeerPortSet(
                    controlPort: controlPort,
                    remoteControlPort: remoteControlPort,
                    audioPort: audioPort,
                    videoPort: videoPort,
                    metricsPort: metricsPort
                )
            ).validate()
        } catch DirectPeerSessionSocketRunnerError.invalidManualHost(let field, _) {
            throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
        } catch DirectPeerSessionSocketRunnerError.invalidManualPort(let field, _) {
            throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
        } catch DirectPeerSessionSocketRunnerError.duplicateManualPort(let field, _) {
            throw NativeAppShellSurfaceValidationError.duplicateCommandPort(field)
        } catch {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("localHost")
        }
    }
}

private func requireCommandText(_ value: String, _ field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requireAllowedCommandText(_ value: String, field: String, allowed: Set<String>) throws {
    guard allowed.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requirePositiveCommandValue(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}

private func requireUInt32CommandValue(_ value: Int, _ field: String) throws {
    guard UInt32(exactly: value) != nil else {
        throw NativeAppShellSurfaceValidationError.invalidCommandField(field)
    }
}
