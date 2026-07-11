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

    var usedDiskCapacity: Int64? {
        guard let total = totalDiskCapacity, let available = totalDataAvailable else { return nil }
        return total - available
    }

    static func combining(
        udid: String,
        connectionType: ConnectionType,
        global: DeviceGlobalInfo,
        battery: DeviceBatteryInfo?,
        disk: DeviceDiskUsageInfo?
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
            totalDataAvailable: disk?.totalDataAvailable
        )
    }
}
