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
        TodayPillPick(regimen: regimen, dayIndex: index, answer: answer)!
    }

    func testTappingAPillResetsTheAnswerAndPillFreeDaysNeedNone() {
        var selection = TodayPillSelection(regimen: .twentyOneOnly)
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
        var selection = TodayPillSelection(regimen: .twentyOneSeven)
        selection.tap(26)
        selection.record(.notYet)

        selection.changeRegimen(.twentySixTwo)
        XCTAssertEqual(selection.pick, pick(26, .notYet, .twentySixTwo))

        selection.changeRegimen(.twentyOneOnly)
        XCTAssertEqual(selection.pick, pick(26, nil, .twentyOneOnly))

        var shorter = TodayPillSelection(regimen: .twentyOneSeven)
        shorter.tap(27)
        shorter.record(.taken)
        shorter.changeRegimen(.twentyOneFour)
        XCTAssertNil(shorter.dayIndex)
        XCTAssertNil(shorter.pick)
    }

    func testTappingTheFlaggedPillAgainKeepsTheAnswer() {
        var selection = TodayPillSelection(regimen: .twentyOneSeven)
        selection.tap(11)
        selection.record(.taken)
        selection.tap(11)
        XCTAssertEqual(selection.pick, pick(11, .taken))
    }

    func testAPillFreeDayThatBecomesASugarPillAsksAgain() {
        var selection = TodayPillSelection(regimen: .twentyOneOnly)
        selection.tap(23)
        XCTAssertNotNil(selection.pick)

        selection.changeRegimen(.twentyOneSeven)
        XCTAssertTrue(selection.asksQuestion)
        XCTAssertNil(selection.pick)
    }

    func testSelectionRestoresFromADraft() {
        let selection = TodayPillSelection(restoring: pick(11, .taken, .twentyFourFour))
        XCTAssertEqual(selection.regimen, .twentyFourFour)
        XCTAssertEqual(selection.pick, pick(11, .taken, .twentyFourFour))
    }
}
