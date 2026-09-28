//
//  TodayPillPickTests.swift
//  PillieTests
//

// Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.

import XCTest

@testable import Pillie

@MainActor
final class TodayPillPickTests: XCTestCase {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func pick(_ index: Int, _ answer: TodayPillPick.Answer?, _ regimen: PillPack.PillRegimenPreset = .twentyOneSeven) -> TodayPillPick {
        TodayPillPick(pack: PackChoice(preset: regimen), dayIndex: index, answer: answer)!
    }

    private func anchor(_ pick: TodayPillPick, now: Date, reminderHour: Int) -> Date {
        pick.anchorDay(now: now, reminderHour: reminderHour, reminderMinute: 0, calendar: Self.calendar)
    }

    func testTakenBeforeAnEveningReminderAnchorsOnTheOpenWindowFromYesterday() {
        XCTAssertEqual(anchor(pick(11, .taken), now: date(27, 12, 24), reminderHour: 20), date(26, 0))
    }

    func testTakenAfterAnEveningReminderAnchorsOnToday() {
        XCTAssertEqual(anchor(pick(11, .taken), now: date(27, 21, 5), reminderHour: 20), date(27, 0))
    }

    func testTakenAfterAMorningReminderAnchorsOnToday() {
        XCTAssertEqual(anchor(pick(11, .taken), now: date(27, 12, 24), reminderHour: 8), date(27, 0))
    }

    func testTakenBeforeAMorningReminderAnchorsOnYesterday() {
        XCTAssertEqual(anchor(pick(11, .taken), now: date(27, 6, 30), reminderHour: 8), date(26, 0))
    }

    func testNotYetBeforeAnEveningReminderAnchorsOnTonightsWindow() {
        XCTAssertEqual(anchor(pick(11, .notYet), now: date(27, 12, 24), reminderHour: 20), date(27, 0))
    }

    func testNotYetAfterAnEveningReminderAnchorsOnTheWindowThatIsOpenNow() {
        XCTAssertEqual(anchor(pick(11, .notYet), now: date(27, 21, 5), reminderHour: 20), date(27, 0))
    }

    func testNotYetBeforeAMorningReminderAnchorsOnTodaysWindow() {
        XCTAssertEqual(anchor(pick(11, .notYet), now: date(27, 6, 30), reminderHour: 8), date(27, 0))
    }

    func testNotYetAfterAMorningReminderAnchorsOnToday() {
        XCTAssertEqual(anchor(pick(11, .notYet), now: date(27, 12, 24), reminderHour: 8), date(27, 0))
    }

    func testPillFreeDayAnchorsOnTheCalendarDay() {
        let breakDay = pick(23, nil, .twentyOneOnly)
        XCTAssertEqual(anchor(breakDay, now: date(27, 12, 24), reminderHour: 20), date(27, 0))
    }

    func testFirstPillAnchorsLikeAnyOtherPill() {
        XCTAssertEqual(anchor(pick(0, .taken), now: date(27, 12, 24), reminderHour: 20), date(26, 0))
        XCTAssertEqual(anchor(pick(0, .notYet), now: date(27, 12, 24), reminderHour: 20), date(27, 0))
    }

    func testPickRefusesStatesThePackCannotHold() {
        XCTAssertNil(TodayPillPick(pack: PackChoice(preset: .twentyOneSeven), dayIndex: 11, answer: nil))
        XCTAssertNil(TodayPillPick(pack: PackChoice(preset: .twentyOneOnly), dayIndex: 23, answer: .taken))
        XCTAssertNil(TodayPillPick(pack: PackChoice(preset: .twentyOneSeven), dayIndex: 28, answer: .taken))
        XCTAssertNotNil(TodayPillPick(pack: PackChoice(preset: .twentyOneSeven), dayIndex: 23, answer: .notYet))
        XCTAssertNotNil(TodayPillPick(pack: PackChoice(preset: .twentyOneOnly), dayIndex: 23, answer: nil))
    }

    func testDraftRoundTripsThroughDefaultsAndClears() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodayPillPickTests.draft"))
        defaults.removePersistentDomain(forName: "TodayPillPickTests.draft")

        XCTAssertNil(TodayPillPick.load(from: defaults))
        pick(11, .notYet, .twentyFourFour).save(to: defaults)
        XCTAssertEqual(TodayPillPick.load(from: defaults), pick(11, .notYet, .twentyFourFour))

        TodayPillPick.clear(from: defaults)
        XCTAssertNil(TodayPillPick.load(from: defaults))
    }

    func testCustomPackPickFollowsTheCustomRegimen() {
        let pack = PackChoice(PackRegimen(activeDays: 88, breakDays: 3, breakKind: .noPills))
        XCTAssertNotNil(TodayPillPick(pack: pack, dayIndex: 87, answer: .taken))
        XCTAssertNotNil(TodayPillPick(pack: pack, dayIndex: 89, answer: nil))
        XCTAssertNil(TodayPillPick(pack: pack, dayIndex: 89, answer: .taken))
        XCTAssertNil(TodayPillPick(pack: pack, dayIndex: 91, answer: nil))
    }

    func testDraftSavedBeforeCustomPacksStillLoads() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodayPillPickTests.legacy"))
        defaults.set(Data(#"{"regimen":"24/4","dayIndex":11,"answer":"taken"}"#.utf8), forKey: TodayPillPick.storageKey)

        XCTAssertEqual(TodayPillPick.load(from: defaults), pick(11, .taken, .twentyFourFour))
        defaults.removePersistentDomain(forName: "TodayPillPickTests.legacy")
    }

    func testCustomDraftRoundTripsWithItsRegimen() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodayPillPickTests.custom"))
        defaults.removePersistentDomain(forName: "TodayPillPickTests.custom")
        let custom = try XCTUnwrap(TodayPillPick(pack: PackChoice(PackRegimen(activeDays: 88, breakDays: 3)), dayIndex: 89, answer: .notYet))

        custom.save(to: defaults)
        let loaded = try XCTUnwrap(TodayPillPick.load(from: defaults))
        XCTAssertEqual(loaded.pack.preset, .custom)
        XCTAssertEqual(loaded.pack.regimen, PackRegimen(activeDays: 88, breakDays: 3))
        XCTAssertEqual(loaded.dayIndex, 89)
        XCTAssertEqual(loaded.answer, .notYet)
        defaults.removePersistentDomain(forName: "TodayPillPickTests.custom")
    }

    func testCustomDraftWithoutItsRegimenLoadsAsNil() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodayPillPickTests.customMissing"))
        defaults.set(Data(#"{"regimen":"CUSTOM","dayIndex":3,"answer":"taken"}"#.utf8), forKey: TodayPillPick.storageKey)

        XCTAssertNil(TodayPillPick.load(from: defaults))
        defaults.removePersistentDomain(forName: "TodayPillPickTests.customMissing")
    }

    func testDraftThatNoLongerFitsItsPackLoadsAsNil() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodayPillPickTests.corrupt"))
        defaults.set(Data(#"{"regimen":"21/7","dayIndex":40,"answer":"taken"}"#.utf8), forKey: TodayPillPick.storageKey)

        XCTAssertNil(TodayPillPick.load(from: defaults))
        defaults.removePersistentDomain(forName: "TodayPillPickTests.corrupt")
    }
}
