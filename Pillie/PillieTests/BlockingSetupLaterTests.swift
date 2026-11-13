//
//  BlockingSetupLaterTests.swift
//  PillieTests
//
//  Setting up app blocking after onboarding: the editor's Screen Time stage
//  and the events that say which surface opened it. Value types and a spy
//  client only, no hosted views.
//

import Foundation
import Testing

@testable import Pillie

struct BlockedAppsAccessStageTests {
    @Test func `a never-asked install opens on the lead-in and waits`() {
        let stage = BlockedAppsAccessStage.opening(for: .notDetermined)

        #expect(stage == .leadIn)
        #expect(!stage.requestsOnOpen)
    }

    @Test func `an approved install opens straight on the editor`() {
        let stage = BlockedAppsAccessStage.opening(for: .approved)

        #expect(stage == .granted)
        #expect(!stage.requestsOnOpen)
    }

    @Test func `a refused install asks again on open`() {
        let stage = BlockedAppsAccessStage.opening(for: .denied)

        #expect(stage == .requesting)
        #expect(stage.requestsOnOpen)
    }

    @Test func `the request resolves to the editor or the refusal`() {
        #expect(BlockedAppsAccessStage.resolved(isAuthorized: true) == .granted)
        #expect(BlockedAppsAccessStage.resolved(isAuthorized: false) == .refused)
    }
}

struct BlockingSetupLaterTelemetryTests {
    private static var kept: [AnyObject] = []

    private func makeTelemetry() -> (ProductAnalyticsTelemetry, ProductAnalyticsSpy, UserDefaults) {
        let client = ProductAnalyticsSpy()
        let defaults = UserDefaults(suiteName: "BlockingSetupLaterTests.\(UUID().uuidString)")!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
                "CFBundleShortVersionString": "9.9",
                "CFBundleVersion": "999",
            ]
        )
        Self.kept.append(defaults)
        Self.kept.append(analytics)
        analytics.configure()
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { true }), client, defaults)
    }

    @Test func `editor screen time events carry the surface that opened it`() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.editorScreenTimeLeadInViewed(surface: .plusSetup)
        telemetry.editorScreenTimePermissionRequested(surface: .plusSetup)
        telemetry.editorScreenTimePermissionCompleted(isAuthorized: false, surface: .plusSetup)

        #expect(client.events.map(\.name) == [
            "screen_time_lead_in_viewed",
            "screen_time_permission_requested",
            "screen_time_permission_completed",
        ])
        #expect(client.events.map { $0.properties["surface"] } == Array(repeating: .string("plus_setup"), count: 3))
        #expect(client.events.map { $0.properties["source"] } == Array(repeating: .string("settings"), count: 3))
        #expect(client.events.last?.properties["result"] == .string("denied"))
    }

    @Test func `every editor surface has its own value`() {
        #expect(AnalyticsBlockerSetupSurface.allCases.map(\.rawValue) == [
            "settings", "home_blocking_card", "plus_setup", "update_trial",
        ])
    }

    @Test func `editor save carries the surface and the selection bit`() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.editorBlockerConfigSaved(hasSelection: true, surface: .homeBlockingCard)

        #expect(client.events.map(\.name) == ["blocker_config_saved"])
        #expect(client.events.first?.properties == [
            "source": .string("settings"),
            "surface": .string("home_blocking_card"),
            "has_blocking_selection": .bool(true),
            "is_plus": .bool(true),
        ])
    }

    @Test func `home blocking card reports its tap and dismissal`() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.homeBlockingCardTapped()
        telemetry.homeBlockingCardDismissed()

        #expect(client.events.map(\.name) == ["home_blocking_card_tapped", "home_blocking_card_dismissed"])
        #expect(client.events.first?.properties == [
            "source": .string("home"),
            "surface": .string("home_blocking_card"),
            "is_plus": .bool(true),
        ])
    }

    @Test func `home blocking card view sends once per day`() {
        let (telemetry, client, defaults) = makeTelemetry()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)

        telemetry.homeBlockingCardViewed(now: morning, defaults: defaults)
        telemetry.homeBlockingCardViewed(now: morning.addingTimeInterval(3_600), defaults: defaults)
        telemetry.homeBlockingCardViewed(now: morning.addingTimeInterval(86_400), defaults: defaults)

        #expect(client.events.map(\.name) == ["home_blocking_card_viewed", "home_blocking_card_viewed"])
    }
}

struct BlockingCardDismissalTests {
    private let dismissedAt = Date(timeIntervalSince1970: 1_790_000_000)

    private func dismissed() -> BlockingCardDismissal {
        var dismissal = BlockingCardDismissal()
        dismissal.dismiss(at: dismissedAt)
        return dismissal
    }

    @Test func `x hides the card and dates the dismissal`() {
        let dismissal = dismissed()

        #expect(dismissal.isDismissed)
        #expect(dismissal.dismissedAt == dismissedAt)
        #expect(!dismissal.hasReturned)
    }

    @Test func `the card stays hidden while no check-in slips`() {
        var dismissal = dismissed()

        dismissal.refresh(now: dismissedAt.addingTimeInterval(86_400), slips: [])

        #expect(dismissal.isDismissed)
    }

    @Test func `a slip from before the x does not bring the card back`() {
        // Dismissed while already late: that reminder fired before the X.
        var dismissal = dismissed()

        dismissal.refresh(
            now: dismissedAt.addingTimeInterval(3_600),
            slips: [dismissedAt.addingTimeInterval(-600)]
        )

        #expect(dismissal.isDismissed)
        #expect(!dismissal.hasReturned)
    }

    @Test func `the next late or missed check-in brings the card back once`() {
        var dismissal = dismissed()

        dismissal.refresh(
            now: dismissedAt.addingTimeInterval(90_000),
            slips: [dismissedAt.addingTimeInterval(-600), dismissedAt.addingTimeInterval(86_400)]
        )

        #expect(!dismissal.isDismissed)
        #expect(dismissal.hasReturned)
    }

    @Test func `the returned card stays up after the slip is checked in`() {
        var dismissal = dismissed()
        dismissal.refresh(now: dismissedAt.addingTimeInterval(90_000), slips: [dismissedAt.addingTimeInterval(86_400)])

        dismissal.refresh(now: dismissedAt.addingTimeInterval(91_000), slips: [])

        #expect(!dismissal.isDismissed)
    }

    @Test func `a second x is final`() {
        var dismissal = dismissed()
        dismissal.refresh(now: dismissedAt.addingTimeInterval(90_000), slips: [dismissedAt.addingTimeInterval(86_400)])
        let secondDismissal = dismissedAt.addingTimeInterval(91_000)
        dismissal.dismiss(at: secondDismissal)

        dismissal.refresh(
            now: secondDismissal.addingTimeInterval(200_000),
            slips: [secondDismissal.addingTimeInterval(86_400)]
        )

        #expect(dismissal.isDismissed)
        #expect(dismissal.hasReturned)
    }

    @Test func `a dismissal from before this rule counts from the first refresh`() {
        var dismissal = BlockingCardDismissal(isDismissed: true, dismissedAt: nil, hasReturned: false)
        let update = dismissedAt

        // The slip under way at the update is not held against the old X.
        dismissal.refresh(now: update, slips: [update.addingTimeInterval(-600)])
        #expect(dismissal.isDismissed)
        #expect(dismissal.dismissedAt == update)

        dismissal.refresh(now: update.addingTimeInterval(90_000), slips: [update.addingTimeInterval(86_400)])
        #expect(!dismissal.isDismissed)
        #expect(dismissal.hasReturned)
    }

    @Test func `a card that was never dismissed is left alone`() {
        var dismissal = BlockingCardDismissal()

        dismissal.refresh(now: dismissedAt, slips: [dismissedAt.addingTimeInterval(-600)])

        #expect(dismissal == BlockingCardDismissal())
    }
}
