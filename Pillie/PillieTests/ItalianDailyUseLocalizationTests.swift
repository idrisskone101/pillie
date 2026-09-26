import XCTest

@testable import Pillie

final class ItalianDailyUseLocalizationTests: XCTestCase {
    func testDailyUseAndCommerceCatalogKeysResolveInItalianWithoutEnglishFallback() {
        let requiredKeys = [
            "global.action.save",
            "global.action.cancel",
            "global.status.completed",
            "today.navigation.title",
            "today.action.take_pill",
            "today.action.apply_patch",
            "today.action.change_patch",
            "today.action.remove_patch",
            "today.action.insert_ring",
            "today.action.change_ring",
            "today.action.remove_ring",
            "today.action.undo_complete",
            "today.action.shake",
            "today.empty.title",
            "today.next_action.date",
            "today.next_action.weekday",
            "today.next_action.today",
            "today.next_action.tomorrow",
            "today.next_action.next_week",
            "today.pack.title",
            "today.pack.day_of_total",
            "today.pack.start_new.title",
            "today.pack.start_new.body",
            "today.pack.start_new.confirm",
            "today.refill.title",
            "today.refill.title.patch",
            "today.refill.title.ring",
            "today.protection.status_title",
            "today.protection.inactive",
            "today.intervention.alert.title",
            "today.intervention.alert.body",
            "history.navigation.title",
            "history.title",
            "history.month.title",
            "history.month.checkins",
            "history.month.checkins_body",
            "history.month.on_track",
            "history.legend.completed",
            "history.legend.unlogged",
            "history.legend.break",
            "history.accessibility.day",
            "settings.navigation.title",
            "settings.section.reminders",
            "settings.section.cycle",
            "settings.section.blocking",
            "settings.reminder_time.title",
            "settings.followup.title",
            "settings.followup.interval",
            "settings.break_notice.title",
            "settings.break_notice.body",
            "settings.method.title",
            "settings.regimen.title",
            "settings.schedule.title",
            "settings.cycle_day.title",
            "settings.cycle_day.adjust",
            "settings.cycle_day.history_note",
            "settings.schedule_reset.title",
            "settings.schedule_reset.body",
            "settings.schedule_reset.confirm",
            "settings.custom_messages.title",
            "settings.custom_messages.body",
            "settings.custom_messages.restore",
            "settings.custom_messages.daily_group",
            "settings.custom_messages.status.customized",
            "settings.custom_messages.status.default",
            "settings.custom_messages.blank",
            "settings.custom_messages.preview",
            "settings.custom_messages.start_tone",
            "settings.custom_messages.start_tone_body",
            "settings.tone.gentle",
            "settings.tone.direct",
            "settings.tone.encouraging",
            "settings.tone.private",
            "settings.blocked_apps.title",
            "settings.blocked_apps.edit",
            "support.mail_failed.title",
            "support.mail_failed.body",
            "error.screen_time.title",
            "error.screen_time.body",
            "onboarding.blocking_setup.privacy",
            "onboarding.blocking_setup.empty_detail",
            "onboarding.blocking_setup.selected_summary",
            "onboarding.blocking_setup.skip",
            "onboarding.blocking_setup.allow_pausing",
            "onboarding.blocking_setup.paused_app",
            "onboarding.blocking_setup.unlock_hint",
            "onboarding.blocking_setup.mark_taken",
            "empty.blocked_apps.title",
        ]
        let commerceKeys = [
            "paywall.title",
            "paywall.subtitle",
            "paywall.feature.daily_reminders",
            "paywall.feature.smart_reminders",
            "paywall.feature.app_blocking",
            "paywall.feature.app_blocking.compact",
            "paywall.feature.shake",
            "paywall.feature.custom_messages",
            "paywall.feature.custom_messages.compact",
            "paywall.feature.future.compact",
            "paywall.plan.annual",
            "paywall.plan.monthly",
            "paywall.plan.price_period",
            "paywall.plan.cancel_anytime_short",
            "paywall.action.upgrade",
            "paywall.action.restore",
            "paywall.purchase_error.title",
            "paywall.error.generic_body",
            "paywall.restore_error.title",
            "paywall.no_subscription.title",
            "paywall.no_subscription.body",
            "trial.granted.subtitle",
            "trial.granted.disclosure",
            "trial.activation.recommended",
            "trial.timeline.today",
            "trial.timeline.today_title",
            "trial.status.title",
            "trial.status.active_short",
            "trial.status.ends",
            "trial.status.after_title",
            "trial.status.indicator.active",
            "trial.status.indicator.active_tonight",
            "trial.status.indicator.setup",
            "trial.status.indicator.setup_tonight",
            "trial.status.after.blocking_off",
            "trial.status.after.reminders_free",
            "trial.status.after.setup_saved",
            "trial.status.keep_plus",
            "trial.end.title",
            "trial.end.kicker",
            "trial.end.blocks",
            "trial.end.actions",
            "trial.end.streak",
            "trial.end.free_title",
            "trial.end.welcome_back",
            "trial.end.back_today",
        ]
        let italian = Locale(identifier: "it_IT")

        for key in requiredKeys {
            let localized = PillieLocalization.string(key, locale: italian)
            XCTAssertNotEqual(localized, key, "Missing Italian localization for \(key)")
            XCTAssertFalse(localized.isEmpty, "Empty Italian localization for \(key)")
        }
        for key in commerceKeys {
            let localized = PillieLocalization.string(key, table: "Commerce", locale: italian)
            XCTAssertNotEqual(localized, key, "Missing Italian commerce localization for \(key)")
            XCTAssertFalse(localized.isEmpty, "Empty Italian commerce localization for \(key)")
        }
    }

    func testTodayPresentationDistinguishesOpenCompletedBreakAndNoActionInItalian() {
        let italian = Locale(identifier: "it_IT")
        let date = Date(timeIntervalSince1970: 1_767_225_600)
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
                .localizedPrimaryLabel(locale: italian),
            "Prendi la pillola"
        )
        XCTAssertEqual(
            TodayActionState.completed.localizedPrimaryLabel(locale: italian),
            "Confermato. Tocca per annullare."
        )
        XCTAssertEqual(
            TodayActionState.dueAction(breakAction, requiresShakeConfirm: false)
                .localizedPrimaryLabel(locale: italian),
            "Oggi non c’è niente da fare."
        )
        XCTAssertEqual(
            TodayActionState.noActionDue.localizedPrimaryLabel(locale: italian),
            "Oggi non c’è niente da fare."
        )
    }

    func testHistoryPresentationUsesItalianStatusCountPercentageAndDateFormatting() {
        let italian = Locale(identifier: "it_IT")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)
        )!

        XCTAssertEqual(
            HistoryPresentation.monthSummary(
                completed: 3,
                percentage: 75,
                displayedMonth: date,
                locale: italian
            ),
            HistoryPresentation.MonthSummary(
                title: "Questo mese",
                month: "luglio 2026",
                completedCount: "3 check-in",
                completedBody: "Conferme finora",
                percentage: "75% registrato"
            )
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .completed,
                locale: italian
            ),
            "15 luglio 2026: Fatto"
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .unlogged,
                locale: italian
            ),
            "15 luglio 2026: Non registrato"
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .breakDay,
                locale: italian
            ),
            "15 luglio 2026: Pausa"
        )
    }

    func testScheduleMutationConfirmationLocalizesTheDestructiveResetWithCycleDay() {
        let confirmation = ScheduleCriticalSettingChange.confirmation(
            cycleDay: 8,
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertEqual(confirmation.title, "Cancellare la cronologia?")
        XCTAssertEqual(
            confirmation.body,
            "La modifica del programma reimposta tutta la cronologia e riparte dal giorno 8. L’operazione non può essere annullata."
        )
        XCTAssertEqual(confirmation.confirmTitle, "Cancella e salva")
        XCTAssertEqual(confirmation.cancelTitle, "Annulla")
    }

    func testSettingsPresentationUsesItalianTimeIntervalAndCycleDayFormatting() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            SettingsPresentation.time(hour: 20, minute: 5, locale: italian),
            "20:05"
        )
        XCTAssertEqual(
            SettingsPresentation.interval(minutes: 10, locale: italian),
            "Ogni 10 minuti"
        )
        XCTAssertEqual(
            SettingsPresentation.cycleDay(day: 3, total: 28, locale: italian),
            "Giorno 3 di 28"
        )
        XCTAssertEqual(
            SettingsPresentation.supplyReminderTitle(method: .pill, locale: italian),
            "Promemoria scorte pillola"
        )
        XCTAssertEqual(
            SettingsPresentation.supplyReminderTitle(method: .patch, locale: italian),
            "Promemoria scorte cerotti"
        )
        XCTAssertEqual(
            SettingsPresentation.supplyReminderTitle(method: .ring, locale: italian),
            "Promemoria scorte anelli"
        )
    }

    func testProtocolEditorUsesItalianCopyForEveryMethod() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            ProtocolEditorPresentation.localized(method: .pill, locale: italian).customDayLabels,
            ["Giorni attivi", "Giorni di pausa"]
        )

        let patch = ProtocolEditorPresentation.localized(method: .patch, locale: italian)
        XCTAssertEqual(patch.scheduleTitle, "Piano cerotto")
        XCTAssertEqual(
            patch.scheduleLines,
            [
                "Giorno 1: applica il cerotto",
                "Giorni 8 e 15: cambia il cerotto",
                "Giorno 22: rimuovi il cerotto",
                "Giorni 23–28: settimana senza cerotto",
            ]
        )

        let ring = ProtocolEditorPresentation.localized(method: .ring, locale: italian)
        XCTAssertEqual(ring.scheduleTitle, "Piano anello")
        XCTAssertEqual(
            ring.scheduleLines,
            [
                "Giorno 1: inserisci l’anello",
                "Giorni 2–21: l’anello resta dentro",
                "Giorno 22: rimuovi l’anello",
                "Giorni 23–28: settimana senza anello",
            ]
        )
    }

    func testSettingsEditorsUseDistinctCompactItalianLabels() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            PillieLocalization.string("settings.followup.interval_title", locale: italian),
            "Intervallo"
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.followup.retry_limit_title", locale: italian),
            "Ripetizioni"
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.followup.body", locale: italian),
            "Altri promemoria finché non confermi oggi."
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.support.suggestion", locale: italian),
            "Condividi un’idea"
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.support.issue_report", locale: italian),
            "Segnala un problema"
        )
        XCTAssertEqual(
            SettingsPresentation.reminderMessagesSummary(hasCustom: true, locale: italian),
            "Personalizzati"
        )
        XCTAssertEqual(
            SettingsPresentation.reminderMessagesSummary(hasCustom: false, locale: italian),
            "Predefiniti"
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.custom_messages.daily_group", locale: italian),
            "Promemoria giornaliero"
        )

        let editor = CustomReminderEditorContent.localized(locale: italian)
        XCTAssertEqual(editor.titleFieldLabel, "Titolo")
        XCTAssertEqual(editor.messageFieldLabel, "Messaggio")
        XCTAssertEqual(editor.defaultTitlePlaceholder, "Titolo predefinito di Pillie")
        XCTAssertEqual(editor.defaultMessagePlaceholder, "Messaggio predefinito di Pillie")
        XCTAssertEqual(editor.selectionValue(isSelected: true), "Opzione selezionata.")
        XCTAssertEqual(editor.selectionValue(isSelected: false), "Opzione non selezionata.")
    }

    func testCustomReminderPresetsAreItalianWhileUserAuthoredTextRoundTripsExactly() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            CustomReminderPreset.allCases.map { $0.localizedDisplayName(locale: italian) },
            ["Delicato", "Diretto", "Incoraggiante", "Riservato"]
        )
        XCTAssertEqual(
            CustomReminderPreset.gentle.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "Un promemoria delicato",
                dueBody: "Un promemoria delicato per la tua routine.",
                retryTitle: "Ancora da fare oggi",
                retryBody: "Quando vuoi, ricordati di confermare oggi.",
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.direct.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "Ora di confermare",
                dueBody: "È ora di confermare.",
                retryTitle: "Ancora da fare oggi",
                retryBody: "Oggi non hai ancora confermato.",
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.encouraging.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "Stai creando un’abitudine",
                dueBody: "Una conferma veloce per la routine di oggi.",
                retryTitle: "Ancora da fare oggi",
                retryBody: "Puoi confermare quando vuoi.",
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.privateDiscreet.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "È il momento della conferma",
                dueBody: "Promemoria Pillie",
                retryTitle: "Ancora da fare oggi",
                retryBody: "La tua conferma su Pillie ti aspetta.",
            )
        )

        let authored = CustomReminderMessages(
            dueTitle: "💊 MIO titolo ",
            dueBody: "Non cambiare — byte per byte\nseconda riga",
            retryTitle: "Retry: 12:34",
            retryBody: "apostrofo ' e accento è",
        )
        XCTAssertEqual(CustomReminderDraft(messages: authored).messages, authored)
    }

    func testCommercePresentationUsesStorePriceActualPeriodAndItalianTrialDate() {
        let italian = Locale(identifier: "it_IT")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let trialEnd = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)
        )!

        XCTAssertEqual(
            CommercePresentation.priceAndPeriod(
                displayPrice: "29,99 €",
                periodValue: 1,
                periodUnit: .year,
                locale: italian
            ),
            "29,99 € per anno"
        )
        XCTAssertEqual(
            CommercePresentation.priceAndPeriod(
                displayPrice: "14,99 €",
                periodValue: 3,
                periodUnit: .month,
                locale: italian
            ),
            "14,99 € ogni 3 mesi"
        )
        XCTAssertEqual(
            CommercePresentation.trialEndText(date: trialEnd, locale: italian),
            PillieLocalization.formatted(
                "trial.status.ends",
                table: "Commerce",
                locale: italian,
                arguments: trialEnd.formatted(
                    Date.FormatStyle()
                        .day()
                        .month(.wide)
                        .year()
                        .locale(italian)
                )
            )
        )
    }

    func testCompactCommerceLabelsUsePurposeBuiltItalianCopy() {
        let italian = Locale(identifier: "it_IT")
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: italian)
        }

        XCTAssertEqual(commerce("paywall.feature.app_blocking"), "Blocco app")
        XCTAssertEqual(commerce("paywall.feature.app_blocking.compact"), "Blocco app")
        XCTAssertEqual(commerce("paywall.feature.custom_messages.compact"), "Testi dei promemoria")
        XCTAssertEqual(commerce("paywall.feature.future.compact"), "Funzioni future")
        XCTAssertEqual(commerce("paywall.feature.shake"), "Scuoti per confermare")
        XCTAssertEqual(commerce("trial.activation.recommended"), "Consigliato")
        XCTAssertEqual(commerce("paywall.plan.cancel_anytime_short"), "Disdici quando vuoi")
        XCTAssertEqual(commerce("trial.end.kicker"), "I tuoi 14 giorni attivi")
        XCTAssertEqual(commerce("trial.end.welcome_back"), "Pillie Plus è di nuovo attivo.")
        XCTAssertEqual(commerce("trial.status.active_short"), "Prova attiva")

        XCTAssertEqual(
            SoftPaywallContent.localized(locale: italian).rows.map(\.title),
            [
                "Promemoria giornalieri",
                "Promemoria successivi",
                "Blocco app",
                "Scuoti per confermare",
                "Testi dei promemoria",
                "Funzioni future",
            ]
        )
        XCTAssertEqual(
            TrialActivationItem.make(for: .unconfigured, locale: italian).map(\.title),
            [
                "Blocco app",
                "Promemoria successivi",
                "Testi dei promemoria",
                "Scuoti per confermare",
            ]
        )
    }

    func testExistingUserTrialAnnouncementUsesItalianTrialAndPaywallCopy() {
        let content = UpdateTrialAnnouncementContent.localized(
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertEqual(content.title, "I tuoi primi 14 giorni attivi")
        XCTAssertEqual(content.titleAccent, "li offriamo noi.")
        XCTAssertEqual(
            content.subtitle,
            "La tua prova di Pillie Plus inizia ora. Ecco cosa include."
        )
        XCTAssertEqual(
            content.perks.map(\.title),
            [
                "Blocco app",
                "Scuoti per confermare",
                "Promemoria successivi",
                PillieLocalization.string(
                    "paywall.feature.custom_messages",
                    table: "Commerce",
                    locale: Locale(identifier: "it_IT")
                ),
            ]
        )
        XCTAssertEqual(content.primaryCTA, "Continua")
        XCTAssertEqual(content.dismissCTA, "Non ora")
        XCTAssertEqual(
            content.disclosure,
            "14 giorni attivi gratis, senza carta. Il blocco app si disattiva dopo la prova. I promemoria restano gratis."
        )
    }

    func testTrialStatusUsesTruthfulItalianCountdownAndFutureExpiryCopy() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        let trialEnd = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))
        )
        let italian = Locale(identifier: "it_IT")

        let active = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: true,
            trialEndDate: trialEnd,
            locale: italian
        )
        XCTAssertEqual(active.indicatorLabel, "Plus è attivo · 7 giorni attivi rimasti")
        XCTAssertEqual(
            active.sheetContent.expiryRows.map(\.text),
            [
                PillieLocalization.string(
                    "trial.status.after.blocking_off",
                    table: "Commerce",
                    locale: italian
                ),
                PillieLocalization.string(
                    "trial.status.after.reminders_free",
                    table: "Commerce",
                    locale: italian
                ),
                "La tua configurazione del blocco app è salvata.",
            ]
        )
        XCTAssertEqual(active.sheetContent.ctaTitle, "Tieni Pillie Plus")

        let setup = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: false,
            locale: italian
        )
        XCTAssertEqual(setup.indicatorLabel, "Imposta il blocco app · 7 giorni attivi rimasti")
    }

    func testHomeRecommendationCardsUseItalianRuntimeCopy() throws {
        let italian = Locale(identifier: "it_IT")
        let review = try XCTUnwrap(
            ReviewPromptCardContent.make(decision: .show, locale: italian)
        )
        XCTAssertEqual(review.headline, "Ti piace Pillie?")
        XCTAssertEqual(review.body, "Come sta andando finora?")
        XCTAssertEqual(review.positiveTitle, "Sì, mi piace")
        XCTAssertEqual(review.negativeTitle, "Non molto")
    }

    func testSupportMailComposerKeepsRoutingSubjectsStableAndLocalizesBody() throws {
        let italian = Locale(identifier: "it_IT")
        XCTAssertEqual(
            FeedbackEscapeHatch.localizedSubject(locale: italian),
            "Pillie feedback"
        )
        let feedbackURL = try XCTUnwrap(FeedbackEscapeHatch.mailURL(locale: italian))
        let feedbackItems = try XCTUnwrap(
            URLComponents(url: feedbackURL, resolvingAgainstBaseURL: false)?.queryItems
        )
        XCTAssertEqual(feedbackItems.first { $0.name == "subject" }?.value, "Pillie feedback")

        XCTAssertEqual(
            OpenLine.Intent.suggestion.localizedSubject(locale: italian),
            "Pillie — Suggestion"
        )
        let diagnostics = OpenLine.Diagnostics(
            appVersion: "2.0.6",
            build: "42",
            systemVersion: "26.2",
            deviceModel: "iPhone17,1"
        )
        let issue = OpenLine.Intent.issueReport(diagnostics)
        XCTAssertEqual(
            issue.localizedSubject(locale: italian),
            "Pillie — Issue Report"
        )
        let body = try XCTUnwrap(issue.localizedBody(locale: italian))
        XCTAssertTrue(body.contains("Raccontaci che cosa non ha funzionato"))
        XCTAssertTrue(body.contains("Dispositivo: iPhone17,1"))
        XCTAssertFalse(body.contains("Device:"))
    }
}
