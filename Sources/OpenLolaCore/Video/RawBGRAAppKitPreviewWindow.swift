import AppKit
import CoreGraphics
import Foundation

public enum RawBGRAPreviewError: Error, Equatable, Sendable {
    case unsupportedPixelFormat(String)
    case payloadSizeMismatch(expected: Int, actual: Int)
    case imageCreationFailed
}

public protocol RawBGRAPreviewSink: AnyObject, Sendable {
    var droppedFrameCount: Int { get }

    func submit(frame: RawCapturedVideoFrame) throws
    func close()
}

public extension RawBGRAPreviewSink {
    var droppedFrameCount: Int { 0 }

    func close() {}
}

public final class RawBGRATestablePreviewSink: RawBGRAPreviewSink, @unchecked Sendable {
    public private(set) var submittedFrames: [RawCapturedVideoFrame] = []

    public init() {}

    public func submit(frame: RawCapturedVideoFrame) throws {
        _ = try RawBGRAImageFactory.makeCGImage(frame: frame)
        submittedFrames.append(frame)
    }
}

public enum RawBGRAImageFactory {
    public static func makeCGImage(frame: RawCapturedVideoFrame) throws -> CGImage {
        guard frame.metadata.pixelFormat == "bgra8" || frame.metadata.pixelFormat == "BGRA" else {
            throw RawBGRAPreviewError.unsupportedPixelFormat(frame.metadata.pixelFormat)
        }
        let expected = frame.metadata.width * frame.metadata.height * 4
        guard frame.payload.count == expected else {
            throw RawBGRAPreviewError.payloadSizeMismatch(expected: expected, actual: frame.payload.count)
        }
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
}

public final class RawBGRAAppKitPreviewWindow: RawBGRAPreviewSink, @unchecked Sendable {
    private let state = RawBGRAAppKitPreviewWindowState()
    private let taskLock = NSLock()
    private var submitPending = false
    private var droppedFrameCountStorage = 0

    public init() {}

    public var droppedFrameCount: Int {
        taskLock.lock()
        defer { taskLock.unlock() }
        return droppedFrameCountStorage
    }

    public func submit(frame: RawCapturedVideoFrame) throws {
        guard beginSubmit() else {
            return
        }
        let image: CGImage
        do {
            image = try RawBGRAImageFactory.makeCGImage(frame: frame)
        } catch {
            endSubmit()
            throw error
        }
        Task.detached(priority: .userInitiated) {
            await self.state.submit(image: image, width: frame.metadata.width, height: frame.metadata.height)
            self.endSubmit()
        }
    }

    public func close() {
        Task { @MainActor in
            self.state.close()
        }
    }

    private func beginSubmit() -> Bool {
        taskLock.lock()
        defer { taskLock.unlock() }
        guard !submitPending else {
            droppedFrameCountStorage += 1
            return false
        }
        submitPending = true
        return true
    }

    private func endSubmit() {
        taskLock.lock()
        defer { taskLock.unlock() }
        submitPending = false
    }
}

@MainActor
private final class RawBGRAAppKitPreviewWindowState {
    private var window: NSWindow?
    private var imageView: NSImageView?

    func submit(image: CGImage, width: Int, height: Int) {
        ensureWindow(width: width, height: height)
        imageView?.image = makeNSImage(from: image, size: NSSize(width: width, height: height))
    }

    func close() {
        window?.close()
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
        window.title = "Open LoLa RX Preview"
        window.contentView = imageView
        window.makeKeyAndOrderFront(nil)
        self.imageView = imageView
        self.window = window
    }

    private func makeNSImage(from image: CGImage, size: NSSize) -> NSImage {
        NSImage(cgImage: image, size: size)
    }
}
