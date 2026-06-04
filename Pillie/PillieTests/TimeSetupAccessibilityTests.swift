import XCTest

@testable import Pillie

final class TimeSetupAccessibilityTests: XCTestCase {
    func testReminderTimePickerAccessibilityLabelsAreSpecific() {
        XCTAssertEqual(ReminderTimePickerAccessibility.hourLabel, "Reminder hour")
        XCTAssertEqual(ReminderTimePickerAccessibility.minuteLabel, "Reminder minute")
        XCTAssertEqual(ReminderTimePickerAccessibility.periodLabel, "Reminder period")
    }
}
