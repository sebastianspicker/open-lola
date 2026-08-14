// Shared synthetic AppKit rendering support for app hotspot coverage tests.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
func render<Content: View>(
    _ rootView: Content,
    size: CGSize,
    settleInterval: TimeInterval = 0.1
) throws -> AppHotspotRender {
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = hostingView.appearance
    window.contentView = hostingView
    defer {
        window.contentView = nil
        window.orderOut(nil)
    }

    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: settleInterval))
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw AppHotspotRenderError.bitmapUnavailable
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    guard let pixels = bitmap.bitmapData else {
        throw AppHotspotRenderError.bitmapUnavailable
    }

    var sampledColors = Set<UInt32>()
    var visibleSamples = 0
    for offset in stride(from: 0, to: bitmap.bytesPerRow * bitmap.pixelsHigh, by: 64) {
        let red = pixels[offset]
        let green = pixels[offset + 1]
        let blue = pixels[offset + 2]
        let alpha = pixels[offset + 3]
        if alpha > 0, Int(red) + Int(green) + Int(blue) > 24 {
            visibleSamples += 1
        }
        sampledColors.insert(UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
    }
    return AppHotspotRender(
        frame: hostingView.bounds,
        hostedSubviewCount: hostingView.subviews.count,
        sampledColorCount: sampledColors.count,
        visibleSampleCount: visibleSamples,
        contentViewAttached: window.contentView === hostingView,
        bitmapSize: CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    )
}

func assertHostedStructure(
    _ render: AppHotspotRender,
    named name: String,
    boundsMessageStyle: AppHotspotRenderBoundsMessageStyle = .rendered
) {
    switch boundsMessageStyle {
    case .rendered:
        #expect(render.frame.width > 0, "\(name) must have a nonzero rendered width.")
        #expect(render.frame.height > 0, "\(name) must have a nonzero rendered height.")
    case .host:
        #expect(render.frame.width > 0, "\(name) must receive a nonzero host width.")
        #expect(render.frame.height > 0, "\(name) must receive a nonzero host height.")
    }
    #expect(render.contentViewAttached, "\(name) must remain attached to its AppKit host.")
    #expect(render.sampledColorCount > 0, "\(name) must produce a render cache.")
}

@MainActor
func assertRendered<Content: View>(
    _ rootView: Content,
    size: CGSize,
    named name: String,
    requiresAttachedHost: Bool = false,
    boundsMessageStyle: AppHotspotRenderBoundsMessageStyle = .host
) {
    do {
        let rendered = try render(rootView, size: size, settleInterval: 0.05)
        assertHostedStructure(rendered, named: name, boundsMessageStyle: boundsMessageStyle)
        if requiresAttachedHost {
            #expect(rendered.contentViewAttached, "\(name) must remain attached to its AppKit host.")
        }
        #expect(rendered.bitmapSize.width > 0, "\(name) must produce a local render cache.")
        #expect(rendered.bitmapSize.height > 0, "\(name) must produce a local render cache.")
    } catch AppHotspotRenderError.bitmapUnavailable {
        Issue.record("\(name) could not allocate a local render bitmap.")
    } catch {
        Issue.record("\(name) could not complete a local render: \(error).")
    }
}

enum AppHotspotRenderBoundsMessageStyle {
    case rendered
    case host
}

struct AppHotspotRender {
    let frame: CGRect
    let hostedSubviewCount: Int
    let sampledColorCount: Int
    let visibleSampleCount: Int
    let contentViewAttached: Bool
    let bitmapSize: CGSize
}

enum AppHotspotRenderError: Error {
    case bitmapUnavailable
}

@MainActor
final class AppSettingsTabRenderState {
    var sessionMode: NativeAppShellSessionMode = .directMacPeer
    var controlMode: NativeAppShellControlMode = .advanced
    var executablePath = "/Applications/Open LoLa/bin/open-lola"
    var planPath = "/tmp/open-lola/synthetic-plan.json"
    var supervisorReportPath = "/tmp/open-lola/synthetic-report.json"
    var requirePreflight = true
    var executionMode: DirectPeerTwoPeerRunExecutionMode = .ssh
    var macASSH = "operator@mac-a.example.test"
    var macBSSH = "operator@mac-b.example.test"
    var macAWorkingDirectory = "/tmp/open-lola/mac-a"
    var macBWorkingDirectory = "/tmp/open-lola/mac-b"
    var sshExecutable = "/usr/bin/ssh"
    var scpExecutable = "/usr/bin/scp"
    var localHost = "192.0.2.10"
    var peerHost = "198.51.100.10"
    var windowsHost = "192.0.2.20"
    var remoteHost = "198.51.100.20"
    var connectorRole: ExternalConnectorSessionRole = .txRx
    var peerRole: DirectPeerSessionManualRole = .initiator
    var controlPort: UInt16 = 7_000
    var remoteControlPort: UInt16 = 7_001
    var audioPort: UInt16 = 7_002
    var peerAudioPort: UInt16 = 7_003
    var videoPort: UInt16 = 7_004
    var metricsPort: UInt16 = 7_005
    var connectorMediaMode: ExternalConnectorMediaMode = .audioVideo
    var payloadMode: LoLaVideoPayloadKind = .generated
    var duration = 30
    var outputPath = "/tmp/open-lola/synthetic-output.json"
    var videoWidth = 1_920
    var videoHeight = 1_080
    var videoFrameRate = 60
    var videoBitsPerPixel = 8
    var sampleRate = 48_000
    var frames = 128
    var channelCount = 2
    var compression = 0
    var bayer = 0
    var localPeer = "mac-a"
    var remotePeer = "mac-b"
    var sampleFormat = "float32"
    var audioTransport: DirectPeerSessionAudioTransport = .openLolaRaw
    var avProfile: DirectPeerSessionAVProfile = .balanced
    var rxBufferProfile: RxBufferProfile = .adaptive
    var videoPixelFormat = "bgra8"
    var videoCompression: DirectPeerSessionVideoCompression = .jpegXS
    var videoStreamID = 101
    var timeoutSeconds = 2
    var previewMode: DirectPeerSessionPreviewMode = .on
    var audioPreviewEnabled = true
    var videoPreviewEnabled = true
    var showSafeFrame = true
    var monitorGain = 0.65
    var videoScale = 1.0

    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettingsTabRenderState, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
