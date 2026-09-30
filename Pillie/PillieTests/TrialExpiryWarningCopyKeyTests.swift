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

        #expect(TrialExpiryWarningCopy.titleKey(day: 10, cohort: cohort) == "notification.trial_expiry.day10.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 10, cohort: cohort) == "notification.trial_expiry.day10.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 13, cohort: cohort) == "notification.trial_expiry.day13.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 13, cohort: cohort) == "notification.trial_expiry.day13.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 15, cohort: cohort) == "notification.trial_expiry.day15.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 15, cohort: cohort) == "notification.trial_expiry.day15.body")
    }

    @Test
    func `Reminder-only cohort reads the reminders bodies and the shared expiry-day copy`() {
        let cohort = TrialEndPaywallCohort.reminderOnly

        #expect(TrialExpiryWarningCopy.titleKey(day: 10, cohort: cohort) == "notification.trial_expiry.day10.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 10, cohort: cohort) == "notification.trial_expiry.day10.reminders.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 13, cohort: cohort) == "notification.trial_expiry.day13.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 13, cohort: cohort) == "notification.trial_expiry.day13.reminders.body")
        #expect(TrialExpiryWarningCopy.titleKey(day: 15, cohort: cohort) == "notification.trial_expiry.day15.title")
        #expect(TrialExpiryWarningCopy.bodyKey(day: 15, cohort: cohort) == "notification.trial_expiry.day15.body")
    }

    @Test
    func `Reminder-only cohort never reads a blocking body`() {
        let blockingBodies: Set = [
            "notification.trial_expiry.day10.body",
            "notification.trial_expiry.day13.body",
        ]
        let reminderOnlyBodies = Set([10, 13, 15].map {
            TrialExpiryWarningCopy.bodyKey(day: $0, cohort: .reminderOnly)
        })

        #expect(reminderOnlyBodies.isDisjoint(with: blockingBodies))
    }
}
