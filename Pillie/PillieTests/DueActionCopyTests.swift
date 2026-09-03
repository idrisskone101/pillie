import XCTest

@testable import Pillie

final class DueActionCopyTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let date = Date(timeIntervalSince1970: 1_767_225_600)

    func testDueActionVerbsMatchLockedEnglish() {
        XCTAssertEqual(label(.pillActive, method: .pill, day: 1), "take pill")
        XCTAssertEqual(label(.patchChange, method: .patch, day: 1), "apply patch")
        XCTAssertEqual(label(.patchChange, method: .patch, day: 8), "change patch")
        XCTAssertEqual(label(.patchRemove, method: .patch, day: 22), "remove patch")
        XCTAssertEqual(label(.ringInsert, method: .ring, day: 1), "insert ring")
        XCTAssertEqual(label(.ringReinsert, method: .ring, day: 1), "change ring")
        XCTAssertEqual(label(.ringRemove, method: .ring, day: 22), "remove ring")
        XCTAssertEqual(label(.pillBreak, method: .pill, day: 22), "there's nothing due today.")
    }

    func testMethodAwareProtectionCopyUsesApplyOnFirstPatchDay() {
        let apply = action(.patchChange, method: .patch, day: 1)
        XCTAssertEqual(
            MethodAwareCopy.key(.todayOff, action: apply, method: .patch),
            "today.protection.off.detail.patch.apply"
        )
        XCTAssertEqual(
            MethodAwareCopy.key(.upsellBlocking, action: apply, method: .patch),
            "paywall.upsell.app_blocking.body.patch.apply"
        )
    }

    private func label(
        _ type: PillDay.ActionType,
        method: ContraceptiveMethod,
        day: Int
    ) -> String {
        DueActionCopy.localizedLabel(for: action(type, method: method, day: day), locale: english)
    }

    private func action(
        _ type: PillDay.ActionType,
        method: ContraceptiveMethod,
        day: Int
    ) -> DoseScheduleAction {
        DoseScheduleAction(
            date: date,
            type: type,
            method: method,
            cycleDay: day,
            cycleLength: 28
        )
    }
}
