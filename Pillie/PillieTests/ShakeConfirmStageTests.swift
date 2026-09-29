//
//  ShakeConfirmStageTests.swift
//  PillieTests
//

import Foundation
import Testing
@testable import Pillie

struct ShakeConfirmStageTests {
    @Test(arguments: [
        (0, ShakeConfirmStage.sealed),
        (1, .dented),
        (2, .torn),
        (3, .done),
        (4, .done),
    ])
    func eachShakeAdvancesOneStage(shakeCount: Int, expected: ShakeConfirmStage) {
        #expect(ShakeConfirmStage(shakeCount: shakeCount, requiredShakes: 3) == expected)
    }

    @Test func counterRollsAThirdPerShake() {
        #expect(ShakeConfirmStage.sealed.odometerProgress == 0)
        #expect(ShakeConfirmStage.dented.odometerProgress == 1.0 / 3.0)
        #expect(ShakeConfirmStage.torn.odometerProgress == 2.0 / 3.0)
        #expect(ShakeConfirmStage.done.odometerProgress == 1)
    }

    @Test func headlinesTalkAboutTheStreakOnlyWhenOneIsKept() {
        #expect(ShakeConfirmStage.sealed.headlineKey(streakBefore: 11, streakAfter: 12) == "shake.streak.headline.start")
        #expect(ShakeConfirmStage.done.headlineKey(streakBefore: 11, streakAfter: 12) == "shake.streak.headline.kept")

        #expect(ShakeConfirmStage.sealed.headlineKey(streakBefore: 0, streakAfter: 1) == "today.action.shake")
        #expect(ShakeConfirmStage.done.headlineKey(streakBefore: 0, streakAfter: 1) == "global.action.done")
        #expect(ShakeConfirmStage.done.headlineKey(streakBefore: 5, streakAfter: 5) == "global.action.done")

        #expect(ShakeConfirmStage.dented.headlineKey(streakBefore: 0, streakAfter: 1) == "shake.streak.headline.keep_going")
        #expect(ShakeConfirmStage.torn.headlineKey(streakBefore: 0, streakAfter: 1) == "shake.streak.headline.almost")
    }
}

struct ShakeConfirmArtworkTests {
    private func action(_ type: PillDay.ActionType, method: ContraceptiveMethod, cycleDay: Int = 5) -> DoseScheduleAction {
        DoseScheduleAction(date: .now, type: type, method: method, cycleDay: cycleDay, cycleLength: 28)
    }

    @Test func eachMethodStateOpensItsOwnWay() {
        #expect(ShakeConfirmArtwork(action: action(.pillActive, method: .pill)) == .pillBlister)
        #expect(ShakeConfirmArtwork(action: action(.patchChange, method: .patch, cycleDay: 1)) == .patchApply)
        #expect(ShakeConfirmArtwork(action: action(.patchChange, method: .patch, cycleDay: 8)) == .patchChange)
        #expect(ShakeConfirmArtwork(action: action(.patchRemove, method: .patch)) == .patchRemove)
        #expect(ShakeConfirmArtwork(action: action(.ringInsert, method: .ring)) == .ringInsert)
        #expect(ShakeConfirmArtwork(action: action(.ringReinsert, method: .ring)) == .ringInsert)
        #expect(ShakeConfirmArtwork(action: action(.ringRemove, method: .ring)) == .ringRemove)
    }

    @Test func daysWithoutAPhysicalStepHaveNoArtwork() {
        #expect(ShakeConfirmArtwork(action: action(.pillBreak, method: .pill)) == nil)
        #expect(ShakeConfirmArtwork(action: action(.patchBreak, method: .patch)) == nil)
        #expect(ShakeConfirmArtwork(action: action(.ringBreak, method: .ring)) == nil)
    }

    @Test func ringRemovalPlaysInsertionBackwards() {
        let insert = ShakeConfirmArtwork.ringInsert.imageNames
        let remove = ShakeConfirmArtwork.ringRemove.imageNames
        #expect(Array(remove.prefix(2)) == [insert[2], insert[1]])
    }

    @Test func doneStageKeepsTheLastFrame() {
        #expect(ShakeConfirmArtwork.patchRemove.imageName(for: .done) == "ShakePatchFolded")
    }
}

struct StreakOdometerDigitsTests {
    @Test func onlyTheChangingWheelRolls() {
        let digits = StreakOdometerDigits(from: 11, to: 12)
        #expect(digits.wheels.map(\.rolls) == [false, true])
        #expect(digits.wheels.map(\.to) == ["1", "2"])
    }

    @Test func carryRollsEveryChangedWheel() {
        let digits = StreakOdometerDigits(from: 19, to: 20)
        #expect(digits.wheels.map(\.from) == ["1", "9"])
        #expect(digits.wheels.map(\.to) == ["2", "0"])
        #expect(digits.wheels.map(\.rolls) == [true, true])
    }

    @Test func newLeadingDigitRollsInFromBlank() {
        let digits = StreakOdometerDigits(from: 99, to: 100)
        #expect(digits.wheels.map(\.from) == [nil, "9", "9"])
        #expect(digits.wheels.map(\.to) == ["1", "0", "0"])
    }

    @Test func unchangedStreakHoldsStill() {
        let digits = StreakOdometerDigits(from: 7, to: 7)
        #expect(digits.wheels.count == 1)
        #expect(digits.wheels.map(\.rolls) == [false])
    }
}
