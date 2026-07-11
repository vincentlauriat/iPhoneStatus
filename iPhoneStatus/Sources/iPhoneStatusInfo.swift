import Foundation

enum ConnectionType: String, Equatable {
    case usb
    case wifi
}

struct DeviceGlobalInfo: Decodable {
    let deviceName: String?
    let productType: String?
    let productVersion: String?
    let buildVersion: String?
    let serialNumber: String?
    let wiFiAddress: String?
    let bluetoothAddress: String?
    let passwordProtected: Bool?

    enum CodingKeys: String, CodingKey {
        case deviceName = "DeviceName"
        case productType = "ProductType"
        case productVersion = "ProductVersion"
        case buildVersion = "BuildVersion"
        case serialNumber = "SerialNumber"
        case wiFiAddress = "WiFiAddress"
        case bluetoothAddress = "BluetoothAddress"
        case passwordProtected = "PasswordProtected"
    }
}

struct DeviceBatteryInfo: Decodable {
    let currentCapacity: Int?
    let isCharging: Bool?

    enum CodingKeys: String, CodingKey {
        case currentCapacity = "BatteryCurrentCapacity"
        case isCharging = "BatteryIsCharging"
    }
}

struct DeviceDiskUsageInfo: Decodable {
    let totalDiskCapacity: Int64?
    let totalDataAvailable: Int64?

    enum CodingKeys: String, CodingKey {
        case totalDiskCapacity = "TotalDiskCapacity"
        case totalDataAvailable = "TotalDataAvailable"
    }
}

/// Parses `idevicediagnostics ioregentry AppleSmartBattery` — a richer, best-effort
/// source than the `com.apple.mobile.battery` lockdown domain (cycle count, detailed
/// capacities, charger info, cell identifier). Values cross-checked against a real
/// device against a third-party report (see PLAN.md) to confirm field meaning.
struct BatterySmartInfo: Decodable {
    let ioRegistry: BatterySmartRegistry

    enum CodingKeys: String, CodingKey {
        case ioRegistry = "IORegistry"
    }
}

struct BatterySmartRegistry: Decodable {
    let cycleCount: Int?
    let voltage: Int?
    let amperage: Int?
    let isCharging: Bool?
    let serial: String?
    let manufacturerData: Data?
    let batteryData: BatteryCapacityDetail?
    let adapterDetails: AdapterDetail?

    enum CodingKeys: String, CodingKey {
        case cycleCount = "CycleCount"
        case voltage = "Voltage"
        case amperage = "Amperage"
        case isCharging = "IsCharging"
        case serial = "Serial"
        case manufacturerData = "ManufacturerData"
        case batteryData = "BatteryData"
        case adapterDetails = "AdapterDetails"
    }

    var cellID: String? {
        guard let manufacturerData else { return nil }
        let text = String(data: manufacturerData, encoding: .utf8) ?? ""
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BatteryCapacityDetail: Decodable {
    let designCapacity: Int?
    let nominalChargeCapacity: Int?
    let fullChargeCapacity: Int?

    enum CodingKeys: String, CodingKey {
        case designCapacity = "DesignCapacity"
        case nominalChargeCapacity = "NominalChargeCapacity"
        case fullChargeCapacity = "FullChargeCapacity"
    }

    /// Matches the "Battery Health" percentage shown in iOS Settings
    /// (round(NominalChargeCapacity / DesignCapacity * 100)), not a Juicy-style
    /// "raw" ratio — verified against a real device's Settings value.
    var healthPercent: Int? {
        guard let nominal = nominalChargeCapacity, let design = designCapacity, design > 0 else { return nil }
        return Int((Double(nominal) / Double(design) * 100).rounded())
    }
}

struct AdapterDetail: Decodable {
    let watts: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case watts = "Watts"
        case description = "Description"
    }
}

struct iPhoneStatusInfo: Equatable {
    let udid: String
    let connectionType: ConnectionType
    let deviceName: String
    let productType: String
    let productVersion: String
    let buildVersion: String
    let serialNumber: String
    let wiFiAddress: String?
    let bluetoothAddress: String?
    let passwordProtected: Bool
    let batteryLevel: Int?
    let isCharging: Bool?
    let totalDiskCapacity: Int64?
    let totalDataAvailable: Int64?

    // Best-effort enrichment from `idevicediagnostics ioregentry AppleSmartBattery`.
    // All nil when unavailable (older iOS, different chip family, call failed) — the
    // UI must degrade gracefully rather than assume these are always present.
    let cycleCount: Int?
    let batteryHealthPercent: Int?
    let designCapacityMah: Int?
    let fullChargeCapacityMah: Int?
    let voltageVolts: Double?
    let amperageMilliAmps: Int?
    let chargerWattage: Int?
    let chargerDescription: String?
    let batterySerial: String?
    let batteryCellID: String?

    var usedDiskCapacity: Int64? {
        guard let total = totalDiskCapacity, let available = totalDataAvailable else { return nil }
        return total - available
    }

    static func combining(
        udid: String,
        connectionType: ConnectionType,
        global: DeviceGlobalInfo,
        battery: DeviceBatteryInfo?,
        disk: DeviceDiskUsageInfo?,
        smartBattery: BatterySmartRegistry? = nil
    ) -> iPhoneStatusInfo {
        iPhoneStatusInfo(
            udid: udid,
            connectionType: connectionType,
            deviceName: global.deviceName ?? "iPhone",
            productType: global.productType ?? "—",
            productVersion: global.productVersion ?? "—",
            buildVersion: global.buildVersion ?? "—",
            serialNumber: global.serialNumber ?? "—",
            wiFiAddress: global.wiFiAddress,
            bluetoothAddress: global.bluetoothAddress,
            passwordProtected: global.passwordProtected ?? false,
            batteryLevel: battery?.currentCapacity,
            isCharging: battery?.isCharging,
            totalDiskCapacity: disk?.totalDiskCapacity,
            totalDataAvailable: disk?.totalDataAvailable,
            cycleCount: smartBattery?.cycleCount,
            batteryHealthPercent: smartBattery?.batteryData?.healthPercent,
            designCapacityMah: smartBattery?.batteryData?.designCapacity,
            fullChargeCapacityMah: smartBattery?.batteryData?.fullChargeCapacity,
            voltageVolts: smartBattery?.voltage.map { Double($0) / 1000 },
            amperageMilliAmps: smartBattery?.amperage,
            chargerWattage: smartBattery?.adapterDetails?.watts,
            chargerDescription: smartBattery?.adapterDetails?.description,
            batterySerial: smartBattery?.serial,
            batteryCellID: smartBattery?.cellID
        )
    }
}
