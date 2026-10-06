//
//  TrialExpiryWarningCopyKeyTests.swift
//  PillieTests
//
//  Which Notifications catalog key each Reverse Trial notice reads, per day and
//  setup cohort. Pure key selection: the catalog itself is covered by the
//  locale tests.
//

import Testing

@testable import Pillie

@Suite
struct TrialExpiryWarningCopyKeyTests {
    @Test
    func `Blocker cohort reads the blocking bodies and the shared expiry-day copy`() {
        let cohort = TrialEndPaywallCohort.blockerConfigured

        #expect(TrialExpiryWarningCopy.titleKey(day: 10) == "notification.trial_expiry.day10.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 10, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day10.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 13) == "notification.trial_expiry.day13.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 13, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day13.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 15) == "notification.trial_expiry.day15.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 15, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day15.body")
    }

    @Test
    func `Reminder-only cohort reads the reminders bodies and the shared expiry-day copy`() {
        let cohort = TrialEndPaywallCohort.reminderOnly

        #expect(TrialExpiryWarningCopy.titleKey(day: 10) == "notification.trial_expiry.day10.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 10, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day10.reminders.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 13) == "notification.trial_expiry.day13.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 13, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day13.reminders.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 15) == "notification.trial_expiry.day15.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 15, cohort: cohort, terms: .legacy) == "notification.trial_expiry.day15.body")
    }

    @Test
    func `Reminder-only cohort never reads a blocking body`() {
        let blockingBodies: Set = [
            "notification.trial_expiry.day10.body",
            "notification.trial_expiry.day13.body",
        ]
        let reminderOnlyBodies = Set([10, 13, 15].map {
            TrialExpiryWarningCopy.bodyKey(day: $0, cohort: .reminderOnly, terms: .legacy)
        })

        #expect(reminderOnlyBodies.isDisjoint(with: blockingBodies))
    }

    @Test
    func `Hard-paywall terms never promise free reminders in any notice`() {
        let english = Locale(identifier: "en")
        let expected = [
            10: "Choose a plan in the next 5 days to keep using Pillie.",
            13: "Choose a plan by tomorrow night to keep using Pillie.",
            15: "Choose monthly, annual, or lifetime to keep using Pillie.",
        ]

        for cohort in [TrialEndPaywallCohort.blockerConfigured, .reminderOnly] {
            for (day, body) in expected {
                #expect(TrialExpiryWarningCopy.body(day: day, cohort: cohort, terms: .hardPaywall, locale: english) == body)
            }
        }
    }
}
