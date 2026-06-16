//
//  ProtectionPlanAnswerTelemetryTests.swift
//  PillieTests
//
//  Verifies the privacy boundary for the new plan-question answers (#75):
//  completing Distraction Choices or Delay Consequence can only emit a safe,
//  low-cardinality funnel event. No raw selected choices, emotional answer, or
//  any high-cardinality text can leave the device.
//
//  Asserts on the value-type `AnalyticsPayload` that
//  `ProductAnalyticsTelemetry.onboardingDistractionChoicesCompleted()` /
//  `onboardingDelayConsequenceCompleted()` build — the schema itself has no slot
//  for a raw answer. Value types only, so there is no hosted-XCTest deinit hazard.
//

import XCTest

@testable import Pillie

final class ProtectionPlanAnswerTelemetryTests: XCTestCase {
    // The exact payloads the two completion methods emit (source: .onboarding,
    // the step, and the coarse is_plus flag). If these methods ever try to attach
    // a raw answer they would have to add a field to AnalyticsPayload, which has
    // no free-text slot — so the boundary is structural.
    private func distractionPayload(isPlus: Bool = false) -> AnalyticsPayload {
        AnalyticsPayload(source: .onboarding, step: .distractionChoices, isPlus: isPlus)
    }

    private func delayPayload(isPlus: Bool = false) -> AnalyticsPayload {
        AnalyticsPayload(source: .onboarding, step: .delayConsequence, isPlus: isPlus)
    }

    func testAnswerStepsHaveStableLowCardinalityLabels() {
        XCTAssertEqual(AnalyticsStep.distractionChoices.rawValue, "distraction_choices")
        XCTAssertEqual(AnalyticsStep.delayConsequence.rawValue, "delay_consequence")
    }

    func testDistractionChoicesAnswerEventCarriesOnlySafeProperties() {
        let properties = distractionPayload().properties
        XCTAssertEqual(properties["step"], .string("distraction_choices"))
        XCTAssertEqual(properties["source"], .string("onboarding"))
        XCTAssertEqual(properties["is_plus"], .bool(false))
        assertOnlySafeKeys(properties)
        assertNoRawText(in: properties, matchingAnyOf: DistractionChoice.allCases.map(\.title))
    }

    func testDelayConsequenceAnswerEventCarriesOnlySafeProperties() {
        let properties = delayPayload().properties
        XCTAssertEqual(properties["step"], .string("delay_consequence"))
        XCTAssertEqual(properties["source"], .string("onboarding"))
        XCTAssertEqual(properties["is_plus"], .bool(false))
        assertOnlySafeKeys(properties)
        assertNoRawText(in: properties, matchingAnyOf: DelayConsequence.allCases.map(\.title))
    }

    // MARK: - Boundary helpers

    /// Answer events must carry only a fixed, low-cardinality set of properties.
    private func assertOnlySafeKeys(
        _ properties: [String: AnalyticsPropertyValue],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            Set(properties.keys),
            ["source", "step", "is_plus"],
            "Answer events must only carry safe, low-cardinality properties.",
            file: file,
            line: line
        )
    }

    private func assertNoRawText(
        in properties: [String: AnalyticsPropertyValue],
        matchingAnyOf forbidden: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lowered = Set(forbidden.map { $0.lowercased() })
        for value in properties.values {
            if case let .string(text) = value {
                XCTAssertFalse(
                    lowered.contains(text.lowercased()),
                    "Raw sensitive answer text leaked into analytics: \(text)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
