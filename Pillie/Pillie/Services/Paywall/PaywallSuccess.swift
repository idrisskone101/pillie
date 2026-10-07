//
//  PaywallSuccess.swift
//  Pillie
//
//  What the purchase success screen (S2c) says and how it moves.
//

import Foundation
import RevenueCat
import SwiftUI

struct PaywallSuccessContent: Equatable {
    struct Reminder: Equatable {
        let label: String
        let when: String
        let step: String
    }

    let title: String
    let receipt: String
    let perksLabel: String
    /// Reading order: App blocking, Follow-up reminders, Shake to check in, Reminder messages.
    let perks: [String]
    let reminder: Reminder?
    let button: String
    /// Only a renewing subscription has something to cancel.
    let manageLine: String?
    /// The phone shield's line under "Plus is on".
    let phoneLine: String

    /// - Parameter isReturning: the person had Plus before this purchase: their trial
    ///   already ended, or the receipt is `.restored`. Drives the "again" title and
    ///   the "Back on now" perks label.
    static func make(
        receipt: PaywallSuccessReceipt,
        isReturning: Bool,
        opensFromSettings: Bool,
        reminder: PaywallSuccessReminder?,
        blockingSetUp: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> PaywallSuccessContent {
        let format = PaywallSuccessFormat(now: now, calendar: calendar, locale: locale)
        let dailyReminder = DoseWindow.reminder(
            for: now, hour: reminderHour, minute: reminderMinute, calendar: calendar
        ) ?? now

        let manageLine: String? = switch receipt {
        case .renewing, .freeTrial: format.commerce("paywall.success.manage")
        case .lifetime, .restored: nil
        }

        return PaywallSuccessContent(
            title: format.commerce(isReturning ? "trial.end.welcome_back" : "paywall.success.title.first"),
            receipt: format.receipt(receipt),
            perksLabel: format.commerce(isReturning ? "paywall.success.perks.returning" : "paywall.success.perks.first"),
            perks: [
                "paywall.feature.app_blocking",
                "paywall.feature.smart_reminders",
                "paywall.feature.shake",
                "paywall.feature.custom_messages",
            ].map { format.commerce($0) },
            reminder: reminder.map { reminder in
                Reminder(
                    label: format.app("onboarding.today_pill.plan.next_reminder"),
                    when: format.when(reminder.date),
                    step: format.step(reminder.step)
                )
            },
            button: opensFromSettings ? format.app("global.action.done") : format.commerce("trial.end.back_today"),
            manageLine: manageLine,
            phoneLine: blockingSetUp
                ? format.commerce("paywall.mockup.plus.blocking", format.time(dailyReminder))
                : format.commerce("paywall.mockup.plus.reminders")
        )
    }
}

enum PaywallSuccessReceipt: Equatable {
    case renewing(price: String, recurrence: PaywallRecurrence, renewsOn: Date)
    case freeTrial(price: String, recurrence: PaywallRecurrence, freeUntil: Date)
    case lifetime
    case restored

    /// Dates come from the product's periods, not the entitlement's expiration, so
    /// sandbox's accelerated renewals never reach the screen.
    static func purchased(
        plan: PilliePlusPlan,
        price: String,
        subscriptionPeriod: DateComponents?,
        introductoryPeriod: DateComponents?,
        isTrial: Bool,
        now: Date,
        calendar: Calendar
    ) -> PaywallSuccessReceipt {
        let recurrence: PaywallRecurrence
        switch plan {
        case .lifetime: return .lifetime
        case .annual: recurrence = .year
        case .monthly: recurrence = .month
        }
        if isTrial {
            let freeUntil = calendar.date(byAdding: introductoryPeriod ?? DateComponents(day: 7), to: now) ?? now
            return .freeTrial(price: price, recurrence: recurrence, freeUntil: freeUntil)
        }
        let fallback = recurrence == .year ? DateComponents(year: 1) : DateComponents(month: 1)
        let renewsOn = calendar.date(byAdding: subscriptionPeriod ?? fallback, to: now) ?? now
        return .renewing(price: price, recurrence: recurrence, renewsOn: renewsOn)
    }

    static func purchased(
        plan: PilliePlusPlan,
        product: StoreProduct,
        outcome: PurchaseOutcome,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PaywallSuccessReceipt {
        purchased(
            plan: plan,
            price: product.localizedPriceString,
            subscriptionPeriod: product.subscriptionPeriod.flatMap { dateComponents($0) },
            introductoryPeriod: product.introductoryDiscount.flatMap { dateComponents($0.subscriptionPeriod) },
            isTrial: outcome.isTrial,
            now: now,
            calendar: calendar
        )
    }

    private static func dateComponents(_ period: SubscriptionPeriod) -> DateComponents? {
        switch period.unit {
        case .day: DateComponents(day: period.value)
        case .week: DateComponents(day: period.value * 7)
        case .month: DateComponents(month: period.value)
        case .year: DateComponents(year: period.value)
        @unknown default: nil
        }
    }
}

struct PaywallSuccessReminder: Equatable {
    enum Step: Equatable {
        case pill(PackDay, PackRegimen)
        case patch(apply: Int)
        case patchOff
        case ringIn
        case ringOut

        init?(_ action: DoseScheduleAction, regimen: PackRegimen) {
            switch action.type {
            case .pillActive, .pillSugar:
                self = .pill(regimen.day(atIndex: action.cycleDay - 1), regimen)
            case .patchChange:
                self = .patch(apply: (action.cycleDay - 1) / RoutineDialDay.daysPerPatch + 1)
            case .patchRemove: self = .patchOff
            case .ringInsert, .ringReinsert: self = .ringIn
            case .ringRemove: self = .ringOut
            case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak: return nil
            }
        }
    }

    /// The day's base reminder, not a follow-up.
    let date: Date
    let step: Step

    /// The first untaken due action whose base reminder is still ahead of `now`.
    /// - Parameter untaken: untaken due actions in date order.
    static func next(
        after now: Date,
        untaken: [DoseScheduleAction],
        regimen: PackRegimen,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar
    ) -> PaywallSuccessReminder? {
        for action in untaken {
            guard let date = DoseWindow.reminder(
                for: action.date, hour: reminderHour, minute: reminderMinute, calendar: calendar
            ), date > now else { continue }
            return Step(action, regimen: regimen).map { PaywallSuccessReminder(date: date, step: $0) }
        }
        return nil
    }

    static func live(store: PillStore, now: Date, calendar: Calendar) -> PaywallSuccessReminder? {
        guard !NotificationPermission.shared.isDenied, !store.isRefillDue,
              let first = store.nextUntakenDueAction(from: calendar.startOfDay(for: now)) else { return nil }
        // Only today's action can already be past its reminder, so one more is enough.
        var untaken = [first]
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: first.date),
           let second = store.nextUntakenDueAction(from: nextDay) {
            untaken.append(second)
        }
        return next(
            after: now,
            untaken: untaken,
            regimen: store.pack.regimen,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            calendar: calendar
        )
    }
}

/// The S2c motion table. Every delay counts from StoreKit's success, the moment
/// the success sheet is inserted and the phone flips to `.plusOn`.
enum PaywallSuccessMotion {
    static let sheetRise: CGFloat = 480
    static let rowRise: CGFloat = 8
    static let sheet = Animation.spring(duration: 0.55, bounce: 0.12).delay(0.30)
    static let shieldFade = Animation.easeOut(duration: 0.15).delay(0.10)
    static let badge = Animation.spring(duration: 0.45, bounce: 0.45).delay(0.12)
    static let rings = Animation.easeOut(duration: 0.6).delay(0.12)
    static let hapticDelay: Duration = .seconds(0.32)
    static let settled: Duration = .seconds(1.14)

    static let fadeIn = Animation.easeOut(duration: 0.3).delay(0.15)
    static let reducedHapticDelay: Duration = .seconds(0.15)
    static let reducedSettled: Duration = .seconds(0.45)

    /// Rows are one sequence; an absent row closes its gap.
    static func row(_ index: Int) -> Animation {
        .easeOut(duration: 0.24).delay(0.42 + 0.06 * Double(index))
    }
}

/// Locale-bound formatting for one `make` call.
private struct PaywallSuccessFormat {
    let now: Date
    let calendar: Calendar
    let locale: Locale

    func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    func commerce(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: commerce(key), locale: locale, arguments: arguments)
    }

    func app(_ key: String) -> String {
        PillieLocalization.string(key, locale: locale)
    }

    func receipt(_ receipt: PaywallSuccessReceipt) -> String {
        switch receipt {
        case .renewing(let price, let recurrence, let renewsOn):
            let key = recurrence == .year ? "paywall.success.receipt.year" : "paywall.success.receipt.month"
            return commerce(key, price, day(renewsOn))
        case .freeTrial(let price, let recurrence, let freeUntil):
            let key = recurrence == .year ? "paywall.success.receipt.trial_year" : "paywall.success.receipt.trial_month"
            return commerce(key, day(freeUntil), price)
        case .lifetime:
            return commerce("paywall.success.receipt.lifetime")
        case .restored:
            return commerce("paywall.success.receipt.restored")
        }
    }

    func when(_ date: Date) -> String {
        let time = time(date)
        if calendar.isDate(date, inSameDayAs: now) {
            let key = calendar.component(.hour, from: date) >= 18
                ? "paywall.success.reminder.tonight"
                : "paywall.success.reminder.today"
            return commerce(key, time)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return commerce("paywall.success.reminder.tomorrow", time)
        }
        let weekday = date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
        return commerce("paywall.success.reminder.on_day", weekday, time)
    }

    func step(_ step: PaywallSuccessReminder.Step) -> String {
        switch step {
        case .pill(let day, let regimen):
            HomePackProgress.title(for: day, in: regimen, locale: locale)
        case .patch(let number):
            PillieLocalization.formatted("home.countdown.task.put_on_patch", locale: locale, arguments: number)
        case .patchOff:
            PillieLocalization.formatted(
                "home.countdown.task.take_off_patch", locale: locale, arguments: RoutineDialDay.patchCount
            )
        case .ringIn: app("home.countdown.task.ring_in")
        case .ringOut: app("home.countdown.task.ring_out")
        }
    }

    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(
            date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone
        ))
    }

    /// "Oct 7, 2027", or "Nov 7" inside the current year.
    private func day(_ date: Date) -> String {
        let monthDay = style.month(.abbreviated).day()
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return date.formatted(sameYear ? monthDay : monthDay.year())
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}

#if DEBUG
extension PaywallSuccessContent {
    enum DebugKind: String, CaseIterable {
        case annual
        case monthly
        case lifetime
        case restored
        case freeTrial
    }

    /// Fixed content for simulator QA without StoreKit: a Pill 8 of 28 reminder tonight at 8:00 PM.
    static func debugSample(_ kind: DebugKind, locale: Locale = PillieLocalization.appLocale) -> PaywallSuccessContent {
        let calendar = Calendar.current
        let now = Date.now
        let receipt: PaywallSuccessReceipt = switch kind {
        case .annual:
            .renewing(price: "$29.99", recurrence: .year, renewsOn: calendar.date(byAdding: .year, value: 1, to: now) ?? now)
        case .monthly:
            .renewing(price: "$4.99", recurrence: .month, renewsOn: calendar.date(byAdding: .month, value: 1, to: now) ?? now)
        case .lifetime: .lifetime
        case .restored: .restored
        case .freeTrial:
            .freeTrial(price: "$29.99", recurrence: .year, freeUntil: calendar.date(byAdding: .day, value: 7, to: now) ?? now)
        }
        let regimen = PackRegimen(activeDays: 21, breakDays: 7)
        let reminder = DoseWindow.reminder(for: now, hour: 20, minute: 0, calendar: calendar).map {
            PaywallSuccessReminder(date: $0, step: .pill(regimen.day(atIndex: 7), regimen))
        }
        return make(
            receipt: receipt,
            isReturning: kind != .monthly,
            opensFromSettings: kind == .monthly,
            reminder: reminder,
            blockingSetUp: kind != .lifetime,
            reminderHour: 20,
            reminderMinute: 0,
            now: now,
            calendar: calendar,
            locale: locale
        )
    }
}
#endif
