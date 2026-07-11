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
            """)

        let disk = try PropertyListDecoder().decode(DeviceDiskUsageInfo.self, from: data)

        XCTAssertEqual(disk.totalDiskCapacity, 256_000_000_000)
        XCTAssertEqual(disk.totalDataAvailable, 45_000_000_000)
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
    }
}
