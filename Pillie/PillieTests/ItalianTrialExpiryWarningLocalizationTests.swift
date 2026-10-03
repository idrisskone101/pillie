//
//  ItalianTrialExpiryWarningLocalizationTests.swift
//  PillieTests
//
//  Italian runtime copy for the Reverse Trial day-10/day-13 warning
//  notifications and the day-15 expiry-day notice. The timing must stay
//  aligned with ReverseTrialClock while keeping the health-neutral
//  app-blocking language from ADR 0007.
//

import Foundation
import XCTest

@testable import Pillie

final class ItalianTrialExpiryWarningLocalizationTests: XCTestCase {
    func testItalianWarningsUseDaySpecificExpiryTiming() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            TrialExpiryWarningCopy.title(day: 10, locale: italian),
            "La tua prova Plus finisce presto"
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 10, cohort: .blockerConfigured, locale: italian),
            "Il blocco app si disattiva tra 5 giorni. I promemoria giornalieri restano gratis."
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.title(day: 13, locale: italian),
            "La tua prova Plus sta per finire"
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 13, cohort: .blockerConfigured, locale: italian),
            "Il blocco app si disattiva domani sera. I promemoria giornalieri restano gratis."
        )
    }

    func testItalianReminderOnlyWarningsNameFollowUpsNotBlocking() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 10, cohort: .reminderOnly, locale: italian),
            "I tuoi promemoria successivi si fermano tra 5 giorni."
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 13, cohort: .reminderOnly, locale: italian),
            "I tuoi promemoria successivi si fermano domani sera."
        )
    }

    func testItalianExpiryDayNoticeReadsTheSameForBothCohorts() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            TrialExpiryWarningCopy.title(day: 15, locale: italian),
            "La tua prova di Plus è finita"
        )
        for cohort in [TrialEndPaywallCohort.blockerConfigured, .reminderOnly] {
            XCTAssertEqual(
                TrialExpiryWarningCopy.body(day: 15, cohort: cohort, locale: italian),
                "I promemoria giornalieri restano gratis. Plus aggiunge i promemoria successivi e il blocco app."
            )
        }
    }

    @MainActor
    func testScheduledWarningsUseItalianRuntimeCopy() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let trialStore = InMemoryTrialGrantStore()
        trialStore.saveGrantDate(now)
        SubscriptionManager.shared.setTrialGrantStoreForTesting(trialStore)
        SubscriptionManager.shared.setPlusForTesting(false)

        addTeardownBlock { @MainActor in
            SubscriptionManager.shared.setPlusForTesting(false)
            SubscriptionManager.shared.setTrialGrantStoreForTesting(InMemoryTrialGrantStore())
            InMemoryStoreFactory.resetClockAndDefaults()
        }

        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        let warnings = KeptNotificationManager.make(hasBlockerSetup: { true }).managedRequestSummariesForTesting(
            store: fixture.store,
            now: now,
            locale: Locale(identifier: "it_IT")
        )
        .filter { $0.requestKind == "trialExpiryWarning" && $0.trialWarningDay != 15 }
        .sorted { ($0.trialWarningDay ?? 0) < ($1.trialWarningDay ?? 0) }

        XCTAssertEqual(warnings.map(\.trialWarningDay), [10, 13])
        XCTAssertEqual(
            warnings.map(\.title),
            [
                "La tua prova Plus finisce presto",
                "La tua prova Plus sta per finire",
            ]
        )
        XCTAssertEqual(
            warnings.map(\.body),
            [
                "Il blocco app si disattiva tra 5 giorni. I promemoria giornalieri restano gratis.",
                "Il blocco app si disattiva domani sera. I promemoria giornalieri restano gratis.",
            ]
        )
    }
}
