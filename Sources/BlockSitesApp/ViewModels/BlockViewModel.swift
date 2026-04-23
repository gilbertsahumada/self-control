import Foundation
import Combine
import MonkModeCore

class BlockViewModel: ObservableObject {
    // MARK: - Setup State

    @Published var selectedSites: Set<String> = []
    @Published var customDomains: [String] = []
    @Published var pendingDomainInput: String = ""
    @Published var pendingDomainError: String?
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
        var sites = Array(selectedSites)
        sites.append(contentsOf: customDomains)
        return Array(Set(sites)).sorted()
    }

    var totalDurationSeconds: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    var canStartBlocking: Bool {
        !allSitesToBlock.isEmpty && totalDurationSeconds > 0
    }

    // MARK: - Custom Domain Input

    /// Validates `pendingDomainInput` and appends it to `customDomains` on
    /// success. Publishes `pendingDomainError` on failure so the UI can
    /// render inline feedback. Accepts one domain per call; splitting on
    /// whitespace/comma is handled by the view before calling.
    @discardableResult
    func commitPendingDomain() -> Bool {
        let raw = pendingDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            pendingDomainError = nil
            return false
        }

        let (valid, invalid) = DomainValidator.validateAndClean([raw])
        guard let cleaned = valid.first else {
            pendingDomainError = "invalid domain: \(invalid.first ?? raw)"
            return false
        }

        if customDomains.contains(cleaned) || selectedSites.contains(cleaned) {
            pendingDomainError = "already in list: \(cleaned)"
            return false
        }

        customDomains.append(cleaned)
        pendingDomainInput = ""
        pendingDomainError = nil
        return true
    }

    func removeCustomDomain(_ domain: String) {
        customDomains.removeAll { $0 == domain }
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

    /// Full uninstall: runs the bundled `uninstall.sh` via privileged
    /// execution. Removes every system modification MonkMode installs
    /// (daemons, enforcer binary, support dir, hosts entries, pf anchor).
    /// Leaves /Applications/MonkMode.app in place — user drags to Trash.
    func runUninstall() {
        let scriptPath = Bundle.main.url(forResource: "uninstall", withExtension: "sh")?.path
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/uninstall.sh").path

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            errorMessage = "uninstall.sh not found at \(scriptPath)"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let quoted = try ShellQuote.posixSingleQuote(scriptPath)
                let wrapper = "#!/bin/bash\nbash \(quoted)\n"
                try PrivilegedExecutor.run(wrapper)
                await MainActor.run {
                    self.isProcessing = false
                    self.isBlocking = false
                    self.config = nil
                    self.needsRecoveryCleanup = false
                    self.isWaitingForDaemonCleanup = false
                    self.errorMessage = "MonkMode was uninstalled. Drag the app to the Trash to complete."
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

    /// Triggers a privileged cleanup of leftover /etc/hosts + pf state.
    /// Used when the enforcer daemon failed to clean up after expiry.
    func runRecoveryCleanup() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let script = try buildRecoveryCleanupScript()
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
                self.customDomains = []
                self.pendingDomainInput = ""
                self.pendingDomainError = nil
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
        let bundleURL = Bundle.main.bundleURL

        // Case 1 — running from an .app bundle. `bundleURL` is the .app dir.
        let appBundled = bundleURL.appendingPathComponent("Contents/MacOS/MonkModeEnforcer").path
        if FileManager.default.fileExists(atPath: appBundled) {
            return appBundled
        }

        // Case 2 — running as a bare executable (`swift run`, Xcode, `.build/debug`).
        // For an unbundled binary, `Bundle.main.bundleURL` is the directory that
        // holds the executable, so the enforcer sits *inside* that directory.
        // The previous implementation used `deletingLastPathComponent()`, which
        // walked up one level too far and caused the system to fall through to
        // the installed-binary branch below — triggering
        // `install: <path> and <path> are the same file` when reinstalling.
        let sibling = bundleURL.appendingPathComponent("MonkModeEnforcer").path
        if FileManager.default.fileExists(atPath: sibling) {
            return sibling
        }

        // NOTE: the install target `/usr/local/bin/monkmode-enforcer` is
        // intentionally NOT a fallback source — returning it here caused
        // `install` to copy a file onto itself (exit 64).
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

        // Every interpolated value MUST go through ShellQuote. The helper
        // rejects control characters and returns a single-quoted string
        // safe to drop into bash. Violating this invariant can execute
        // arbitrary commands as root — see #15.
        let q = ShellQuote.posixSingleQuote
        let marker = try ShellQuote.sedBRE(MonkModeConstants.marker)
        let supportDir = try q(MonkModeConstants.supportDir)
        let pfAnchorPath = try q(MonkModeConstants.pfAnchorPath)
        let enforcerDaemonPath = try q(MonkModeConstants.enforcerDaemonPlistPath)
        let cleanupDaemonPath = try q(MonkModeConstants.cleanupDaemonPlistPath)
        let enforcerBinaryDest = try q(MonkModeConstants.enforcerInstallPath)
        let hostsPath = try q(MonkModeConstants.hostsPath)
        let pfConfPath = try q(MonkModeConstants.pfConfPath)
        let installLog = try q(MonkModeConstants.installLogPath)
        let supportConfig = try q("\(MonkModeConstants.supportDir)/config.json")
        let supportIPCache = try q("\(MonkModeConstants.supportDir)/ip_cache.json")
        let supportHostsBackup = try q("\(MonkModeConstants.supportDir)/hosts.backup")
        let enforcerSrcQ = try q(enforcerSrc)
        let tempConfigQ = try q(tempConfig.path)
        let tempPfRulesQ = try q(tempPfRules.path)
        let tempIPCacheQ = try q(tempIPCache.path)
        let tempEnforcerPlistQ = try q(tempEnforcerPlist.path)
        let tempCleanupPlistQ = try q(tempCleanupPlist.path)
        let tempHostsEntriesQ = try q(tempHostsEntries.path)
        let tempDirQ = try q(tempDir.path)

        // The pf.conf anchor block goes into an `fi` grep check and a printf.
        // Build its two canonical forms here so the script body only does a
        // literal substitution on a pre-validated string.
        let anchorDecl = "anchor \"\(MonkModeConstants.pfAnchorName)\""
        let loadDecl = "load anchor \"\(MonkModeConstants.pfAnchorName)\" from \"\(MonkModeConstants.pfAnchorPath)\""
        let anchorGrep = try q(anchorDecl)

        let script = """
        #!/bin/bash
        set -e
        mkdir -p \(supportDir)
        chown root:wheel \(supportDir)
        chmod 0755 \(supportDir)
        LOG=\(installLog)
        touch "$LOG"
        chmod 0640 "$LOG"
        exec > >(tee -a "$LOG") 2>&1
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] install: starting"
        trap 'ec=$?; echo "[$(date -u '\"'\"'+%Y-%m-%dT%H:%M:%SZ'\"'\"')] install: exit=$ec"; exit $ec' EXIT

        if [ "$(readlink -f \(enforcerSrcQ) 2>/dev/null || echo \(enforcerSrcQ))" != "$(readlink -f \(enforcerBinaryDest) 2>/dev/null || echo \(enforcerBinaryDest))" ]; then
          install -m 0755 \(enforcerSrcQ) \(enforcerBinaryDest)
        fi
        cp \(tempConfigQ) \(supportConfig)
        cp \(tempIPCacheQ) \(supportIPCache)
        cp \(tempPfRulesQ) \(pfAnchorPath)
        cp \(tempEnforcerPlistQ) \(enforcerDaemonPath)
        cp \(tempCleanupPlistQ) \(cleanupDaemonPath)
        cp \(hostsPath) \(supportHostsBackup)
        chown root:wheel \(supportConfig) \(supportIPCache) \(supportHostsBackup)
        # config.json + ip_cache.json are world-readable (0644) so the
        # unprivileged app can check block state. They are only WRITABLE
        # by root, which is what protects against a second local user
        # shortening the timer. hosts.backup stays 0600 because it mirrors
        # the user's full /etc/hosts and may contain private entries.
        chmod 0644 \(supportConfig) \(supportIPCache)
        chmod 0600 \(supportHostsBackup)
        sed -i '' '/\(marker)/d' \(hostsPath)
        cat \(tempHostsEntriesQ) >> \(hostsPath)
        /usr/bin/dscacheutil -flushcache
        /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
        if ! grep -qF \(anchorGrep) \(pfConfPath); then
          printf '\\n# MonkMode anchor\\n%s\\n%s\\n' \(try q(anchorDecl)) \(try q(loadDecl)) >> \(pfConfPath)
        fi
        /sbin/pfctl -e 2>/dev/null || true
        /sbin/pfctl -f \(pfConfPath) 2>/dev/null || true

        /bin/launchctl unload -w \(enforcerDaemonPath) 2>/dev/null || true
        /bin/launchctl load -w \(enforcerDaemonPath)
        /bin/launchctl unload -w \(cleanupDaemonPath) 2>/dev/null || true
        /bin/launchctl load -w \(cleanupDaemonPath)

        rm -rf \(tempDirQ)
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] install: success"
        """

        return script
    }

    private func buildRecoveryCleanupScript() throws -> String {
        let q = ShellQuote.posixSingleQuote
        let marker = try ShellQuote.sedBRE(MonkModeConstants.marker)
        let anchorPattern = try ShellQuote.sedBRE("anchor \"\(MonkModeConstants.pfAnchorName)\"")
        let loadAnchorPattern = try ShellQuote.sedBRE("load anchor \"\(MonkModeConstants.pfAnchorName)\"")
        let hostsPath = try q(MonkModeConstants.hostsPath)
        let pfConfPath = try q(MonkModeConstants.pfConfPath)
        let pfAnchorPath = try q(MonkModeConstants.pfAnchorPath)
        let supportDir = try q(MonkModeConstants.supportDir)
        let enforcerDaemonPath = try q(MonkModeConstants.enforcerDaemonPlistPath)
        let cleanupDaemonPath = try q(MonkModeConstants.cleanupDaemonPlistPath)
        let installLog = try q(MonkModeConstants.installLogPath)
        let configPath = try q("\(MonkModeConstants.supportDir)/config.json")
        let ipCachePath = try q("\(MonkModeConstants.supportDir)/ip_cache.json")
        let hostsBackupPath = try q("\(MonkModeConstants.supportDir)/hosts.backup")
        let statePath = try q("\(MonkModeConstants.supportDir)/enforcer_state.json")

        return """
        #!/bin/bash
        set +e
        mkdir -p \(supportDir)
        LOG=\(installLog)
        exec > >(tee -a "$LOG") 2>&1
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] recovery: starting"

        sed -i '' '/\(marker)/d' \(hostsPath)
        /usr/bin/dscacheutil -flushcache
        /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true

        sed -i '' '/# MonkMode anchor/d' \(pfConfPath)
        sed -i '' '/\(anchorPattern)/d' \(pfConfPath)
        sed -i '' '/\(loadAnchorPattern)/d' \(pfConfPath)
        /sbin/pfctl -d 2>/dev/null || true
        /sbin/pfctl -f \(pfConfPath) 2>/dev/null || true
        rm -f \(pfAnchorPath)

        /bin/launchctl unload -w \(enforcerDaemonPath) 2>/dev/null || true
        /bin/launchctl unload -w \(cleanupDaemonPath) 2>/dev/null || true
        rm -f \(enforcerDaemonPath) \(cleanupDaemonPath)
        rm -f \(configPath) \(ipCachePath) \(hostsBackupPath) \(statePath)

        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] recovery: success"
        """
    }
}
