import Foundation

enum LibimobiledeviceBinaryError: Error {
    case notFound
}

private struct ProcessResult {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32
}

struct LibimobiledeviceService: Sendable {
    func listConnectedUDIDs() async -> [String] {
        await Task.detached(priority: .utility) {
            (try? Self.runListConnectedUDIDs()) ?? []
        }.value
    }

    func fetchStatus(udid: String) async -> DeviceConnectionState {
        await Task.detached(priority: .utility) {
            Self.runFetchStatus(udid: udid)
        }.value
    }

    private static func runListConnectedUDIDs() throws -> [String] {
        let result = try run("idevice_id", arguments: ["-l"])
        guard result.exitCode == 0 else { return [] }
        let output = String(data: result.stdout, encoding: .utf8) ?? ""
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func runFetchStatus(udid: String) -> DeviceConnectionState {
        do {
            let globalResult = try run("ideviceinfo", arguments: ["-u", udid, "-x"])
            guard globalResult.exitCode == 0 else {
                let stderrText = String(data: globalResult.stderr, encoding: .utf8) ?? ""
                return .needsTrust(StderrClassifier.classify(stderrText))
            }
            let global = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: globalResult.stdout)

            let batteryResult = try? run("ideviceinfo", arguments: ["-u", udid, "-q", "com.apple.mobile.battery", "-x"])
            let batteryInfo = batteryResult.flatMap { try? PropertyListDecoder().decode(DeviceBatteryInfo.self, from: $0.stdout) }

            let diskResult = try? run("ideviceinfo", arguments: ["-u", udid, "-q", "com.apple.disk_usage", "-x"])
            let diskInfo = diskResult.flatMap { try? PropertyListDecoder().decode(DeviceDiskUsageInfo.self, from: $0.stdout) }

            // Best-effort enrichment (cycle count, health, charger info, cell ID) — not
            // guaranteed to succeed on every device/iOS combination, degrades gracefully.
            let smartBatteryResult = try? run("idevicediagnostics", arguments: ["-u", udid, "ioregentry", "AppleSmartBattery"])
            let smartBattery = smartBatteryResult.flatMap { try? PropertyListDecoder().decode(BatterySmartInfo.self, from: $0.stdout) }?.ioRegistry

            let info = iPhoneStatusInfo.combining(udid: udid, connectionType: .usb, global: global, battery: batteryInfo, disk: diskInfo, smartBattery: smartBattery)
            return .connected(info)
        } catch is LibimobiledeviceBinaryError {
            return .binariesNotFound
        } catch {
            return .needsTrust(.pendingConfirmation)
        }
    }

    private static func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        guard let path = LibimobiledeviceBinaryLocator.path(for: executable) else {
            throw LibimobiledeviceBinaryError.notFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Drain both pipes concurrently BEFORE waiting for exit. A child that writes
        // more than the pipe buffer (64KB on macOS — e.g. ideviceinfo's disk_usage
        // domain, whose NANDInfo blob easily exceeds that) blocks on write() once the
        // buffer fills; calling waitUntilExit() first would then deadlock forever
        // since nothing is draining the pipe to unblock the child.
        let stdoutQueue = DispatchQueue(label: "iPhoneStatus.stdout-drain")
        var stdoutData = Data()
        let stdoutDone = DispatchSemaphore(value: 0)
        stdoutQueue.async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutDone.signal()
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutDone.wait()

        process.waitUntilExit()

        return ProcessResult(stdout: stdoutData, stderr: stderrData, exitCode: process.terminationStatus)
    }
}
