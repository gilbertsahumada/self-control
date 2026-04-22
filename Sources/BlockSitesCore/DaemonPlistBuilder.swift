import Foundation

/// Builds LaunchDaemon plist XML documents used by the MonkMode app.
///
/// The outputs are pure strings derived from `MonkModeConstants` and (for the
/// cleanup daemon) a supplied end-time. Keeping the generation here — rather than
/// inside `BlockViewModel` — means it is reachable from the test target, and the
/// shape of the plists is pinned down by unit tests.
public enum DaemonPlistBuilder {

    /// Plist for the primary enforcer daemon. Runs every 60 seconds and re-asserts
    /// blocking state. `RunAtLoad` is true so the first run kicks in immediately.
    public static func buildEnforcerDaemonPlist() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(MonkModeConstants.enforcerDaemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(MonkModeConstants.enforcerInstallPath)</string>
            </array>
            <key>StartInterval</key>
            <integer>60</integer>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(MonkModeConstants.enforcerLogPath)</string>
            <key>StandardErrorPath</key>
            <string>\(MonkModeConstants.enforcerLogPath)</string>
        </dict>
        </plist>
        """
    }

    /// One-shot cleanup daemon that fires at `endTime` via `StartCalendarInterval`.
    /// `RunAtLoad` is deliberately false so loading the plist during install does
    /// not trigger an immediate cleanup.
    public static func buildCleanupDaemonPlist(endTime: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: endTime)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(MonkModeConstants.cleanupDaemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(MonkModeConstants.enforcerInstallPath)</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Month</key>
                <integer>\(month)</integer>
                <key>Day</key>
                <integer>\(day)</integer>
                <key>Hour</key>
                <integer>\(hour)</integer>
                <key>Minute</key>
                <integer>\(minute)</integer>
            </dict>
            <key>RunAtLoad</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(MonkModeConstants.enforcerLogPath)</string>
            <key>StandardErrorPath</key>
            <string>\(MonkModeConstants.enforcerLogPath)</string>
        </dict>
        </plist>
        """
    }
}
