import SwiftUI
import AppKit

/// Loads a brand SVG from the app bundle and renders it tinted with the
/// current phosphor color. Falls back to an SF Symbol when the SVG cannot
/// be loaded (debug builds that do not ship the BrandIcons resource dir).
struct BrandIcon: View {
    let brand: String
    let fallback: String
    var size: CGFloat = 22

    var body: some View {
        if let nsImage = Self.load(brand: brand) {
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallback)
                .font(.system(size: size * 0.9))
        }
    }

    private static func load(brand: String) -> NSImage? {
        let candidates: [URL] = [
            Bundle.main.url(forResource: brand, withExtension: "svg", subdirectory: "BrandIcons"),
            Bundle.main.url(forResource: brand, withExtension: "svg"),
            repoAssetURL(for: brand),
        ].compactMap { $0 }

        for url in candidates {
            if let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                return img
            }
        }
        return nil
    }

    /// Repo-relative fallback for `swift run` / `make run` — the brand
    /// icons live under `assets/brand-icons/` in the source tree.
    private static func repoAssetURL(for brand: String) -> URL? {
        let sourceFile = URL(fileURLWithPath: #filePath)
        // Views/BrandIcon.swift -> BlockSitesApp -> Sources -> repo root
        let repoRoot = sourceFile
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // BlockSitesApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
        let url = repoRoot
            .appendingPathComponent("assets/brand-icons/\(brand).svg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
