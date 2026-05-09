import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let codexBundleIdentifier = "com.openai.codex"
    private let enabledPath = NSString(string: "~/.codex/notifications/alerts_enabled").expandingTildeInPath

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ensureEnabledFile()
        observeWorkspaceChanges()
        updateVisibility()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func observeWorkspaceChanges() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceApplicationChanged(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceApplicationChanged(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func ensureEnabledFile() {
        let manager = FileManager.default
        let directory = (enabledPath as NSString).deletingLastPathComponent
        try? manager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        if !manager.fileExists(atPath: enabledPath) {
            try? "1\n".write(toFile: enabledPath, atomically: true, encoding: .utf8)
        }
    }

    private func codexIsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == codexBundleIdentifier
        }
    }

    private func alertsEnabled() -> Bool {
        guard let value = try? String(contentsOfFile: enabledPath, encoding: .utf8) else {
            return true
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines) != "0"
    }

    private func setAlertsEnabled(_ enabled: Bool) {
        try? (enabled ? "1\n" : "0\n").write(toFile: enabledPath, atomically: true, encoding: .utf8)
        refreshStatusItem()
    }

    private func updateVisibility() {
        if codexIsRunning() {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                statusItem?.button?.target = self
                statusItem?.button?.action = #selector(toggleFromButton)
                statusItem?.button?.toolTip = "Codex alerts"
            }
            refreshStatusItem()
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func refreshStatusItem() {
        guard let item = statusItem else { return }
        let enabled = alertsEnabled()
        item.button?.title = enabled ? "Codex Alerts: On" : "Codex Alerts: Off"
    }

    @objc private func toggleFromButton() {
        setAlertsEnabled(!alertsEnabled())
    }

    @objc private func workspaceApplicationChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == codexBundleIdentifier else {
            return
        }
        updateVisibility()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
