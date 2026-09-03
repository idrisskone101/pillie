import XCTest

@testable import Pillie

final class GermanLocalizationContractTests: XCTestCase {
    func testGermanOnboardingCompoundLabelsStayCompactForAccessibilityLayouts() {
        let german = Locale(identifier: "de_DE")
        let expectedByKey = [
            "onboarding.personalise.pain.title": "Was kommt dir in die Quere?",
            "onboarding.personalise.choice.snooze": "Ich wische Erinnerungen weg.",
            "onboarding.personalise.choice.busy": "Ich hab keine Zeit, wenn sie kommen.",
            "onboarding.personalise.choice.forget": "Ich vergesse es einfach.",
            "onboarding.personalise.outcome.interruptions": "Weniger Unterbrechungen",
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
            "onboarding.method.title": "Wähl deine Methode.",
            "onboarding.regimen.21_7": "21 aktive Tage, 7 Pausentage",
            "onboarding.cycle_position.title": "Wo stehst du in deiner Routine?",
            "onboarding.reminder_time.title": "Wähl eine Erinnerungszeit.",
            "onboarding.plan.title": "Dein Erinnerungsplan",
            "onboarding.permission.title": "Mitteilungen erlauben",
            "onboarding.blocking_setup.title": "Wähl Apps zum Pausieren",
            "onboarding.ready.title": "Alles bereit.",
            "notification.reminder.pill.title": "Pillie-Zeit!",
            "notification.reminder.patch.title": "Pillie-Zeit!",
            "notification.reminder.ring.title": "Pillie-Zeit!",
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
            ("onboarding.regimen.name.custom", "Localizable", "Eigener Zyklus"),
            ("trial.decline_feedback.optional_note", "Commerce", "Das ist optional. Du kannst überspringen und Pillie weiter kostenlos nutzen."),
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
            "Im kostenlosen Tarif und in Plus enthalten"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: false,
                locale: german
            ),
            "Nur im kostenlosen Tarif"
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
            ["Pillie-Zeit!", "Pillie-Zeit!", "Pillie-Zeit!"]
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
            "Das ist eingetragen. Tippe zum Rückgängig machen."
        )
        XCTAssertEqual(
            HistoryPresentation.monthSummary(
                completed: 3,
                percentage: 75,
                displayedMonth: date,
                locale: german
            ),
            HistoryPresentation.MonthSummary(
                title: "Dieser Monat",
                month: "Juli 2026",
                completedCount: "3 Check-ins",
                completedBody: "Check-ins bisher",
                percentage: PillieLocalization.formatted(
                    "history.month.on_track",
                    locale: german,
                    arguments: Int64(75)
                )
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
            PillieLocalization.formatted(
                "trial.status.ends",
                table: "Commerce",
                locale: german,
                arguments: date.formatted(
                    Date.FormatStyle()
                        .day()
                        .month(.wide)
                        .year()
                        .locale(german)
                )
            )
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
            "1 Check-in"
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
                "Eigene",
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
        XCTAssertEqual(entitledCard.title, "Du hast App-Pause noch nicht eingerichtet.")
        XCTAssertEqual(entitledCard.ctaTitle, "App-Pause einrichten")

        let protectionOff = try XCTUnwrap(
            ProtectionOffCardContent.make(
                hasPlusAccess: false,
                blockerConfigSaved: true,
                locale: german
            )
        )
        XCTAssertEqual(protectionOff.title, "App-Pause ist aus")
        XCTAssertEqual(protectionOff.ctaTitle, "Plus wieder einschalten")

        let trial = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: true,
            locale: german
        )
        XCTAssertEqual(trial.indicatorLabel, "Plus ist an · noch 7 Tage")
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
                "Schütteln zum Eintragen",
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
                body: "Das startet heute eine neue Packung. Deine alte Historie bleibt."
            )
        )
        XCTAssertEqual(
            CycleNounPresentation.startNewConfirmation(for: .patch, locale: german),
            CycleNounPresentation.StartNewConfirmation(
                title: "Neuen Zyklus beginnen?",
                body: "Das startet heute einen neuen Zyklus. Deine alte Historie bleibt."
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
                "Hey, kurzer Check-in. Trag deine Pille ein, wenn du fertig bist",
                "Hey, kurzer Check-in. Trag dein Pflaster ein, wenn du fertig bist",
                "Hey, kurzer Check-in. Trag deinen Ring ein, wenn du fertig bist",
            ]
        )
        XCTAssertEqual(
            actions[0].localizedFollowUpBody(locale: german),
            "Hey, der kurze Check-in ist noch offen. Trag's ein, wenn du soweit bist"
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
            "Pille nehmen"
        )
        XCTAssertEqual(
            TodayActionState.dueAction(breakAction, requiresShakeConfirm: false)
                .localizedPrimaryLabel(locale: german),
            "Heute ist nichts fällig."
        )
        XCTAssertEqual(
            TodayActionState.noActionDue.localizedPrimaryLabel(locale: german),
            "Heute ist nichts fällig."
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
            "15. Juli 2026: Nicht eingetragen"
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
