import Foundation

/// Finds the Homebrew-installed libimobiledevice CLI binaries. iPhoneStatus does not
/// bundle them — the user installs `libimobiledevice` themselves (`brew install`),
/// covering both Apple Silicon (`/opt/homebrew/bin`) and Intel (`/usr/local/bin`) prefixes.
enum LibimobiledeviceBinaryLocator {
    private static let searchDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    /// Absolute path to `executable` if found in a known Homebrew prefix, else `nil`.
    static func path(for executable: String) -> String? {
        for directory in searchDirectories {
            let candidate = directory + "/" + executable
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// `true` when all three CLI tools iPhoneStatus depends on are present.
    static var isInstalled: Bool {
        path(for: "idevice_id") != nil && path(for: "ideviceinfo") != nil && path(for: "idevicediagnostics") != nil
    }
}
