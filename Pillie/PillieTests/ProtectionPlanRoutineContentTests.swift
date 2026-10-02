//
//  ProtectionPlanRoutineContentTests.swift
//  PillieTests
//
//  Verifies Routine Method and Reminder Time (#77) read their catalog keys and
//  respect Pillie's privacy / non-medical boundary. Value types only — no host crash.
//

import XCTest

@testable import Pillie

final class ProtectionPlanRoutineContentTests: XCTestCase {
    // MARK: - Routine Method

    func testRoutineMethodContentReadsItsCatalogKeysAndOffersEveryMethod() {
        let content = ProtectionPlanRoutineMethodContent.localized(locale: english)
        XCTAssertEqual(content.title, catalog("onboarding.method.title"))
        XCTAssertEqual(content.subtitle, catalog("onboarding.method.subtitle"))
        XCTAssertEqual(content.footnote, catalog("onboarding.plan.disclaimer"))
        XCTAssertEqual(content.primaryCTA, catalog("global.action.continue"))
        XCTAssertEqual(content.choices, [.pill, .patch, .ring])
    }

    func testEachMethodHasADistinctPlainLanguageDescriptor() {
        let descriptors = ContraceptiveMethod.allCases.map { $0.localizedRoutineDescriptor(locale: english) }
        XCTAssertEqual(descriptors, [
            catalog("onboarding.method.pill.subtitle"),
            catalog("onboarding.method.patch.subtitle"),
            catalog("onboarding.method.ring.subtitle"),
        ])
        XCTAssertEqual(Set(descriptors).count, ContraceptiveMethod.allCases.count)
    }

    func testRoutineMethodContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanRoutineMethodContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Reminder Time

    func testReminderTimeContentReadsItsCatalogKeys() {
        let content = ProtectionPlanReminderTimeContent.localized(locale: english)
        XCTAssertEqual(content.title, catalog("onboarding.reminder_time.title"))
        XCTAssertEqual(content.subtitle, catalog("onboarding.reminder_time.subtitle"))
        XCTAssertEqual(content.pickerLabel, catalog("onboarding.plan.schedule"))
        XCTAssertEqual(content.primaryCTA, catalog("onboarding.permission.cta"))
    }

    func testReminderTimeContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanReminderTimeContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Helpers

    private let english = Locale(identifier: "en")

    /// Copy passes rewrite the English, so assert the key each field reads. A key
    /// missing from the catalog resolves to itself, which this rejects.
    private func catalog(_ key: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let value = PillieLocalization.string(key, locale: english)
        XCTAssertNotEqual(value, key, "Missing catalog key \(key)", file: file, line: line)
        return value
    }

    private func assertNoMedicalOrFakeClaims(
        _ line: String,
        file: StaticString = #filePath,
        line lineNumber: UInt = #line
    ) {
        let banned = ["doctor", "prescri", "diagnos", "guarantee", "clinically", "% of users", "fda"]
        let lowered = line.lowercased()
        for term in banned {
            XCTAssertFalse(
                lowered.contains(term),
                "Copy must avoid medical/fake claims; found \"\(term)\" in: \(line)",
                file: file,
                line: lineNumber
            )
        }
        XCTAssertFalse(line.contains("%"), "Routine copy must not invent stats: \(line)", file: file, line: lineNumber)
    }
}
