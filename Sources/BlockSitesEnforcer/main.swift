import Foundation
import BlockSitesCore

// This is the daemon enforcer - runs every minute to ensure blocks stay active

let configPath = "/Library/Application Support/BlockSites/config.json"
let hostsPath = "/etc/hosts"
let marker = "# BLOCKSITES"

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
    hostsContent = HostsGenerator.cleanHostsContent(hostsContent, marker: marker)

    // Add new blocks
    hostsContent += HostsGenerator.generateHostsEntries(for: sites, marker: marker)

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

    let cleanedContent = HostsGenerator.cleanHostsContent(hostsContent, marker: marker)

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
