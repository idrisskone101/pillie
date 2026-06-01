//
//  CoreEngagementAnalyticsTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class CoreEngagementAnalyticsTests: XCTestCase {
    func testCoreEngagementEventsUseApprovedEventNames() {
        let events: [AnalyticsEvent] = [
            .appLaunched,
            .appBecameActive,
            .tabSelected,
            .todayActionStarted,
            .todayActionCompleted,
            .todayActionUndone,
            .newPackOrCyclePrompted,
            .newPackOrCycleStarted
        ]

        XCTAssertEqual(
            events.map(\.rawValue),
            [
                "app_launched",
                "app_became_active",
                "tab_selected",
                "today_action_started",
                "today_action_completed",
                "today_action_undone",
                "new_pack_or_cycle_prompted",
                "new_pack_or_cycle_started"
            ]
        )
    }

    func testCoreEngagementPropertiesUseOnlyApprovedLowCardinalityKeys() {
        let properties = AnalyticsPayload(
            source: .home,
            screen: .calendar,
            isPlus: false
        ).properties

        XCTAssertEqual(Set(properties.keys), ["source", "screen", "is_plus"])
        XCTAssertEqual(properties["source"], .string("home"))
        XCTAssertEqual(properties["screen"], .string("calendar"))
        XCTAssertEqual(properties["is_plus"], .bool(false))
    }
}
