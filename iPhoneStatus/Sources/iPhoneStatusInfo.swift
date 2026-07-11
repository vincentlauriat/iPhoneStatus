import Foundation

enum ConnectionType: String, Equatable {
    case usb
    case wifi
}

struct CarrierBundleInfo: Decodable {
    let cfBundleIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case cfBundleIdentifier = "CFBundleIdentifier"
    }
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

    // Hardware
    let hardwareModel: String?
    let modelNumber: String?
    let cpuArchitecture: String?

    // System
    let humanReadableProductVersion: String?
    let releaseType: String?
    let activationState: String?
    let timeZone: String?

    // Cellular — displayed as-is per explicit user choice, see PLAN.md
    let telephonyCapability: Bool?
    let sim1IsEmbedded: Bool?
    let simStatus: String?
    let imei: String?
    let imei2: String?
    let iccid: String?
    let imsi: String?
    let phoneNumber: String?
    let carrierBundleInfoArray: [CarrierBundleInfo]?

    // Default values on the new fields keep the synthesized memberwise initializer
    // source-compatible with call sites (tests) written before these fields existed.
    init(
        deviceName: String?, productType: String?, productVersion: String?, buildVersion: String?,
        serialNumber: String?, wiFiAddress: String?, bluetoothAddress: String?, passwordProtected: Bool?,
        hardwareModel: String? = nil, modelNumber: String? = nil, cpuArchitecture: String? = nil,
        humanReadableProductVersion: String? = nil, releaseType: String? = nil,
        activationState: String? = nil, timeZone: String? = nil,
        telephonyCapability: Bool? = nil, sim1IsEmbedded: Bool? = nil, simStatus: String? = nil,
        imei: String? = nil, imei2: String? = nil, iccid: String? = nil, imsi: String? = nil,
        phoneNumber: String? = nil, carrierBundleInfoArray: [CarrierBundleInfo]? = nil
    ) {
        self.deviceName = deviceName
        self.productType = productType
        self.productVersion = productVersion
        self.buildVersion = buildVersion
        self.serialNumber = serialNumber
        self.wiFiAddress = wiFiAddress
        self.bluetoothAddress = bluetoothAddress
        self.passwordProtected = passwordProtected
        self.hardwareModel = hardwareModel
        self.modelNumber = modelNumber
        self.cpuArchitecture = cpuArchitecture
        self.humanReadableProductVersion = humanReadableProductVersion
        self.releaseType = releaseType
        self.activationState = activationState
        self.timeZone = timeZone
        self.telephonyCapability = telephonyCapability
        self.sim1IsEmbedded = sim1IsEmbedded
        self.simStatus = simStatus
        self.imei = imei
        self.imei2 = imei2
        self.iccid = iccid
        self.imsi = imsi
        self.phoneNumber = phoneNumber
        self.carrierBundleInfoArray = carrierBundleInfoArray
    }

    enum CodingKeys: String, CodingKey {
        case deviceName = "DeviceName"
        case productType = "ProductType"
        case productVersion = "ProductVersion"
        case buildVersion = "BuildVersion"
        case serialNumber = "SerialNumber"
        case wiFiAddress = "WiFiAddress"
        case bluetoothAddress = "BluetoothAddress"
        case passwordProtected = "PasswordProtected"
        case hardwareModel = "HardwareModel"
        case modelNumber = "ModelNumber"
        case cpuArchitecture = "CPUArchitecture"
        case humanReadableProductVersion = "HumanReadableProductVersionString"
        case releaseType = "ReleaseType"
        case activationState = "ActivationState"
        case timeZone = "TimeZone"
        case telephonyCapability = "TelephonyCapability"
        case sim1IsEmbedded = "SIM1IsEmbedded"
        case simStatus = "SIMStatus"
        case imei = "InternationalMobileEquipmentIdentity"
        case imei2 = "InternationalMobileEquipmentIdentity2"
        case iccid = "IntegratedCircuitCardIdentity"
        case imsi = "InternationalMobileSubscriberIdentity"
        case phoneNumber = "PhoneNumber"
        case carrierBundleInfoArray = "CarrierBundleInfoArray"
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
    let totalDataCapacity: Int64?
    let totalSystemCapacity: Int64?

    enum CodingKeys: String, CodingKey {
        case totalDiskCapacity = "TotalDiskCapacity"
        case totalDataAvailable = "TotalDataAvailable"
        case totalDataCapacity = "TotalDataCapacity"
        case totalSystemCapacity = "TotalSystemCapacity"
    }
}

/// `com.apple.mobile.backup` domain — iCloud backup status.
struct DeviceBackupInfo: Decodable {
    let cloudBackupEnabled: Bool?
    let willEncrypt: Bool?

    enum CodingKeys: String, CodingKey {
        case cloudBackupEnabled = "CloudBackupEnabled"
        case willEncrypt = "WillEncrypt"
    }
}

/// `com.apple.mobile.iTunes` domain — only the screen fields are decoded; the rest of
/// this ~2400-line domain is FairPlay certificate blobs, silently ignored by decoding
/// into this narrow struct.
struct DeviceScreenInfo: Decodable {
    let screenWidth: Int?
    let screenHeight: Int?
    let screenScaleFactor: Double?

    enum CodingKeys: String, CodingKey {
        case screenWidth = "ScreenWidth"
        case screenHeight = "ScreenHeight"
        case screenScaleFactor = "ScreenScaleFactor"
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
    let avgTimeToEmpty: Int?
    let fullyCharged: Bool?
    let atCriticalLevel: Bool?

    enum CodingKeys: String, CodingKey {
        case cycleCount = "CycleCount"
        case voltage = "Voltage"
        case amperage = "Amperage"
        case isCharging = "IsCharging"
        case serial = "Serial"
        case manufacturerData = "ManufacturerData"
        case batteryData = "BatteryData"
        case adapterDetails = "AdapterDetails"
        case avgTimeToEmpty = "AvgTimeToEmpty"
        case fullyCharged = "FullyCharged"
        case atCriticalLevel = "AtCriticalLevel"
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
    let totalDataCapacity: Int64?
    let totalSystemCapacity: Int64?

    // Best-effort enrichment from `idevicediagnostics ioregentry AppleSmartBattery`.
    // All nil when unavailable (older iOS, different chip family, call failed) — the
    // UI must degrade gracefully rather than assume these are always present.
    let cycleCount: Int?
    let batteryHealthPercent: Int?
    let designCapacityMah: Int?
    let nominalChargeCapacityMah: Int?
    let fullChargeCapacityMah: Int?
    let voltageVolts: Double?
    let amperageMilliAmps: Int?
    let chargerWattage: Int?
    let chargerDescription: String?
    let batterySerial: String?
    let batteryCellID: String?
    let avgTimeToEmptyMinutes: Int?
    let isFullyCharged: Bool?
    let isAtCriticalBatteryLevel: Bool?

    // Hardware / system — from the already-fetched global dump, no extra process call.
    let hardwareModel: String?
    let modelNumber: String?
    let cpuArchitecture: String?
    let humanReadableProductVersion: String?
    let isBetaRelease: Bool
    let activationState: String?
    let timeZone: String?

    // Cellular — displayed as-is per explicit user choice, see PLAN.md.
    let telephonyCapability: Bool?
    let simIsEmbedded: Bool?
    let simStatus: String?
    let imei: String?
    let imei2: String?
    let iccid: String?
    let imsi: String?
    let phoneNumber: String?
    let carrierName: String?

    // Best-effort enrichment from optional domain calls.
    let cloudBackupEnabled: Bool?
    let backupWillEncrypt: Bool?
    let screenWidth: Int?
    let screenHeight: Int?
    let screenScaleFactor: Double?

    var usedDiskCapacity: Int64? {
        guard let total = totalDiskCapacity, let available = totalDataAvailable else { return nil }
        return total - available
    }

    var hasCellularInfo: Bool {
        telephonyCapability == true || imei != nil || iccid != nil || carrierName != nil
    }

    static func combining(
        udid: String,
        connectionType: ConnectionType,
        global: DeviceGlobalInfo,
        battery: DeviceBatteryInfo?,
        disk: DeviceDiskUsageInfo?,
        smartBattery: BatterySmartRegistry? = nil,
        backup: DeviceBackupInfo? = nil,
        screen: DeviceScreenInfo? = nil
    ) -> iPhoneStatusInfo {
        let carrierName = global.carrierBundleInfoArray?.first?.cfBundleIdentifier.flatMap { identifier -> String? in
            guard let last = identifier.split(separator: ".").last else { return nil }
            return last.replacingOccurrences(of: "_", with: " ")
        }

        return iPhoneStatusInfo(
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
            totalDataCapacity: disk?.totalDataCapacity,
            totalSystemCapacity: disk?.totalSystemCapacity,
            cycleCount: smartBattery?.cycleCount,
            batteryHealthPercent: smartBattery?.batteryData?.healthPercent,
            designCapacityMah: smartBattery?.batteryData?.designCapacity,
            nominalChargeCapacityMah: smartBattery?.batteryData?.nominalChargeCapacity,
            fullChargeCapacityMah: smartBattery?.batteryData?.fullChargeCapacity,
            voltageVolts: smartBattery?.voltage.map { Double($0) / 1000 },
            amperageMilliAmps: smartBattery?.amperage,
            chargerWattage: smartBattery?.adapterDetails?.watts,
            chargerDescription: smartBattery?.adapterDetails?.description,
            batterySerial: smartBattery?.serial,
            batteryCellID: smartBattery?.cellID,
            avgTimeToEmptyMinutes: smartBattery?.avgTimeToEmpty,
            isFullyCharged: smartBattery?.fullyCharged,
            isAtCriticalBatteryLevel: smartBattery?.atCriticalLevel,
            hardwareModel: global.hardwareModel,
            modelNumber: global.modelNumber,
            cpuArchitecture: global.cpuArchitecture,
            humanReadableProductVersion: global.humanReadableProductVersion,
            isBetaRelease: global.releaseType == "Beta",
            activationState: global.activationState,
            timeZone: global.timeZone,
            telephonyCapability: global.telephonyCapability,
            simIsEmbedded: global.sim1IsEmbedded,
            simStatus: global.simStatus,
            imei: global.imei,
            imei2: global.imei2,
            iccid: global.iccid,
            imsi: global.imsi,
            phoneNumber: global.phoneNumber,
            carrierName: carrierName,
            cloudBackupEnabled: backup?.cloudBackupEnabled,
            backupWillEncrypt: backup?.willEncrypt,
            screenWidth: screen?.screenWidth,
            screenHeight: screen?.screenHeight,
            screenScaleFactor: screen?.screenScaleFactor
        )
    }
}
