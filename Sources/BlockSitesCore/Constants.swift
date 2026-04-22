import Foundation

public enum MonkModeConstants {
    public static let marker = "# MONKMODE"

    public static let enforcerDaemonLabel = "com.monkmode.enforcer"
    public static let cleanupDaemonLabel = "com.monkmode.cleanup"

    public static let pfAnchorName = "com.monkmode"

    public static let supportDir = "/Library/Application Support/MonkMode"
    public static let hostsPath = "/etc/hosts"
    public static let pfConfPath = "/etc/pf.conf"
    public static let pfAnchorPath = "/etc/pf.anchors/com.monkmode"

    public static let enforcerInstallPath = "/usr/local/bin/monkmode-enforcer"
    public static let enforcerDaemonPlistPath = "/Library/LaunchDaemons/com.monkmode.enforcer.plist"
    public static let cleanupDaemonPlistPath = "/Library/LaunchDaemons/com.monkmode.cleanup.plist"

    public static let configFilePath = "\(supportDir)/config.json"
    public static let ipCachePath = "\(supportDir)/ip_cache.json"
    public static let hostsBackupPath = "\(supportDir)/hosts.backup"
    public static let stateFilePath = "\(supportDir)/enforcer_state.json"
    public static let enforcerLogPath = "\(supportDir)/enforcer.log"
    public static let installLogPath = "\(supportDir)/install.log"
}
