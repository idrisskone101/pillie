import XCTest
@testable import Pillie

final class CalendarDayHitTestTests: XCTestCase {
    func testGridHitMapsSeptember2026TuesdayTheFirst() {
        let width: CGFloat = 362
        let leadingBlanks = 2
        let daysInMonth = 30
        let cellWidth = (width - 4 * 6) / 7
        let x = CGFloat(2) * (cellWidth + 4) + cellWidth / 2
        let y = CalendarDayHitTest.weekdayHeaderHeight
            + CalendarDayHitTest.headerToGridSpacing
            + cellWidth / 2

        XCTAssertEqual(
            CalendarDayHitTest.day(
                at: CGPoint(x: x, y: y),
                calendarWidth: width,
                daysInMonth: daysInMonth,
                leadingBlanks: leadingBlanks
            ),
            1
        )
    }

    func testGridHitRejectsWeekdayHeader() {
        XCTAssertNil(
            CalendarDayHitTest.day(
                at: CGPoint(x: 40, y: 4),
                calendarWidth: 362,
                daysInMonth: 30,
                leadingBlanks: 2
            )
        )
    }

    func testGridHitUsesPublishedFramesForOrigin() {
        let frames = [1: CGRect(x: 104, y: 21, width: 48, height: 56)]
        XCTAssertEqual(
            CalendarDayHitTest.day(
                at: CGPoint(x: 128, y: 40),
                calendarWidth: 362,
                daysInMonth: 30,
                leadingBlanks: 2,
                frames: frames
            ),
            1
        )
    }

    func testPublishedFrameWinsOnCellTrailingEdge() {
        let frames = [
            1: CGRect(x: 104, y: 21, width: 48, height: 56),
            2: CGRect(x: 156, y: 21, width: 48, height: 56)
        ]
        XCTAssertEqual(
            CalendarDayHitTest.day(
                at: CGPoint(x: 150, y: 28),
                calendarWidth: 362,
                daysInMonth: 30,
                leadingBlanks: 2,
                frames: frames
            ),
            1
        )
        XCTAssertEqual(
            CalendarDayHitTest.day(
                at: CGPoint(x: 160, y: 28),
                calendarWidth: 362,
                daysInMonth: 30,
                leadingBlanks: 2,
                frames: frames
            ),
            2
        )
    }
}
