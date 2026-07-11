import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: DeviceStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            content

            Spacer(minLength: 0)

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
        .frame(width: 680)
        .fixedSize(horizontal: false, vertical: true)
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    BatteryCardContent(info: info)
                    StorageCardContent(info: info)
                }
                .frame(width: 318)
                VStack(alignment: .leading, spacing: 12) {
                    DeviceCardContent(info: info)
                    if info.hasCellularInfo {
                        CellularCardContent(info: info)
                    }
                }
                .frame(width: 318)
            }
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

private struct BatteryCardContent: View {
    let info: iPhoneStatusInfo

    private var isCharging: Bool { info.isCharging ?? false }

    var body: some View {
        MetricCard(title: "Batterie", systemImage: isCharging ? "battery.100.bolt" : batterySymbol) {
            VStack(alignment: .leading, spacing: 10) {
                if let level = info.batteryLevel {
                    HStack {
                        Text("\(level)%")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        if info.isFullyCharged == true {
                            Text("Chargée")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        Text(isCharging ? "En charge" : "Sur batterie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(level), total: 100)
                        .tint(isCharging ? .green : .accentColor)
                }

                if info.isAtCriticalBatteryLevel == true {
                    StatusDotRow(label: "Niveau critique", value: "⚠️", color: .red)
                }
                if let health = info.batteryHealthPercent {
                    StatusDotRow(label: "Santé de la batterie", value: "\(health)%", color: healthColor(health))
                }
                if let cycles = info.cycleCount {
                    InfoRow(label: "Cycles de charge", value: "\(cycles) (repère Apple : 1000)")
                }
                if let minutes = info.avgTimeToEmptyMinutes, minutes > 0, !isCharging {
                    InfoRow(label: "Autonomie restante estimée", value: formatMinutes(minutes))
                }
                if isCharging, let watts = info.chargerWattage, watts > 0 {
                    let description = info.chargerDescription.map { " (\($0))" } ?? ""
                    InfoRow(label: "Puissance du chargeur", value: "\(watts) W\(description)")
                }
                if let voltage = info.voltageVolts {
                    InfoRow(label: "Tension", value: String(format: "%.2f V", voltage))
                }
                if let amperage = info.amperageMilliAmps {
                    InfoRow(label: "Courant", value: "\(amperage) mA")
                }
                if let designCapacity = info.designCapacityMah {
                    InfoRow(label: "Capacité de conception", value: "\(designCapacity) mAh")
                }
                if let nominalCapacity = info.nominalChargeCapacityMah {
                    InfoRow(label: "Capacité nominale", value: "\(nominalCapacity) mAh")
                }
                if let fullChargeCapacity = info.fullChargeCapacityMah {
                    InfoRow(label: "Capacité à pleine charge", value: "\(fullChargeCapacity) mAh")
                }
                if let serial = info.batterySerial {
                    InfoRow(label: "N° de série batterie", value: serial)
                }
                if let cellID = info.batteryCellID {
                    InfoRow(label: "ID cellule", value: cellID)
                }
            }
        }
    }

    private var batterySymbol: String {
        guard let level = info.batteryLevel else { return "battery.0" }
        switch level {
        case ..<15: return "battery.0"
        case ..<40: return "battery.25"
        case ..<65: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    private func healthColor(_ percent: Int) -> Color {
        switch percent {
        case 90...: .green
        case 80..<90: .yellow
        case 70..<80: .orange
        default: .red
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 {
            return "\(hours) h \(remainder) min"
        }
        return "\(remainder) min"
    }
}

private struct StorageCardContent: View {
    let info: iPhoneStatusInfo

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        if let total = info.totalDiskCapacity, let used = info.usedDiskCapacity, total > 0 {
            MetricCard(title: "Stockage", systemImage: "internaldrive") {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(used), total: Double(total))
                        .tint(.indigo)
                    Text("\(Self.byteFormatter.string(fromByteCount: used)) utilisés sur \(Self.byteFormatter.string(fromByteCount: total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let dataCapacity = info.totalDataCapacity {
                        InfoRow(label: "Capacité partition data", value: Self.byteFormatter.string(fromByteCount: dataCapacity))
                    }
                    if let systemCapacity = info.totalSystemCapacity {
                        InfoRow(label: "Capacité partition système", value: Self.byteFormatter.string(fromByteCount: systemCapacity))
                    }
                }
            }
        }
    }
}

private struct DeviceCardContent: View {
    let info: iPhoneStatusInfo

    var body: some View {
        MetricCard(title: info.deviceName, systemImage: "iphone") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Modèle", value: info.productType)
                if let hardwareModel = info.hardwareModel {
                    InfoRow(label: "Modèle interne", value: hardwareModel)
                }
                if let modelNumber = info.modelNumber {
                    InfoRow(label: "Référence", value: modelNumber)
                }
                if let cpuArchitecture = info.cpuArchitecture {
                    InfoRow(label: "Architecture CPU", value: cpuArchitecture)
                }
                HStack(spacing: 4) {
                    Text("iOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if info.isBetaRelease {
                        Text("Beta")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    Text(info.humanReadableProductVersion.map { "\($0) (\(info.buildVersion))" } ?? "\(info.productVersion) (\(info.buildVersion))")
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                InfoRow(label: "N° de série", value: info.serialNumber)
                if let activationState = info.activationState {
                    InfoRow(label: "Activation", value: activationState)
                }
                if let timeZone = info.timeZone {
                    InfoRow(label: "Fuseau horaire", value: timeZone)
                }
                if let width = info.screenWidth, let height = info.screenHeight {
                    let scale = info.screenScaleFactor.map { "@\(Int($0))x" } ?? ""
                    InfoRow(label: "Résolution écran", value: "\(width)×\(height)\(scale)")
                }
                InfoRow(label: "Connexion", value: info.connectionType == .usb ? "USB" : "Wi-Fi")
                if let wifi = info.wiFiAddress {
                    InfoRow(label: "Adresse Wi-Fi", value: wifi)
                }
                if let bluetooth = info.bluetoothAddress {
                    InfoRow(label: "Adresse Bluetooth", value: bluetooth)
                }
                if let cloudBackupEnabled = info.cloudBackupEnabled {
                    let encryption = info.backupWillEncrypt == true ? ", chiffrée" : ""
                    InfoRow(label: "Sauvegarde iCloud", value: cloudBackupEnabled ? "Activée\(encryption)" : "Désactivée")
                }
            }
        }
    }
}

private struct CellularCardContent: View {
    let info: iPhoneStatusInfo

    var body: some View {
        MetricCard(title: "Cellulaire", systemImage: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 8) {
                if let carrierName = info.carrierName {
                    InfoRow(label: "Opérateur", value: carrierName)
                }
                if let simStatus = info.simStatus {
                    InfoRow(label: "Statut SIM", value: simStatus)
                }
                if let simIsEmbedded = info.simIsEmbedded {
                    InfoRow(label: "Type de SIM", value: simIsEmbedded ? "eSIM" : "SIM physique")
                }
                if let imei = info.imei {
                    InfoRow(label: "IMEI", value: imei)
                }
                if let imei2 = info.imei2 {
                    InfoRow(label: "IMEI 2", value: imei2)
                }
                if let iccid = info.iccid {
                    InfoRow(label: "ICCID", value: iccid)
                }
                if let imsi = info.imsi {
                    InfoRow(label: "IMSI", value: imsi)
                }
                if let phoneNumber = info.phoneNumber {
                    InfoRow(label: "Numéro de téléphone", value: phoneNumber)
                }
            }
        }
    }
}
