import Foundation

// This is the daemon enforcer - runs every minute to ensure blocks stay active

let configPath = "/Library/Application Support/BlockSites/config.json"
let hostsPath = "/etc/hosts"
let marker = "# BLOCKSITES"

struct BlockConfiguration: Codable {
    let sites: [String]
    let startTime: Date
    let endTime: Date
}

func loadConfiguration() -> BlockConfiguration? {
    guard FileManager.default.fileExists(atPath: configPath),
          let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let config = try? JSONDecoder().decode(BlockConfiguration.self, from: data) else {
        return nil
    }
    return config
}

func applyBlocks(_ sites: [String]) {
    guard var hostsContent = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
        return
    }

    // Remove old blocks
    let lines = hostsContent.components(separatedBy: .newlines)
    hostsContent = lines.filter { !$0.contains(marker) }.joined(separator: "\n")

    // Add new blocks
    var blockEntries = "\n\(marker) START\n"
    for site in sites {
        // Block main domain
        blockEntries += "127.0.0.1 \(site) \(marker)\n"
        blockEntries += "127.0.0.1 www.\(site) \(marker)\n"

        // Block common subdomains for problematic sites
        let commonSubdomains = ["mobile", "m", "api", "static", "cdn", "pbs", "abs", "video"]
        for subdomain in commonSubdomains {
            blockEntries += "127.0.0.1 \(subdomain).\(site) \(marker)\n"
        }

        // Special handling for X/Twitter
        if site == "x.com" || site == "twitter.com" {
            let xDomains = [
                "x.com", "www.x.com", "mobile.x.com", "api.x.com",
                "twitter.com", "www.twitter.com", "mobile.twitter.com", "api.twitter.com",
                "t.co", "www.t.co",
                "twimg.com", "pbs.twimg.com", "abs.twimg.com", "video.twimg.com"
            ]
            for domain in xDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Special handling for Instagram
        if site == "instagram.com" {
            let igDomains = [
                "instagram.com", "www.instagram.com", "i.instagram.com",
                "graph.instagram.com", "edge-chat.instagram.com",
                "scontent.cdninstagram.com", "cdninstagram.com",
                "www.cdninstagram.com", "static.cdninstagram.com",
                "scontent-*.cdninstagram.com",
                "l.instagram.com", "b.i.instagram.com",
                "about.instagram.com", "help.instagram.com",
                "web.instagram.com", "d.instagram.com",
                "z-p3-graph.instagram.com", "z-p4-graph.instagram.com"
            ]
            for domain in igDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Special handling for Facebook
        if site == "facebook.com" {
            let fbDomains = [
                "facebook.com", "www.facebook.com", "m.facebook.com",
                "web.facebook.com", "mobile.facebook.com",
                "graph.facebook.com", "edge-chat.facebook.com",
                "static.facebook.com", "staticxx.facebook.com",
                "upload.facebook.com", "l.facebook.com",
                "fbcdn.net", "static.xx.fbcdn.net", "scontent.xx.fbcdn.net",
                "video.xx.fbcdn.net", "external.xx.fbcdn.net",
                "fbcdn.com", "connect.facebook.net",
                "star.facebook.com", "z-m-graph.facebook.com"
            ]
            for domain in fbDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Special handling for YouTube
        if site == "youtube.com" {
            let ytDomains = [
                "youtube.com", "www.youtube.com", "m.youtube.com",
                "youtu.be", "www.youtu.be",
                "youtube-nocookie.com", "www.youtube-nocookie.com",
                "googlevideo.com", "www.googlevideo.com",
                "ytimg.com", "i.ytimg.com", "s.ytimg.com",
                "music.youtube.com", "tv.youtube.com",
                "accounts.youtube.com", "studio.youtube.com"
            ]
            for domain in ytDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Special handling for TikTok
        if site == "tiktok.com" {
            let ttDomains = [
                "tiktok.com", "www.tiktok.com", "m.tiktok.com",
                "vm.tiktok.com", "t.tiktok.com",
                "sf-tb-sg.ibytedtos.com", "v16m-default.akamaized.net",
                "mon.musical.ly", "log.tiktokv.com",
                "ib.tiktokv.com", "api.tiktokv.com"
            ]
            for domain in ttDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Special handling for Reddit
        if site == "reddit.com" {
            let rdDomains = [
                "reddit.com", "www.reddit.com", "old.reddit.com",
                "new.reddit.com", "i.reddit.com", "m.reddit.com",
                "sh.reddit.com", "oauth.reddit.com",
                "redd.it", "i.redd.it", "v.redd.it", "preview.redd.it",
                "external-preview.redd.it", "www.redditmedia.com",
                "redditstatic.com", "www.redditstatic.com"
            ]
            for domain in rdDomains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }
    }
    blockEntries += "\(marker) END\n"

    hostsContent += blockEntries

    try? hostsContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

    // Flush DNS cache
    runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
    runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])

    // Re-apply firewall rules
    FirewallManager.shared.reapplyFirewallRules()
}

func removeBlocks() {
    guard let hostsContent = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
        return
    }

    let lines = hostsContent.components(separatedBy: .newlines)
    let cleanedContent = lines.filter { !$0.contains(marker) }.joined(separator: "\n")

    try? cleanedContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

    // Flush DNS cache
    runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
    runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])

    // Remove firewall rules
    FirewallManager.shared.removeFirewallRules()

    // Remove config and residual files
    try? FileManager.default.removeItem(atPath: configPath)
    try? FileManager.default.removeItem(atPath: "/Library/Application Support/BlockSites/ip_cache.json")
    try? FileManager.default.removeItem(atPath: "/Library/Application Support/BlockSites/hosts.backup")

    let plistPath = "/Library/LaunchDaemons/com.blocksites.enforcer.plist"

    // Unload self
    runCommand("/bin/launchctl", args: ["unload", "-w", plistPath])

    // Remove plist
    try? FileManager.default.removeItem(atPath: plistPath)
}

// Main enforcement logic
guard let config = loadConfiguration() else {
    exit(0)
}

let now = Date()

if now < config.endTime {
    // Still blocking - re-apply blocks
    applyBlocks(config.sites)
} else {
    // Time expired - remove blocks
    removeBlocks()
}
