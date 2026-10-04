//
//  ScheduleDraftTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct ScheduleDraftTests {
    private let twentyOneSeven = PackRegimen(activeDays: 21, breakDays: 7)
    private let twentyOneOnly = PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills)

    private func current(
        _ method: ContraceptiveMethod,
        regimen: PackRegimen,
        cycleDayIndex: Int,
        isTodayTaken: Bool
    ) -> ScheduleDraft.Current {
        ScheduleDraft.Current(method: method, regimen: regimen, cycleDayIndex: cycleDayIndex, isTodayTaken: isTodayTaken)
    }

    @Test func `the current pill opens on today with the taken dose ready to save`() {
        let draft = ScheduleDraft.seeded(.pill, from: current(.pill, regimen: twentyOneSeven, cycleDayIndex: 4, isTodayTaken: true))

        #expect(draft.method == .pill)
        #expect(draft.cycleDay == 5)
        #expect(draft.isComplete)
        #expect(draft.logsToday)
        #expect(draft.preset == .twentyOneSeven)
        #expect(draft.customRegimen == nil)
    }

    @Test func `the current pill not yet taken saves without logging`() {
        let draft = ScheduleDraft.seeded(.pill, from: current(.pill, regimen: twentyOneSeven, cycleDayIndex: 4, isTodayTaken: false))

        #expect(draft.cycleDay == 5)
        #expect(draft.isComplete)
        #expect(!draft.logsToday)
    }

    @Test func `a pill-free day asks nothing and is ready to save`() {
        let draft = ScheduleDraft.seeded(.pill, from: current(.pill, regimen: twentyOneOnly, cycleDayIndex: 23, isTodayTaken: false))

        guard case .pill(let selection) = draft else {
            Issue.record("expected a pill draft, got \(draft)")
            return
        }
        #expect(selection.dayIndex == 23)
        #expect(selection.answer == nil)
        #expect(draft.cycleDay == 24)
        #expect(draft.isComplete)
        #expect(!draft.logsToday)
        #expect(draft.preset == .twentyOneOnly)
    }

    @Test func `switching to the pill starts on a standard pack with no pill tapped`() {
        let draft = ScheduleDraft.seeded(.pill, from: current(.patch, regimen: twentyOneSeven, cycleDayIndex: 9, isTodayTaken: false))

        #expect(draft.method == .pill)
        #expect(draft.cycleDay == nil)
        #expect(!draft.isComplete)
        #expect(draft.preset == .twentyOneSeven)
    }

    @Test func `switching to the ring starts on day 1 waiting for an answer`() {
        let draft = ScheduleDraft.seeded(.ring, from: current(.pill, regimen: twentyOneSeven, cycleDayIndex: 4, isTodayTaken: true))

        #expect(draft.method == .ring)
        #expect(draft.cycleDay == 1)
        #expect(!draft.isComplete)
        #expect(!draft.logsToday)
        #expect(draft.preset == .twentyOneSeven)
        #expect(draft.customRegimen == nil)
    }

    @Test func `the current patch on a wearing day without a task is ready to save`() {
        let draft = ScheduleDraft.seeded(.patch, from: current(.patch, regimen: twentyOneSeven, cycleDayIndex: 9, isTodayTaken: false))

        #expect(draft.method == .patch)
        #expect(draft.cycleDay == 10)
        #expect(draft.isComplete)
        #expect(!draft.logsToday)
    }

    @Test func `the current patch on a change day carries today's answer`() {
        let draft = ScheduleDraft.seeded(.patch, from: current(.patch, regimen: twentyOneSeven, cycleDayIndex: 7, isTodayTaken: true))

        #expect(draft.cycleDay == 8)
        #expect(draft.isComplete)
        #expect(draft.logsToday)
    }

    @Test func `a custom pack saves as custom with its own regimen`() {
        let custom = PackRegimen(activeDays: 63, breakDays: 7)
        let draft = ScheduleDraft.seeded(.pill, from: current(.pill, regimen: custom, cycleDayIndex: 40, isTodayTaken: false))

        #expect(draft.preset == .custom)
        #expect(draft.customRegimen == PackRegimen(activeDays: 63, breakDays: 7))
        #expect(draft.cycleDay == 41)
        #expect(draft.isComplete)
    }

    @Test func `the save note names the restart point on the same method`() {
        let english = Locale(identifier: "en")
        let pill = ScheduleDraft.seeded(.pill, from: current(.pill, regimen: twentyOneSeven, cycleDayIndex: 8, isTodayTaken: false))
        let patch = ScheduleDraft.seeded(.patch, from: current(.patch, regimen: twentyOneSeven, cycleDayIndex: 9, isTodayTaken: false))

        #expect(pill.saveNote(from: .pill, locale: english) == "Saving clears your history and restarts from pill 9.")
        #expect(patch.saveNote(from: .patch, locale: english) == "Saving clears your history and restarts from day 10.")
    }

    @Test func `the save note names the method a switch leaves behind`() {
        let english = Locale(identifier: "en")
        let pillUser = current(.pill, regimen: twentyOneSeven, cycleDayIndex: 8, isTodayTaken: false)
        let ringUser = current(.ring, regimen: twentyOneSeven, cycleDayIndex: 2, isTodayTaken: false)

        #expect(ScheduleDraft.seeded(.patch, from: pillUser).saveNote(from: .pill, locale: english)
            == "Saving switches you to Patch and clears your pill history.")
        #expect(ScheduleDraft.seeded(.pill, from: ringUser).saveNote(from: .ring, locale: english)
            == "Saving switches you to Pill and clears your ring history.")
    }
}
