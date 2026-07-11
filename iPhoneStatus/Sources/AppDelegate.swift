import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Accessory apps with no visible window are eligible for macOS's automatic
        // idle termination shortly after launch — this app has no window but must
        // keep running to poll for a connected iPhone in the background.
        ProcessInfo.processInfo.disableAutomaticTermination("Monitoring for a connected iPhone")
        statusMenuController = StatusMenuController()
        statusMenuController?.setup()
    }
}
