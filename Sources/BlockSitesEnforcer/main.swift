import Foundation
import SelfControlCore

let configPath = "/Library/Application Support/BlockSites/config.json"
let hostsPath = "/etc/hosts"
let marker = "# BLOCKSITES"
let stateFilePath = "/Library/Application Support/BlockSites/enforcer_state.json"

struct EnforcerState: Codable {
    var lastHostsHash: Int
    var firstRunDone: Bool
}

func loadConfiguration() -> BlockConfiguration? {
    guard FileManager.default.fileExists(atPath: configPath),
          let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let config = try? JSONDecoder().decode(BlockConfiguration.self, from: data) else {
        return nil
    }
    return config
}

func loadState() -> EnforcerState {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
          let state = try? JSONDecoder().decode(EnforcerState.self, from: data) else {
        return EnforcerState(lastHostsHash: 0, firstRunDone: false)
    }
    return state
}

func saveState(_ state: EnforcerState) {
    if let data = try? JSONEncoder().encode(state) {
        try? data.write(to: URL(fileURLWithPath: stateFilePath))
    }
}

func computeHostsHash(_ content: String) -> Int {
    var hasher = Hasher()
    hasher.combine(content)
    return hasher.finalize()
}

func applyBlocks(_ sites: [String], forceDNSFlush: Bool) {
    guard var hostsContent = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
        return
    }

    let currentHash = computeHostsHash(hostsContent)
    let state = loadState()

    hostsContent = HostsGenerator.cleanHostsContent(hostsContent, marker: marker)
    let newContent = hostsContent + HostsGenerator.generateHostsEntries(for: sites, marker: marker)
    let newHash = computeHostsHash(newContent)

    if currentHash != newHash || forceDNSFlush {
        try? newContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

        if forceDNSFlush {
            runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
            runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])
        }
    }

    FirewallManager.shared.reapplyFirewallRules()

    var newState = state
    newState.lastHostsHash = newHash
    newState.firstRunDone = true
    saveState(newState)
}

func removeBlocks() {
    // Always clean hosts file — remove all BLOCKSITES entries
    if let hostsContent = try? String(contentsOfFile: hostsPath, encoding: .utf8) {
        let cleanedContent = HostsGenerator.cleanHostsContent(hostsContent, marker: marker)
        if cleanedContent != hostsContent {
            try? cleanedContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        }
    }

    // Always flush DNS cache on block expiry
    runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
    runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])

    // Remove firewall rules and clean pf.conf
    FirewallManager.shared.removeFirewallRules()

    // Clean up app data files
    try? FileManager.default.removeItem(atPath: configPath)
    try? FileManager.default.removeItem(atPath: "/Library/Application Support/BlockSites/ip_cache.json")
    try? FileManager.default.removeItem(atPath: "/Library/Application Support/BlockSites/hosts.backup")
    try? FileManager.default.removeItem(atPath: stateFilePath)

    // Unload and remove daemon plist — must be last since it stops this process
    let plistPath = "/Library/LaunchDaemons/com.blocksites.enforcer.plist"
    runCommand("/bin/launchctl", args: ["unload", "-w", plistPath])
    try? FileManager.default.removeItem(atPath: plistPath)
}

guard let config = loadConfiguration() else {
    exit(0)
}

let now = Date()

if now < config.endTime {
    let state = loadState()
    let forceDNSFlush = !state.firstRunDone
    applyBlocks(config.sites, forceDNSFlush: forceDNSFlush)
} else {
    removeBlocks()
}
