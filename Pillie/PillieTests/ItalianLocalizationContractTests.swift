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
            "Scegli il tuo metodo."
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

    func testWelcomeDemoChromeUsesItalianRuntimeCopy() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            PillieLocalization.string("onboarding.welcome.demo.reminder_title", locale: italian),
            "Check-in del pomeriggio"
        )
        XCTAssertEqual(
            PillieLocalization.formatted(
                "onboarding.welcome.demo.reminder_time",
                locale: italian,
                arguments: "14:00"
            ),
            "Promemoria · 14:00"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.welcome.demo.apps_title", locale: italian),
            "Le tue app"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.welcome.demo.apps_locked", locale: italian),
            "In pausa finché non fai il check-in"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.welcome.demo.apps_open", locale: italian),
            "Ti viene voglia di aprirle…"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.demo_label", locale: italian),
            "Demo"
        )
    }

    func testEarlyValueProofChromeAndHighRiskActionsUseCompactItalianCopy() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            PillieLocalization.string("onboarding.permission.cta", locale: italian),
            "Attiva notifiche"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.shake_title", locale: italian),
            "Scuoti per confermare"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.drag_title", locale: italian),
            "Trascina questo sulle tue app."
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.shake_body", locale: italian),
            "Scuoti ora il telefono oppure tocca questa scheda nel simulatore."
        )
        XCTAssertEqual(
            PillieLocalization.string("today.action.shake", locale: italian),
            "Scuoti per confermare"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.apps_label", locale: italian),
            "Le tue app"
        )
        XCTAssertEqual(
            PillieLocalization.string("onboarding.blocking_demo.locked_label", locale: italian),
            "In pausa"
        )
        XCTAssertEqual(
            PillieLocalization.formatted(
                "onboarding.blocking_demo.shake_progress",
                locale: italian,
                arguments: Int64(2), Int64(3)
            ),
            "2 di 3 scosse"
        )
    }

    func testPersonalisationOutcomeUsesCompleteNaturalItalianCopy() {
        XCTAssertEqual(
            PillieLocalization.string(
                "onboarding.personalise.outcome.confidence",
                locale: Locale(identifier: "it_IT")
            ),
            "La certezza di averlo fatto"
        )
    }

    func testDiagnosisAndBlockerAccessibilityUseItalianRuntimeCopy() {
        let italian = Locale(identifier: "it_IT")
        let content = ProtectionPlanDiagnosisContent.localized(locale: italian)

        XCTAssertEqual(
            content.analyzingAccessibilityLabel(signals: ["Messaggi", "21:05"]),
            "Il tuo piano promemoria. Rilevati: Messaggi, 21:05."
        )
        XCTAssertEqual(
            DistractionApp.messages.localizedDisplayName(locale: italian),
            "Messaggi"
        )
        XCTAssertEqual(
            BlockerSelectionState(applicationCount: 2, categoryCount: 1)
                .localizedAccessibilitySummary(locale: italian),
            "3 elementi selezionati"
        )
        XCTAssertEqual(
            BlockerSelectionState(applicationCount: 1, categoryCount: 0)
                .localizedAccessibilitySummary(locale: italian),
            "1 Elemento selezionato"
        )

        let genericDiagnosis = ProtectionPlanDiagnosis(
            primaryDistraction: .generic,
            protectedApps: [],
            method: .pill,
            dueActionTimeText: "21:05",
            riskWindow: nil,
            distractionChoices: [],
            delayConsequence: nil,
            missFrequency: nil,
            locale: italian
        )
        XCTAssertEqual(genericDiagnosis.mainRiskValue, "App che distraggono")
    }

    func testActiveOnboardingUsesCompactItalianPlanChrome() {
        let italian = Locale(identifier: "it_IT")
        let diagnosis = ProtectionPlanDiagnosisContent.localized(locale: italian)
        let routine = ProtectionPlanRoutineSummary(locale: italian)

        XCTAssertEqual(routine.cardLabel, "Il tuo piano")
        XCTAssertEqual(diagnosis.protectedAppsHeader, "App in pausa")
        XCTAssertEqual(
            ProtectionPlanRoutineSummary(method: .pill, locale: italian)
                .accessibilityHeadings,
            ["Il tuo piano promemoria"]
        )
        XCTAssertEqual(diagnosis.handNote, "Tutto pronto!")
    }

    func testDiagnosisCycleTileKeepsFullItalianDetailBehindCompactVisualCopy() {
        let italian = Locale(identifier: "it_IT")

        let pill = ProtectionPlanCycleStatContent.make(
            method: .pill,
            regimen: .twentyOneSeven,
            activeDays: 21,
            breakDays: 7,
            locale: italian
        )
        XCTAssertEqual(pill.compactValue, "21/7")
        XCTAssertEqual(pill.accessibilityValue, "21 giorni attivi, 7 giorni di pausa")

        let patch = ProtectionPlanCycleStatContent.make(
            method: .patch,
            regimen: .twentyOneSeven,
            activeDays: 21,
            breakDays: 7,
            locale: italian
        )
        XCTAssertEqual(patch.compactValue, "Cerotto")
        XCTAssertEqual(
            patch.accessibilityValue,
            ContraceptiveMethod.patch.localizedRoutineDescriptor(locale: italian)
        )

        let ring = ProtectionPlanCycleStatContent.make(
            method: .ring,
            regimen: .twentyOneSeven,
            activeDays: 21,
            breakDays: 7,
            locale: italian
        )
        XCTAssertEqual(ring.compactValue, "Anello")
        XCTAssertEqual(
            ring.accessibilityValue,
            ContraceptiveMethod.ring.localizedRoutineDescriptor(locale: italian)
        )
    }

    func testAppBlockingSetupUsesScreenTimeAndTrialAwareItalianCopy() {
        let content = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertEqual(
            content.trialDisclosure,
            "Il tuo trial gratis dura 14 giorni. Non serve la carta. Il blocco app si spegne quando finisce, e i promemoria restano gratis."
        )
        XCTAssertEqual(
            content.emptyDetail,
            "Usa Tempo di utilizzo di Apple per scegliere categorie o app."
        )
        XCTAssertEqual(
            content.authorizationDeniedTitle,
            "Il blocco delle app richiede l’autorizzazione"
        )
        XCTAssertEqual(
            content.authorizationDeniedDetail,
            "Consenti l’accesso a Tempo di utilizzo per scegliere e mettere in pausa le app."
        )
        XCTAssertEqual(content.selectedSummaryLabel, "App selezionate")
        XCTAssertEqual(
            content.selectedPrivacyNote,
            "Pillie riceve solo il numero di elementi selezionati. La selezione resta su questo dispositivo."
        )
        XCTAssertEqual(content.skipCTA, "Continua senza blocco app")
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
            ["Pillie time!", "Pillie time!", "Pillie time!"]
        )
        XCTAssertEqual(
            actions.map { $0.localizedFollowUpTitle(locale: italian) },
            Array(repeating: "Promemoria successivo", count: 3)
        )
        XCTAssertEqual(
            actions.map { $0.localizedFinalTitle(locale: italian) },
            Array(repeating: "Promemoria finale", count: 3)
        )
        XCTAssertEqual(
            NotificationManager.shared.reminderCategoryActionTitlesForTesting(
                isPlus: true,
                locale: italian
            ),
            ["Registra ora", "Ricordamelo più tardi"]
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
