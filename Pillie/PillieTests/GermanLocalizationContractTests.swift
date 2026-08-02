import XCTest

@testable import Pillie

final class GermanLocalizationContractTests: XCTestCase {
    func testGermanOnboardingCompoundLabelsStayCompactForAccessibilityLayouts() {
        let german = Locale(identifier: "de_DE")
        let expectedByKey = [
            "onboarding.personalise.pain.title": "Was stört deine Routine?",
            "onboarding.personalise.choice.snooze": "Ich wische sie weg",
            "onboarding.personalise.choice.busy": "Ich bin beschäftigt",
            "onboarding.personalise.choice.forget": "Ich vergesse es",
            "onboarding.personalise.outcome.interruptions": "Weniger Störungen",
        ]

        for (key, expected) in expectedByKey {
            XCTAssertEqual(
                PillieLocalization.string(key, locale: german),
                expected,
                "German accessibility layout input drifted for \(key)"
            )
        }
    }

    func testRequiredSetupAndReminderKeysResolveInGermanWithoutEnglishFallback() {
        let expectedByKey = [
            "onboarding.welcome.title": "Der Wecker für deine Pille.",
            "onboarding.method.title": "Wähle deine Methode",
            "onboarding.regimen.21_7": "21 aktive Tage, 7 Pausentage",
            "onboarding.cycle_position.title": "Wo bist du in deiner Routine?",
            "onboarding.reminder_time.title": "Wähle eine Erinnerungszeit",
            "onboarding.plan.title": "Dein persönlicher Erinnerungsplan",
            "onboarding.permission.title": "Mitteilungen erlauben",
            "onboarding.blocking_setup.title": "Wähle Apps zum Pausieren",
            "onboarding.ready.title": "Deine Erinnerungen sind eingerichtet.",
            "notification.reminder.pill.title": "Pillenerinnerung",
            "notification.reminder.patch.title": "Pflastererinnerung",
            "notification.reminder.ring.title": "Ringerinnerung",
            "notification.action.complete": "Als erledigt markieren",
            "notification.action.snooze": "Später erinnern",
        ]
        let german = Locale(identifier: "de_DE")

        for (key, expected) in expectedByKey {
            let table = key.hasPrefix("notification.") ? "Notifications" : "Localizable"
            let localized = PillieLocalization.string(key, table: table, locale: german)

            XCTAssertEqual(localized, expected, "Incorrect German localization for \(key)")
        }
    }

    func testActiveAccessibilityAndSetupDetailsUseCompleteIdiomaticGerman() {
        let german = Locale(identifier: "de_DE")
        let expectedByKeyAndTable = [
            ("onboarding.cycle_position.calculated", "Localizable", "Aus deiner Auswahl berechnet"),
            ("onboarding.regimen.name.custom", "Localizable", "Individuell"),
            ("trial.decline_feedback.optional_note", "Commerce", "Deine Antwort ist freiwillig. Du kannst die Frage überspringen und Pillie kostenlos weiter nutzen."),
        ]

        for (key, table, expected) in expectedByKeyAndTable {
            XCTAssertEqual(
                PillieLocalization.string(key, table: table, locale: german),
                expected,
                "Incorrect German localization for \(key)"
            )
        }

        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: true,
                locale: german
            ),
            "im kostenlosen Tarif und in Plus enthalten"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: false,
                locale: german
            ),
            "nur im kostenlosen Tarif"
        )
    }

    func testOnboardingNotificationsAndShieldPresentFriendlyGermanCopy() {
        let german = Locale(identifier: "de_DE")
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
            ContraceptiveMethod.allCases.map { $0.localizedTitle(locale: german) },
            ["Pille", "Pflaster", "Ring"]
        )
        XCTAssertEqual(
            actions.map { $0.localizedReminderTitle(locale: german) },
            ["Pillenerinnerung", "Pflastererinnerung", "Ringerinnerung"]
        )
        XCTAssertEqual(
            NotificationManager.shared.reminderCategoryActionTitlesForTesting(
                isPlus: true,
                locale: german
            ),
            ["Als erledigt markieren", "Später erinnern"]
        )
        XCTAssertEqual(
            PillPack.PillRegimenPreset.twentyOneSeven.localizedScheduleSummary(locale: german),
            "21 aktive Tage, 7 Pausentage"
        )
        XCTAssertEqual(
            ProtectionPlanRoutineSummary.clockText(
                hour12: 9,
                minute: 5,
                isPM: true,
                locale: german
            ),
            "21:05"
        )
        XCTAssertEqual(
            ContraceptiveMethod.pill.blockingReasonText(locale: german),
            "Die heutige Aktion ist in Pillie noch offen."
        )
    }

    func testDailyUseAndCommercePresentLocaleCorrectGermanCopy() {
        let german = Locale(identifier: "de_DE")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)
        )!

        XCTAssertEqual(
            TodayActionState.completed.localizedPrimaryLabel(locale: german),
            "Erledigt · Rückgängig"
        )
        XCTAssertEqual(
            HistoryPresentation.monthSummary(
                completed: 3,
                percentage: 75,
                displayedMonth: date,
                locale: german
            ),
            HistoryPresentation.MonthSummary(
                title: "Dein Monatsüberblick",
                month: "Juli 2026",
                completedCount: "3 Einträge",
                completedBody: "bisher protokollierte Einträge",
                percentage: "75 % protokolliert"
            )
        )
        XCTAssertEqual(
            SettingsPresentation.interval(minutes: 10, locale: german),
            "Alle 10 Minuten"
        )
        XCTAssertEqual(
            SettingsPresentation.cycleDay(day: 3, total: 28, locale: german),
            "Tag 3 von 28"
        )
        XCTAssertEqual(
            CommercePresentation.priceAndPeriod(
                displayPrice: "29,99 €",
                periodValue: 1,
                periodUnit: .year,
                locale: german
            ),
            "29,99 € pro Jahr"
        )
        XCTAssertEqual(
            CommercePresentation.priceAndPeriod(
                displayPrice: "14,99 €",
                periodValue: 3,
                periodUnit: .month,
                locale: german
            ),
            "14,99 € alle 3 Monate"
        )
        XCTAssertEqual(
            CommercePresentation.trialEndText(date: date, locale: german),
            "Testphase endet am 15. Juli 2026"
        )

        let authored = CustomReminderMessages(
            dueTitle: "💊 Mein Titel ",
            dueBody: "Nicht ändern — Byte für Byte\nzweite Zeile",
            retryTitle: "Retry: 12:34",
            retryBody: "Apostroph ' und Umlaut ü",
            lastCallTitle: "FINAL_custom",
            lastCallBody: "🌙"
        )
        XCTAssertEqual(CustomReminderDraft(messages: authored).messages, authored)
    }

    func testGermanSingularCountsUseNaturalGrammar() {
        let german = Locale(identifier: "de_DE")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)
        )!

        XCTAssertEqual(
            HistoryPresentation.monthSummary(
                completed: 1,
                percentage: 25,
                displayedMonth: date,
                locale: german
            ).completedCount,
            "1 Eintrag"
        )
        XCTAssertEqual(
            SettingsPresentation.interval(minutes: 1, locale: german),
            "Jede Minute"
        )
    }

    func testGermanReminderPresetsUseGermanDefaultsWithoutChangingAuthoredText() {
        let german = Locale(identifier: "de_DE")

        XCTAssertEqual(
            CustomReminderPreset.allCases.map {
                $0.localizedDisplayName(locale: german)
            },
            ["Sanft", "Direkt", "Ermutigend", "Diskret"]
        )
        XCTAssertEqual(
            CustomReminderPreset.gentle.localizedMessages(locale: german),
            CustomReminderMessages(
                dueTitle: "Eine sanfte Erinnerung",
                dueBody: "Eine sanfte Erinnerung an deine Routine.",
                retryTitle: "Folgeerinnerung",
                retryBody: "Wenn du bereit bist, denk daran, die heutige Aktion zu protokollieren.",
                lastCallTitle: "Letzte geplante Erinnerung",
                lastCallBody: "Für heute ist noch eine letzte Erinnerung geplant."
            )
        )

        let authored = CustomReminderMessages(
            dueTitle: "💊 Mein Titel ",
            dueBody: "Unverändert\nzweite Zeile",
            retryTitle: "Benutzerdefiniert",
            retryBody: "Text ' mit Umlaut ü",
            lastCallTitle: "FINAL_custom",
            lastCallBody: "🌙"
        )
        XCTAssertEqual(CustomReminderDraft(messages: authored).messages, authored)
    }

    func testEveryPillRegimenHasAGermanScheduleSummary() {
        let german = Locale(identifier: "de_DE")

        XCTAssertEqual(
            PillPack.PillRegimenPreset.allCases.map {
                $0.localizedScheduleSummary(locale: german)
            },
            [
                "21 aktive Tage, 7 Pausentage",
                "24 aktive Tage, 4 Pausentage",
                "26 aktive Tage, 2 Pausentage",
                "28 aktive Tage, keine Pause",
                "84 aktive Tage, 7 Pausentage",
                "365 aktive Tage, keine Pause",
                "Eigener Zyklus",
            ]
        )
    }

    func testTrialAndBlockingStatesPresentGermanWithoutEnglishFallback() throws {
        let german = Locale(identifier: "de_DE")
        let entitledCard = try XCTUnwrap(
            BlockingStatusCardContent.make(
                for: .incompleteEntitled,
                locale: german
            )
        )
        XCTAssertEqual(entitledCard.title, "App-Pause ist deaktiviert")
        XCTAssertEqual(entitledCard.ctaTitle, "Apps auswählen")

        let protectionOff = try XCTUnwrap(
            ProtectionOffCardContent.make(
                hasPlusAccess: false,
                blockerConfigSaved: true,
                locale: german
            )
        )
        XCTAssertEqual(protectionOff.title, "App-Pause ist deaktiviert")
        XCTAssertEqual(protectionOff.ctaTitle, "Zu Pillie Plus wechseln")

        let trial = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: true,
            locale: german
        )
        XCTAssertEqual(trial.indicatorLabel, "App-Pause aktiv · noch 7 Tage")
        XCTAssertEqual(
            trial.sheetContent.ctaTitle,
            "Pillie Plus behalten"
        )

        let activationItems = TrialActivationItem.make(
            for: .unconfigured,
            locale: german
        )
        XCTAssertEqual(
            activationItems.map(\.title),
            [
                "App-Pause",
                "Smarte Erinnerungen",
                "Erinnerungstexte",
                "Zum Bestätigen schütteln",
            ]
        )
        XCTAssertEqual(activationItems[0].statusTitle, "Einrichten")
        XCTAssertEqual(activationItems[0].actionTitle, "Einrichten")
        XCTAssertEqual(activationItems[1].statusTitle, "Automatisch aktiv")
        XCTAssertEqual(activationItems[1].actionTitle, "Anpassen")
    }

    func testNewPackConfirmationUsesNaturalGermanMethodAwareGrammar() {
        let german = Locale(identifier: "de_DE")

        XCTAssertEqual(
            CycleNounPresentation.startNewConfirmation(for: .pill, locale: german),
            CycleNounPresentation.StartNewConfirmation(
                title: "Neue Packung beginnen?",
                body: "Damit beginnt heute eine neue Packung. Dein bisheriger Verlauf bleibt erhalten."
            )
        )
        XCTAssertEqual(
            CycleNounPresentation.startNewConfirmation(for: .patch, locale: german),
            CycleNounPresentation.StartNewConfirmation(
                title: "Neuen Zyklus beginnen?",
                body: "Damit beginnt heute ein neuer Zyklus. Dein bisheriger Verlauf bleibt erhalten."
            )
        )
        XCTAssertEqual(
            CycleNounPresentation.startNewConfirmation(for: .ring, locale: german),
            CycleNounPresentation.startNewConfirmation(for: .patch, locale: german)
        )
    }

    func testGermanNotificationCopyCoversMethodsFollowUpsFinalRefillAndTrial() {
        let german = Locale(identifier: "de_DE")
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
            actions.map { $0.localizedReminderBody(locale: german) },
            [
                "Es ist Zeit für deine Pille. Protokolliere die Aktion danach.",
                "Deine geplante Pflasteraktion ist fällig. Protokolliere sie danach.",
                "Deine geplante Ringaktion ist fällig. Protokolliere sie danach.",
            ]
        )
        XCTAssertEqual(
            actions[0].localizedFollowUpBody(locale: german),
            "Die heutige Aktion ist noch offen. Protokolliere sie, wenn du bereit bist."
        )
        XCTAssertEqual(
            actions[0].localizedFinalBody(locale: german),
            "Für heute ist noch keine Aktion protokolliert."
        )
        XCTAssertEqual(
            PillieLocalization.string(
                "notification.refill.patch.title",
                table: "Notifications",
                locale: german
            ),
            "Erinnerung an den Pflastervorrat"
        )
        XCTAssertEqual(
            PillieLocalization.string(
                "notification.trial_ending.title",
                table: "Notifications",
                locale: german
            ),
            "Deine Pillie-Plus-Testphase endet bald"
        )
    }

    func testGermanTodayHistoryAndDestructiveSettingsCopyCoverAllStates() {
        let german = Locale(identifier: "de_DE")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)
        )!
        let openAction = DoseScheduleAction(
            date: date,
            type: .pillActive,
            method: .pill,
            cycleDay: 1,
            cycleLength: 28
        )
        let breakAction = DoseScheduleAction(
            date: date,
            type: .pillBreak,
            method: .pill,
            cycleDay: 22,
            cycleLength: 28
        )

        XCTAssertEqual(
            TodayActionState.dueAction(openAction, requiresShakeConfirm: false)
                .localizedPrimaryLabel(locale: german),
            "Als erledigt markieren"
        )
        XCTAssertEqual(
            TodayActionState.dueAction(breakAction, requiresShakeConfirm: false)
                .localizedPrimaryLabel(locale: german),
            "Heute ist keine Aktion fällig"
        )
        XCTAssertEqual(
            TodayActionState.noActionDue.localizedPrimaryLabel(locale: german),
            "Heute ist keine Aktion fällig"
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .completed,
                locale: german
            ),
            "15. Juli 2026: Erledigt"
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .unlogged,
                locale: german
            ),
            "15. Juli 2026: Nicht protokolliert"
        )

        let confirmation = ScheduleCriticalSettingChange.confirmation(
            cycleDay: 8,
            locale: german
        )
        XCTAssertEqual(confirmation.title, "Protokolldaten zurücksetzen?")
        XCTAssertEqual(
            confirmation.body,
            "Wenn du den Zeitplan änderst, wird der gesamte Protokollverlauf zurückgesetzt und bei Tag 8 neu begonnen. Dies kann nicht rückgängig gemacht werden."
        )
        XCTAssertEqual(confirmation.confirmTitle, "Zurücksetzen & sichern")
        XCTAssertEqual(confirmation.cancelTitle, "Abbrechen")
    }

    func testGermanHealthAndReminderCopyAvoidsProhibitedClaims() {
        let german = Locale(identifier: "de_DE")
        let reviewedKeys = [
            ("Localizable", "legal.disclaimer"),
            ("Localizable", "shield.blocking_reason"),
            ("Notifications", "notification.reminder.pill.body"),
            ("Notifications", "notification.followup.body"),
            ("Notifications", "notification.final.body"),
            ("Commerce", "paywall.title"),
            ("Commerce", "paywall.subtitle"),
            ("Commerce", "trial.end.subtitle"),
        ]
        let prohibited = [
            "nie vergessen",
            "garantiert",
            "immer geschützt",
            "verhindert eine schwangerschaft",
            "du hast versagt",
            "deine schuld",
        ]

        for (table, key) in reviewedKeys {
            let copy = PillieLocalization.string(
                key,
                table: table,
                locale: german
            ).lowercased(with: german)
            for phrase in prohibited {
                XCTAssertFalse(
                    copy.contains(phrase),
                    "Prohibited claim '\(phrase)' appears in \(key): \(copy)"
                )
            }
        }
    }
}
