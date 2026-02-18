import Foundation

struct PopularSite: Identifiable {
    let id: String
    let name: String
    let domain: String
    let icon: String

    static let allSites: [PopularSite] = [
        PopularSite(id: "instagram", name: "Instagram", domain: "instagram.com", icon: "camera"),
        PopularSite(id: "facebook", name: "Facebook", domain: "facebook.com", icon: "person.2"),
        PopularSite(id: "twitter", name: "Twitter / X", domain: "twitter.com", icon: "bubble.left"),
        PopularSite(id: "youtube", name: "YouTube", domain: "youtube.com", icon: "play.rectangle"),
        PopularSite(id: "tiktok", name: "TikTok", domain: "tiktok.com", icon: "music.note"),
        PopularSite(id: "reddit", name: "Reddit", domain: "reddit.com", icon: "text.bubble"),
    ]
}
