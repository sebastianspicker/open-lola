// Packs PNG icon representations into a modern ICNS container for macOS assets.
import Foundation

guard CommandLine.arguments.count >= 3 else {
  FileHandle.standardError.write(
    Data("usage: build_icns.swift output.icns type=icon.png [...]\n".utf8))
  exit(2)
}

func bigEndianData(_ value: UInt32) -> Data {
  var encoded = value.bigEndian
  return withUnsafeBytes(of: &encoded) { Data($0) }
}

var chunks = Data()
for argument in CommandLine.arguments.dropFirst(2) {
  let pieces = argument.split(separator: "=", maxSplits: 1).map(String.init)
  guard pieces.count == 2,
    pieces[0].utf8.count == 4,
    let png = FileManager.default.contents(atPath: pieces[1])
  else {
    FileHandle.standardError.write(Data("invalid ICNS representation: \(argument)\n".utf8))
    exit(1)
  }
  chunks.append(Data(pieces[0].utf8))
  chunks.append(bigEndianData(UInt32(png.count + 8)))
  chunks.append(png)
}

var container = Data("icns".utf8)
container.append(bigEndianData(UInt32(chunks.count + 8)))
container.append(chunks)
try container.write(
  to: URL(fileURLWithPath: CommandLine.arguments[1]),
  options: .atomic
)
