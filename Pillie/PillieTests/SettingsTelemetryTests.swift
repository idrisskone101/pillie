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
            .customReminders,
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
            "custom_reminders",
            "subscription"
        ])
    }

    func testCustomRemindersSavedPayloadCarriesOnlyCoarseCustomizationBooleans() {
        let properties = AnalyticsPayload(
            source: .settings,
            setting: .customReminders,
            isPlus: true,
            titleCustomized: true,
            bodyCustomized: false
        ).properties

        // Only the setting category, source, is_plus, and the two customization bits —
        // never the message strings or their lengths.
        XCTAssertEqual(Set(properties.keys), [
            "source",
            "setting",
            "is_plus",
            "title_customized",
            "body_customized"
        ])
        XCTAssertEqual(properties["setting"], .string("custom_reminders"))
        XCTAssertEqual(properties["title_customized"], .bool(true))
        XCTAssertEqual(properties["body_customized"], .bool(false))
        XCTAssertNil(properties["title"])
        XCTAssertNil(properties["body"])
        XCTAssertNil(properties["title_length"])
        XCTAssertNil(properties["body_length"])
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
