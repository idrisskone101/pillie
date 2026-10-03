//
//  TrialStatusPresentation.swift
//  Pillie
//
//  Drives the truthful in-trial protection-status indicator and its status
//  sheet (issues #166/#220 / ADR 0007). Pure presentation logic (no SwiftUI) so the
//  visibility and day-count contract is testable as a value type: visible only
//  during an active Reverse Trial without an entitlement, with day copy that
//  agrees with the midnight-after-day-14 expiry rule ("ends tonight" on the
//  last protected day, never a misleading "0 days left").
//

import Foundation

struct TrialStatusPresentation: Equatable {
    /// Local-day rollovers until expiry (`ReverseTrialClock.daysRemaining`).
    let daysRemaining: Int
    let protectionActive: Bool
    let trialEndDate: Date?
    let locale: Locale
    let trialEndTerms: TrialEndAccessTerms
    let calendar: Calendar
    /// Clock question: expiry is the next local midnight. Not `daysRemaining == 1`.
    private let expiresTonight: Bool

    init(
        daysRemaining: Int,
        protectionActive: Bool = false,
        trialEndDate: Date? = nil,
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy,
        calendar: Calendar = .current,
        expiresTonight: Bool? = nil
    ) {
        self.daysRemaining = daysRemaining
        self.protectionActive = protectionActive
        self.trialEndDate = trialEndDate
        self.locale = locale
        self.trialEndTerms = trialEndTerms
        self.calendar = calendar
        self.expiresTonight = expiresTonight ?? (daysRemaining == 1)
    }

    /// Day count as shown to the user. Same clamp as the paywall stamp so
    /// the home badge and Plus screen never disagree.
    var displayedDaysRemaining: Int {
        ReverseTrialClock.displayedDaysRemaining(daysRemaining)
    }

    /// Whether the trial expires at tonight's local-day rollover — the whole
    /// last day is still protected, so copy says "ends tonight", never "0 days
    /// left" (misleading while active) or "1 days left".
    var endsTonight: Bool { expiresTonight }

    /// The persistent indicator. Once blocking is on it says Plus is on;
    /// before that it is a plain countdown (the setup strip owns the ask).
    var indicatorLabel: String {
        protectionActive ? activeLabel : countdownLabel
    }

    /// "%lld active days left", or "Ends tonight" on the last protected day.
    /// The badge and the sheet hero share it.
    var countdownLabel: String {
        endsTonight
            ? commerce("trial.status.indicator.countdown_tonight")
            : commerce("trial.status.indicator.countdown", Int64(displayedDaysRemaining))
    }

    private var activeLabel: String {
        endsTonight
            ? commerce("trial.status.indicator.active_tonight")
            : commerce("trial.status.indicator.active", Int64(displayedDaysRemaining))
    }

    /// The counted day the user is on, 1 through 14. Pairs with the countdown
    /// so "Day N" plus "M days left" always spans the 14 promised days.
    var currentDay: Int {
        min(max(1, ReverseTrialClock.fullDays + 1 - displayedDaysRemaining), ReverseTrialClock.fullDays)
    }

    /// Status and commerce only. Setup lives in the Today strip.
    var sheetContent: TrialStatusSheetContent {
        TrialStatusSheetContent(
            eyebrow: commerce("trial.status.eyebrow"),
            headline: countdownLabel,
            until: trialEndDate.map {
                PillieLocalization.formatted(
                    "trial.status.until",
                    table: "Commerce",
                    locale: locale,
                    arguments: longDate($0)
                )
            },
            progress: TrialProgress(
                filledDays: currentDay,
                totalDays: ReverseTrialClock.fullDays,
                todayLabel: commerce("trial.status.day_today", Int64(currentDay)),
                endLabel: trialEndDate.map { $0.formatted(dateStyle.day().month(.abbreviated)) }
            ),
            timelineTitle: commerce("trial.status.timeline_title"),
            timeline: timeline,
            ctaTitle: commerce("trial.status.keep_plus")
        )
    }

    /// The notices the planner will send (`trialNoticeSlots` with days before
    /// expiry), then the expiry day itself, all counted back from the real
    /// `ReverseTrialClock` expiry so a break week moves every date together.
    var timeline: [TrialTimelineRow] {
        guard let expiry = trialEndDate else { return [] }
        let warningKeys = [
            10: "trial.status.timeline.heads_up",
            13: "trial.status.timeline.last_call",
        ]
        let warnings = ReminderSchedulePlanner.trialNoticeSlots
            .filter { $0.calendarDaysBeforeExpiry > 0 }
            .compactMap { slot -> TrialTimelineRow? in
                guard let key = warningKeys[slot.day],
                      let date = calendar.date(
                        byAdding: .day,
                        value: -slot.calendarDaysBeforeExpiry,
                        to: expiry
                      )
                else { return nil }
                return row(date: date, key: key, symbol: "bell.fill")
            }
        let expiryKey = trialEndTerms == .hardPaywall
            ? "trial.status.timeline.plus_pauses"
            : "trial.status.timeline.blocking_off"
        return warnings + [row(date: expiry, key: expiryKey, symbol: "lock.fill")]
    }

    private func row(date: Date, key: String, symbol: String) -> TrialTimelineRow {
        TrialTimelineRow(
            date: date,
            dateText: longDate(date),
            text: commerce(key),
            symbol: symbol
        )
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    private func longDate(_ date: Date) -> String {
        date.formatted(dateStyle.day().month(.wide))
    }

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    private func commerce(_ key: String, _ count: Int64) -> String {
        PillieLocalization.formatted(key, table: "Commerce", locale: locale, arguments: count)
    }

    /// The indicator + sheet surface, or `nil` when no indicator should exist:
    /// entitled users (including mid-trial purchases), expired trials, or no
    /// trial ever granted.
    static func make(
        state: PlusAccessState,
        protectionActive: Bool = false,
        calendar: Calendar,
        now: Date,
        locale: Locale = .current,
        hardPaywallEnabled: Bool = false,
        termsCohort: TrialTermsCohort? = nil
    ) -> TrialStatusPresentation? {
        // Entitlement wins over a still-running trial clock: a mid-trial
        // purchase removes the indicator immediately.
        guard !state.hasEntitlement, let grantDate = state.trialGrantDate else { return nil }
        let clock = ReverseTrialClock(grantDate: grantDate, schedule: state.schedule)
        guard clock.isActive(calendar: calendar, now: now) else { return nil }
        let assignedTermsCohort = termsCohort
            ?? HardPaywallPolicy.cohort(forTrialGrantedAt: grantDate)
        return TrialStatusPresentation(
            daysRemaining: clock.daysRemaining(calendar: calendar, now: now),
            protectionActive: protectionActive,
            trialEndDate: clock.expiryMoment(calendar: calendar),
            locale: locale,
            trialEndTerms: HardPaywallPolicy.terms(
                for: assignedTermsCohort,
                hardPaywallEnabled: hardPaywallEnabled
            ),
            calendar: calendar,
            expiresTonight: clock.endsTonight(calendar: calendar, now: now)
        )
    }
}

/// Copy for the status-only trial sheet: countdown, expiry, a 14-day bar,
/// what happens next, and the quiet "Keep Plus" path into the existing
/// purchase flow.
struct TrialStatusSheetContent: Equatable {
    let eyebrow: String
    let headline: String
    let until: String?
    let progress: TrialProgress
    let timelineTitle: String
    let timeline: [TrialTimelineRow]
    let ctaTitle: String
}

struct TrialProgress: Equatable {
    let filledDays: Int
    let totalDays: Int
    let todayLabel: String
    let endLabel: String?
}

struct TrialTimelineRow: Equatable {
    let date: Date
    let dateText: String
    let text: String
    let symbol: String
}
