//
//  TrialDayTenNoticeCopyTests.swift
//  PillieTests
//
//  The day-10 notice fires 5 calendar days before the trial ends, so its
//  hard-paywall body and the status sheet's row for it count calendar days.
//  A break inside those 5 days would make "5 active days" untrue.
//

import XCTest

@testable import Pillie

final class TrialDayTenNoticeCopyTests: XCTestCase {

    func testStatusSheetRowCountsCalendarDays() {
        XCTAssertEqual(headsUpRow("en"), "Pillie reminds you 5 days before it ends.")
        XCTAssertEqual(headsUpRow("de"), "Pillie erinnert dich 5 Tage, bevor deine Testphase endet.")
        XCTAssertEqual(headsUpRow("it"), "Pillie ti avvisa 5 giorni prima che la tua prova finisca.")
    }

    func testHardPaywallNoticeCountsCalendarDays() {
        XCTAssertEqual(
            hardPaywallBody("en"),
            "Your trial ends in 5 days. After that, your daily reminders stop until you pick a plan."
        )
        XCTAssertEqual(
            hardPaywallBody("de"),
            "Deine Testphase endet in 5 Tagen. Danach hören deine täglichen Erinnerungen auf, bis du einen Tarif wählst."
        )
        XCTAssertEqual(
            hardPaywallBody("it"),
            "La tua prova finisce tra 5 giorni. Poi i promemoria giornalieri si fermano finché non scegli un piano."
        )
    }

    /// The status sheet's first timeline row, which names the day-10 notice.
    private func headsUpRow(_ identifier: String) -> String? {
        let calendar = Calendar(identifier: .gregorian)
        let grant = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10))!
        return TrialStatusPresentation.make(
            state: PlusAccessState(hasEntitlement: false, trialGrantDate: grant),
            calendar: calendar,
            now: calendar.date(byAdding: .day, value: 1, to: grant)!,
            locale: Locale(identifier: identifier),
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )?.sheetContent.timeline.first?.text
    }

    private func hardPaywallBody(_ identifier: String) -> String {
        TrialExpiryWarningCopy.body(
            day: 10,
            cohort: .blockerConfigured,
            terms: .hardPaywall,
            locale: Locale(identifier: identifier)
        )
    }
}
