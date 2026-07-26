import XCTest

@testable import Pillie

final class ItalianLocalizationContractTests: XCTestCase {
    func testRequiredSetupAndReminderKeysResolveInItalianWithoutEnglishFallback() {
        let requiredKeys = [
            "onboarding.welcome.title",
            "onboarding.method.title",
            "onboarding.regimen.21_7",
            "onboarding.cycle_position.title",
            "onboarding.reminder_time.title",
            "onboarding.plan.title",
            "onboarding.permission.title",
            "onboarding.blocking_setup.title",
            "onboarding.ready.title",
            "notification.reminder.pill.title",
            "notification.reminder.patch.title",
            "notification.reminder.ring.title",
            "notification.action.complete",
            "notification.action.snooze",
        ]

        for key in requiredKeys {
            let localized = PillieLocalization.string(
                key,
                table: key.hasPrefix("notification.") ? "Notifications" : "Localizable",
                locale: Locale(identifier: "it")
            )
            XCTAssertNotEqual(localized, key, "Missing Italian localization for \(key)")
            XCTAssertFalse(localized.isEmpty, "Italian localization is empty for \(key)")
        }
    }

    func testOnboardingPresentationUsesCompleteItalianMethodScheduleAndTimeCopy() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            ProtectionPlanWelcomeContent.localized(locale: italian).title,
            "La sveglia per la tua pillola."
        )
        XCTAssertEqual(
            ProtectionPlanRoutineMethodContent.localized(locale: italian).title,
            "Scegli il tuo metodo"
        )
        XCTAssertEqual(
            ContraceptiveMethod.allCases.map { $0.localizedTitle(locale: italian) },
            ["Pillola", "Cerotto", "Anello"]
        )

        let summary = ProtectionPlanRoutineSummary(
            method: .pill,
            scheduleSummary: PillPack.PillRegimenPreset.twentyOneSeven.localizedScheduleSummary(
                locale: italian
            ),
            cycleDay: 8,
            reminderTimeText: ProtectionPlanRoutineSummary.clockText(
                hour12: 9,
                minute: 5,
                isPM: true,
                locale: italian
            ),
            locale: italian
        )

        XCTAssertEqual(summary.rows.map(\.label), ["Metodo", "Programma", "Ciclo attuale", "Promemoria"])
        XCTAssertEqual(summary.rows[1].value, "21 giorni attivi, 7 giorni di pausa")
        XCTAssertEqual(summary.rows[2].value, "Giorno 8")
        XCTAssertEqual(summary.reminderTimeText, "21:05")
        XCTAssertEqual(
            PillPack.PillRegimenPreset.twentyOneSeven.localizedRoutineDisplayName(locale: italian),
            "Standard"
        )
        XCTAssertEqual(
            PillPack.PillRegimenPreset.twentyOneSeven.localizedScheduleSubtitle(locale: italian),
            "21 giorni attivi, 7 giorni di pausa"
        )
        XCTAssertEqual(
            PillPack.PillRegimenPreset.threeSixtyFiveZero.localizedRoutineDisplayName(locale: italian),
            "Continuo"
        )
    }

    func testMethodAwareNotificationsAndCategoryActionsResolveInItalian() {
        let italian = Locale(identifier: "it_IT")
        let date = Date(timeIntervalSince1970: 1_767_225_600)
        let actions = [
            DoseScheduleAction(
                date: date,
                type: .pillActive,
                method: .pill,
                cycleDay: 1,
                cycleLength: 28
            ),
            DoseScheduleAction(
                date: date,
                type: .patchChange,
                method: .patch,
                cycleDay: 1,
                cycleLength: 28
            ),
            DoseScheduleAction(
                date: date,
                type: .ringInsert,
                method: .ring,
                cycleDay: 1,
                cycleLength: 28
            ),
        ]

        XCTAssertEqual(
            actions.map { $0.localizedReminderTitle(locale: italian) },
            ["Promemoria pillola", "Promemoria cerotto", "Promemoria anello"]
        )
        XCTAssertEqual(
            actions.map { $0.localizedFollowUpTitle(locale: italian) },
            Array(repeating: "Promemoria successivo", count: 3)
        )
        XCTAssertEqual(
            actions.map { $0.localizedFinalTitle(locale: italian) },
            Array(repeating: "Promemoria finale programmato", count: 3)
        )
        XCTAssertEqual(
            NotificationManager.shared.reminderCategoryActionTitlesForTesting(
                isPlus: true,
                locale: italian
            ),
            ["Segna come completata", "Ricordamelo più tardi"]
        )

        XCTAssertEqual(
            CustomReminderCopy.effective(
                custom: "Testo scritto dall’utente",
                default: actions[0].localizedReminderBody(locale: italian),
                cap: CustomReminderCopy.bodyCap,
                isPlus: true
            ),
            "Testo scritto dall’utente"
        )
    }

    func testPersistedBlockingReasonUsesItalianExtensionSafeCopy() {
        let italian = Locale(identifier: "it_IT")

        for method in ContraceptiveMethod.allCases {
            XCTAssertEqual(
                method.blockingReasonText(locale: italian),
                "L’azione Pillie di oggi è ancora da registrare."
            )
        }
    }

    func testCoveredSetupAndReminderCopyPassesConservativeClaimLint() {
        let locales = [Locale(identifier: "en_US"), Locale(identifier: "it_IT")]
        let prohibited = [
            "never miss",
            "non dimenticare mai",
            "guaranteed",
            "garantito",
            "always protected",
            "sempre protetta",
            "prevents pregnancy",
            "evita la gravidanza",
        ]

        for locale in locales {
            let copy = ProtectionPlanWelcomeContent.localized(locale: locale).visibleCopy
                + ProtectionPlanEarlyValueProofContent.localized(locale: locale).visibleCopy
                + [
                    PillieLocalization.string("notification.followup.body", locale: locale),
                    PillieLocalization.string("notification.final.body", locale: locale),
                    PillieLocalization.string("shield.blocking_reason", locale: locale),
                ]

            for line in copy {
                let normalized = line.lowercased(with: locale)
                for phrase in prohibited {
                    XCTAssertFalse(
                        normalized.contains(phrase),
                        "Prohibited claim '\(phrase)' appears in: \(line)"
                    )
                }
            }
        }
    }
}
