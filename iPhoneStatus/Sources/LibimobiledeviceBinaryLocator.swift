import Foundation

enum LibimobiledeviceBinaryLocator {
    private static let searchDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    static func path(for executable: String) -> String? {
        for directory in searchDirectories {
            let candidate = directory + "/" + executable
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static var isInstalled: Bool {
        path(for: "idevice_id") != nil && path(for: "ideviceinfo") != nil
    }
}
