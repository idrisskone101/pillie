//
//  TrialEndExtendOfferCardTests.swift
//  PillieTests
//
//  The extend offer card's words and dates (Paper 3A) and its renewal
//  reminder (Paper "6 · Lock Screen"), built for a Wed Oct 7 2026 start.
//

import Foundation
import SwiftUI
import Testing
import UserNotifications

@testable import Pillie

struct TrialEndExtendOfferCardTests {
    private let english = Locale(identifier: "en_US")

    private var newYork: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func offer(_ trigger: TrialEndExtendTrigger = .sheetCancel, freeDays: Int = 7) -> TrialEndExtendOffer {
        let start = ISO8601DateFormatter().date(from: "2026-10-07T09:30:00-04:00")!
        return TrialEndExtendOffer(
            trigger: trigger,
            product: TrialEndExtendProduct(
                productID: SubscriptionManager.extendAnnualProductID,
                priceDisplay: "$29.99",
                freeDays: freeDays
            ),
            timeline: TrialEndExtendTimeline(start: start, freeDays: freeDays, calendar: newYork)!
        )
    }

    private func card(_ offer: TrialEndExtendOffer, remindersAllowed: Bool = true, locale: Locale? = nil) -> TrialEndExtendOfferCard {
        TrialEndExtendOfferCard.make(
            offer: offer,
            remindersAllowed: remindersAllowed,
            calendar: newYork,
            locale: locale ?? english
        )
    }

    @Test func `Cancel card reads like Paper 3A`() {
        let card = card(offer())

        #expect(card.restoreNote == nil)
        #expect(card.title == "Try Plus for\n7 more days.")
        #expect(card.subtitle == "No charge today. Cancel by Oct 13 to pay nothing.")
        #expect(card.stops == [
            .init(kind: .today, date: "Today", headline: "Plus is back on",
                  caption: "Reminders and app blocking work again."),
            .init(kind: .reminder, date: "Mon, Oct 12", headline: "We remind you",
                  caption: "A notification 2 days before you’re charged."),
            .init(kind: .charge(price: "$29.99"), date: "Wed, Oct 14", headline: "$29.99 a year",
                  caption: "Charged after your 7 free days. Renews every year until you cancel."),
        ])
        #expect(card.cta == "Start my free week")
    }

    @Test func `Notifications off swaps the reminder for the last day to cancel`() {
        let middle = card(offer(), remindersAllowed: false).stops[1]

        #expect(middle == .init(
            kind: .lastDayToCancel,
            date: "Tue, Oct 13",
            headline: "Last day to cancel",
            caption: "Notifications are off, so we can’t remind you. Cancel in Settings by the end of the day."
        ))
    }

    @Test func `Restore that found nothing adds the chip`() {
        #expect(card(offer(.restoreEmpty)).restoreNote == "No purchase found on this Apple Account")
    }

    @Test func `German dates come from the formatter`() {
        let card = card(offer(), locale: Locale(identifier: "de_DE"))

        #expect(card.subtitle == "Heute keine Kosten. Kündige bis zum 13. Okt. und du zahlst nichts.")
        #expect(card.stops.map(\.date) == ["Heute", "Mo. 12. Okt.", "Mi. 14. Okt."])
        #expect(card.stops.last?.headline == "$29.99 pro Jahr")
        #expect(card.stops.last?.caption == "Abbuchung nach deinen 7 Gratistagen. Verlängert sich jedes Jahr, bis du kündigst.")
    }

    @Test(arguments: [
        ("$29.99 a year", "$29.99", "$29.99"),
        ("Évi 29 990 Ft", "29 990 Ft", "29 990 Ft"),
        ("年額¥4,500", "¥4,500", "¥4,500"),
        ("$29.99", "$29.99", "$29.99"),
        ("29,99 € pro Jahr", "$29.99", "29,99 € pro Jahr"),
    ])
    func `Charge headline sets only the price at the price size`(headline: String, price: String, largeRun: String) {
        let text = TrialEndExtendSwap.chargeHeadline(headline, price: price)
        let large = text.runs
            .filter { $0.font == TrialEndExtendSwap.priceFont }
            .map { String(text[$0.range].characters) }
            .joined()
        #expect(large == largeRun)
        #expect(String(text.characters) == headline)
    }

    @Test func `Reminder fires at 20:00 two days before the charge with the Lock Screen copy`() throws {
        let request = try #require(TrialEndExtendReminder.request(offer: offer(), calendar: newYork, locale: english))
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)

        #expect(request.identifier == "pillie_trial_end_extend_renewal")
        #expect(request.content.title == "Plus renews on Oct 14")
        #expect(request.content.body
            == "Your free week ends in 2 days, then Plus costs $29.99 a year. To stop it, cancel in Settings by Oct 13.")
        #expect(request.content.userInfo[SmartReminderDelivery.requestKindKey] as? String == "trialEndExtendRenewal")
        #expect(trigger.repeats == false)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 10)
        #expect(trigger.dateComponents.day == 12)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test func `No reminder day means no request`() {
        #expect(TrialEndExtendReminder.request(offer: offer(freeDays: 2), calendar: newYork, locale: english) == nil)
    }

    @Test func `Reminder stays only while the extend plan is active and renewing`() {
        let extend = SubscriptionManager.extendAnnualProductID
        #expect(TrialEndExtendReminder.isStillDue(isActive: true, productID: extend, willRenew: true))
        #expect(!TrialEndExtendReminder.isStillDue(isActive: true, productID: extend, willRenew: false))
        #expect(!TrialEndExtendReminder.isStillDue(isActive: false, productID: extend, willRenew: true))
        #expect(!TrialEndExtendReminder.isStillDue(
            isActive: true, productID: SubscriptionManager.monthlyProductID, willRenew: true
        ))
        #expect(!TrialEndExtendReminder.isStillDue(isActive: false, productID: nil, willRenew: false))
    }
}
