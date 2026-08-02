import XCTest

@testable import Pillie

final class ItalianDailyUseLocalizationTests: XCTestCase {
    func testDailyUseAndCommerceCatalogKeysResolveInItalianWithoutEnglishFallback() {
        let requiredKeys = [
            "global.action.save",
            "global.action.cancel",
            "global.status.completed",
            "global.status.missed",
            "global.status.break_day",
            "today.navigation.title",
            "today.action.mark_complete",
            "today.action.undo_complete",
            "today.action.snooze",
            "today.action.shake",
            "today.empty.title",
            "today.empty.body",
            "today.next_action.title",
            "today.next_action.date",
            "today.pack.title",
            "today.pack.day_of_total",
            "today.pack.start_new.title",
            "today.pack.start_new.body",
            "today.pack.start_new.confirm",
            "today.refill.title",
            "today.refill.title.patch",
            "today.refill.title.ring",
            "today.refill.body",
            "today.protection.status_title",
            "today.protection.active",
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
            "settings.final_reminder.title",
            "settings.final_reminder.body",
            "settings.break_notice.title",
            "settings.break_notice.body",
            "settings.adaptive_time.title",
            "settings.adaptive_time.body",
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
            "settings.subscription.manage",
            "settings.restore.title",
            "settings.support.email",
            "settings.support.privacy",
            "settings.support.terms",
            "settings.support.version",
            "support.mail_failed.title",
            "support.mail_failed.body",
            "error.generic.title",
            "error.generic.body",
            "error.notifications_denied.title",
            "error.notifications_denied.body",
            "error.screen_time.title",
            "error.screen_time.body",
            "onboarding.blocking_setup.privacy",
            "onboarding.blocking_setup.empty_detail",
            "onboarding.blocking_setup.selected_summary",
            "onboarding.blocking_setup.skip",
            "empty.history.title",
            "empty.history.body",
            "empty.blocked_apps.title",
            "empty.blocked_apps.body",
            "accessibility.shake.progress",
            "accessibility.paywall.selected",
            "accessibility.toggle.state",
            "legal.disclaimer",
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
            "paywall.feature.future",
            "paywall.feature.future.compact",
            "paywall.plan.annual",
            "paywall.plan.monthly",
            "paywall.plan.best_value",
            "paywall.plan.price_period",
            "paywall.plan.cancel_anytime",
            "paywall.plan.cancel_anytime_short",
            "paywall.action.upgrade",
            "paywall.action.restore",
            "paywall.action.terms",
            "paywall.action.privacy",
            "paywall.loading.failed",
            "paywall.purchase_error.title",
            "paywall.error.generic_body",
            "paywall.restore_error.title",
            "paywall.no_subscription.title",
            "paywall.no_subscription.body",
            "trial.granted.title",
            "trial.granted.subtitle",
            "trial.granted.disclosure",
            "trial.activation.recommended",
            "trial.timeline.today",
            "trial.timeline.today_title",
            "trial.timeline.warning",
            "trial.timeline.choose",
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
            "trial.end.subtitle",
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
            "Registra ora"
        )
        XCTAssertEqual(
            TodayActionState.completed.localizedPrimaryLabel(locale: italian),
            "Completata — tocca per annullare"
        )
        XCTAssertEqual(
            TodayActionState.dueAction(breakAction, requiresShakeConfirm: false)
                .localizedPrimaryLabel(locale: italian),
            "Nessuna azione prevista oggi"
        )
        XCTAssertEqual(
            TodayActionState.noActionDue.localizedPrimaryLabel(locale: italian),
            "Nessuna azione prevista oggi"
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
                title: "Il tuo mese",
                month: "luglio 2026",
                completedCount: "3 registrazioni",
                completedBody: "registrazioni effettuate finora",
                percentage: "75% registrato"
            )
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .completed,
                locale: italian
            ),
            "15 luglio 2026: Completata"
        )
        XCTAssertEqual(
            HistoryPresentation.dayAccessibilityLabel(
                date: date,
                status: .unlogged,
                locale: italian
            ),
            "15 luglio 2026: Non registrata"
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

        XCTAssertEqual(confirmation.title, "Reimpostare i dati di monitoraggio?")
        XCTAssertEqual(
            confirmation.body,
            "La modifica del programma reimposta tutta la cronologia e riparte dal giorno 8. L’operazione non può essere annullata."
        )
        XCTAssertEqual(confirmation.confirmTitle, "Reimposta e salva")
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
            "Promemoria scorte di pillole"
        )
        XCTAssertEqual(
            SettingsPresentation.supplyReminderTitle(method: .patch, locale: italian),
            "Promemoria scorte di cerotti"
        )
        XCTAssertEqual(
            SettingsPresentation.supplyReminderTitle(method: .ring, locale: italian),
            "Promemoria scorte di anelli"
        )
    }

    func testProtocolEditorUsesItalianCopyForEveryMethod() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            ProtocolEditorPresentation.localized(method: .pill, locale: italian).customDayLabels,
            ["Giorni attivi", "Giorni di pausa"]
        )

        let patch = ProtocolEditorPresentation.localized(method: .patch, locale: italian)
        XCTAssertEqual(patch.scheduleTitle, "Programma del cerotto")
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
        XCTAssertEqual(ring.scheduleTitle, "Programma dell’anello")
        XCTAssertEqual(
            ring.scheduleLines,
            [
                "Giorno 1: inserisci l’anello",
                "Giorni 2–21: l’anello resta inserito",
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
            "Promemoria aggiuntivi finché l’azione di oggi resta da registrare."
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.final_reminder.title", locale: italian),
            "Promemoria finale"
        )
        XCTAssertEqual(
            PillieLocalization.string("settings.support.suggestion", locale: italian),
            "Suggerisci un miglioramento"
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
                retryTitle: "Promemoria successivo",
                retryBody: "Quando vuoi, ricorda di registrare l’azione di oggi.",
                lastCallTitle: "Promemoria finale",
                lastCallBody: "Per oggi è programmato un ultimo promemoria."
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.direct.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "Registrazione Pillie da completare",
                dueBody: "È prevista l’azione programmata.",
                retryTitle: "Promemoria successivo",
                retryBody: "L’azione di oggi è ancora da registrare.",
                lastCallTitle: "Promemoria finale",
                lastCallBody: "Promemoria finale: non è ancora stata registrata alcuna azione."
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.encouraging.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "Stai costruendo costanza",
                dueBody: "Una breve registrazione per la routine di oggi.",
                retryTitle: "Promemoria successivo",
                retryBody: "Puoi registrare l’azione di oggi quando vuoi.",
                lastCallTitle: "Promemoria finale",
                lastCallBody: "Ultima registrazione programmata per oggi."
            )
        )
        XCTAssertEqual(
            CustomReminderPreset.privateDiscreet.localizedMessages(locale: italian),
            CustomReminderMessages(
                dueTitle: "È il momento di registrare",
                dueBody: "Promemoria Pillie",
                retryTitle: "Promemoria successivo",
                retryBody: "La registrazione di Pillie è ancora aperta.",
                lastCallTitle: "Promemoria finale",
                lastCallBody: "Ultimo promemoria Pillie per oggi."
            )
        )

        let authored = CustomReminderMessages(
            dueTitle: "💊 MIO titolo ",
            dueBody: "Non cambiare — byte per byte\nseconda riga",
            retryTitle: "Retry: 12:34",
            retryBody: "apostrofo ' e accento è",
            lastCallTitle: "FINAL_custom",
            lastCallBody: "🌙"
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
            "La prova termina il 15 luglio 2026"
        )
    }

    func testCompactCommerceLabelsUsePurposeBuiltItalianCopy() {
        let italian = Locale(identifier: "it_IT")
        func commerce(_ key: String) -> String {
            PillieLocalization.string(key, table: "Commerce", locale: italian)
        }

        XCTAssertEqual(commerce("paywall.feature.app_blocking"), "Metti in pausa le app che distraggono")
        XCTAssertEqual(commerce("paywall.feature.app_blocking.compact"), "Blocco app distraenti")
        XCTAssertEqual(commerce("paywall.feature.custom_messages"), "Messaggi dei promemoria personalizzati")
        XCTAssertEqual(commerce("paywall.feature.custom_messages.compact"), "Messaggi promemoria su misura")
        XCTAssertEqual(commerce("paywall.feature.future"), "Nuove funzioni al loro arrivo")
        XCTAssertEqual(commerce("paywall.feature.future.compact"), "Nuove funzioni incluse")
        XCTAssertEqual(commerce("paywall.feature.shake"), "Scuoti per confermare")
        XCTAssertEqual(commerce("paywall.plan.best_value"), "Più conveniente")
        XCTAssertEqual(commerce("trial.activation.recommended"), "Consigliato")
        XCTAssertEqual(commerce("paywall.plan.cancel_anytime_short"), "Annulla quando vuoi")
        XCTAssertEqual(commerce("trial.end.kicker"), "I tuoi 14 giorni")
        XCTAssertEqual(commerce("trial.end.welcome_back"), "Pillie Plus è di nuovo attivo")
        XCTAssertEqual(commerce("trial.status.active_short"), "Prova attiva")

        XCTAssertEqual(
            SoftPaywallContent.localized(locale: italian).rows.map(\.title),
            [
                "Promemoria quotidiani",
                "Promemoria smart",
                "Blocco app distraenti",
                "Scuoti per confermare",
                "Messaggi promemoria su misura",
                "Nuove funzioni incluse",
            ]
        )
        XCTAssertEqual(
            TrialActivationItem.make(for: .unconfigured, locale: italian).map(\.title),
            [
                "Blocco app distraenti",
                "Promemoria smart",
                "Messaggi promemoria su misura",
                "Scuoti per confermare",
            ]
        )
    }

    func testExistingUserTrialAnnouncementUsesItalianTrialAndPaywallCopy() {
        let content = UpdateTrialAnnouncementContent.localized(
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertEqual(content.badge, "Oggi")
        XCTAssertEqual(content.title, "Le prossime due settimane")
        XCTAssertEqual(content.titleAccent, "le offriamo noi.")
        XCTAssertEqual(content.subtitle, "La prova di Pillie Plus inizia ora. Ecco cosa include.")
        XCTAssertEqual(
            content.perks.map(\.title),
            [
                "Metti in pausa le app che distraggono",
                "Scuoti per confermare",
                "Promemoria smart",
                "Messaggi dei promemoria personalizzati",
            ]
        )
        XCTAssertEqual(content.primaryCTA, "Continua")
        XCTAssertEqual(content.dismissCTA, "Non ora")
        XCTAssertEqual(
            content.disclosure,
            "La prova gratuita dura 14 giorni. Al termine, il blocco delle app si disattiva, mentre i promemoria restano gratuiti."
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
        XCTAssertEqual(active.indicatorLabel, "Protezione attiva · 7 giorni rimasti")
        XCTAssertEqual(
            active.sheetContent.expiryItems,
            [
                "Il blocco delle app si disattiva",
                "I promemoria restano gratuiti, per sempre",
                "La configurazione del blocco resta salvata",
            ]
        )
        XCTAssertEqual(active.sheetContent.ctaTitle, "Mantieni Pillie Plus")

        let setup = TrialStatusPresentation(
            daysRemaining: 7,
            protectionActive: false,
            locale: italian
        )
        XCTAssertEqual(setup.indicatorLabel, "Configura protezione · 7 giorni rimasti")
    }

    func testHomeRecommendationCardsUseItalianRuntimeCopy() throws {
        let italian = Locale(identifier: "it_IT")
        let review = try XCTUnwrap(
            ReviewPromptCardContent.make(decision: .show, locale: italian)
        )
        XCTAssertEqual(review.headline, "Ti piace Pillie?")
        XCTAssertEqual(review.body, "Ci piacerebbe sapere come ti trovi.")
        XCTAssertEqual(review.positiveTitle, "Sì, mi piace")
        XCTAssertEqual(review.negativeTitle, "Non molto")

        let suggestion = AdaptiveReminderTimeAnalyzer.Suggestion(
            hour: 20,
            minute: 40,
            deltaMinutes: 40
        )
        let adaptive = try XCTUnwrap(
            AdaptiveReminderSuggestionCardContent.make(
                suggestion: suggestion,
                isPlus: true,
                locale: italian
            )
        )
        let time = AdaptiveReminderSuggestionCardContent.formattedTime(
            hour: 20,
            minute: 40,
            locale: italian
        )
        XCTAssertEqual(adaptive.headline, "Di solito registri verso le \(time)")
        XCTAssertEqual(
            adaptive.body,
            "Vuoi spostare il promemoria giornaliero alle \(time), così arriva quando ti è più utile?"
        )
        XCTAssertEqual(adaptive.acceptTitle, "Sposta il promemoria alle \(time)")
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
