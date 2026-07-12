import Foundation

/// Masks personally-identifying cellular fields (IMEI, ICCID, IMSI, phone
/// number) for display. Masked by default — a user's own device is theirs to
/// see, but a public app shouldn't put a bystander-visible IMEI on screen by
/// default (e.g. screen sharing, screenshots, presentations).
enum SensitiveDataMasking {
    private static let visibleSuffixLength = 4
    private static let mask = "••••"

    /// Returns `value` unchanged, or masked down to its last 4 characters
    /// (e.g. `"359123456789012"` → `"••••9012"`) if shorter values are fully masked.
    static func apply(_ value: String, revealed: Bool) -> String {
        guard !revealed else { return value }
        guard value.count > visibleSuffixLength else {
            return String(repeating: "•", count: value.count)
        }
        return mask + value.suffix(visibleSuffixLength)
    }
}
