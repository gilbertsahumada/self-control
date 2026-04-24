import Foundation

struct PopularSite: Identifiable {
    let id: String
    let name: String
    let domain: String
    /// Filename (without extension) of the brand SVG under `BrandIcons/`.
    let brandIcon: String
    /// SF Symbol fallback when the brand SVG cannot be loaded (debug builds
    /// that do not copy the resource bundle, or missing asset).
    let fallbackSymbol: String

    static let allSites: [PopularSite] = [
        PopularSite(id: "instagram", name: "Instagram", domain: "instagram.com", brandIcon: "instagram", fallbackSymbol: "camera"),
        PopularSite(id: "facebook", name: "Facebook", domain: "facebook.com", brandIcon: "facebook", fallbackSymbol: "person.2"),
        PopularSite(id: "twitter", name: "X", domain: "twitter.com", brandIcon: "x", fallbackSymbol: "xmark"),
        PopularSite(id: "youtube", name: "YouTube", domain: "youtube.com", brandIcon: "youtube", fallbackSymbol: "play.rectangle"),
        PopularSite(id: "tiktok", name: "TikTok", domain: "tiktok.com", brandIcon: "tiktok", fallbackSymbol: "music.note"),
        PopularSite(id: "reddit", name: "Reddit", domain: "reddit.com", brandIcon: "reddit", fallbackSymbol: "text.bubble"),
        PopularSite(id: "linkedin", name: "LinkedIn", domain: "linkedin.com", brandIcon: "linkedin", fallbackSymbol: "briefcase"),
    ]
}
