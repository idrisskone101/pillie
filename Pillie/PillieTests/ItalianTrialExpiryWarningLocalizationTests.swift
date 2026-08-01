//
//  ItalianTrialExpiryWarningLocalizationTests.swift
//  PillieTests
//
//  Italian runtime copy for the Reverse Trial day-10/day-13 warning
//  notifications. The timing must stay aligned with ReverseTrialClock while
//  keeping the health-neutral app-blocking language from ADR 0007.
//

import Foundation
import XCTest

@testable import Pillie

final class ItalianTrialExpiryWarningLocalizationTests: XCTestCase {
    func testItalianWarningsUseDaySpecificExpiryTiming() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            TrialExpiryWarningCopy.title(day: 10, locale: italian),
            "La prova di Pillie Plus terminerà presto"
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 10, locale: italian),
            "Il blocco delle app si disattiverà tra 5 giorni. I promemoria resteranno gratuiti, per sempre."
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.title(day: 13, locale: italian),
            "La prova di Pillie Plus sta per terminare"
        )
        XCTAssertEqual(
            TrialExpiryWarningCopy.body(day: 13, locale: italian),
            "Il blocco delle app si disattiverà domani sera. I promemoria resteranno gratuiti, per sempre."
        )
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
        let warnings = NotificationManager.shared.managedRequestSummariesForTesting(
            store: fixture.store,
            now: now,
            locale: Locale(identifier: "it_IT")
        )
        .filter { $0.requestKind == "trialExpiryWarning" }
        .sorted { ($0.trialWarningDay ?? 0) < ($1.trialWarningDay ?? 0) }

        XCTAssertEqual(warnings.map(\.trialWarningDay), [10, 13])
        XCTAssertEqual(
            warnings.map(\.title),
            [
                "La prova di Pillie Plus terminerà presto",
                "La prova di Pillie Plus sta per terminare",
            ]
        )
        XCTAssertEqual(
            warnings.map(\.body),
            [
                "Il blocco delle app si disattiverà tra 5 giorni. I promemoria resteranno gratuiti, per sempre.",
                "Il blocco delle app si disattiverà domani sera. I promemoria resteranno gratuiti, per sempre.",
            ]
        )
    }
}
