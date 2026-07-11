import XCTest
@testable import iPhoneStatus

final class BatterySmartInfoParsingTests: XCTestCase {
    /// Trimmed extract of a real `idevicediagnostics ioregentry AppleSmartBattery`
    /// capture (values cross-checked against a third-party battery report).
    private let samplePlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>IORegistry</key>
            <dict>
                <key>AdapterDetails</key>
                <dict>
                    <key>Description</key>
                    <string>pd charger</string>
                    <key>Watts</key>
                    <integer>15</integer>
                </dict>
                <key>Amperage</key>
                <integer>2656</integer>
                <key>BatteryData</key>
                <dict>
                    <key>DesignCapacity</key>
                    <integer>3544</integer>
                    <key>FullChargeCapacity</key>
                    <integer>3233</integer>
                    <key>NominalChargeCapacity</key>
                    <integer>3103</integer>
                </dict>
                <key>CycleCount</key>
                <integer>856</integer>
                <key>IsCharging</key>
                <true/>
                <key>ManufacturerData</key>
                <data>
                VEVTVENFTExJRFZBTFVFMQAAAAAAAAAAAAAAAAAAAAA=
                </data>
                <key>Serial</key>
                <string>F8YTESTBATTERY001</string>
                <key>Voltage</key>
                <integer>3998</integer>
            </dict>
        </dict>
        </plist>
        """

    func testDecodeBatterySmartInfo() throws {
        let data = Data(samplePlist.utf8)
        let info = try PropertyListDecoder().decode(BatterySmartInfo.self, from: data)
        let registry = info.ioRegistry

        XCTAssertEqual(registry.cycleCount, 856)
        XCTAssertEqual(registry.voltage, 3998)
        XCTAssertEqual(registry.amperage, 2656)
        XCTAssertEqual(registry.isCharging, true)
        XCTAssertEqual(registry.serial, "F8YTESTBATTERY001")
        XCTAssertEqual(registry.adapterDetails?.watts, 15)
        XCTAssertEqual(registry.adapterDetails?.description, "pd charger")
    }

    func testHealthPercentMatchesIOSSettingsFormula() throws {
        let data = Data(samplePlist.utf8)
        let info = try PropertyListDecoder().decode(BatterySmartInfo.self, from: data)

        // round(NominalChargeCapacity / DesignCapacity * 100) = round(3103/3544*100) = 88
        XCTAssertEqual(info.ioRegistry.batteryData?.healthPercent, 88)
    }

    func testManufacturerDataDecodesToCellID() throws {
        let data = Data(samplePlist.utf8)
        let info = try PropertyListDecoder().decode(BatterySmartInfo.self, from: data)

        XCTAssertEqual(info.ioRegistry.cellID, "TESTCELLIDVALUE1")
    }

    func testCombiningPopulatesEnrichedFields() throws {
        let data = Data(samplePlist.utf8)
        let smartBattery = try PropertyListDecoder().decode(BatterySmartInfo.self, from: data).ioRegistry
        let global = DeviceGlobalInfo(
            deviceName: "iPhone",
            productType: "iPhone17,1",
            productVersion: "27.0",
            buildVersion: "24A5380h",
            serialNumber: "TESTDEVICESN01",
            wiFiAddress: nil,
            bluetoothAddress: nil,
            passwordProtected: false
        )

        let combined = iPhoneStatusInfo.combining(udid: "abc", connectionType: .usb, global: global, battery: nil, disk: nil, smartBattery: smartBattery)

        XCTAssertEqual(combined.cycleCount, 856)
        XCTAssertEqual(combined.batteryHealthPercent, 88)
        XCTAssertEqual(combined.designCapacityMah, 3544)
        XCTAssertEqual(combined.voltageVolts, 3.998)
        XCTAssertEqual(combined.chargerWattage, 15)
        XCTAssertEqual(combined.chargerDescription, "pd charger")
        XCTAssertEqual(combined.batterySerial, "F8YTESTBATTERY001")
        XCTAssertEqual(combined.batteryCellID, "TESTCELLIDVALUE1")
    }

    func testMissingSmartBatteryLeavesEnrichedFieldsNil() {
        let global = DeviceGlobalInfo(
            deviceName: nil, productType: nil, productVersion: nil, buildVersion: nil,
            serialNumber: nil, wiFiAddress: nil, bluetoothAddress: nil, passwordProtected: nil
        )

        let combined = iPhoneStatusInfo.combining(udid: "abc", connectionType: .usb, global: global, battery: nil, disk: nil, smartBattery: nil)

        XCTAssertNil(combined.cycleCount)
        XCTAssertNil(combined.batteryHealthPercent)
        XCTAssertNil(combined.batteryCellID)
    }
}
