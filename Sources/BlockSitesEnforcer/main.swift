import Foundation
import MonkModeCore

struct EnforcerState: Codable {
    var lastHostsHash: Int
    var firstRunDone: Bool
}

func enforcerLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: MonkModeConstants.enforcerLogPath) {
        handle.seekToEndOfFile()
        handle.write(entry.data(using: .utf8) ?? Data())
        handle.closeFile()
    } else if let data = entry.data(using: .utf8) {
        try? data.write(to: URL(fileURLWithPath: MonkModeConstants.enforcerLogPath))
    }
}

func loadConfiguration() -> BlockConfiguration? {
    guard FileManager.default.fileExists(atPath: MonkModeConstants.configFilePath),
          let data = try? Data(contentsOf: URL(fileURLWithPath: MonkModeConstants.configFilePath)),
          let config = try? JSONDecoder().decode(BlockConfiguration.self, from: data) else {
        return nil
    }
    return config
}

func loadState() -> EnforcerState {
    guard FileManager.default.fileExists(atPath: MonkModeConstants.stateFilePath) else {
        return EnforcerState(lastHostsHash: 0, firstRunDone: false)
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: MonkModeConstants.stateFilePath)),
          let state = try? JSONDecoder().decode(EnforcerState.self, from: data) else {
        enforcerLog("State file corrupt — resetting but preserving firstRunDone=true to avoid redundant DNS flush")
        return EnforcerState(lastHostsHash: 0, firstRunDone: true)
    }
    return state
}

func saveState(_ state: EnforcerState) {
    if let data = try? JSONEncoder().encode(state) {
        try? data.write(to: URL(fileURLWithPath: MonkModeConstants.stateFilePath))
    }
}

func computeHostsHash(_ content: String) -> Int {
    var hasher = Hasher()
    hasher.combine(content)
    return hasher.finalize()
}

func applyBlocks(_ sites: [String], forceDNSFlush: Bool) {
    guard var hostsContent = try? String(contentsOfFile: MonkModeConstants.hostsPath, encoding: .utf8) else {
        enforcerLog("Error: could not read \(MonkModeConstants.hostsPath)")
        return
    }

    let currentHash = computeHostsHash(hostsContent)
    let state = loadState()

    hostsContent = HostsGenerator.cleanHostsContent(hostsContent, marker: MonkModeConstants.marker)
    let newContent = hostsContent + HostsGenerator.generateHostsEntries(for: sites, marker: MonkModeConstants.marker)
    let newHash = computeHostsHash(newContent)

    if currentHash != newHash || forceDNSFlush {
        try? newContent.write(toFile: MonkModeConstants.hostsPath, atomically: true, encoding: .utf8)

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
    enforcerLog("removeBlocks() invoked — timer expired or forced cleanup")

    if let hostsContent = try? String(contentsOfFile: MonkModeConstants.hostsPath, encoding: .utf8) {
        let cleanedContent = HostsGenerator.cleanHostsContent(hostsContent, marker: MonkModeConstants.marker)
        if cleanedContent != hostsContent {
            try? cleanedContent.write(toFile: MonkModeConstants.hostsPath, atomically: true, encoding: .utf8)
            enforcerLog("Hosts file cleaned")
        }
    }

    runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
    runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])

    FirewallManager.shared.removeFirewallRules()

    try? FileManager.default.removeItem(atPath: MonkModeConstants.configFilePath)
    try? FileManager.default.removeItem(atPath: MonkModeConstants.ipCachePath)
    try? FileManager.default.removeItem(atPath: MonkModeConstants.hostsBackupPath)
    try? FileManager.default.removeItem(atPath: MonkModeConstants.stateFilePath)

    let cleanupPlistPath = MonkModeConstants.cleanupDaemonPlistPath
    if FileManager.default.fileExists(atPath: cleanupPlistPath) {
        runCommand("/bin/launchctl", args: ["unload", "-w", cleanupPlistPath])
        try? FileManager.default.removeItem(atPath: cleanupPlistPath)
    }

    let enforcerPlistPath = MonkModeConstants.enforcerDaemonPlistPath
    runCommand("/bin/launchctl", args: ["unload", "-w", enforcerPlistPath])
    try? FileManager.default.removeItem(atPath: enforcerPlistPath)

    enforcerLog("Cleanup complete")
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
