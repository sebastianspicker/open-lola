// Presents validated raw BGRA frames in an AppKit preview window with delivery metrics.
import AppKit
import CoreGraphics
import Foundation

/// Reports `unsupportedPixelFormat`, `payloadSizeMismatch`, and `imageCreationFailed` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum RawBGRAPreviewError: Error, Equatable, Sendable {
    case unsupportedPixelFormat(String)
    case payloadSizeMismatch(expected: Int, actual: Int)
    case imageCreationFailed
    case closed
}

/// Requires a UI-owned destination that can present validated BGRA frames.
public protocol RawBGRAPreviewSink: AnyObject, Sendable {
    var droppedFrameCount: Int { get }
    /// Frames that have reached the display surface, rather than merely been queued.
    var renderedFrameCount: Int { get }

    func submit(frame: RawCapturedVideoFrame) throws
    func close()
}

public extension RawBGRAPreviewSink {
    var droppedFrameCount: Int { 0 }
    var renderedFrameCount: Int { 0 }

    func close() {}
}

/// Requires a UI-owned destination that can present validated BGRA frames.
public final class RawBGRATestablePreviewSink: RawBGRAPreviewSink, @unchecked Sendable {
    public private(set) var submittedFrames: [RawCapturedVideoFrame] = []

    public init() {}

    public func submit(frame: RawCapturedVideoFrame) throws {
        try RawBGRAImageFactory.validate(frame: frame)
        submittedFrames.append(frame)
    }

    public var renderedFrameCount: Int { submittedFrames.count }
}

/// Builds preview-ready images only from validated BGRA frame bytes.
public enum RawBGRAImageFactory {
    public static func makeCGImage(frame: RawCapturedVideoFrame) throws -> CGImage {
        try validate(frame: frame)
        guard let provider = CGDataProvider(data: frame.payload as CFData),
              let image = CGImage(
                width: frame.metadata.width,
                height: frame.metadata.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: frame.metadata.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
                    .union(.byteOrder32Little),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw RawBGRAPreviewError.imageCreationFailed
        }
        return image
    }

    public static func validate(frame: RawCapturedVideoFrame) throws {
        guard frame.metadata.pixelFormat == "bgra8" || frame.metadata.pixelFormat == "BGRA" else {
            throw RawBGRAPreviewError.unsupportedPixelFormat(frame.metadata.pixelFormat)
        }
        let expected = frame.metadata.width * frame.metadata.height * 4
        guard frame.payload.count == expected else {
            throw RawBGRAPreviewError.payloadSizeMismatch(expected: expected, actual: frame.payload.count)
        }
    }
}

/// Owns AppKit preview-window state and counts rendered versus dropped raw BGRA frames.
public final class RawBGRAAppKitPreviewWindow: RawBGRAPreviewSink, @unchecked Sendable {
    private let state = RawBGRAAppKitPreviewWindowState()
    private let taskLock = NSLock()
    private let renderQueue = DispatchQueue(label: "open-lola.preview.bgra-render", qos: .userInitiated)
    private var pendingFrame: RawCapturedVideoFrame?
    private var workerScheduled = false
    private var closed = false
    private var droppedFrameCountStorage = 0
    private var renderedFrameCountStorage = 0
    private let beforeMainActorDelivery: @Sendable () -> Void

    public init() {
        beforeMainActorDelivery = {}
    }

    init(beforeMainActorDelivery: @escaping @Sendable () -> Void) {
        self.beforeMainActorDelivery = beforeMainActorDelivery
    }

    @MainActor
    func performCloseForTesting() {
        state.performClose()
    }

    @MainActor
    var hasPreviewWindowForTesting: Bool {
        state.hasWindow
    }

    @MainActor
    var previewWindowIsReleasedWhenClosedForTesting: Bool? {
        state.windowIsReleasedWhenClosed
    }

    public var droppedFrameCount: Int {
        taskLock.lock()
        defer { taskLock.unlock() }
        return droppedFrameCountStorage
    }

    public var renderedFrameCount: Int {
        taskLock.lock()
        defer { taskLock.unlock() }
        return renderedFrameCountStorage
    }

    public func submit(frame: RawCapturedVideoFrame) throws {
        try RawBGRAImageFactory.validate(frame: frame)
        let shouldSchedule: Bool
        taskLock.lock()
        guard !closed else {
            droppedFrameCountStorage += 1
            taskLock.unlock()
            throw RawBGRAPreviewError.closed
        }
        if pendingFrame != nil {
            droppedFrameCountStorage += 1
        }
        pendingFrame = frame
        shouldSchedule = !workerScheduled
        workerScheduled = true
        taskLock.unlock()
        if shouldSchedule {
            renderQueue.async { [weak self] in self?.renderNewestFrame() }
        }
    }

    public func close() {
        taskLock.lock()
        let shouldClose = !closed
        closed = true
        if pendingFrame != nil {
            droppedFrameCountStorage += 1
        }
        pendingFrame = nil
        taskLock.unlock()
        guard shouldClose else { return }
        performOnMainActorSynchronously { self.state.close() }
    }

    private func renderNewestFrame() {
        let frame: RawCapturedVideoFrame?
        taskLock.lock()
        frame = pendingFrame
        pendingFrame = nil
        guard let frame else {
            workerScheduled = false
            taskLock.unlock()
            return
        }
        taskLock.unlock()

        do {
            let image = try RawBGRAImageFactory.makeCGImage(frame: frame)
            beforeMainActorDelivery()
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isClosed else {
                    self.recordDroppedFrame()
                    return
                }
                self.state.submit(image: image, width: frame.metadata.width, height: frame.metadata.height)
                self.recordRenderedFrame()
            }
        } catch {
            taskLock.lock()
            droppedFrameCountStorage += 1
            taskLock.unlock()
        }

        taskLock.lock()
        let shouldContinue = pendingFrame != nil
        if !shouldContinue {
            workerScheduled = false
        }
        taskLock.unlock()
        if shouldContinue {
            renderQueue.async { [weak self] in self?.renderNewestFrame() }
        }
    }

    private func recordRenderedFrame() {
        taskLock.lock()
        defer { taskLock.unlock() }
        renderedFrameCountStorage += 1
    }

    private func recordDroppedFrame() {
        taskLock.lock()
        defer { taskLock.unlock() }
        droppedFrameCountStorage += 1
    }

    private var isClosed: Bool {
        taskLock.lock()
        defer { taskLock.unlock() }
        return closed
    }
}

private func performOnMainActorSynchronously(_ body: @MainActor @escaping () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated(body)
    } else {
        DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
    }
}

@MainActor
private final class RawBGRAAppKitPreviewWindowState: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var imageView: NSImageView?

    nonisolated override init() {
        super.init()
    }

    var hasWindow: Bool {
        window != nil
    }

    var windowIsReleasedWhenClosed: Bool? {
        window?.isReleasedWhenClosed
    }

    func submit(image: CGImage, width: Int, height: Int) {
        ensureWindow(width: width, height: height)
        imageView?.image = makeNSImage(from: image, size: NSSize(width: width, height: height))
    }

    func close() {
        window?.close()
        window = nil
        imageView = nil
    }

    func performClose() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }
        window = nil
        imageView = nil
    }

    private func ensureWindow(width: Int, height: Int) {
        guard window == nil else {
            return
        }
        let frame = NSRect(x: 80, y: 80, width: max(320, width), height: max(180, height))
        let imageView = NSImageView(frame: frame)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Open LoLa RX Preview"
        window.delegate = self
        window.contentView = imageView
        window.makeKeyAndOrderFront(nil)
        self.imageView = imageView
        self.window = window
    }

    private func makeNSImage(from image: CGImage, size: NSSize) -> NSImage {
        NSImage(cgImage: image, size: size)
    }
}
