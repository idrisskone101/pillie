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
}

struct ShakeClipTests {
    private func shell(_ clip: ShakeClip, restingOn stage: ShakeConfirmStage) -> String {
        clip.poses[clip.stop(for: stage)].shell
    }

    @Test(arguments: [
        ShakeConfirmArtwork.pillBlister, .patchApply, .patchChange, .patchRemove, .ringInsert, .ringRemove,
    ])
    func everyStageRestsOnAPoseInOrder(artwork: ShakeConfirmArtwork) {
        let clip = artwork.clip
        #expect(clip.stops.count == 4)
        #expect(clip.stops == clip.stops.sorted())
        #expect(clip.stops.allSatisfy(clip.poses.indices.contains))
    }

    @Test(arguments: [
        (ShakeConfirmArtwork.pillBlister, 7),
        (.patchApply, 11),
        (.patchChange, 11),
        (.patchRemove, 4),
        (.ringInsert, 4),
        (.ringRemove, 4),
    ])
    func tappingThroughFromTheStartPlaysEveryLaterPose(artwork: ShakeConfirmArtwork, lastPose: Int) {
        #expect(Array(artwork.clip.posesToPlay(from: 0, to: .done)) == Array(1...lastPose))
    }

    @Test func aShakeMidPlaybackCarriesOnFromThePoseOnScreen() {
        #expect(Array(ShakeClip.pill.posesToPlay(from: 1, to: .torn)) == [2, 3])
        #expect(Array(ShakeClip.pill.posesToPlay(from: 5, to: .done)) == [6, 7])
    }

    @Test func aStageBehindThePoseOnScreenPlaysNothing() {
        #expect(ShakeClip.pill.posesToPlay(from: 3, to: .dented).isEmpty)
        #expect(ShakeClip.patchApply.posesToPlay(from: 11, to: .dented).isEmpty)
        #expect(ShakeClip.patchApply.posesToPlay(from: 11, to: .done).isEmpty)
        #expect(ShakeClip.ringInsert.posesToPlay(from: 2, to: .dented).isEmpty)
    }

    @Test func secondShakeSeatsThePillInTheTornFoil() {
        let clip = ShakeClip.pill
        #expect(shell(clip, restingOn: .torn) == "ShakeLayerBlisterEmpty")
        #expect(clip.poses[clip.stop(for: .torn)].cutout != nil)
        #expect(clip.cutoutImage == "ShakeLayerPill")
    }

    @Test func patchChangeOpensOnTheOldPatchThenTheBarePouch() {
        let poses = ShakeClip.patchChange.poses
        #expect(poses[0].shell == "ShakePatchFoldedOnPouch")
        #expect(poses[1].shell == "ShakeLayerPatchPouchSealed")
        #expect(ShakeClip.patchApply.poses[0].shell == "ShakeLayerPatchPouchSealed")
    }

    @Test func ringRemovalOpensOnTheRingItselfAndEndsResealed() {
        let clip = ShakeClip.ringRemove
        #expect(shell(clip, restingOn: .sealed) == "ShakeRingOut")
        #expect(shell(clip, restingOn: .done) == "ShakeRingPouchResealed")
    }

    @Test func doneStageKeepsTheLastFrame() {
        #expect(shell(.patchRemove, restingOn: .done) == "ShakePatchFolded")
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
