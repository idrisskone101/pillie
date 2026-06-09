import XCTest

@testable import Pillie

final class AppBlockingSetupContentTests: XCTestCase {
    func testAppBlockingSetupContentUsesScreenTimePlusAndOnDeviceSelectionCopy() {
        let content = AppBlockingSetupContent.default

        XCTAssertEqual(content.badge, "Pillie Plus")
        XCTAssertEqual(content.title, "App Blocking")
        XCTAssertTrue(content.plusSubtitle.contains("iOS Screen Time"))
        XCTAssertEqual(content.lockedTitle, "Included with Pillie Plus")
        XCTAssertTrue(content.privacyNote.contains("app choices stay on this device"))

        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertTrue(visibleCopy.contains("pillie plus"))
        XCTAssertTrue(visibleCopy.contains("screen time"))
        XCTAssertTrue(visibleCopy.contains("app choices stay on this device"))
        XCTAssertFalse(visibleCopy.contains("pillie+"))
        XCTAssertFalse(visibleCopy.contains("ad blocking"))
        XCTAssertFalse(visibleCopy.contains("ads"))
    }
}
