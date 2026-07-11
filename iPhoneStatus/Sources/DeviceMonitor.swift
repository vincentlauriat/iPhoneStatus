import Foundation

actor DeviceMonitor {
    private let service = LibimobiledeviceService()
    private var presencePollTask: Task<Void, Never>?
    private var detailPollTask: Task<Void, Never>?
    private(set) var state: DeviceConnectionState = .disconnected
    private var stateContinuations: [UUID: AsyncStream<DeviceConnectionState>.Continuation] = [:]
    private var currentUDID: String?
    private var isPopoverOpen = false

    func start() {
        guard presencePollTask == nil else { return }
        presencePollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollPresence()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

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

    func popoverDidOpen() {
        isPopoverOpen = true
        if let udid = currentUDID {
            Task { await self.refreshDetails(udid: udid) }
        }
        startDetailPollingIfNeeded()
    }

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
        if udid != currentUDID {
            currentUDID = udid
            await refreshDetails(udid: udid)
            startDetailPollingIfNeeded()
        }
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
