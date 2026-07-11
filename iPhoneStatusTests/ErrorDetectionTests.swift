import XCTest
@testable import iPhoneStatus

final class ErrorDetectionTests: XCTestCase {
    func testPendingConfirmationMessage() {
        let stderr = "ERROR: Could not connect to lockdownd: Pairing dialog response pending (-19)"
        XCTAssertEqual(StderrClassifier.classify(stderr), .pendingConfirmation)
    }

    func testDeniedMessage() {
        let stderr = "ERROR: Could not connect to lockdownd: User denied pairing (-18)"
        XCTAssertEqual(StderrClassifier.classify(stderr), .denied)
    }

    func testPasswordProtectedMessage() {
        let stderr = "ERROR: Could not connect to lockdownd: Password protected (-21)"
        XCTAssertEqual(StderrClassifier.classify(stderr), .passwordProtected)
    }

    func testMissingPairRecordFallsBackToPendingConfirmation() {
        let stderr = "ERROR: Could not connect to lockdownd: Invalid HostID (-9)"
        XCTAssertEqual(StderrClassifier.classify(stderr), .pendingConfirmation)
    }

    func testCaseInsensitiveMatching() {
        XCTAssertEqual(StderrClassifier.classify("USER DENIED PAIRING"), .denied)
    }

    func testUnknownMessageFallsBackToPendingConfirmation() {
        XCTAssertEqual(StderrClassifier.classify("some completely unexpected message"), .pendingConfirmation)
    }
}
