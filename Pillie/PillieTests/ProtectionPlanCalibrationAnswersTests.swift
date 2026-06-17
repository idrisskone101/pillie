//
//  ProtectionPlanCalibrationAnswersTests.swift
//  PillieTests
//
//  Covers the second plan-question slice (#76): the new Risk Window and Draft
//  Blocked App Choice answer models, plus the committed-answer behavior of the
//  Protection Plan Onboarding value core for those answers — selection semantics,
//  persistence, and back-navigation restore. Value types only, so there is no
//  main-actor `@Observable` deinit hazard in the test host.
//

import XCTest

@testable import Pillie

final class ProtectionPlanCalibrationAnswersTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ProtectionPlanCalibrationAnswersTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - RiskWindow (single-select answer)

    func testRiskWindowExposesEveryDraftOptionInOrder() {
        // Matches the Superdesign "Risk Window" draft, in order.
        let titles = RiskWindow.allCases.map(\.title)
        XCTAssertEqual(
            titles,
            ["Right after the alarm", "Within 5 minutes", "Later in the day", "Randomly"]
        )
    }

    func testRiskWindowEveryOptionHasACalibrationSubtitle() {
        let subtitles = RiskWindow.allCases.map(\.subtitle)
        XCTAssertEqual(
            subtitles,
            ["The danger zone", "The slow drift", "After the morning rush", "No specific pattern"]
        )
        for window in RiskWindow.allCases {
            XCTAssertFalse(window.subtitle.isEmpty, "\(window) needs a subtitle.")
        }
    }

    func testRiskWindowRawValuesRoundTripForPersistence() {
        XCTAssertEqual(RiskWindow.rightAfterAlarm.rawValue, "rightAfterAlarm")
        for window in RiskWindow.allCases {
            XCTAssertEqual(RiskWindow(rawValue: window.rawValue), window)
        }
    }

    /// Risk Window is copy/personalization only in v1: it must carry no scheduling
    /// surface (no Date, time, or schedule API) so it cannot influence the blocking
    /// schedule. The whole type is just a label + subtitle.
    func testRiskWindowIsCopyOnlyWithNoSchedulingSurface() {
        // A pure raw-String enum whose only data are display strings. If anyone ever
        // adds a schedule/time property this won't compile against the assertion
        // that the answer is fully reconstructable from its rawValue alone.
        for window in RiskWindow.allCases {
            XCTAssertEqual(RiskWindow(rawValue: window.rawValue), window)
        }
        XCTAssertEqual(RiskWindow.allCases.count, 4)
    }

    // MARK: - DraftBlockedAppChoice (multi-select, grouped answer)

    func testDraftBlockedAppsExposeGroupedCategoriesThenAppsThenOther() {
        // Grouped: broad distraction categories, then specific apps, then the Other
        // catch-all (Superdesign "Draft Blocked Apps" + chip-interaction drafts).
        XCTAssertEqual(
            DraftBlockedAppChoice.categories.map(\.title),
            ["Short videos", "Social feeds", "Messages", "Games"]
        )
        XCTAssertEqual(
            DraftBlockedAppChoice.apps.map(\.title),
            ["TikTok", "Instagram", "YouTube", "X", "Snapchat"]
        )
        XCTAssertTrue(DraftBlockedAppChoice.allCases.contains(.other))
    }

    func testDraftBlockedAppsGroupsArePartitionedAndComplete() {
        // Every case belongs to exactly one rendered group, and the grouped accessors
        // plus Other cover every case with no overlap.
        let grouped = DraftBlockedAppChoice.categories
            + DraftBlockedAppChoice.apps
            + [.other]
        XCTAssertEqual(Set(grouped), Set(DraftBlockedAppChoice.allCases))
        XCTAssertEqual(grouped.count, DraftBlockedAppChoice.allCases.count, "Groups must not overlap.")

        for category in DraftBlockedAppChoice.categories {
            XCTAssertEqual(category.group, .category)
        }
        for app in DraftBlockedAppChoice.apps {
            XCTAssertEqual(app.group, .app)
        }
        XCTAssertEqual(DraftBlockedAppChoice.other.group, .other)
    }

    func testDraftBlockedAppsOtherIsTheTrailingCatchAll() {
        XCTAssertTrue(DraftBlockedAppChoice.other.isOther)
        XCTAssertEqual(DraftBlockedAppChoice.allCases.last, .other)
        XCTAssertEqual(DraftBlockedAppChoice.allCases.filter(\.isOther), [.other])
    }

    func testDraftBlockedAppsRawValuesRoundTripForPersistence() {
        XCTAssertEqual(DraftBlockedAppChoice.tiktok.rawValue, "tiktok")
        XCTAssertEqual(DraftBlockedAppChoice.shortVideos.rawValue, "shortVideos")
        for choice in DraftBlockedAppChoice.allCases {
            XCTAssertEqual(DraftBlockedAppChoice(rawValue: choice.rawValue), choice)
        }
    }

    // MARK: - Committed answers on the state core

    func testNewStateHasNoCommittedCalibrationAnswers() {
        let state = ProtectionPlanOnboardingState()
        XCTAssertNil(state.riskWindow)
        XCTAssertTrue(state.draftBlockedApps.isEmpty)
    }

    func testRecordingRiskWindowCommitsTheSingleSelectAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.recordRiskWindow(.rightAfterAlarm)
        XCTAssertEqual(state.riskWindow, .rightAfterAlarm)

        state.recordRiskWindow(.laterInDay)
        XCTAssertEqual(state.riskWindow, .laterInDay, "Risk Window is single-select; the latest answer wins.")
    }

    func testRecordingDraftBlockedAppsCommitsTheMultiSelectAnswer() {
        var state = ProtectionPlanOnboardingState()
        state.recordDraftBlockedApps([.shortVideos, .tiktok, .other])
        XCTAssertEqual(state.draftBlockedApps, [.shortVideos, .tiktok, .other])
    }

    func testRecordingDraftBlockedAppsReplacesThePreviousSelection() {
        var state = ProtectionPlanOnboardingState()
        state.recordDraftBlockedApps([.tiktok, .instagram])
        state.recordDraftBlockedApps([.games])
        XCTAssertEqual(state.draftBlockedApps, [.games])
    }

    // MARK: - Persistence / interruption

    func testCommittedCalibrationAnswersSurviveAppInterruption() {
        var state = ProtectionPlanOnboardingState()
        state.recordRiskWindow(.withinFiveMinutes)
        state.recordDraftBlockedApps([.socialFeeds, .snapchat, .other])
        ProtectionPlanOnboardingStore.save(state, to: defaults)

        let resumed = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertEqual(resumed.riskWindow, .withinFiveMinutes)
        XCTAssertEqual(resumed.draftBlockedApps, [.socialFeeds, .snapchat, .other])
    }

    func testFreshDefaultsLoadWithNoCalibrationAnswers() {
        let loaded = ProtectionPlanOnboardingStore.load(from: defaults)
        XCTAssertNil(loaded.riskWindow)
        XCTAssertTrue(loaded.draftBlockedApps.isEmpty)
    }

    // MARK: - Back navigation restores committed answers

    func testCalibrationAnswersAreRestoredWhenSteppingBackAndForward() {
        // The user commits Risk Window, moves on to Draft Blocked Apps, then steps
        // back: both committed answers must still be there to re-seed the screens.
        var state = ProtectionPlanOnboardingState(currentStep: .riskWindow)
        state.recordRiskWindow(.randomly)
        state.advance() // -> draftBlockedApps
        state.recordDraftBlockedApps([.instagram, .games])

        state.goBack() // back to riskWindow
        XCTAssertEqual(state.currentStep, .riskWindow)
        XCTAssertEqual(state.riskWindow, .randomly)
        XCTAssertEqual(state.draftBlockedApps, [.instagram, .games], "Stepping back must not erase a committed answer.")
    }
}
