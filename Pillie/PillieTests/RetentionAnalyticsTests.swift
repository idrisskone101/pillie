import Foundation
import Testing
@testable import Pillie

struct StreakChangeReportTests {
    @Test func firstReadOnlyStoresABaseline() {
        #expect(StreakChangeReport.change(from: nil, to: 6, reason: nil) == nil)
    }

    @Test func unchangedStreakSendsNothing() {
        #expect(StreakChangeReport.change(from: 4, to: 4, reason: .packChange) == nil)
    }

    @Test func infersTheReasonFromTheDirection() {
        #expect(StreakChangeReport.change(from: 4, to: 5, reason: nil) == .init(from: 4, to: 5, reason: .logged))
        #expect(StreakChangeReport.change(from: 4, to: 0, reason: nil) == .init(from: 4, to: 0, reason: .missed))
    }

    @Test func explicitReasonWins() {
        #expect(StreakChangeReport.change(from: 5, to: 4, reason: .undone) == .init(from: 5, to: 4, reason: .undone))
        #expect(StreakChangeReport.change(from: 5, to: 0, reason: .packChange) == .init(from: 5, to: 0, reason: .packChange))
    }
}

struct RetentionAnalyticsTelemetryTests {
    private static var kept: [AnyObject] = []

    private func makeTelemetry() -> (ProductAnalyticsTelemetry, ProductAnalyticsSpy, UserDefaults) {
        let client = ProductAnalyticsSpy()
        let defaults = UserDefaults(suiteName: "RetentionAnalyticsTests.\(UUID().uuidString)")!
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
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false }), client, defaults)
    }

    @Test func notificationCheckInIsATodayActionCompleted() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.todayActionCompleted(source: .notification)
        telemetry.todayActionCompleted(source: .firstReminder)

        #expect(client.events.map(\.name) == ["today_action_completed", "today_action_completed"])
        #expect(client.events.map { $0.properties["source"] } == [.string("notification"), .string("first_reminder")])
    }

    @Test func onboardingTodayAnswerCarriesAnswerAndReminderPassed() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.onboardingTodayAnswer(.notYet, reminderPassed: true)

        #expect(client.events.map(\.name) == ["onboarding_today_answer"])
        #expect(client.events.first?.properties == [
            "source": .string("onboarding"),
            "answer": .string("not_yet"),
            "reminder_passed": .bool(true),
            "is_plus": .bool(false),
        ])
    }

    @Test func streakChangedCarriesFromToAndReason() {
        let (telemetry, client, _) = makeTelemetry()

        telemetry.streakChanged(.init(from: 3, to: 0, reason: .packChange))

        #expect(client.events.map(\.name) == ["streak_changed"])
        #expect(client.events.first?.properties == [
            "from": .int(3),
            "to": .int(0),
            "reason": .string("pack_change"),
            "is_plus": .bool(false),
        ])
    }

    @Test func plusSetupStripViewedSendsOncePerDay() {
        let (telemetry, client, defaults) = makeTelemetry()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)

        telemetry.plusSetupStripViewed(completedCount: 1, now: morning, defaults: defaults)
        telemetry.plusSetupStripViewed(completedCount: 1, now: morning.addingTimeInterval(3_600), defaults: defaults)
        telemetry.plusSetupStripViewed(completedCount: 2, now: morning.addingTimeInterval(86_400), defaults: defaults)

        #expect(client.events.map(\.name) == ["plus_setup_strip_viewed", "plus_setup_strip_viewed"])
        #expect(client.events.map { $0.properties["completed_count"] } == [.int(1), .int(2)])
    }

    @Test func firstReminderStateShownSendsOncePerInstall() {
        let (telemetry, client, defaults) = makeTelemetry()

        telemetry.firstReminderStateShown(defaults: defaults)
        telemetry.firstReminderStateShown(defaults: defaults)

        #expect(client.events.map(\.name) == ["first_reminder_state_shown"])
        #expect(client.events.first?.properties["source"] == .string("home"))
    }
}
