import XCTest
@testable import iPhoneStatus

final class PlistParsingTests: XCTestCase {
    private func plistData(_ body: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \(body)
        </dict>
        </plist>
        """
        return Data(xml.utf8)
    }

    func testDecodeGlobalInfo() throws {
        let data = plistData("""
            <key>DeviceName</key>
            <string>iPhone de Vincent</string>
            <key>ProductType</key>
            <string>iPhone15,3</string>
            <key>ProductVersion</key>
            <string>17.5.1</string>
            <key>BuildVersion</key>
            <string>21F90</string>
            <key>SerialNumber</key>
            <string>ABCD1234EFGH</string>
            <key>WiFiAddress</key>
            <string>AA:BB:CC:DD:EE:FF</string>
            <key>BluetoothAddress</key>
            <string>11:22:33:44:55:66</string>
            <key>PasswordProtected</key>
            <true/>
            """)

        let info = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: data)

        XCTAssertEqual(info.deviceName, "iPhone de Vincent")
        XCTAssertEqual(info.productType, "iPhone15,3")
        XCTAssertEqual(info.productVersion, "17.5.1")
        XCTAssertEqual(info.buildVersion, "21F90")
        XCTAssertEqual(info.serialNumber, "ABCD1234EFGH")
        XCTAssertEqual(info.wiFiAddress, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(info.bluetoothAddress, "11:22:33:44:55:66")
        XCTAssertEqual(info.passwordProtected, true)
    }

    func testDecodeGlobalInfoExtendedFields() throws {
        let data = plistData("""
            <key>DeviceName</key>
            <string>iPhone de Vincent</string>
            <key>HardwareModel</key>
            <string>D74AP</string>
            <key>ModelNumber</key>
            <string>MYNJ3</string>
            <key>CPUArchitecture</key>
            <string>arm64e</string>
            <key>HumanReadableProductVersionString</key>
            <string>27.0</string>
            <key>ReleaseType</key>
            <string>Beta</string>
            <key>ActivationState</key>
            <string>Activated</string>
            <key>TimeZone</key>
            <string>Europe/Paris</string>
            <key>TelephonyCapability</key>
            <true/>
            <key>SIM1IsEmbedded</key>
            <true/>
            <key>SIMStatus</key>
            <string>kCTSIMSupportSIMStatusReady</string>
            <key>InternationalMobileEquipmentIdentity</key>
            <string>359123456789012</string>
            <key>InternationalMobileEquipmentIdentity2</key>
            <string>359123456789029</string>
            <key>IntegratedCircuitCardIdentity</key>
            <string>8933010000000000001</string>
            <key>InternationalMobileSubscriberIdentity</key>
            <string>208010000000001</string>
            <key>PhoneNumber</key>
            <string>+33612345678</string>
            <key>CarrierBundleInfoArray</key>
            <array>
                <dict>
                    <key>CFBundleIdentifier</key>
                    <string>com.apple.CARRIER.Orange_France</string>
                </dict>
            </array>
            """)

        let info = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: data)

        XCTAssertEqual(info.hardwareModel, "D74AP")
        XCTAssertEqual(info.modelNumber, "MYNJ3")
        XCTAssertEqual(info.cpuArchitecture, "arm64e")
        XCTAssertEqual(info.humanReadableProductVersion, "27.0")
        XCTAssertEqual(info.releaseType, "Beta")
        XCTAssertEqual(info.activationState, "Activated")
        XCTAssertEqual(info.timeZone, "Europe/Paris")
        XCTAssertEqual(info.telephonyCapability, true)
        XCTAssertEqual(info.sim1IsEmbedded, true)
        XCTAssertEqual(info.simStatus, "kCTSIMSupportSIMStatusReady")
        XCTAssertEqual(info.imei, "359123456789012")
        XCTAssertEqual(info.imei2, "359123456789029")
        XCTAssertEqual(info.iccid, "8933010000000000001")
        XCTAssertEqual(info.imsi, "208010000000001")
        XCTAssertEqual(info.phoneNumber, "+33612345678")
        XCTAssertEqual(info.carrierBundleInfoArray?.first?.cfBundleIdentifier, "com.apple.CARRIER.Orange_France")
    }

    func testDecodeBatteryInfo() throws {
        let data = plistData("""
            <key>BatteryCurrentCapacity</key>
            <integer>82</integer>
            <key>BatteryIsCharging</key>
            <true/>
            """)

        let battery = try PropertyListDecoder().decode(DeviceBatteryInfo.self, from: data)

        XCTAssertEqual(battery.currentCapacity, 82)
        XCTAssertEqual(battery.isCharging, true)
    }

    func testDecodeDiskUsageInfo() throws {
        let data = plistData("""
            <key>TotalDataAvailable</key>
            <integer>45000000000</integer>
            <key>TotalDiskCapacity</key>
            <integer>256000000000</integer>
            <key>TotalDataCapacity</key>
            <integer>246000000000</integer>
            <key>TotalSystemCapacity</key>
            <integer>10000000000</integer>
            """)

        let disk = try PropertyListDecoder().decode(DeviceDiskUsageInfo.self, from: data)

        XCTAssertEqual(disk.totalDiskCapacity, 256_000_000_000)
        XCTAssertEqual(disk.totalDataAvailable, 45_000_000_000)
        XCTAssertEqual(disk.totalDataCapacity, 246_000_000_000)
        XCTAssertEqual(disk.totalSystemCapacity, 10_000_000_000)
    }

    func testDecodeBackupInfo() throws {
        let data = plistData("""
            <key>CloudBackupEnabled</key>
            <true/>
            <key>WillEncrypt</key>
            <true/>
            """)

        let backup = try PropertyListDecoder().decode(DeviceBackupInfo.self, from: data)

        XCTAssertEqual(backup.cloudBackupEnabled, true)
        XCTAssertEqual(backup.willEncrypt, true)
    }

    func testDecodeScreenInfo() throws {
        let data = plistData("""
            <key>ScreenWidth</key>
            <integer>1179</integer>
            <key>ScreenHeight</key>
            <integer>2556</integer>
            <key>ScreenScaleFactor</key>
            <real>3.0</real>
            """)

        let screen = try PropertyListDecoder().decode(DeviceScreenInfo.self, from: data)

        XCTAssertEqual(screen.screenWidth, 1179)
        XCTAssertEqual(screen.screenHeight, 2556)
        XCTAssertEqual(screen.screenScaleFactor, 3.0)
    }

    func testCombiningProducesExpectedStatusInfoAndComputesUsedCapacity() throws {
        let global = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: plistData("""
            <key>DeviceName</key>
            <string>iPhone de Vincent</string>
            <key>ProductType</key>
            <string>iPhone15,3</string>
            <key>ProductVersion</key>
            <string>17.5.1</string>
            <key>BuildVersion</key>
            <string>21F90</string>
            <key>SerialNumber</key>
            <string>ABCD1234EFGH</string>
            """))
        let battery = try PropertyListDecoder().decode(DeviceBatteryInfo.self, from: plistData("""
            <key>BatteryCurrentCapacity</key>
            <integer>82</integer>
            <key>BatteryIsCharging</key>
            <false/>
            """))
        let disk = try PropertyListDecoder().decode(DeviceDiskUsageInfo.self, from: plistData("""
            <key>TotalDataAvailable</key>
            <integer>45000000000</integer>
            <key>TotalDiskCapacity</key>
            <integer>256000000000</integer>
            """))

        let info = iPhoneStatusInfo.combining(udid: "abc-123", connectionType: .usb, global: global, battery: battery, disk: disk)

        XCTAssertEqual(info.udid, "abc-123")
        XCTAssertEqual(info.connectionType, .usb)
        XCTAssertEqual(info.deviceName, "iPhone de Vincent")
        XCTAssertEqual(info.batteryLevel, 82)
        XCTAssertEqual(info.isCharging, false)
        XCTAssertEqual(info.usedDiskCapacity, 211_000_000_000)
    }

    func testMissingOptionalFieldsFallBackToDefaults() throws {
        let global = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: plistData(""))

        let info = iPhoneStatusInfo.combining(udid: "abc-123", connectionType: .usb, global: global, battery: nil, disk: nil)

        XCTAssertEqual(info.deviceName, "iPhone")
        XCTAssertEqual(info.productType, "—")
        XCTAssertEqual(info.passwordProtected, false)
        XCTAssertNil(info.batteryLevel)
        XCTAssertNil(info.usedDiskCapacity)
        XCTAssertFalse(info.isBetaRelease)
        XCTAssertFalse(info.hasCellularInfo)
    }

    func testCombiningPopulatesExtendedFieldsAndDerivesCarrierName() throws {
        let global = try PropertyListDecoder().decode(DeviceGlobalInfo.self, from: plistData("""
            <key>DeviceName</key>
            <string>iPhone de Vincent</string>
            <key>HardwareModel</key>
            <string>D74AP</string>
            <key>ReleaseType</key>
            <string>Beta</string>
            <key>TelephonyCapability</key>
            <true/>
            <key>InternationalMobileEquipmentIdentity</key>
            <string>359123456789012</string>
            <key>CarrierBundleInfoArray</key>
            <array>
                <dict>
                    <key>CFBundleIdentifier</key>
                    <string>com.apple.CARRIER.Orange_France</string>
                </dict>
            </array>
            """))
        let disk = try PropertyListDecoder().decode(DeviceDiskUsageInfo.self, from: plistData("""
            <key>TotalDataCapacity</key>
            <integer>246000000000</integer>
            <key>TotalSystemCapacity</key>
            <integer>10000000000</integer>
            """))
        let backup = try PropertyListDecoder().decode(DeviceBackupInfo.self, from: plistData("""
            <key>CloudBackupEnabled</key>
            <true/>
            """))
        let screen = try PropertyListDecoder().decode(DeviceScreenInfo.self, from: plistData("""
            <key>ScreenWidth</key>
            <integer>1179</integer>
            <key>ScreenHeight</key>
            <integer>2556</integer>
            """))

        let info = iPhoneStatusInfo.combining(
            udid: "abc-123", connectionType: .usb, global: global, battery: nil, disk: disk,
            backup: backup, screen: screen
        )

        XCTAssertEqual(info.hardwareModel, "D74AP")
        XCTAssertTrue(info.isBetaRelease)
        XCTAssertEqual(info.totalDataCapacity, 246_000_000_000)
        XCTAssertEqual(info.totalSystemCapacity, 10_000_000_000)
        XCTAssertEqual(info.cloudBackupEnabled, true)
        XCTAssertEqual(info.screenWidth, 1179)
        XCTAssertEqual(info.screenHeight, 2556)
        XCTAssertEqual(info.carrierName, "Orange France")
        XCTAssertTrue(info.hasCellularInfo)
    }
}
