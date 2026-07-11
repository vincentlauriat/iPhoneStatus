import Foundation

enum TrustIssue: Equatable {
    case pendingConfirmation
    case denied
    case passwordProtected
}

enum DeviceConnectionState: Equatable {
    case binariesNotFound
    case disconnected
    case needsTrust(TrustIssue)
    case connected(iPhoneStatusInfo)
}

enum StderrClassifier {
    static func classify(_ stderr: String) -> TrustIssue {
        let message = stderr.lowercased()
        if message.contains("denied") {
            return .denied
        }
        if message.contains("password") {
            return .passwordProtected
        }
        // Couvre "pairing dialog response pending", "trust", "missing pair record",
        // "invalid hostid" et tout message non reconnu — même traitement UX :
        // l'utilisateur doit valider "Faire confiance" sur l'écran de l'iPhone.
        return .pendingConfirmation
    }
}
