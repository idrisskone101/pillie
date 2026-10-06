//
//  AppSelectionBlockerSaveTests.swift
//  PillieTests
//
//  Issue #82 — Native App Selection And Blocker Config Save.
//
//  The native picker + save path is locked behind AppBlockingManager (an
//  @Observable singleton over opaque, unconstructible Screen Time tokens), so the
//  testable behavior lives in the BlockerSelectionState value core: it is derived
//  only from token *counts*, never names. Value types only — no hosted-XCTest
//  deinit hazard (see xcode27-beta-mainactor-deinit-crash).
//

import XCTest
import FamilyControls

@testable import Pillie

final class AppSelectionBlockerSaveTests: XCTestCase {
    // MARK: - Tracer: empty selection cannot save (AC2)

    func testEmptySelectionCannotSaveBlockerConfig() {
        let state = BlockerSelectionState(applicationCount: 0, categoryCount: 0)

        XCTAssertTrue(state.isEmpty)
        XCTAssertFalse(state.canSaveBlockerConfig)
    }

    // MARK: - Valid selection saves and enables Finish (AC3)

    func testSelectionWithAppsCanSaveAndFinish() {
        let state = BlockerSelectionState(applicationCount: 2, categoryCount: 0)

        XCTAssertFalse(state.isEmpty)
        XCTAssertTrue(state.hasSelection)
        XCTAssertTrue(state.canSaveBlockerConfig)
        XCTAssertTrue(state.canFinish)
    }

    func testSelectionWithOnlyCategoriesCanSaveAndFinish() {
        // A category-only selection is still a valid blocker config.
        let state = BlockerSelectionState(applicationCount: 0, categoryCount: 3)

        XCTAssertEqual(state.selectedCount, 3)
        XCTAssertTrue(state.canSaveBlockerConfig)
        XCTAssertTrue(state.canFinish)
    }

    func testEmptySelectionDisablesFinish() {
        // AC3: the Finish CTA stays disabled while nothing is selected.
        let state = BlockerSelectionState(applicationCount: 0, categoryCount: 0)

        XCTAssertFalse(state.hasSelection)
        XCTAssertFalse(state.canFinish)
    }

    // MARK: - Whole-category selections from 2.2 builds collapse to their categories

    private func selection(includeEntireCategory: Bool, apps: Int, categories: Int) throws -> FamilyActivitySelection {
        func tokens(_ count: Int) -> [[String: String]] {
            (0..<count).map { _ in ["data": Data((0..<128).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()] }
        }
        let json: [String: Any] = [
            "includeEntireCategory": includeEntireCategory,
            "applicationTokens": tokens(apps),
            "categoryTokens": tokens(categories),
            "webDomainTokens": [],
            "untokenizedApplicationIdentifiers": [],
            "untokenizedCategoryIdentifiers": [],
            "untokenizedWebDomainIdentifiers": [],
        ]
        return try JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
    }

    func testWholeCategorySelectionCollapsesToItsCategories() throws {
        // "Social" expanded into its 200 installed apps hangs the picker; the
        // category token alone still shields every one of them.
        let collapsed = try selection(includeEntireCategory: true, apps: 200, categories: 1)
            .collapsingEntireCategories()

        XCTAssertFalse(collapsed.includeEntireCategory)
        XCTAssertEqual(collapsed.applicationTokens.count, 0)
        XCTAssertEqual(collapsed.categoryTokens.count, 1)
    }

    func testWholeCategorySelectionWithOnlyAppsKeepsThem() throws {
        let collapsed = try selection(includeEntireCategory: true, apps: 3, categories: 0)
            .collapsingEntireCategories()

        XCTAssertFalse(collapsed.includeEntireCategory)
        XCTAssertEqual(collapsed.applicationTokens.count, 3)
    }

    func testCategorySelectionCountsEachCategoryOnce() {
        let state = BlockerSelectionState(applicationCount: 1, categoryCount: 1)

        XCTAssertEqual(state.selectedCount, 2)
        XCTAssertEqual(state.countText, "2")
    }

    // MARK: - Privacy-safe, count-only summary (AC5)

    func testSummaryIsGenericCountOnly() {
        let state = BlockerSelectionState(applicationCount: 2, categoryCount: 1)

        XCTAssertEqual(state.countText, "3")
        XCTAssertEqual(state.accessibilitySummary, "3 selected")
    }

    func testSummaryDependsOnlyOnTotalCountNotComposition() {
        // The summary is a function of the total count alone, so the specific
        // apps/categories — and therefore their names — can never appear in it.
        let appsOnly = BlockerSelectionState(applicationCount: 3, categoryCount: 0)
        let mixed = BlockerSelectionState(applicationCount: 1, categoryCount: 2)

        XCTAssertEqual(appsOnly.accessibilitySummary, mixed.accessibilitySummary)
        XCTAssertEqual(appsOnly.countText, mixed.countText)
    }

    // MARK: - blocker_config_saved telemetry (AC4 / AC6)

    func testBlockerConfigSavedEventUsesStableLowCardinalityName() {
        XCTAssertEqual(AnalyticsEvent.blockerConfigSaved.rawValue, "blocker_config_saved")
    }

    func testBlockerConfigSavedPayloadNeverLeaksAppNamesTokensOrCounts() {
        // The save fires from onboarding's App Blocking step with the coarse
        // selection bit only. `AnalyticsPropertyValue` has no numeric case and the
        // payload has no app-name/token/count slot, so the boundary is structural.
        let properties = AnalyticsPayload(
            source: .onboarding,
            step: .appBlocking,
            isPlus: true,
            hasBlockingSelection: true
        ).properties

        XCTAssertEqual(properties["source"], .string("onboarding"))
        XCTAssertEqual(properties["step"], .string("app_blocking"))
        XCTAssertEqual(properties["is_plus"], .bool(true))
        XCTAssertEqual(properties["has_blocking_selection"], .bool(true))

        // Only the fixed, coarse key set — never an app name, token, or count.
        XCTAssertEqual(
            Set(properties.keys),
            ["source", "step", "is_plus", "has_blocking_selection"]
        )
        let countShapedKeys = properties.keys.filter { $0.contains("count") || $0.contains("num") }
        XCTAssertTrue(countShapedKeys.isEmpty, "No count-shaped property may appear: \(countShapedKeys)")
        let possibleCounts = Set((0...50).map(String.init))
        for value in properties.values {
            if case let .string(text) = value {
                XCTAssertFalse(possibleCounts.contains(text), "A selection count leaked into analytics: \(text)")
            }
        }
    }

    // MARK: - Selection feeds the completion classifier (activation vs reminder-only)

    func testValidSelectionActivatesWhileEmptyStaysReminderOnlyWhenAuthorized() {
        // The picker's saved selection (canSaveBlockerConfig) is exactly what feeds
        // ProtectionPlanCompletion.State.blockerConfigSaved. With Screen Time
        // authorized, a valid selection activates; an empty one stays reminder-only.
        let selected = BlockerSelectionState(applicationCount: 1, categoryCount: 1)
        let empty = BlockerSelectionState(applicationCount: 0, categoryCount: 0)

        let activated = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: true,
                blockerConfigSaved: selected.canSaveBlockerConfig
            )
        )
        let reminderOnly = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: true,
                blockerConfigSaved: empty.canSaveBlockerConfig
            )
        )

        XCTAssertEqual(activated, .protectionPlanActivated)
        XCTAssertEqual(reminderOnly, .reminderOnly)
    }
}
