import Foundation
import Combine
import SelfControlCore

class BlockViewModel: ObservableObject {
    // MARK: - Setup State

    @Published var selectedSites: Set<String> = []
    @Published var customSitesText: String = ""
    @Published var hours: Int = 0
    @Published var minutes: Int = 30

    // MARK: - Active Block State

    @Published var isBlocking: Bool = false
    @Published var config: BlockConfiguration?
    @Published var remainingSeconds: TimeInterval = 0

    // MARK: - UI State

    @Published var showConfirmation: Bool = false
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    private var timer: Timer?
    private let configPath = "/Library/Application Support/BlockSites/config.json"
    private let marker = "# BLOCKSITES"

    init() {
        checkExistingBlock()
    }

    // MARK: - Computed Properties

    var allSitesToBlock: [String] {
        let (valid, _) = DomainValidator.validateAndClean(customSitesText
            .split(separator: ",")
            .map { String($0) })
        var sites = Array(selectedSites)
        sites.append(contentsOf: valid)
        return Array(Set(sites)).sorted()
    }

    var invalidDomains: [String] {
        let custom = customSitesText
            .split(separator: ",")
            .map { String($0) }
        let (_, invalid) = DomainValidator.validateAndClean(custom)
        return invalid
    }

    var totalDurationSeconds: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    var canStartBlocking: Bool {
        !allSitesToBlock.isEmpty && totalDurationSeconds > 0
    }

    var progress: Double {
        guard let config = config else { return 0 }
        let total = config.endTime.timeIntervalSince(config.startTime)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(config.startTime)
        return min(1, max(0, elapsed / total))
    }

    var endTimeFormatted: String {
        guard let config = config else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: config.endTime)
    }

    private func escapeForSed(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: ".", with: "\\.")
    }

    // MARK: - Check Existing Block

    func checkExistingBlock() {
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let savedConfig = try? JSONDecoder().decode(BlockConfiguration.self, from: data),
              savedConfig.endTime > Date() else {
            isBlocking = false
            config = nil
            return
        }

        config = savedConfig
        isBlocking = true
        remainingSeconds = savedConfig.endTime.timeIntervalSince(Date())
        startCountdownTimer()
    }

    // MARK: - Start Blocking

    func startBlocking() {
        let sites = allSitesToBlock
        guard !sites.isEmpty, totalDurationSeconds > 0 else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let script = try await buildBlockingScriptAsync(sites: sites, duration: totalDurationSeconds)
                try PrivilegedExecutor.run(script)

                await MainActor.run {
                    self.isProcessing = false
                    self.checkExistingBlock()
                }
            } catch let error as PrivilegedExecutor.ExecutionError {
                await MainActor.run {
                    self.isProcessing = false
                    switch error {
                    case .userCancelled:
                        break
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Countdown Timer

    private func startCountdownTimer() {
        timer?.invalidate()

        let interval: TimeInterval
        if remainingSeconds <= 60 {
            interval = 1
        } else if remainingSeconds <= 3600 {
            interval = 10
        } else {
            interval = 60
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let config = self.config else { return }
            let remaining = config.endTime.timeIntervalSince(Date())
            if remaining <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.isBlocking = false
                self.config = nil
                self.remainingSeconds = 0
                self.selectedSites = []
                self.customSitesText = ""
            } else {
                self.remainingSeconds = remaining
                if remaining <= 60 && interval != 1 {
                    self.startCountdownTimer()
                } else if remaining <= 3600 && interval > 10 {
                    self.startCountdownTimer()
                }
            }
        }
    }

    // MARK: - Build Shell Script

    private func buildBlockingScript(sites: [String], duration: TimeInterval) throws -> String {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)

        let blockConfig = BlockConfiguration(sites: sites, startTime: startTime, endTime: endTime)
        let configData = try JSONEncoder().encode(blockConfig)
        guard let configJSON = String(data: configData, encoding: .utf8) else {
            throw NSError(domain: "BlockSites", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode config"])
        }

        let hostsEntries = HostsGenerator.generateHostsEntries(for: sites, marker: marker)

        let firewallData = FirewallManager.generateFirewallData(for: sites)
        let pfRules = firewallData.rules
        let ipCacheJSON: String
        if let cacheData = firewallData.cacheData, let str = String(data: cacheData, encoding: .utf8) {
            ipCacheJSON = str
        } else {
            ipCacheJSON = "{}"
        }

        return try buildScriptContent(
            configJSON: configJSON,
            hostsEntries: hostsEntries,
            pfRules: pfRules,
            ipCacheJSON: ipCacheJSON
        )
    }

    private func buildBlockingScriptAsync(sites: [String], duration: TimeInterval) async throws -> String {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)

        let blockConfig = BlockConfiguration(sites: sites, startTime: startTime, endTime: endTime)
        let configData = try JSONEncoder().encode(blockConfig)
        guard let configJSON = String(data: configData, encoding: .utf8) else {
            throw NSError(domain: "BlockSites", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode config"])
        }

        let hostsEntries = HostsGenerator.generateHostsEntries(for: sites, marker: marker)

        let firewallData = await FirewallManager.generateFirewallDataAsync(for: sites)
        let pfRules = firewallData.rules
        let ipCacheJSON: String
        if let cacheData = firewallData.cacheData, let str = String(data: cacheData, encoding: .utf8) {
            ipCacheJSON = str
        } else {
            ipCacheJSON = "{}"
        }

        return try buildScriptContent(
            configJSON: configJSON,
            hostsEntries: hostsEntries,
            pfRules: pfRules,
            ipCacheJSON: ipCacheJSON
        )
    }

    private func buildScriptContent(configJSON: String, hostsEntries: String, pfRules: String, ipCacheJSON: String) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("blocksites-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempConfig = tempDir.appendingPathComponent("config.json")
        let tempPfRules = tempDir.appendingPathComponent("pf_rules")
        let tempIPCache = tempDir.appendingPathComponent("ip_cache.json")
        let tempDaemonPlist = tempDir.appendingPathComponent("com.blocksites.enforcer.plist")
        let tempHostsEntries = tempDir.appendingPathComponent("hosts_entries")

        let daemonPlist = """
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
            <string>/Library/Application Support/BlockSites/enforcer.log</string>
            <key>StandardErrorPath</key>
            <string>/Library/Application Support/BlockSites/enforcer.log</string>
        </dict>
        </plist>
        """

        try configJSON.write(to: tempConfig, atomically: true, encoding: .utf8)
        try pfRules.write(to: tempPfRules, atomically: true, encoding: .utf8)
        try ipCacheJSON.write(to: tempIPCache, atomically: true, encoding: .utf8)
        try daemonPlist.write(to: tempDaemonPlist, atomically: true, encoding: .utf8)
        try hostsEntries.write(to: tempHostsEntries, atomically: true, encoding: .utf8)

        let escapedMarker = escapeForSed(marker)
        let supportDir = "/Library/Application Support/BlockSites"
        let pfAnchorPath = "/etc/pf.anchors/com.blocksites"
        let daemonPath = "/Library/LaunchDaemons/com.blocksites.enforcer.plist"

        let anchorLine = "anchor \\\"com.blocksites\\\""
        let loadLine = "load anchor \\\"com.blocksites\\\" from \\\"/etc/pf.anchors/com.blocksites\\\""

        let script = """
        mkdir -p '\(supportDir)' && \
        cp '\(tempConfig.path)' '\(supportDir)/config.json' && \
        cp '\(tempIPCache.path)' '\(supportDir)/ip_cache.json' && \
        cp '\(tempPfRules.path)' '\(pfAnchorPath)' && \
        cp '\(tempDaemonPlist.path)' '\(daemonPath)' && \
        cp /etc/hosts '\(supportDir)/hosts.backup' && \
        sed -i '' '/\(escapedMarker)/d' /etc/hosts && \
        cat '\(tempHostsEntries.path)' >> /etc/hosts && \
        dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null; \
        if ! grep -q '\(anchorLine)' /etc/pf.conf; then \
            printf '\\n# BlockSites anchor\\n\(anchorLine)\\n\(loadLine)\\n' >> /etc/pf.conf; \
        fi && \
        pfctl -e 2>/dev/null; pfctl -f /etc/pf.conf 2>/dev/null; \
        launchctl unload -w '\(daemonPath)' 2>/dev/null; \
        launchctl load -w '\(daemonPath)' && \
        rm -rf '\(tempDir.path)'
        """

        return script
    }
}
