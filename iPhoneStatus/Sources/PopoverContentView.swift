import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: DeviceStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quitter iPhoneStatus", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300, height: 420)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.system(size: 18))
            Text("iPhoneStatus")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .binariesNotFound:
            StatusMessageView(
                symbol: "exclamationmark.triangle",
                title: "libimobiledevice n'est pas installé",
                message: "Ouvrez un Terminal et lancez :"
            ) {
                Text("brew install libimobiledevice")
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

        case .disconnected:
            StatusMessageView(
                symbol: "iphone.slash",
                title: "Aucun iPhone connecté",
                message: "Branchez votre iPhone en USB pour voir son statut."
            )

        case .needsTrust(let issue):
            StatusMessageView(
                symbol: "hand.raised",
                title: trustTitle(for: issue),
                message: trustMessage(for: issue)
            )

        case .connected(let info):
            DeviceDetailView(info: info)
        }
    }

    private func trustTitle(for issue: TrustIssue) -> String {
        switch issue {
        case .pendingConfirmation: "En attente de confiance"
        case .denied: "Confiance refusée"
        case .passwordProtected: "iPhone verrouillé"
        }
    }

    private func trustMessage(for issue: TrustIssue) -> String {
        switch issue {
        case .pendingConfirmation:
            "Déverrouillez votre iPhone et appuyez sur \"Faire confiance\" dans la boîte de dialogue."
        case .denied:
            "Débranchez puis rebranchez le câble pour réafficher la boîte de dialogue de confiance."
        case .passwordProtected:
            "Déverrouillez votre iPhone avec son code pour continuer."
        }
    }
}

private struct StatusMessageView<Extra: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var extra: () -> Extra

    init(symbol: String, title: String, message: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.extra = extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.bold())
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            extra()
        }
    }
}

private struct DeviceDetailView: View {
    let info: iPhoneStatusInfo

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(info.deviceName)
                .font(.title3.bold())

            InfoRow(label: "Modèle", value: info.productType)
            InfoRow(label: "iOS", value: "\(info.productVersion) (\(info.buildVersion))")
            InfoRow(label: "N° de série", value: info.serialNumber)
            InfoRow(label: "Connexion", value: info.connectionType == .usb ? "USB" : "Wi-Fi")

            if let batteryLevel = info.batteryLevel {
                HStack {
                    Image(systemName: (info.isCharging ?? false) ? "battery.100.bolt" : batterySymbol(for: batteryLevel))
                        .foregroundStyle(batteryLevel < 20 ? .red : .primary)
                    Text("\(batteryLevel)%")
                    if info.isCharging ?? false {
                        Text("(en charge)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }

            if let total = info.totalDiskCapacity, let used = info.usedDiskCapacity, total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(used), total: Double(total))
                    Text("\(Self.byteFormatter.string(fromByteCount: used)) utilisés sur \(Self.byteFormatter.string(fromByteCount: total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
    }

    private func batterySymbol(for level: Int) -> String {
        switch level {
        case ..<15: "battery.0"
        case ..<40: "battery.25"
        case ..<65: "battery.50"
        case ..<90: "battery.75"
        default: "battery.100"
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
