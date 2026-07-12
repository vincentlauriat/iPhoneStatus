import AppKit
import SwiftUI

/// Bridges `DeviceMonitor`'s async state stream to SwiftUI's observation system.
@MainActor
final class DeviceStatusViewModel: ObservableObject {
    @Published var state: DeviceConnectionState = .disconnected
}

/// Owns the menu bar icon (`NSStatusItem`) and its popover. Colors the icon per
/// `DeviceConnectionState` and forwards popover open/close events to `DeviceMonitor`
/// so detail polling only runs while the user is actually looking.
@MainActor
final class StatusMenuController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var popover: NSPopover?
    private let monitor = DeviceMonitor()
    private let viewModel = DeviceStatusViewModel()
    private var monitorTask: Task<Void, Never>?

    func setup() {
        let button = statusItem.button!
        button.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "iPhoneStatus")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self

        let popover = NSPopover()
        popover.behavior = .transient
        let hostingController = NSHostingController(rootView: PopoverContentView(viewModel: viewModel))
        // Lets the popover track the SwiftUI content's natural height as cards
        // change (e.g. the conditional Cellular card) instead of a fixed size.
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        self.popover = popover

        Task { await monitor.start() }
        monitorTask = Task {
            for await state in await monitor.stateStream {
                viewModel.state = state
                updateIcon(for: state)
            }
        }
    }

    private func updateIcon(for state: DeviceConnectionState) {
        guard let button = statusItem.button else { return }
        let color: NSColor
        switch state {
        case .connected: color = .systemGreen
        case .needsTrust: color = .systemOrange
        case .binariesNotFound: color = .systemRed
        case .disconnected: color = .secondaryLabelColor
        }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            .applying(.init(paletteColors: [color]))
        button.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "iPhoneStatus")?
            .withSymbolConfiguration(config)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
            Task { await monitor.popoverDidClose() }
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { await monitor.popoverDidOpen() }
        }
    }
}
