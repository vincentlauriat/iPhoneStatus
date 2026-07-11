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

            let info = iPhoneStatusInfo.combining(udid: udid, connectionType: .usb, global: global, battery: batteryInfo, disk: diskInfo)
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
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(stdout: stdoutData, stderr: stderrData, exitCode: process.terminationStatus)
    }
}
