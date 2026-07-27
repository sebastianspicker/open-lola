// Verifies the checked-in Open LoLa identity assets, naming, and generated formats.
import Foundation
import ImageIO
import Testing

@Test
func openLolaBrandAssetsAreReproducibleAndUseTheApprovedPalette() throws {
  let generation = try ReleaseArtifactHygieneSupport.runBashScript(
    "scripts/macos/generate_brand_assets.sh",
    "--check"
  )
  #expect(generation.status == 0)
  #expect(generation.output.contains("Brand assets are current and reproducible."))

  let lightMark = try ReleaseArtifactHygieneSupport.readText(
    ".github/assets/open-lola-mark-light.svg"
  )
  let darkMark = try ReleaseArtifactHygieneSupport.readText(
    ".github/assets/open-lola-mark-dark.svg"
  )
  for mark in [lightMark, darkMark] {
    #expect(mark.contains("Open LoLa signal-path mark"))
    #expect(mark.contains("Two open endpoints"))
    #expect(!mark.contains("#006E24"))
    #expect(!mark.contains("#2EC752"))
    #expect(!mark.contains("#8C3800"))
    #expect(!mark.contains("#F27900"))
    #expect(!mark.contains("#C70000"))
    #expect(!mark.contains("#FF4540"))
  }

  let previewURL = ReleaseArtifactHygieneSupport.repositoryRoot
    .appendingPathComponent(".github/assets/open-lola-social-preview.png")
  guard let previewSource = CGImageSourceCreateWithURL(previewURL as CFURL, nil),
        let previewProperties = CGImageSourceCopyPropertiesAtIndex(
          previewSource,
          0,
          nil
        ) as? [CFString: Any] else {
    Issue.record("Could not read the generated social preview PNG.")
    return
  }
  #expect(previewProperties[kCGImagePropertyPixelWidth] as? Int == 1_280)
  #expect(previewProperties[kCGImagePropertyPixelHeight] as? Int == 640)

  let icon = try Data(contentsOf: ReleaseArtifactHygieneSupport.repositoryRoot
    .appendingPathComponent(".github/assets/OpenLoLa.icns"))
  #expect(icon.starts(with: Data("icns".utf8)))
  for representation in ["icp4", "icp5", "icp6", "ic07", "ic08", "ic09", "ic10"] {
    #expect(icon.range(of: Data(representation.utf8)) != nil)
  }
}

@Test
func openLolaPublicNamingAndPositioningStayAligned() throws {
  let readme = try ReleaseArtifactHygieneSupport.readText("README.md")
  let product = try ReleaseArtifactHygieneSupport.readText("docs/product.md")
  let designSystem = try ReleaseArtifactHygieneSupport.readText("docs/design-system.md")
  let manifest = try ReleaseArtifactHygieneSupport.readText("pyproject.toml")

  for publicSurface in [readme, product, designSystem] {
    let normalizedSurface = publicSurface
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
    #expect(normalizedSurface.contains("Configure, run, and verify low-latency media sessions."))
    #expect(publicSurface.contains("independent"))
    #expect(publicSurface.contains("https://lola.conts.it/"))
    #expect(!publicSurface.contains("open-lola2"))
  }
  #expect(manifest.contains("name = \"open-lola-linux-connector\""))
  #expect(!manifest.contains("open-lola2-linux-connector"))
}
