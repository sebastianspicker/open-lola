import Foundation

public enum BlackmagicDesktopVideoSDKStatus: String, Codable, Equatable, Sendable {
    case notLinked
    case linkedNoDevice
    case linkedDeviceAvailable
}

public struct BlackmagicOutputBoundaryReport: Codable, Equatable, Sendable {
    public var backend: VideoOutputBackendKind
    public var desktopVideoSDK: BlackmagicDesktopVideoSDKStatus
    public var compileTimeAvailable: Bool
    public var runtimeAvailable: Bool
    public var hardwareDetected: Bool
    public var enumerationError: String?
    public var notes: String

    public init(
        backend: VideoOutputBackendKind,
        desktopVideoSDK: BlackmagicDesktopVideoSDKStatus,
        compileTimeAvailable: Bool,
        runtimeAvailable: Bool,
        hardwareDetected: Bool,
        enumerationError: String? = nil,
        notes: String
    ) {
        self.backend = backend
        self.desktopVideoSDK = desktopVideoSDK
        self.compileTimeAvailable = compileTimeAvailable
        self.runtimeAvailable = runtimeAvailable
        self.hardwareDetected = hardwareDetected
        self.enumerationError = enumerationError
        self.notes = notes
    }

    public var hasPhysicalOutputEvidence: Bool {
        backend == .blackmagicDeckLink
            && desktopVideoSDK == .linkedDeviceAvailable
            && compileTimeAvailable
            && runtimeAvailable
            && hardwareDetected
    }

    public var outputLimitationSummary: String {
        hasPhysicalOutputEvidence
            ? "DeckLink output hardware evidence present."
            : "PARTIAL: DeckLink output unavailable; local preview/report metrics only."
    }
}

public enum BlackmagicOutputBoundary {
    public static func detect() -> BlackmagicOutputBoundaryReport {
        #if canImport(DeckLinkAPI)
        BlackmagicOutputBoundaryReport(
            backend: .blackmagicDeckLink,
            desktopVideoSDK: .linkedNoDevice,
            compileTimeAvailable: true,
            runtimeAvailable: false,
            hardwareDetected: false,
            enumerationError: "hardware enumeration is not implemented in this public boundary",
            notes: "PARTIAL: Blackmagic Desktop Video SDK module is linked, but hardware enumeration and DeckLink output are not implemented in this public boundary."
        )
        #else
        localPreviewFallback()
        #endif
    }

    public static func localPreviewFallback() -> BlackmagicOutputBoundaryReport {
        BlackmagicOutputBoundaryReport(
            backend: .localPreview,
            desktopVideoSDK: .notLinked,
            compileTimeAvailable: false,
            runtimeAvailable: false,
            hardwareDetected: false,
            enumerationError: nil,
            notes: "PARTIAL: Blackmagic Desktop Video SDK is not linked; DeckLink output is unavailable and the public API uses local preview/report metrics only."
        )
    }
}
