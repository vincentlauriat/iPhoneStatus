import XCTest
@testable import iPhoneStatus

final class SensitiveDataMaskingTests: XCTestCase {
    func testMasksLongValueKeepingLastFourCharacters() {
        XCTAssertEqual(SensitiveDataMasking.apply("359123456789012", revealed: false), "••••9012")
        XCTAssertEqual(SensitiveDataMasking.apply("+33612345678", revealed: false), "••••5678")
    }

    func testFullyMasksValueShorterThanSuffixLength() {
        XCTAssertEqual(SensitiveDataMasking.apply("12", revealed: false), "••")
        XCTAssertEqual(SensitiveDataMasking.apply("", revealed: false), "")
    }

    func testRevealedReturnsValueUnchanged() {
        XCTAssertEqual(SensitiveDataMasking.apply("359123456789012", revealed: true), "359123456789012")
    }
}
