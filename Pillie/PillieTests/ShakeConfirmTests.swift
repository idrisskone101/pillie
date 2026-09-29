import Foundation
import Testing
import UIKit
@testable import Pillie

struct ShakeProgressTests {
    private let kept = StreakChange(before: 11, after: 12)

    @Test func keptStreakHeadlinesAcrossFiveShakes() {
        let headlines = (0...5).map { ShakeProgress(shakes: $0, total: 5).headline(streak: kept) }
        #expect(headlines == [
            ShakeHeadline(key: "shake.streak.headline.start"),
            ShakeHeadline(key: "shake.streak.headline.counting", number: 11),
            ShakeHeadline(key: "shake.streak.headline.counting", number: 11),
            ShakeHeadline(key: "shake.streak.headline.counting", number: 11),
            ShakeHeadline(key: "shake.streak.headline.almost_count", number: 12),
            ShakeHeadline(key: "shake.streak.headline.kept"),
        ])
    }

    @Test(arguments: [StreakChange(before: 0, after: 1), StreakChange(before: 5, after: 5)])
    func headlinesSkipTheStreakWhenNoneIsKeptAcrossFourShakes(streak: StreakChange) {
        let headlines = (0...4).map { ShakeProgress(shakes: $0, total: 4).headline(streak: streak) }
        #expect(headlines == [
            ShakeHeadline(key: "today.action.shake"),
            ShakeHeadline(key: "shake.streak.headline.keep_going"),
            ShakeHeadline(key: "shake.streak.headline.keep_going"),
            ShakeHeadline(key: "shake.streak.headline.almost"),
            ShakeHeadline(key: "global.action.done"),
        ])
    }

    @Test func theLastShakeReadsAlmostUntilTheRevealLands() {
        let done = ShakeProgress(shakes: 5, total: 5)
        #expect(done.shown(revealed: false).headline(streak: kept)
            == ShakeHeadline(key: "shake.streak.headline.almost_count", number: 12))
        #expect(done.shown(revealed: false).halftoneIndex == 2)
        #expect(done.shown(revealed: true).headline(streak: kept) == ShakeHeadline(key: "shake.streak.headline.kept"))
        #expect(done.shown(revealed: true).halftoneIndex == 3)
    }

    @Test func counterRollsOneStepPerShake() {
        #expect(ShakeProgress(shakes: 0, total: 5).fraction == 0)
        #expect(ShakeProgress(shakes: 1, total: 5).fraction == 0.2)
        #expect(ShakeProgress(shakes: 3, total: 4).fraction == 0.75)
        #expect(ShakeProgress(shakes: 4, total: 4).fraction == 1)
    }

    @Test func extraShakesStayDone() {
        #expect(ShakeProgress(shakes: 7, total: 4) == ShakeProgress(shakes: 4, total: 4))
        #expect(ShakeProgress(shakes: 7, total: 4).isDone)
    }

    @Test func halftoneBoardDarkensPastTheHalfway() {
        #expect((0...5).map { ShakeProgress(shakes: $0, total: 5).halftoneIndex } == [0, 1, 1, 2, 2, 3])
        #expect((0...4).map { ShakeProgress(shakes: $0, total: 4).halftoneIndex } == [0, 1, 1, 2, 3])
    }
}

struct ShakeLoggedNoteTests {
    private func action(_ type: PillDay.ActionType, method: ContraceptiveMethod, cycleDay: Int) -> DoseScheduleAction {
        DoseScheduleAction(date: .now, type: type, method: method, cycleDay: cycleDay, cycleLength: 28)
    }

    @Test func pillNoteNamesThePillInThePack() {
        let note = ShakeLoggedNote(action: action(.pillActive, method: .pill, cycleDay: 12))
        #expect(note.key == "shake.logged.take_pill")
        #expect(note.pillNumber == 12)
        #expect(ShakeLoggedNote(action: action(.pillSugar, method: .pill, cycleDay: 24)).pillNumber == 24)
    }

    @Test(arguments: [
        (PillDay.ActionType.patchChange, ContraceptiveMethod.patch, 1, "shake.logged.apply_patch"),
        (.patchChange, .patch, 8, "shake.logged.change_patch"),
        (.patchRemove, .patch, 22, "shake.logged.remove_patch"),
        (.ringInsert, .ring, 1, "shake.logged.insert_ring"),
        (.ringReinsert, .ring, 29, "shake.logged.change_ring"),
        (.ringRemove, .ring, 22, "shake.logged.remove_ring"),
    ])
    func patchAndRingNotesMirrorTheHomeButton(
        type: PillDay.ActionType, method: ContraceptiveMethod, cycleDay: Int, key: String
    ) {
        let note = ShakeLoggedNote(action: action(type, method: method, cycleDay: cycleDay))
        #expect(note.key == key)
        #expect(note.pillNumber == nil)
    }
}

struct ShakeClipForActionTests {
    private func action(_ type: PillDay.ActionType, method: ContraceptiveMethod, cycleDay: Int = 5) -> DoseScheduleAction {
        DoseScheduleAction(date: .now, type: type, method: method, cycleDay: cycleDay, cycleLength: 28)
    }

    @Test func eachMethodStateOpensItsOwnWay() {
        #expect(ShakeClip(action: action(.pillActive, method: .pill)) == .pill)
        #expect(ShakeClip(action: action(.patchChange, method: .patch, cycleDay: 1)) == .patchApply)
        #expect(ShakeClip(action: action(.patchChange, method: .patch, cycleDay: 8)) == .patchChange)
        #expect(ShakeClip(action: action(.patchRemove, method: .patch)) == .patchRemove)
        #expect(ShakeClip(action: action(.ringInsert, method: .ring)) == .ringInsert)
        #expect(ShakeClip(action: action(.ringReinsert, method: .ring)) == .ringInsert)
        #expect(ShakeClip(action: action(.ringRemove, method: .ring)) == .ringRemove)
    }

    @Test func daysWithoutAPhysicalStepHaveNoClip() {
        #expect(ShakeClip(action: action(.pillBreak, method: .pill)) == nil)
        #expect(ShakeClip(action: action(.patchBreak, method: .patch)) == nil)
        #expect(ShakeClip(action: action(.ringBreak, method: .ring)) == nil)
    }
}

struct ShakeClipTests {
    @Test(arguments: [
        (ShakeClip.pill, 5),
        (.patchApply, 5),
        (.patchChange, 5),
        (.patchRemove, 4),
        (.ringInsert, 5),
        (.ringRemove, 4),
    ])
    func eachShakeRestsOnALaterPose(clip: ShakeClip, shakes: Int) {
        #expect(clip.shakeCount == shakes)
        let stops = (0...shakes).map(clip.stop(afterShakes:))
        #expect(zip(stops, stops.dropFirst()).allSatisfy { $0 < $1 })
        #expect(stops.allSatisfy(clip.poses.indices.contains))
        #expect(stops.last == clip.poses.count - 1)
    }

    @Test(arguments: [
        ShakeClip.pill, .patchApply, .patchChange, .patchRemove, .ringInsert, .ringRemove,
    ])
    func everyPoseHasItsArt(clip: ShakeClip) {
        let names = clip.poses.map(\.shell) + [clip.cutoutImage].compactMap { $0 }
        #expect(names.filter { UIImage(named: $0) == nil } == [])
    }

    @Test(arguments: [
        (ShakeClip.pill, 10),
        (.patchApply, 17),
        (.patchChange, 17),
        (.patchRemove, 8),
        (.ringInsert, 10),
        (.ringRemove, 8),
    ])
    func tappingThroughFromTheStartPlaysEveryLaterPose(clip: ShakeClip, lastPose: Int) {
        #expect(Array(clip.posesToPlay(from: 0, afterShakes: clip.shakeCount)) == Array(1...lastPose))
    }

    @Test func aShakeMidPlaybackCarriesOnFromThePoseOnScreen() {
        #expect(Array(ShakeClip.pill.posesToPlay(from: 1, afterShakes: 2)) == [2, 3])
        #expect(Array(ShakeClip.pill.posesToPlay(from: 6, afterShakes: 5)) == [7, 8, 9, 10])
        #expect(Array(ShakeClip.patchApply.posesToPlay(from: 2, afterShakes: 2)) == Array(3...11))
    }

    @Test func aShakeBehindThePoseOnScreenPlaysNothing() {
        #expect(ShakeClip.pill.posesToPlay(from: 3, afterShakes: 1).isEmpty)
        #expect(ShakeClip.patchApply.posesToPlay(from: 17, afterShakes: 2).isEmpty)
        #expect(ShakeClip.patchApply.posesToPlay(from: 17, afterShakes: 5).isEmpty)
        #expect(ShakeClip.ringInsert.posesToPlay(from: 4, afterShakes: 1).isEmpty)
    }

    @Test func secondShakeSeatsThePillInTheTornFoil() {
        let clip = ShakeClip.pill
        let seated = clip.poses[clip.stop(afterShakes: 2)]
        #expect(seated.shell == "ShakeLayerBlisterEmpty")
        #expect(seated.cutout != nil)
        #expect(clip.poses[clip.stop(afterShakes: 1)].cutout == nil)
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
        #expect(clip.poses[clip.stop(afterShakes: 0)].shell == "ShakeRingFullyOut")
        #expect(clip.poses[clip.stop(afterShakes: 4)].shell == "ShakeRingPouchResealed")
    }

    @Test func eachFrameShakeLandsOnTheNextPhoto() {
        let clip = ShakeClip.patchRemove
        #expect((1...4).map { clip.poses[clip.stop(afterShakes: $0)].shell } == [
            "ShakePatchPeeling", "ShakePatchHalfPeeled", "ShakePatchFolding", "ShakePatchFolded",
        ])
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
