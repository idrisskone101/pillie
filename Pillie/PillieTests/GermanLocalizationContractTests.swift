import XCTest

@testable import Pillie

final class GermanLocalizationContractTests: XCTestCase {
    func testGermanOnboardingCompoundLabelsStayCompactForAccessibilityLayouts() {
        let german = Locale(identifier: "de_DE")
        let expectedByKey = [
            "onboarding.personalise.pain.title": "Was kommt dazwischen?",
            "onboarding.personalise.choice.snooze": "Ich wische Erinnerungen weg.",
            "onboarding.personalise.choice.busy": "Ich hab dann keine Zeit.",
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
            "onboarding.method.title": "Wähle deine Methode.",
            "onboarding.regimen.21_7": "21 aktive Tage, 7 Pausentage",
            "onboarding.cycle_position.title": "Wo stehst du in deiner Routine?",
            "onboarding.reminder_time.title": "Wähle eine Zeit.",
            "onboarding.plan.title": "Dein Erinnerungsplan",
            "onboarding.blocking_setup.title": "Wähle Apps zum Pausieren",
            "onboarding.ready.title": "Alles bereit.",
            "notification.reminder.pill.title": "Zeit für deine Pille",
            "notification.reminder.patch.title": "Zeit für dein Pflaster",
            "notification.reminder.ring.title": "Zeit für deinen Ring",
            "notification.action.complete": "Abhaken",
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
            ("onboarding.cycle_position.calculated", "Localizable", "Anhand des Tages, den du gewählt hast"),
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
            ["Zeit für deine Pille", "Zeit für dein Pflaster", "Zeit für deinen Ring"]
        )
        XCTAssertEqual(
            NotificationManager.shared.reminderCategoryActionTitlesForTesting(
                isPlus: true,
                locale: german
            ),
            ["Abhaken", "Später erinnern"]
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
            "Du hast heute in Pillie noch nicht abgehakt."
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
            "Abgehakt. Zum Rückgängigmachen tippen.",
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
                completedCount: "3 Häkchen",
                completedBody: "Häkchen bisher",
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
            "1 Häkchen"
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
                retryTitle: "Heute noch zu erledigen",
                retryBody: "Wenn du so weit bist, denk daran, heute abzuhaken.",
            )
        )

        let authored = CustomReminderMessages(
            dueTitle: "💊 Mein Titel ",
            dueBody: "Unverändert\nzweite Zeile",
            retryTitle: "Benutzerdefiniert",
            retryBody: "Text ' mit Umlaut ü",
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
        XCTAssertEqual(entitledCard.title, "Du hast die App-Sperre noch nicht eingerichtet.")
        XCTAssertEqual(entitledCard.ctaTitle, "App-Sperre einrichten")

        let protectionOff = try XCTUnwrap(
            ProtectionOffCardContent.make(
                hasPlusAccess: false,
                blockerConfigSaved: true,
                locale: german
            )
        )
        XCTAssertEqual(protectionOff.title, "App-Sperre ist aus")
        XCTAssertEqual(protectionOff.ctaTitle, "Plus wieder einschalten")

        let trial = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: true,
            locale: german
        )
        XCTAssertEqual(trial.indicatorLabel, "Plus ist an · noch 7 aktive Tage")
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
                "App-Sperre",
                "Folgeerinnerungen",
                "Erinnerungstexte",
                "Zum Abhaken schütteln",
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
                "Nimm sie, dann tippe hier zum Abhaken.",
                "Klebe dein Pflaster auf, dann tippe hier zum Abhaken.",
                "Setze deinen Ring ein, dann tippe hier zum Abhaken.",
            ]
        )
        XCTAssertEqual(
            actions[0].localizedFollowUpBody(locale: german),
            "Du hast noch nicht abgehakt. Tippe hier, wenn du fertig bist."
        )
        XCTAssertEqual(
            PillieLocalization.string(
                "notification.refill.patch.title",
                table: "Notifications",
                locale: german
            ),
            "Erinnerung an den Pflastervorrat"
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
            "Heute gibt es nichts zu tun."
        )
        XCTAssertEqual(
            TodayActionState.noActionDue.localizedPrimaryLabel(locale: german),
            "Heute gibt es nichts zu tun."
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
            "15. Juli 2026: Nicht abgehakt"
        )

        let confirmation = ScheduleCriticalSettingChange.confirmation(
            cycleDay: 8,
            locale: german
        )
        XCTAssertEqual(confirmation.title, "Deinen Verlauf löschen?")
        XCTAssertEqual(
            confirmation.body,
            "Wenn du deinen Zeitplan änderst, wird dein ganzer Verlauf gelöscht und du startest bei Tag 8. Das lässt sich nicht rückgängig machen."
        )
        XCTAssertEqual(confirmation.confirmTitle, "Löschen und speichern")
        XCTAssertEqual(confirmation.cancelTitle, "Abbrechen")
    }

    func testGermanHealthAndReminderCopyAvoidsProhibitedClaims() {
        let german = Locale(identifier: "de_DE")
        let reviewedKeys = [
            ("Localizable", "shield.blocking_reason"),
            ("Notifications", "notification.reminder.pill.body"),
            ("Notifications", "notification.followup.body"),
            ("Commerce", "paywall.title"),
            ("Commerce", "paywall.subtitle"),
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
