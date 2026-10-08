//
//  TrialEndExtendOfferCard.swift
//  Pillie
//

import Foundation

/// Every word and date on the extend offer card (Paper 3A), resolved from the
/// offer so the view only lays it out. Dates and the price come from
/// formatters and the store product, never from the catalog.
struct TrialEndExtendOfferCard: Equatable {
    /// The card says "7 more days" and "free week", so only a one-week intro
    /// offer may raise it. Any other length would make the copy untrue.
    static let supportedFreeDays = 7

    let restoreNote: String?
    let title: String
    let subtitle: String
    let stops: [Stop]
    let cta: String

    struct Stop: Equatable {
        let kind: Kind
        let date: String
        let headline: String
        let caption: String
    }

    enum Kind: Equatable {
        case today
        /// A notification goes out on this day.
        case reminder
        /// Notifications are off, so this row names the last day to cancel.
        case lastDayToCancel
        /// The headline is the yearly price; the sheet sets `price` itself
        /// largest, wherever the locale puts it in the headline.
        case charge(price: String)
    }

    static func make(
        offer: TrialEndExtendOffer,
        remindersAllowed: Bool,
        calendar: Calendar,
        locale: Locale
    ) -> TrialEndExtendOfferCard {
        let timeline = offer.timeline
        let lastDay = timeline.lastDayToCancel(calendar: calendar)
        let dates = TrialEndExtendDates(calendar: calendar, locale: locale)

        let middle: Stop = if remindersAllowed, let reminder = timeline.reminder {
            Stop(
                kind: .reminder,
                date: dates.weekdayMonthDay(reminder),
                headline: commerce("trial.end.extend.reminder.title", locale),
                caption: commerce("trial.end.extend.reminder.body", locale)
            )
        } else {
            Stop(
                kind: .lastDayToCancel,
                date: dates.weekdayMonthDay(lastDay),
                headline: commerce("trial.end.extend.last_day.title", locale),
                caption: commerce("trial.end.extend.last_day.body", locale)
            )
        }

        return TrialEndExtendOfferCard(
            restoreNote: offer.trigger == .restoreEmpty
                ? commerce("trial.end.extend.restore_empty", locale)
                : nil,
            title: commerce("trial.end.extend.title", locale),
            subtitle: PillieLocalization.formatted(
                "trial.end.extend.subtitle",
                table: "Commerce",
                locale: locale,
                arguments: dates.monthDay(lastDay)
            ),
            stops: [
                Stop(
                    kind: .today,
                    date: commerce("trial.timeline.today", locale),
                    headline: commerce("trial.end.extend.today.title", locale),
                    caption: commerce("trial.end.extend.today.body", locale)
                ),
                middle,
                Stop(
                    kind: .charge(price: offer.product.priceDisplay),
                    date: dates.weekdayMonthDay(timeline.charge),
                    headline: PillieLocalization.formatted(
                        "trial.end.extend.charge.price",
                        table: "Commerce",
                        locale: locale,
                        arguments: offer.product.priceDisplay
                    ),
                    caption: commerce("trial.end.extend.charge.body", locale)
                ),
            ],
            cta: commerce("trial.end.extend.cta", locale)
        )
    }

    private static func commerce(_ key: String, _ locale: Locale) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }
}

extension TrialEndExtendTimeline {
    /// The charge lands at the start time on the charge day, so the day
    /// before it is the last whole day to cancel and pay nothing.
    func lastDayToCancel(calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -1, to: charge) ?? charge
    }
}

/// "Oct 13" and "Mon, Oct 12" in the reader's locale and calendar.
struct TrialEndExtendDates {
    let calendar: Calendar
    let locale: Locale

    func monthDay(_ date: Date) -> String {
        date.formatted(style.month(.abbreviated).day())
    }

    func weekdayMonthDay(_ date: Date) -> String {
        date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
