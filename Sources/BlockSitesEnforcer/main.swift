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
    }
    blockEntries += "\(marker) END\n"

    hostsContent += blockEntries

    try? hostsContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

    // Flush DNS cache
    let flushDNS = Process()
    flushDNS.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
    flushDNS.arguments = ["-flushcache"]
    try? flushDNS.run()

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
    let flushDNS = Process()
    flushDNS.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
    flushDNS.arguments = ["-flushcache"]
    try? flushDNS.run()

    // Remove config
    try? FileManager.default.removeItem(atPath: configPath)

    // Remove firewall rules
    FirewallManager.shared.removeFirewallRules()

    // Unload self
    let unload = Process()
    unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    unload.arguments = ["unload", "-w", "/Library/LaunchDaemons/com.blocksites.enforcer.plist"]
    try? unload.run()
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
