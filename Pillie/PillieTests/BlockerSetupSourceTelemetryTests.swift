//
//  BlockerSetupSourceTelemetryTests.swift
//  PillieTests
//
//  #163 (Reverse Trial 4/10): the activation metric "% of new users with blocker
//  configured on day 1" needs onboarding blocker setup told apart from Settings
//  blocker setup. screen_time_permission_requested/_completed and
//  blocker_config_saved carry `source: onboarding | settings` from both surfaces,
//  with unchanged event names and the existing PII boundary (coarse funnel
//  signals only — never app names or routine details).
//  Recorder + keep-alive style (no AnalyticsManager instance) per the hosted
//  XCTest @MainActor-deinit instability on the Xcode 27 beta.
//

import XCTest

@testable import Pillie

final class BlockerSetupSourceTelemetryTests: XCTestCase {

    // Held for the whole process: deallocating any Swift class inside a hosted
    // test aborts on the Xcode 27 beta (@MainActor deinit crash).
    private static let recorder = BlockerSourceAnalyticsRecorder()

    private func makeTelemetry() -> ProductAnalyticsTelemetry {
        ProductAnalyticsTelemetry(analytics: Self.recorder, isPlus: { true })
    }

    func testSettingsBlockerConfigSaveFiresDedicatedEventWithSettingsSource() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().settingsBlockerConfigSaved(hasSelection: true)

        let events = recorder.events.dropFirst(before)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            events.first,
            .init(
                event: .blockerConfigSaved,
                source: .settings,
                step: nil,
                result: nil,
                setting: nil,
                isPlus: true,
                hasBlockingSelection: true
            )
        )
    }

    func testSettingsScreenTimePermissionRequestFiresWithSettingsSource() {
        let recorder = Self.recorder
        let before = recorder.events.count

        makeTelemetry().settingsScreenTimePermissionRequested()

        let events = recorder.events.dropFirst(before)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            events.first,
            .init(
                event: .screenTimePermissionRequested,
                source: .settings,
                step: nil,
                result: nil,
                setting: nil,
                isPlus: true,
                hasBlockingSelection: nil
            )
        )
    }

    func testSettingsScreenTimePermissionCompletionCarriesSettingsSourceAndResult() {
        let recorder = Self.recorder
        let before = recorder.events.count

        let telemetry = makeTelemetry()
        telemetry.settingsScreenTimePermissionCompleted(isAuthorized: true)
        telemetry.settingsScreenTimePermissionCompleted(isAuthorized: false)

        let events = Array(recorder.events.dropFirst(before))
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(
            events,
            [
                .init(
                    event: .screenTimePermissionCompleted,
                    source: .settings,
                    step: nil,
                    result: .granted,
                    setting: nil,
                    isPlus: true,
                    hasBlockingSelection: nil
                ),
                .init(
                    event: .screenTimePermissionCompleted,
                    source: .settings,
                    step: nil,
                    result: .denied,
                    setting: nil,
                    isPlus: true,
                    hasBlockingSelection: nil
                ),
            ]
        )
    }
}

private final class BlockerSourceAnalyticsRecorder: AnalyticsTracking {
    struct Event: Equatable {
        let event: AnalyticsEvent
        let source: AnalyticsSource?
        let step: AnalyticsStep?
        let result: AnalyticsResult?
        let setting: AnalyticsSetting?
        let isPlus: Bool?
        let hasBlockingSelection: Bool?
    }

    private(set) var events: [Event] = []

    func track(
        _ event: AnalyticsEvent,
        source: AnalyticsSource?,
        step: AnalyticsStep?,
        stepIndex: Int?,
        screen: AnalyticsScreen?,
        plan: AnalyticsPlan?,
        result: AnalyticsResult?,
        setting: AnalyticsSetting?,
        acquisitionSource: AcquisitionSource?,
        isPlus: Bool?,
        hasBlockingSelection: Bool?,
        interventionCount: Int?,
        shakeCount: Int?,
        trialWarningDay: Int?,
        trialEndCohort: TrialEndPaywallCohort?,
        titleCustomized: Bool?,
        bodyCustomized: Bool?,
        retryTitleCustomized: Bool?,
        retryBodyCustomized: Bool?,
        lastCallTitleCustomized: Bool?,
        lastCallBodyCustomized: Bool?
    ) {
        events.append(
            Event(
                event: event,
                source: source,
                step: step,
                result: result,
                setting: setting,
                isPlus: isPlus,
                hasBlockingSelection: hasBlockingSelection
            )
        )
    }
}
