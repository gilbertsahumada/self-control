import Foundation
import Combine
import MonkModeCore

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
    @Published var needsRecoveryCleanup: Bool = false
    @Published var isWaitingForDaemonCleanup: Bool = false

    /// Seconds after timer expiry during which we suppress the stale-block
    /// banner while polling to give the LaunchDaemon time to run cleanup.
    /// The primary enforcer daemon runs every 60s so 90s gives a full cycle
    /// plus launchd wake-up slack.
    static let postExpiryGraceSeconds: TimeInterval = 90
    static let postExpiryPollInterval: TimeInterval = 10

    private var timer: Timer?
    private var postExpiryPollTimer: Timer?
    private var postExpiryDeadline: Date?

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

    // MARK: - Check Existing Block + Recovery

    func checkExistingBlock() {
        let configPath = MonkModeConstants.configFilePath
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let savedConfig = try? JSONDecoder().decode(BlockConfiguration.self, from: data) else {
            isBlocking = false
            config = nil
            needsRecoveryCleanup = detectStaleBlock()
            return
        }

        if savedConfig.endTime > Date() {
            config = savedConfig
            isBlocking = true
            remainingSeconds = savedConfig.endTime.timeIntervalSince(Date())
            startCountdownTimer()
        } else {
            // Config exists but is expired. Enforcer should have cleaned up — if not, offer recovery.
            isBlocking = false
            config = nil
            needsRecoveryCleanup = detectStaleBlock()
        }
    }

    /// Polls `/etc/hosts` every `postExpiryPollInterval` for up to
    /// `postExpiryGraceSeconds` after block expiry before surfacing the
    /// stale-block banner. In the normal path the enforcer daemon cleans
    /// up within 60s and the banner never appears.
    private func startPostExpiryPolling() {
        postExpiryPollTimer?.invalidate()
        postExpiryDeadline = Date().addingTimeInterval(Self.postExpiryGraceSeconds)
        isWaitingForDaemonCleanup = true
        needsRecoveryCleanup = false

        postExpiryPollTimer = Timer.scheduledTimer(withTimeInterval: Self.postExpiryPollInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.detectStaleBlock() {
                self.postExpiryPollTimer?.invalidate()
                self.postExpiryPollTimer = nil
                self.isWaitingForDaemonCleanup = false
                self.needsRecoveryCleanup = false
                return
            }
            if let deadline = self.postExpiryDeadline, Date() >= deadline {
                self.postExpiryPollTimer?.invalidate()
                self.postExpiryPollTimer = nil
                self.isWaitingForDaemonCleanup = false
                self.needsRecoveryCleanup = true
            }
        }
    }

    /// Returns true if /etc/hosts still contains MonkMode markers without an active block.
    /// This indicates the enforcer daemon failed to clean up on expiry.
    private func detectStaleBlock() -> Bool {
        guard let hosts = try? String(contentsOfFile: MonkModeConstants.hostsPath, encoding: .utf8) else {
            return false
        }
        return hosts.contains(MonkModeConstants.marker)
    }

    /// Triggers a privileged cleanup of leftover /etc/hosts + pf state.
    /// Used when the enforcer daemon failed to clean up after expiry.
    func runRecoveryCleanup() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let script = buildRecoveryCleanupScript()
                try PrivilegedExecutor.run(script)
                await MainActor.run {
                    self.isProcessing = false
                    self.needsRecoveryCleanup = false
                    self.checkExistingBlock()
                }
            } catch let error as PrivilegedExecutor.ExecutionError {
                await MainActor.run {
                    self.isProcessing = false
                    if case .userCancelled = error { return }
                    self.errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
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
                // Poll the hosts file for up to `postExpiryGraceSeconds` so the
                // LaunchDaemon has time to run cleanup before we surface the
                // stale-block banner. Normal path: banner never appears.
                self.startPostExpiryPolling()
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

    private func buildBlockingScriptAsync(sites: [String], duration: TimeInterval) async throws -> String {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)

        let blockConfig = BlockConfiguration(sites: sites, startTime: startTime, endTime: endTime)
        let configData = try JSONEncoder().encode(blockConfig)
        guard let configJSON = String(data: configData, encoding: .utf8) else {
            throw NSError(domain: "MonkMode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode config"])
        }

        let hostsEntries = HostsGenerator.generateHostsEntries(for: sites, marker: MonkModeConstants.marker)

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
            ipCacheJSON: ipCacheJSON,
            endTime: endTime
        )
    }

    private func enforcerBinarySourcePath() -> String? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/MonkModeEnforcer").path
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        // Fallback for `swift build` / Xcode runs: binary sits next to the main executable.
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MonkModeEnforcer").path
        if FileManager.default.fileExists(atPath: sibling) {
            return sibling
        }
        // Installed MonkMode binary (reinstall flow).
        let installed = "/usr/local/bin/monkmode-enforcer"
        if FileManager.default.fileExists(atPath: installed) {
            return installed
        }
        // Legacy install paths from earlier names — keep as last-resort fallbacks so
        // a transitioning install can still find a prior binary.
        let legacySelfControl = "/usr/local/bin/selfcontrol-enforcer"
        if FileManager.default.fileExists(atPath: legacySelfControl) {
            return legacySelfControl
        }
        let legacyBlockSites = "/usr/local/bin/blocksites-enforcer"
        if FileManager.default.fileExists(atPath: legacyBlockSites) {
            return legacyBlockSites
        }
        return nil
    }

    private func buildScriptContent(configJSON: String, hostsEntries: String, pfRules: String, ipCacheJSON: String, endTime: Date) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("monkmode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempConfig = tempDir.appendingPathComponent("config.json")
        let tempPfRules = tempDir.appendingPathComponent("pf_rules")
        let tempIPCache = tempDir.appendingPathComponent("ip_cache.json")
        let tempEnforcerPlist = tempDir.appendingPathComponent("com.monkmode.enforcer.plist")
        let tempCleanupPlist = tempDir.appendingPathComponent("com.monkmode.cleanup.plist")
        let tempHostsEntries = tempDir.appendingPathComponent("hosts_entries")

        try configJSON.write(to: tempConfig, atomically: true, encoding: .utf8)
        try pfRules.write(to: tempPfRules, atomically: true, encoding: .utf8)
        try ipCacheJSON.write(to: tempIPCache, atomically: true, encoding: .utf8)
        try DaemonPlistBuilder.buildEnforcerDaemonPlist().write(to: tempEnforcerPlist, atomically: true, encoding: .utf8)
        try DaemonPlistBuilder.buildCleanupDaemonPlist(endTime: endTime).write(to: tempCleanupPlist, atomically: true, encoding: .utf8)
        try hostsEntries.write(to: tempHostsEntries, atomically: true, encoding: .utf8)

        guard let enforcerSrc = enforcerBinarySourcePath() else {
            throw NSError(domain: "MonkMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "MonkModeEnforcer binary not found in app bundle"])
        }

        let escapedMarker = escapeForSed(MonkModeConstants.marker)
        let supportDir = MonkModeConstants.supportDir
        let pfAnchorPath = MonkModeConstants.pfAnchorPath
        let enforcerDaemonPath = MonkModeConstants.enforcerDaemonPlistPath
        let cleanupDaemonPath = MonkModeConstants.cleanupDaemonPlistPath
        let enforcerBinaryDest = MonkModeConstants.enforcerInstallPath
        let hostsPath = MonkModeConstants.hostsPath
        let pfConfPath = MonkModeConstants.pfConfPath
        let installLog = MonkModeConstants.installLogPath

        let anchorDecl = "anchor \\\"\(MonkModeConstants.pfAnchorName)\\\""
        let loadDecl = "load anchor \\\"\(MonkModeConstants.pfAnchorName)\\\" from \\\"\(pfAnchorPath)\\\""

        // set -e ensures any failure aborts. trap logs final status.
        let script = """
        #!/bin/bash
        set -e
        mkdir -p '\(supportDir)'
        LOG='\(installLog)'
        exec > >(tee -a "$LOG") 2>&1
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] install: starting"
        trap 'ec=$?; echo "[$(date -u '\"'\"'+%Y-%m-%dT%H:%M:%SZ'\"'\"')] install: exit=$ec"; exit $ec' EXIT

        install -m 0755 '\(enforcerSrc)' '\(enforcerBinaryDest)'
        cp '\(tempConfig.path)' '\(supportDir)/config.json'
        cp '\(tempIPCache.path)' '\(supportDir)/ip_cache.json'
        cp '\(tempPfRules.path)' '\(pfAnchorPath)'
        cp '\(tempEnforcerPlist.path)' '\(enforcerDaemonPath)'
        cp '\(tempCleanupPlist.path)' '\(cleanupDaemonPath)'
        cp '\(hostsPath)' '\(supportDir)/hosts.backup'
        sed -i '' '/\(escapedMarker)/d' '\(hostsPath)'
        cat '\(tempHostsEntries.path)' >> '\(hostsPath)'
        /usr/bin/dscacheutil -flushcache
        /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
        if ! grep -q '\(anchorDecl)' '\(pfConfPath)'; then
          printf '\\n# MonkMode anchor\\n\(anchorDecl)\\n\(loadDecl)\\n' >> '\(pfConfPath)'
        fi
        /sbin/pfctl -e 2>/dev/null || true
        /sbin/pfctl -f '\(pfConfPath)' 2>/dev/null || true

        /bin/launchctl unload -w '\(enforcerDaemonPath)' 2>/dev/null || true
        /bin/launchctl load -w '\(enforcerDaemonPath)'
        /bin/launchctl unload -w '\(cleanupDaemonPath)' 2>/dev/null || true
        /bin/launchctl load -w '\(cleanupDaemonPath)'

        rm -rf '\(tempDir.path)'
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] install: success"
        """

        return script
    }

    private func buildRecoveryCleanupScript() -> String {
        let escapedMarker = escapeForSed(MonkModeConstants.marker)
        let hostsPath = MonkModeConstants.hostsPath
        let pfConfPath = MonkModeConstants.pfConfPath
        let pfAnchorPath = MonkModeConstants.pfAnchorPath
        let supportDir = MonkModeConstants.supportDir
        let enforcerDaemonPath = MonkModeConstants.enforcerDaemonPlistPath
        let cleanupDaemonPath = MonkModeConstants.cleanupDaemonPlistPath
        let installLog = MonkModeConstants.installLogPath

        return """
        #!/bin/bash
        set +e
        mkdir -p '\(supportDir)'
        LOG='\(installLog)'
        exec > >(tee -a "$LOG") 2>&1
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] recovery: starting"

        sed -i '' '/\(escapedMarker)/d' '\(hostsPath)'
        /usr/bin/dscacheutil -flushcache
        /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true

        # Remove anchor lines from pf.conf (match both Apple-escaped and literal forms)
        sed -i '' '/# MonkMode anchor/d' '\(pfConfPath)'
        sed -i '' '/anchor "\(MonkModeConstants.pfAnchorName)"/d' '\(pfConfPath)'
        sed -i '' '/load anchor "\(MonkModeConstants.pfAnchorName)"/d' '\(pfConfPath)'
        /sbin/pfctl -d 2>/dev/null || true
        /sbin/pfctl -f '\(pfConfPath)' 2>/dev/null || true
        rm -f '\(pfAnchorPath)'

        /bin/launchctl unload -w '\(enforcerDaemonPath)' 2>/dev/null || true
        /bin/launchctl unload -w '\(cleanupDaemonPath)' 2>/dev/null || true
        rm -f '\(enforcerDaemonPath)' '\(cleanupDaemonPath)'
        rm -f '\(supportDir)/config.json' '\(supportDir)/ip_cache.json' '\(supportDir)/hosts.backup' '\(supportDir)/enforcer_state.json'

        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] recovery: success"
        """
    }
}
