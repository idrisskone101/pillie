//
//  TodayPillSelectionTests.swift
//  PillieTests
//

// Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.

import XCTest

@testable import Pillie

@MainActor
final class TodayPillSelectionTests: XCTestCase {
    private func pick(_ index: Int, _ answer: TodayPillPick.Answer?, _ regimen: PillPack.PillRegimenPreset = .twentyOneSeven) -> TodayPillPick {
        TodayPillPick(pack: PackChoice(preset: regimen), dayIndex: index, answer: answer)!
    }

    func testTappingAPillResetsTheAnswerAndPillFreeDaysNeedNone() {
        var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneOnly))
        XCTAssertNil(selection.pick)

        selection.tap(11)
        XCTAssertTrue(selection.asksQuestion)
        XCTAssertNil(selection.pick)

        selection.record(.taken)
        XCTAssertEqual(selection.pick, pick(11, .taken, .twentyOneOnly))

        selection.tap(23)
        XCTAssertFalse(selection.asksQuestion)
        XCTAssertNil(selection.answer)
        XCTAssertEqual(selection.pick, pick(23, nil, .twentyOneOnly))
    }

    func testChangingThePackKeepsTheTappedPillOnlyWhenItStillExists() {
        var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneSeven))
        selection.tap(26)
        selection.record(.notYet)

        selection.changePack(PackChoice(preset: .twentySixTwo))
        XCTAssertEqual(selection.pick, pick(26, .notYet, .twentySixTwo))

        selection.changePack(PackChoice(preset: .twentyOneOnly))
        XCTAssertEqual(selection.pick, pick(26, nil, .twentyOneOnly))

        var shorter = TodayPillSelection(pack: PackChoice(preset: .twentyOneSeven))
        shorter.tap(27)
        shorter.record(.taken)
        shorter.changePack(PackChoice(preset: .twentyOneFour))
        XCTAssertNil(shorter.dayIndex)
        XCTAssertNil(shorter.pick)
    }

    func testSwitchingToALongerCustomPackKeepsTheTappedPill() throws {
        var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneSeven))
        selection.tap(26)
        selection.record(.notYet)

        let custom = PackChoice(PackRegimen(activeDays: 88, breakDays: 3))
        selection.changePack(custom)
        XCTAssertEqual(selection.pick, TodayPillPick(pack: custom, dayIndex: 26, answer: .notYet))
        XCTAssertEqual(selection.packRegimen.totalDays, 91)
    }

    func testTappingTheFlaggedPillAgainKeepsTheAnswer() {
        var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneSeven))
        selection.tap(11)
        selection.record(.taken)
        selection.tap(11)
        XCTAssertEqual(selection.pick, pick(11, .taken))
    }

    func testAPillFreeDayThatBecomesASugarPillAsksAgain() {
        var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneOnly))
        selection.tap(23)
        XCTAssertNotNil(selection.pick)

        selection.changePack(PackChoice(preset: .twentyOneSeven))
        XCTAssertTrue(selection.asksQuestion)
        XCTAssertNil(selection.pick)
    }

    func testSelectionRestoresFromADraft() {
        let selection = TodayPillSelection(restoring: pick(11, .taken, .twentyFourFour))
        XCTAssertEqual(selection.pack, PackChoice(preset: .twentyFourFour))
        XCTAssertEqual(selection.pick, pick(11, .taken, .twentyFourFour))
    }
}
