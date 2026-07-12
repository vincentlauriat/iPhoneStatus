import Foundation

/// Polls for a connected iPhone and publishes its status as a `DeviceConnectionState`
/// stream. Presence (`idevice_id -l`) is polled continuously and cheaply; the full
/// detail fetch (`ideviceinfo`/`idevicediagnostics`, slower) only runs while the
/// popover is open, on new-device detection, or while not yet connected.
actor DeviceMonitor {
    private let service = LibimobiledeviceService()
    private var presencePollTask: Task<Void, Never>?
    private var detailPollTask: Task<Void, Never>?
    private(set) var state: DeviceConnectionState = .disconnected
    private var stateContinuations: [UUID: AsyncStream<DeviceConnectionState>.Continuation] = [:]
    private var currentUDID: String?
    private var isPopoverOpen = false

    /// Starts the presence-polling loop (idempotent). Call once, typically at app launch.
    func start() {
        guard presencePollTask == nil else { return }
        presencePollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollPresence()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    /// A fresh `AsyncStream` per subscriber, replaying the current state immediately
    /// and yielding every subsequent change. Multiple subscribers are supported.
    var stateStream: AsyncStream<DeviceConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            stateContinuations[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    /// Call when the popover opens: triggers an immediate detail refresh and starts
    /// the slower detail-polling loop for as long as it stays open.
    func popoverDidOpen() {
        isPopoverOpen = true
        if let udid = currentUDID {
            Task { await self.refreshDetails(udid: udid) }
        }
        startDetailPollingIfNeeded()
    }

    /// Call when the popover closes: stops detail polling (presence polling continues).
    func popoverDidClose() {
        isPopoverOpen = false
        detailPollTask?.cancel()
        detailPollTask = nil
    }

    private func removeContinuation(id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }

    private func update(_ newState: DeviceConnectionState) {
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }

    private func pollPresence() async {
        guard LibimobiledeviceBinaryLocator.isInstalled else {
            currentUDID = nil
            update(.binariesNotFound)
            return
        }
        let udids = await service.listConnectedUDIDs()
        guard let udid = udids.first else {
            currentUDID = nil
            update(.disconnected)
            return
        }
        let isNewDevice = udid != currentUDID
        currentUDID = udid
        // Keep retrying on every presence tick until connected — not just on a new
        // UDID — so the app notices as soon as "Trust This Computer" is accepted,
        // without requiring the popover to be reopened.
        if isNewDevice || !isConnected(state) {
            await refreshDetails(udid: udid)
            startDetailPollingIfNeeded()
        }
    }

    private func isConnected(_ state: DeviceConnectionState) -> Bool {
        if case .connected = state { return true }
        return false
    }

    private func startDetailPollingIfNeeded() {
        guard isPopoverOpen, detailPollTask == nil, currentUDID != nil else { return }
        detailPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, let udid = await self.currentUDID else { break }
                await self.refreshDetails(udid: udid)
            }
        }
    }

    private func refreshDetails(udid: String) async {
        let newState = await service.fetchStatus(udid: udid)
        update(newState)
    }
}
