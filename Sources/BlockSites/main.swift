import Foundation
import ArgumentParser

@main
struct BlockSites: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blocksites",
        abstract: "Block websites for a specified duration - no way to unblock early",
        version: "1.0.0"
    )

    @Option(name: .shortAndLong, help: "Duration in hours to block sites")
    var hours: Double?

    @Option(name: .shortAndLong, help: "Duration in minutes to block sites")
    var minutes: Double?

    @Option(name: .shortAndLong, help: "Sites to block (comma-separated)")
    var sites: String?

    @Flag(name: .shortAndLong, help: "Show current block status")
    var status: Bool = false

    mutating func run() throws {
        if status {
            try showStatus()
            return
        }

        // Calculate total duration in seconds
        var durationInSeconds: TimeInterval = 0

        if let h = hours {
            durationInSeconds += h * 3600
        }

        if let m = minutes {
            durationInSeconds += m * 60
        }

        guard durationInSeconds > 0, let sites = sites else {
            print("Usage:")
            print("  blocksites --hours 2 --sites facebook.com,twitter.com")
            print("  blocksites --minutes 30 --sites facebook.com,twitter.com")
            print("  blocksites --hours 1 --minutes 30 --sites facebook.com")
            print("  blocksites --status")
            throw ExitCode.failure
        }

        let siteList = sites.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        try BlockManager.shared.blockSites(siteList, forSeconds: durationInSeconds)

        let endTime = Date().addingTimeInterval(durationInSeconds)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        print("✓ Blocked \(siteList.count) site(s) until \(formatter.string(from: endTime))")
        print("Sites blocked: \(siteList.joined(separator: ", "))")
        print("\n⚠️  Cannot be undone until timer expires!")
    }

    func showStatus() throws {
        if let config = try BlockManager.shared.loadConfiguration() {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            let now = Date()
            if config.endTime > now {
                let remaining = config.endTime.timeIntervalSince(now)
                let hours = Int(remaining / 3600)
                let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

                print("🔒 ACTIVE BLOCK")
                print("Sites blocked: \(config.sites.joined(separator: ", "))")
                print("Started: \(formatter.string(from: config.startTime))")
                print("Ends: \(formatter.string(from: config.endTime))")
                print("Time remaining: \(hours)h \(minutes)m")
            } else {
                print("No active blocks")
            }
        } else {
            print("No active blocks")
        }
    }
}

class BlockManager {
    static let shared = BlockManager()

    private let hostsPath = "/etc/hosts"
    private let configPath = "/Library/Application Support/BlockSites/config.json"
    private let backupPath = "/Library/Application Support/BlockSites/hosts.backup"
    private let daemonPlistPath = "/Library/LaunchDaemons/com.blocksites.enforcer.plist"

    private let marker = "# BLOCKSITES"

    func blockSites(_ sites: [String], forSeconds seconds: TimeInterval) throws {
        // Check if we're running as root
        guard getuid() == 0 else {
            print("❌ This command requires root privileges")
            print("Please run with sudo")
            throw ExitCode.failure
        }

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(seconds)

        let config = BlockConfiguration(sites: sites, startTime: startTime, endTime: endTime)

        // Create directory if needed
        let configDir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        // Backup current hosts file
        try? FileManager.default.copyItem(atPath: hostsPath, toPath: backupPath)

        // Save configuration
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: configPath))

        // Apply blocks (hosts file)
        try applyBlocks(sites)

        // Apply firewall blocks (more aggressive)
        print("Applying firewall rules...")
        try? FirewallManager.shared.blockSitesWithFirewall(sites)

        // Install daemon
        try installDaemon()

        // Start daemon
        try runCommand("/bin/launchctl", args: ["load", "-w", daemonPlistPath])
    }

    func applyBlocks(_ sites: [String]) throws {
        var hostsContent = try String(contentsOfFile: hostsPath, encoding: .utf8)

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

        try hostsContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

        // Flush DNS cache
        try? runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
        try? runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])
    }

    func removeBlocks() throws {
        guard let hostsContent = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
            return
        }

        let lines = hostsContent.components(separatedBy: .newlines)
        let cleanedContent = lines.filter { !$0.contains(marker) }.joined(separator: "\n")

        try cleanedContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

        // Flush DNS cache
        try? runCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
        try? runCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])

        // Remove firewall rules
        try? FirewallManager.shared.removeFirewallRules()

        // Remove config
        try? FileManager.default.removeItem(atPath: configPath)
    }

    func loadConfiguration() throws -> BlockConfiguration? {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return nil
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let decoder = JSONDecoder()
        return try decoder.decode(BlockConfiguration.self, from: data)
    }

    func checkAndEnforce() throws {
        guard let config = try loadConfiguration() else {
            return
        }

        let now = Date()

        if now < config.endTime {
            // Still blocking - re-apply blocks in case user tried to modify
            try applyBlocks(config.sites)
        } else {
            // Time expired - remove blocks
            try removeBlocks()

            // Unload daemon
            try? runCommand("/bin/launchctl", args: ["unload", "-w", daemonPlistPath])
        }
    }

    private func installDaemon() throws {
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.blocksites.enforcer</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/blocksites-enforcer</string>
            </array>
            <key>StartInterval</key>
            <integer>60</integer>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/var/log/blocksites.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/blocksites.log</string>
        </dict>
        </plist>
        """

        try plistContent.write(toFile: daemonPlistPath, atomically: true, encoding: .utf8)
    }

    private func runCommand(_ path: String, args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
    }
}
