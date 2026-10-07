//
//  PaywallSuccessContentTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PaywallSuccessContentTests {
    private let locale = Locale(identifier: "en_US")
    private let regimen = PackRegimen(activeDays: 21, breakDays: 7)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(month: Int = 10, day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var now: Date { at(day: 7) }

    private func content(
        _ receipt: PaywallSuccessReceipt = .lifetime,
        isReturning: Bool = true,
        opensFromSettings: Bool = false,
        reminder: PaywallSuccessReminder? = nil,
        blockingSetUp: Bool = true,
        now: Date? = nil
    ) -> PaywallSuccessContent {
        .make(
            receipt: receipt,
            isReturning: isReturning,
            opensFromSettings: opensFromSettings,
            reminder: reminder,
            blockingSetUp: blockingSetUp,
            reminderHour: 20,
            reminderMinute: 0,
            now: now ?? self.now,
            calendar: calendar,
            locale: locale
        )
    }

    private func purchased(
        _ plan: PilliePlusPlan,
        price: String,
        period: DateComponents? = nil,
        intro: DateComponents? = nil,
        isTrial: Bool = false
    ) -> PaywallSuccessReceipt {
        .purchased(
            plan: plan, price: price, subscriptionPeriod: period, introductoryPeriod: intro,
            isTrial: isTrial, now: now, calendar: calendar
        )
    }

    private func action(_ type: PillDay.ActionType, method: ContraceptiveMethod, cycleDay: Int, on day: Int) -> DoseScheduleAction {
        DoseScheduleAction(
            date: calendar.startOfDay(for: at(day: day)), type: type, method: method, cycleDay: cycleDay, cycleLength: 28
        )
    }

    private func reminder(_ untaken: [DoseScheduleAction], now: Date, hour: Int = 20) -> PaywallSuccessReminder? {
        PaywallSuccessReminder.next(
            after: now, untaken: untaken, regimen: regimen, reminderHour: hour, reminderMinute: 0, calendar: calendar
        )
    }

    // MARK: Receipt

    @Test func `A yearly plan renews a year out with the year shown`() {
        let receipt = purchased(.annual, price: "$29.99", period: DateComponents(year: 1))

        #expect(content(receipt).receipt == "$29.99 a year, renews Oct 7, 2027")
    }

    @Test func `A monthly plan renews this year without the year`() {
        #expect(content(purchased(.monthly, price: "$4.99")).receipt == "$4.99 a month, renews Nov 7")
    }

    @Test func `A yearly plan with a free week says when the week ends`() {
        let receipt = purchased(.annual, price: "$29.99", period: DateComponents(year: 1), intro: DateComponents(day: 7), isTrial: true)

        #expect(content(receipt).receipt == "Free until Oct 14, then $29.99 a year")
    }

    @Test func `Lifetime and restore have their own lines`() {
        #expect(content(purchased(.lifetime, price: "$69.99")).receipt == "Paid once. It doesn\u{2019}t renew.")
        #expect(content(.restored).receipt == "Your purchase is back on this iPhone")
    }

    @Test func `Only a renewing subscription shows the Settings line`() {
        let manage = "Manage or cancel anytime in Settings"

        #expect(content(purchased(.annual, price: "$29.99")).manageLine == manage)
        #expect(content(purchased(.monthly, price: "$4.99", isTrial: true)).manageLine == manage)
        #expect(content(.lifetime).manageLine == nil)
        #expect(content(.restored).manageLine == nil)
    }

    // MARK: Header and button

    @Test func `A returning person is welcomed back`() {
        let returning = content(isReturning: true)

        #expect(returning.title == "Pillie Plus is on again.")
        #expect(returning.perksLabel == "Back on now")
    }

    @Test func `A first purchase drops the again`() {
        let first = content(isReturning: false)

        #expect(first.title == "Pillie Plus is on.")
        #expect(first.perksLabel == "Included in Plus")
    }

    @Test func `Perks read in the board's order`() {
        #expect(content().perks == ["App blocking", "Follow-up reminders", "Shake to check in", "Reminder messages"])
    }

    @Test func `Settings closes with Done and the trial wall goes back to today`() {
        #expect(content(opensFromSettings: true).button == "Done")
        #expect(content(opensFromSettings: false).button == "Back to today")
    }

    @Test func `The phone names the blocking time only when blocking is set up`() {
        #expect(content(blockingSetUp: true).phoneLine == "At 8:00\u{202F}PM your chosen apps pause until you check in.")
        #expect(content(blockingSetUp: false).phoneLine == "Pillie keeps reminding you until you check in.")
    }

    // MARK: Next reminder

    @Test func `An evening reminder today reads tonight`() {
        let next = reminder([action(.pillActive, method: .pill, cycleDay: 8, on: 7)], now: at(day: 7, hour: 10))

        #expect(content(reminder: next).reminder == PaywallSuccessContent.Reminder(
            label: "Next reminder", when: "Tonight at 8:00\u{202F}PM", step: "Pill 8 of 28"
        ))
    }

    @Test func `A morning reminder today reads today`() {
        let now = at(day: 7, hour: 7)
        let next = reminder([action(.pillActive, method: .pill, cycleDay: 8, on: 7)], now: now, hour: 8)

        #expect(content(reminder: next, now: now).reminder?.when == "Today at 8:00\u{202F}AM")
    }

    @Test func `A reminder already past today moves to the next untaken action`() {
        let now = at(day: 7, hour: 21)
        let next = reminder([
            action(.pillActive, method: .pill, cycleDay: 8, on: 7),
            action(.pillActive, method: .pill, cycleDay: 9, on: 8),
        ], now: now)

        let card = content(reminder: next, now: now).reminder
        #expect(card?.when == "Tomorrow at 8:00\u{202F}PM")
        #expect(card?.step == "Pill 9 of 28")
    }

    @Test func `A reminder days away names its day`() {
        let next = reminder([action(.patchChange, method: .patch, cycleDay: 8, on: 14)], now: now)

        let card = content(reminder: next).reminder
        #expect(card?.when == "Wed, Oct 14 at 8:00\u{202F}PM")
        #expect(card?.step == "Apply patch 2")
    }

    @Test func `Patch removal and the ring name their task`() {
        let steps = [
            action(.patchRemove, method: .patch, cycleDay: 22, on: 8),
            action(.ringInsert, method: .ring, cycleDay: 1, on: 8),
            action(.ringRemove, method: .ring, cycleDay: 22, on: 8),
        ].map { content(reminder: reminder([$0], now: now)).reminder?.step }

        #expect(steps == ["Remove patch 3", "Insert your ring", "Remove your ring"])
    }

    @Test func `A day whose only reminder has passed has no next reminder`() {
        let next = reminder([action(.pillActive, method: .pill, cycleDay: 8, on: 7)], now: at(day: 7, hour: 21))

        #expect(next == nil)
    }
}
