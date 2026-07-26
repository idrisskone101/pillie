//
//  TrialEndPaywallPresentation.swift
//  Pillie
//
//  Drives the Trial-End Paywall (issue #169 / ADR 0007 / CONTEXT.md): the Plus
//  offer shown once, as a dismissible full-screen sheet, on first launch after
//  a Reverse Trial expires. Pure presentation logic (no SwiftUI) so cohort
//  selection and own-stats assembly are testable as value types — including the
//  honesty contract from ADR 0002: real stats only, missing stats drop their
//  row instead of bragging zeros.
//

import Foundation

/// Which framing the expired user gets (ADR 0007): loss-framed around their own
/// trial record for the blocker-configured cohort, gain-framed for users who
/// never configured the blocker and so have nothing to lose yet. The raw value
/// is the `cohort` analytics property on `paywall_viewed`.
enum TrialEndPaywallCohort: String, Equatable {
    case blockerConfigured = "blocker_configured"
    case reminderOnly = "reminder_only"
}

/// The user's own trial record, as raw optionals: `nil` means the stat is
/// unknown and its row must be dropped — never shown as a zero brag.
struct TrialEndOwnStats: Equatable {
    var blocksIntercepted: Int?
    var dosesTaken: Int?
    var dosesDue: Int?
    var currentStreak: Int?

    /// No stats at all — the reminder-only cohort's input.
    static let none = TrialEndOwnStats(
        blocksIntercepted: nil, dosesTaken: nil, dosesDue: nil, currentStreak: nil
    )
}

/// Copy for the Trial-End Paywall. `nil` when the sheet must not exist:
/// entitled users, still-active trials, or no trial ever granted.
struct TrialEndPaywallContent: Equatable {
    /// One line of the dark own-record card. `emphasized` renders the value in
    /// coral (the blocks row); `valueSuffix` is the quiet "of 14" tail.
    struct RecordRow: Equatable {
        let label: String
        let value: String
        let valueSuffix: String?
        let emphasized: Bool
    }

    /// The dark centerpiece card: the user's own trial record (loss framing) or
    /// the "What Plus adds" perk chips (gain framing).
    enum CenterpieceCard: Equatable {
        case record(kicker: String, dateRange: String, rows: [RecordRow], quietShieldNote: String?)
        case perks(kicker: String, chips: [String], footnote: String)
    }

    let cohort: TrialEndPaywallCohort
    let title: String
    let titleAccent: String
    let subtitle: String
    let card: CenterpieceCard
    let handwrittenAside: String
    let primaryCTA: String

    static func make(
        state: PlusAccessState,
        blockerConfigSaved: Bool,
        stats: TrialEndOwnStats,
        calendar: Calendar,
        now: Date,
        locale: Locale = .current
    ) -> TrialEndPaywallContent? {
        guard !state.hasEntitlement, let grantDate = state.trialGrantDate,
              !state.trialActive(calendar: calendar, now: now) else {
            return nil
        }
        let cohort: TrialEndPaywallCohort = blockerConfigSaved ? .blockerConfigured : .reminderOnly
        if locale.language.languageCode?.identifier == "it" {
            return localized(
                cohort: cohort,
                grantDate: grantDate,
                stats: stats,
                calendar: calendar,
                locale: locale
            )
        }
        switch cohort {
        case .blockerConfigured:
            return lossFramed(grantDate: grantDate, stats: stats, calendar: calendar, now: now)
        case .reminderOnly:
            return gainFramed()
        }
    }

    private static func localized(
        cohort: TrialEndPaywallCohort,
        grantDate: Date,
        stats: TrialEndOwnStats,
        calendar: Calendar,
        locale: Locale
    ) -> TrialEndPaywallContent {
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: locale)
        }
        var rows: [RecordRow] = []
        if let blocks = stats.blocksIntercepted, blocks > 0 {
            rows.append(RecordRow(
                label: commerce("trial.end.blocks"),
                value: blocks.formatted(.number.locale(locale)),
                valueSuffix: nil,
                emphasized: true
            ))
        }
        if let actions = stats.dosesTaken, actions > 0 {
            rows.append(RecordRow(
                label: commerce("trial.end.actions"),
                value: actions.formatted(.number.locale(locale)),
                valueSuffix: nil,
                emphasized: false
            ))
        }
        if let streak = stats.currentStreak, streak > 0 {
            rows.append(RecordRow(
                label: commerce("trial.end.streak"),
                value: streak.formatted(.number.locale(locale)),
                valueSuffix: nil,
                emphasized: false
            ))
        }

        let card: CenterpieceCard = rows.isEmpty
            ? .perks(
                kicker: commerce("trial.end.free_title"),
                chips: [
                    commerce("paywall.feature.app_blocking"),
                    commerce("paywall.feature.shake"),
                    commerce("paywall.feature.smart_reminders"),
                    commerce("paywall.feature.custom_messages"),
                ],
                footnote: commerce("paywall.subtitle")
            )
            : .record(
                kicker: commerce("trial.end.title"),
                dateRange: localizedRecordDateRange(
                    grantDate: grantDate,
                    calendar: calendar,
                    locale: locale
                ),
                rows: rows,
                quietShieldNote: nil
            )

        return TrialEndPaywallContent(
            cohort: cohort,
            title: commerce("trial.end.title"),
            titleAccent: "",
            subtitle: commerce("trial.end.subtitle"),
            card: card,
            handwrittenAside: "",
            primaryCTA: commerce("paywall.action.upgrade")
        )
    }

    private static func localizedRecordDateRange(
        grantDate: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let expiry = ReverseTrialClock(grantDate: grantDate).expiryMoment(calendar: calendar)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: expiry) ?? expiry
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: grantDate)) – \(formatter.string(from: lastDay))"
    }

    // MARK: - Loss framing (blocker-configured cohort)

    private static func lossFramed(
        grantDate: Date,
        stats: TrialEndOwnStats,
        calendar: Calendar,
        now: Date
    ) -> TrialEndPaywallContent {
        let rows = recordRows(stats: stats)
        // No usable stat at all: nothing honest to anchor loss framing on, so
        // the record gives way to the perks card — never a wall of zeros.
        guard !rows.isEmpty else {
            return TrialEndPaywallContent(
                cohort: .blockerConfigured,
                title: "That was Plus,",
                titleAccent: "working for you.",
                subtitle: "Your 14 days ended — app blocking is now off. Reminders stay free forever.",
                card: perksCard,
                handwrittenAside: "worth keeping, right?",
                primaryCTA: "Keep my protection"
            )
        }
        // Zero blocks is the good outcome, not a failed stat: the counter row is
        // dropped and a shield note reframes the quiet trial. `nil` (unknown)
        // also drops the row but claims nothing (ADR 0002: real stats only).
        let quietShield = stats.blocksIntercepted == 0
        return TrialEndPaywallContent(
            cohort: .blockerConfigured,
            title: quietShield ? "Your quiet" : "That was Plus,",
            titleAccent: quietShield ? "safety net." : "working for you.",
            subtitle: "Your 14 days ended — app blocking is now off. Reminders stay free forever.",
            card: .record(
                kicker: "Your 14-day record",
                dateRange: recordDateRange(grantDate: grantDate, calendar: calendar),
                rows: rows,
                quietShieldNote: quietShield
                    ? "Your blocker stood guard all 14 days — it never had to step in. That's the good outcome."
                    : nil
            ),
            handwrittenAside: quietShield ? "quiet shield, strong streak" : "worth keeping, right?",
            primaryCTA: "Keep my protection"
        )
    }

    private static func recordRows(stats: TrialEndOwnStats) -> [RecordRow] {
        var rows: [RecordRow] = []
        if let blocks = stats.blocksIntercepted, blocks > 0 {
            rows.append(RecordRow(
                label: "Blocks intercepted", value: "\(blocks)", valueSuffix: nil, emphasized: true
            ))
        }
        // `taken > 0` too: "0 of 8" is a zero brag, not an anchor.
        if let taken = stats.dosesTaken, let due = stats.dosesDue, due > 0, taken > 0 {
            rows.append(RecordRow(
                label: "Doses on time", value: "\(taken)", valueSuffix: "of \(due)", emphasized: false
            ))
        }
        if let streak = stats.currentStreak, streak > 0 {
            rows.append(RecordRow(
                label: "Current streak",
                value: streak == 1 ? "🔥 1 day" : "🔥 \(streak) days",
                valueSuffix: nil,
                emphasized: false
            ))
        }
        return rows
    }

    /// "Jun 21 – Jul 5": grant day through the last protected day (the day
    /// before the midnight-after-day-14 expiry moment).
    private static func recordDateRange(grantDate: Date, calendar: Calendar) -> String {
        let clock = ReverseTrialClock(grantDate: grantDate)
        let expiry = clock.expiryMoment(calendar: calendar)
        let lastProtectedDay = calendar.date(byAdding: .day, value: -1, to: expiry) ?? expiry
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: grantDate)) – \(formatter.string(from: lastProtectedDay))"
    }

    // MARK: - Gain framing (reminder-only cohort)

    private static func gainFramed() -> TrialEndPaywallContent {
        TrialEndPaywallContent(
            cohort: .reminderOnly,
            title: "Reminders are",
            titleAccent: "free. Forever.",
            subtitle: "Your trial ended. Your reminders keep working — Plus is here whenever you want app blocking and more.",
            card: perksCard,
            handwrittenAside: "whenever you're ready!",
            primaryCTA: "Unlock Pillie Plus"
        )
    }

    private static var perksCard: CenterpieceCard {
        .perks(
            kicker: "What Plus adds",
            // Matches the Trial Granted Moment's perk list.
            chips: ["App blocking", "Shake to confirm", "Smart Reminders", "Custom messages"],
            footnote: "For the days a reminder isn't enough — apps you pick stay blocked until your dose is logged."
        )
    }
}
