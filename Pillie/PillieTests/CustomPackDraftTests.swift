//
//  CustomPackDraftTests.swift
//  PillieTests
//

import CoreGraphics
import Foundation
import Testing

@testable import Pillie

struct CustomPackDraftTests {
    private let en = Locale(identifier: "en")

    private func draft(_ active: Int, _ breakDays: Int, _ kind: PackRegimen.BreakKind = .sugarPills) -> CustomPackDraft {
        CustomPackDraft(PackRegimen(activeDays: active, breakDays: breakDays, breakKind: kind))
    }

    @Test func `active days step within 1 to 365`() {
        var low = draft(1, 0)
        low.stepActive(by: -1)
        #expect(low.activeDays == 1)

        var high = draft(365, 0)
        high.stepActive(by: 1)
        #expect(high.activeDays == 365)

        var mid = draft(24, 4)
        mid.stepActive(by: 1)
        #expect(mid.regimen == PackRegimen(activeDays: 25, breakDays: 4))
    }

    @Test func `break days stop at 7 and at the 365 day cap`() {
        var seven = draft(21, 7)
        seven.stepBreak(by: 1)
        #expect(seven.breakDays == 7)

        var nearCap = draft(360, 5)
        nearCap.stepBreak(by: 1)
        #expect(nearCap.breakDays == 5)
        #expect(nearCap.breakRange == 0...5)

        var zero = draft(28, 0)
        zero.stepBreak(by: -1)
        #expect(zero.breakDays == 0)
    }

    @Test func `raising active days clamps the break down`() {
        var pack = draft(358, 7)
        pack.stepActive(by: 3)
        #expect(pack.regimen == PackRegimen(activeDays: 361, breakDays: 4))
    }

    @Test func `no pills survives a trip through a zero break`() {
        var pack = draft(21, 1, .noPills)
        pack.stepBreak(by: -1)
        #expect(pack.regimen.breakKind == .sugarPills)
        pack.stepBreak(by: 1)
        #expect(pack.regimen == PackRegimen(activeDays: 21, breakDays: 1, breakKind: .noPills))
    }

    @Test func `typed active days clamp to 1 through 365`() {
        var pack = draft(24, 4)
        pack.setActiveDays(typed: 0)
        #expect(pack.activeDays == 1)
        pack.setActiveDays(typed: 400)
        #expect(pack.regimen == PackRegimen(activeDays: 365, breakDays: 0))
        pack.setActiveDays(typed: 88)
        #expect(pack.activeDays == 88)
    }

    @Test func `typing keeps three digits and caps at 365`() {
        #expect(CustomPackDraft.sanitizedTyping("8a8") == "88")
        #expect(CustomPackDraft.sanitizedTyping("1000") == "100")
        #expect(CustomPackDraft.sanitizedTyping("366") == "365")
        #expect(CustomPackDraft.sanitizedTyping("") == "")
    }

    @Test func `keypad digits append and re-clamp on overshoot`() {
        #expect(CustomPackDraft.typingByAppending(8, to: "") == "8")
        #expect(CustomPackDraft.typingByAppending(8, to: "8") == "88")
        #expect(CustomPackDraft.typingByAppending(7, to: "36") == "365")
        #expect(CustomPackDraft.typingByAppending(9, to: "99") == "365")
    }

    @Test func `keypad backspace deletes the last digit and stops at empty`() {
        #expect(CustomPackDraft.typingByDeletingLastDigit(from: "88") == "8")
        #expect(CustomPackDraft.typingByDeletingLastDigit(from: "") == "")
    }

    @Test func `keypad done commits a clamped value or reverts when empty`() {
        #expect(CustomPackDraft.commitTyping("", previousValue: 24) == 24)
        #expect(CustomPackDraft.commitTyping("0", previousValue: 24) == 1)
        #expect(CustomPackDraft.commitTyping("88", previousValue: 24) == 88)
    }

    @Test func `a draft equal to a preset comes back as that preset`() {
        var pack = draft(88, 3)
        #expect(pack.choice.preset == .custom)
        pack.setActiveDays(typed: 24)
        pack.stepBreak(by: 1)
        #expect(pack.choice == PackChoice(preset: .twentyFourFour))
    }

    @Test func `packs up to five weeks draw as a grid, longer ones as a map`() {
        #expect(draft(28, 7).layout == .grid)
        #expect(draft(29, 7).layout == .map)
    }

    @Test func `captions describe the pack length`() {
        #expect(draft(24, 4).caption(locale: en) == "28-day pack · starts again every 4 weeks")
        #expect(draft(26, 4).caption(locale: en) == "30-day pack · then a new pack starts")
        #expect(draft(7, 0).caption(locale: en) == "7-day pack · starts again every week")
        #expect(draft(84, 7).caption(locale: en) == "91-day pack · 13 weeks, one column per week")
        #expect(draft(100, 3).caption(locale: en) == "103-day pack · about 15 weeks")
    }

    @Test func `a 13-week map keeps full-size dots and weekday labels in one band`() {
        let map = CustomPackMapMetrics(weeks: 13, availableWidth: 330)
        #expect(map.bands == 1)
        #expect(map.showsLabels)
        #expect(abs(map.dot - 15) < 0.05)
    }

    @Test func `a year-long pack wraps into two bands and drops the labels`() {
        let map = CustomPackMapMetrics(weeks: 53, availableWidth: 330)
        #expect(map.bands == 2)
        #expect(map.columnsPerBand == 27)
        #expect(!map.showsLabels)
        #expect(map.dot > 6.5)
    }

    @Test func `every map fits the fixed preview box`() {
        for weeks in 6...53 {
            let map = CustomPackMapMetrics(weeks: weeks, availableWidth: 330)
            #expect(map.size.height <= CustomPackMapMetrics.boxHeight + 0.01)
            let labelSpace = map.showsLabels ? CustomPackMapMetrics.labelWidth + CustomPackMapMetrics.labelGap : 0
            #expect(map.size.width + labelSpace <= 330 + 0.01)
        }
    }

    @Test func `week 28 of a two-band map starts the second band`() {
        let map = CustomPackMapMetrics(weeks: 53, availableWidth: 330)
        let first = map.origin(ofDay: 0)
        let wrapped = map.origin(ofDay: 27 * 7)
        #expect(wrapped.x == first.x)
        #expect(abs(wrapped.y - (map.bandHeight + CustomPackMapMetrics.bandGap)) < 0.01)
    }
}
