// Rasterizes one repository SVG with macOS AppKit for deterministic project assets.
import AppKit
import Foundation

guard CommandLine.arguments.count == 5,
  let width = Int(CommandLine.arguments[3]),
  let height = Int(CommandLine.arguments[4]),
  width > 0,
  height > 0
else {
  FileHandle.standardError.write(
    Data("usage: render_svg.swift input.svg output.png width height\n".utf8))
  exit(2)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: inputPath),
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ),
  let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
  FileHandle.standardError.write(Data("could not rasterize SVG: \(inputPath)\n".utf8))
  exit(1)
}

bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
graphicsContext.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
image.draw(
  in: NSRect(x: 0, y: 0, width: width, height: height),
  from: .zero,
  operation: .sourceOver,
  fraction: 1,
  respectFlipped: false,
  hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
  FileHandle.standardError.write(Data("could not encode PNG: \(outputPath)\n".utf8))
  exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
