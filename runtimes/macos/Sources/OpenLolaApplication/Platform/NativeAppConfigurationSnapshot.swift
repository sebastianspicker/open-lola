import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Defines the immutable native app configuration snapshot handed to runtime paths.
import Foundation

/// Defines the validated fields for native app configuration snapshot.
public struct NativeAppConfigurationSnapshot: Codable, Equatable, Sendable {
    public struct Profile: Equatable, Sendable {
        public let name: String
        public let audioDeviceSelection: String
        public let outputDeviceUID: String?

        public init(name: String, audioDeviceSelection: String, outputDeviceUID: String?) {
            self.name = name
            self.audioDeviceSelection = audioDeviceSelection
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Audio: Equatable, Sendable {
        public let sampleRateHertz: Int
        public let framesPerBuffer: Int
        public let requestedPlayoutTargetFrames: Int

        public init(sampleRateHertz: Int, framesPerBuffer: Int, requestedPlayoutTargetFrames: Int) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.requestedPlayoutTargetFrames = requestedPlayoutTargetFrames
        }
    }

    public struct Features: Equatable, Sendable {
        public let videoEnabled: Bool
        public let showControlEnabled: Bool
        public let lightingEnabled: Bool
        public let createdByUI: Bool
        public let immutableHandoff: Bool

        public init(
            videoEnabled: Bool,
            showControlEnabled: Bool,
            lightingEnabled: Bool,
            createdByUI: Bool,
            immutableHandoff: Bool
        ) {
            self.videoEnabled = videoEnabled
            self.showControlEnabled = showControlEnabled
            self.lightingEnabled = lightingEnabled
            self.createdByUI = createdByUI
            self.immutableHandoff = immutableHandoff
        }
    }

    public var profileName: String
    public var audioDeviceSelection: String
    public var outputDeviceUID: String?
    public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var requestedPlayoutTargetFrames: Int
    public var videoEnabled: Bool
    public var showControlEnabled: Bool
    public var lightingEnabled: Bool
    public var createdByUI: Bool
    public var immutableHandoff: Bool

    public init(profile: Profile, audio: Audio, features: Features) {
        profileName = profile.name
        audioDeviceSelection = profile.audioDeviceSelection
        outputDeviceUID = profile.outputDeviceUID
        sampleRateHertz = audio.sampleRateHertz
        framesPerBuffer = audio.framesPerBuffer
        requestedPlayoutTargetFrames = audio.requestedPlayoutTargetFrames
        videoEnabled = features.videoEnabled
        showControlEnabled = features.showControlEnabled
        lightingEnabled = features.lightingEnabled
        createdByUI = features.createdByUI
        immutableHandoff = features.immutableHandoff
    }
}
