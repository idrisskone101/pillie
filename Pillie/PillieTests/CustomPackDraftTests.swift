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

    @Test func `the map shrinks only when 53 weeks would overflow`() {
        let short = CustomPackMapMetrics(columns: 13, availableWidth: 300)
        #expect(short.pitch == 20.2)
        #expect(short.dot == 15)

        let widest = CustomPackMapMetrics(columns: 53, availableWidth: 318)
        #expect(widest.pitch == 6)
        #expect(abs(widest.size.width - 316.46) < 0.01)
    }
}
