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

    @Flag(name: .long, help: "Show current block status")
    var status: Bool = false

    mutating func run() throws {
        if status {
            try showLiveStatus()
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

        // If no arguments provided, launch interactive mode (requires root)
        guard durationInSeconds > 0 || sites != nil else {
            try runInteractiveMode()
            return
        }

        guard durationInSeconds > 0, let sites = sites else {
            TerminalUI.printError("Debes especificar duración y sitios")
            print("")
            print("  \(TerminalUI.dim)blocksites --hours 2 --sites facebook.com,twitter.com\(TerminalUI.reset)")
            print("  \(TerminalUI.dim)blocksites --minutes 30 --sites instagram.com\(TerminalUI.reset)")
            print("  \(TerminalUI.dim)blocksites --status\(TerminalUI.reset)")
            throw ExitCode.failure
        }

        let siteList = sites.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        // Show confirmation
        guard showConfirmation(sites: siteList, seconds: durationInSeconds) else {
            print("")
            TerminalUI.printWarning("Cancelado.")
            return
        }

        try BlockManager.shared.blockSites(siteList, forSeconds: durationInSeconds)

        let endTime = Date().addingTimeInterval(durationInSeconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        print("")
        TerminalUI.printSuccess("Bloqueados \(siteList.count) sitio(s) hasta \(formatter.string(from: endTime))")
        print("  \(TerminalUI.dim)Sitios: \(siteList.joined(separator: ", "))\(TerminalUI.reset)")
        print("")
        TerminalUI.printWarning("NO se puede deshacer hasta que expire el timer.")
    }

    // MARK: - Interactive Mode

    func runInteractiveMode() throws {
        guard getuid() == 0 else {
            TerminalUI.printError("El modo interactivo requiere root")
            print("  \(TerminalUI.dim)Ejecuta: sudo blocksites\(TerminalUI.reset)")
            throw ExitCode.failure
        }

        while true {
            TerminalUI.clearScreen()
            let width = 37
            TerminalUI.printBoxWithDivider(
                header: [
                    TerminalUI.centerText("\(TerminalUI.boldCyan)BLOCKSITES v1.0\(TerminalUI.reset)", width: width - 2)
                ],
                body: [
                    "  \(TerminalUI.boldWhite)[1]\(TerminalUI.reset) Bloquear sitios",
                    "  \(TerminalUI.boldWhite)[2]\(TerminalUI.reset) Ver estado",
                    "  \(TerminalUI.boldWhite)[3]\(TerminalUI.reset) Salir",
                    ""
                ],
                width: width
            )

            let choice = TerminalUI.readInput(prompt: "  Elige una opción: ")

            switch choice.trimmingCharacters(in: .whitespaces) {
            case "1":
                try interactiveBlock()
            case "2":
                try showLiveStatus()
            case "3":
                return
            default:
                TerminalUI.printError("Opción no válida")
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    func interactiveBlock() throws {
        TerminalUI.clearScreen()
        print("\(TerminalUI.boldCyan)  BLOQUEAR SITIOS\(TerminalUI.reset)")
        print("")

        let sitesInput = TerminalUI.readInput(prompt: "  Sitios (separados por coma): ")
        guard !sitesInput.trimmingCharacters(in: .whitespaces).isEmpty else {
            TerminalUI.printError("No ingresaste sitios")
            Thread.sleep(forTimeInterval: 1.5)
            return
        }

        let siteList = sitesInput.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !siteList.isEmpty else {
            TerminalUI.printError("No ingresaste sitios válidos")
            Thread.sleep(forTimeInterval: 1.5)
            return
        }

        let hoursInput = TerminalUI.readInput(prompt: "  Horas (0 si solo minutos): ")
        let minsInput = TerminalUI.readInput(prompt: "  Minutos (0 si solo horas): ")

        let h = Double(hoursInput.trimmingCharacters(in: .whitespaces)) ?? 0
        let m = Double(minsInput.trimmingCharacters(in: .whitespaces)) ?? 0
        let totalSeconds = h * 3600 + m * 60

        guard totalSeconds > 0 else {
            TerminalUI.printError("La duración debe ser mayor a 0")
            Thread.sleep(forTimeInterval: 1.5)
            return
        }

        print("")
        guard showConfirmation(sites: siteList, seconds: totalSeconds) else {
            print("")
            TerminalUI.printWarning("Cancelado.")
            Thread.sleep(forTimeInterval: 1.5)
            return
        }

        try BlockManager.shared.blockSites(siteList, forSeconds: totalSeconds)

        let endTime = Date().addingTimeInterval(totalSeconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        print("")
        TerminalUI.printSuccess("Bloqueados \(siteList.count) sitio(s) hasta \(formatter.string(from: endTime))")
        print("")
        print("  \(TerminalUI.dim)Presiona Enter para continuar...\(TerminalUI.reset)")
        _ = readLine()
    }

    // MARK: - Confirmation

    func showConfirmation(sites: [String], seconds: TimeInterval) -> Bool {
        let endTime = Date().addingTimeInterval(seconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        print("")
        TerminalUI.printWarning("Vas a bloquear:")
        for site in sites {
            let subCount = TerminalUI.subdomainCount(for: site)
            print("    \(TerminalUI.boldWhite)•\(TerminalUI.reset) \(site) \(TerminalUI.dim)(+ \(subCount) subdominios)\(TerminalUI.reset)")
        }
        print("")
        print("    \(TerminalUI.boldYellow)Duración:\(TerminalUI.reset) \(TerminalUI.formatDurationShort(seconds))")
        print("    \(TerminalUI.boldYellow)Hasta:\(TerminalUI.reset)    \(formatter.string(from: endTime))")
        print("")
        TerminalUI.printWarning("NO se puede deshacer.")
        print("")
        return TerminalUI.confirm(prompt: "  ¿Continuar?")
    }

    // MARK: - Live Status

    func showLiveStatus() throws {
        guard let config = try BlockManager.shared.loadConfiguration() else {
            print("")
            TerminalUI.printBox([
                "  \(TerminalUI.boldGreen)🔓  SIN BLOQUEOS ACTIVOS\(TerminalUI.reset)",
                "",
                "  \(TerminalUI.dim)No hay sitios bloqueados\(TerminalUI.reset)",
                ""
            ])
            return
        }

        let now = Date()
        guard config.endTime > now else {
            print("")
            TerminalUI.printBox([
                "  \(TerminalUI.boldGreen)🔓  SIN BLOQUEOS ACTIVOS\(TerminalUI.reset)",
                "",
                "  \(TerminalUI.dim)El bloqueo anterior ya expiró\(TerminalUI.reset)",
                ""
            ])
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"

        let sitesStr = config.sites.joined(separator: ", ")
        let startStr = formatter.string(from: config.startTime)
        let endStr = formatter.string(from: config.endTime)

        // Setup signal handler for Ctrl+C
        TerminalUI.hideCursor()

        signal(SIGINT) { _ in
            TerminalUI.showCursor()
            print("")
            Darwin.exit(0)
        }

        // Live loop
        while true {
            let now = Date()
            let remaining = config.endTime.timeIntervalSince(now)

            if remaining <= 0 {
                TerminalUI.clearScreen()
                TerminalUI.showCursor()
                print("")
                TerminalUI.printBox([
                    "  \(TerminalUI.boldGreen)🔓  BLOQUEO EXPIRADO\(TerminalUI.reset)",
                    "",
                    "  \(TerminalUI.dim)Los sitios ya están desbloqueados\(TerminalUI.reset)",
                    ""
                ])
                return
            }

            let totalDuration = config.endTime.timeIntervalSince(config.startTime)
            let elapsed = now.timeIntervalSince(config.startTime)
            let progress = elapsed / totalDuration

            TerminalUI.clearScreen()
            print("")
            TerminalUI.printBoxWithDivider(
                header: [
                    "  \(TerminalUI.boldRed)🔒  BLOQUEO ACTIVO\(TerminalUI.reset)"
                ],
                body: [
                    "  \(TerminalUI.dim)Sitios:\(TerminalUI.reset) \(sitesStr)",
                    "  \(TerminalUI.dim)Inicio:\(TerminalUI.reset) \(startStr)",
                    "  \(TerminalUI.dim)Fin:\(TerminalUI.reset)    \(endStr)",
                    "",
                    "  \(TerminalUI.boldYellow)Restante: \(TerminalUI.formatDuration(remaining))\(TerminalUI.reset)",
                    "  \(TerminalUI.progressBar(progress: progress))",
                    ""
                ],
                width: 39
            )
            print("  \(TerminalUI.dim)Presiona Ctrl+C para salir\(TerminalUI.reset)")

            Thread.sleep(forTimeInterval: 1)
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

        // Remove config and residual files
        try? FileManager.default.removeItem(atPath: configPath)
        try? FileManager.default.removeItem(atPath: "/Library/Application Support/BlockSites/ip_cache.json")
        try? FileManager.default.removeItem(atPath: backupPath)

        // Unload daemon
        try? runCommand("/bin/launchctl", args: ["unload", "-w", daemonPlistPath])
        try? FileManager.default.removeItem(atPath: daemonPlistPath)
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
            // Time expired - remove blocks (also unloads daemon and cleans files)
            try removeBlocks()
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
