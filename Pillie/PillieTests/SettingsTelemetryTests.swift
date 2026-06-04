//
//  SettingsTelemetryTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class SettingsTelemetryTests: XCTestCase {
    func testSupportedSettingsCategoriesAreLowCardinalityAndDoNotExposeUserValues() {
        let settings: [AnalyticsSetting] = [
            .reminderTime,
            .autoReminderInterval,
            .autoReminderRetryLimit,
            .supplyReminder,
            .protocol,
            .cycleDay,
            .blockedApps,
            .subscription
        ]

        XCTAssertEqual(settings.map(\.rawValue), [
            "reminder_time",
            "auto_reminder_interval",
            "auto_reminder_retry_limit",
            "supply_reminder",
            "protocol",
            "cycle_day",
            "blocked_apps",
            "subscription"
        ])
    }

    func testSettingsOpenSaveAndCancelEventsUseApprovedNames() {
        XCTAssertEqual(
            [
                AnalyticsEvent.settingsSheetOpened,
                .settingsChangeSaved,
                .settingsChangeCancelled
            ].map(\.rawValue),
            [
                "settings_sheet_opened",
                "settings_change_saved",
                "settings_change_cancelled"
            ]
        )
    }

    func testSettingsTelemetryPayloadUsesOnlySafeSettingCategory() {
        let properties = AnalyticsPayload(
            source: .settings,
            setting: .autoReminderInterval,
            isPlus: false
        ).properties

        XCTAssertEqual(properties, [
            "source": .string("settings"),
            "setting": .string("auto_reminder_interval"),
            "is_plus": .bool(false)
        ])
    }

    func testBlockedAppsTelemetryUsesOnlyCoarseSelectionBoolean() {
        let properties = AnalyticsPayload(
            source: .settings,
            setting: .blockedApps,
            isPlus: true,
            hasBlockingSelection: true
        ).properties

        XCTAssertEqual(Set(properties.keys), [
            "source",
            "setting",
            "is_plus",
            "has_blocking_selection"
        ])
        XCTAssertEqual(properties["has_blocking_selection"], .bool(true))
        XCTAssertNil(properties["app_name"])
        XCTAssertNil(properties["category_name"])
        XCTAssertNil(properties["token_identifier"])
        XCTAssertNil(properties["selection_count"])
    }

    func testSettingsPayloadDoesNotExposeSensitiveSettingValues() {
        let properties = AnalyticsPayload(
            source: .settings,
            setting: .supplyReminder,
            isPlus: false
        ).properties

        XCTAssertNil(properties["method"])
        XCTAssertNil(properties["regimen"])
        XCTAssertNil(properties["cycle_day"])
        XCTAssertNil(properties["reminder_time"])
        XCTAssertNil(properties["retry_interval"])
        XCTAssertNil(properties["supply_threshold"])
    }
}
