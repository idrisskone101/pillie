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
            "paywall.feature.shake",
            "paywall.feature.custom_messages",
            "paywall.feature.future",
            "paywall.plan.annual",
            "paywall.plan.monthly",
            "paywall.plan.best_value",
            "paywall.plan.price_period",
            "paywall.plan.cancel_anytime",
            "paywall.action.upgrade",
            "paywall.action.restore",
            "paywall.action.terms",
            "paywall.action.privacy",
            "paywall.loading.failed",
            "paywall.purchase_error.title",
            "paywall.restore_error.title",
            "paywall.no_subscription.title",
            "paywall.no_subscription.body",
            "trial.granted.title",
            "trial.granted.subtitle",
            "trial.timeline.today",
            "trial.timeline.today_title",
            "trial.timeline.warning",
            "trial.timeline.choose",
            "trial.status.title",
            "trial.status.ends",
            "trial.status.after_title",
            "trial.end.title",
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
            "Segna come completata"
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
                dueTitle: "Promemoria Pillie",
                dueBody: "Un promemoria delicato per la tua routine.",
                retryTitle: "Promemoria successivo",
                retryBody: "Quando vuoi, ricorda di registrare l’azione di oggi.",
                lastCallTitle: "Promemoria finale programmato",
                lastCallBody: "Per oggi è programmato un ultimo promemoria."
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
            "14,99 € per 3 mesi"
        )
        XCTAssertEqual(
            CommercePresentation.trialEndText(date: trialEnd, locale: italian),
            "La prova termina il 15 luglio 2026"
        )
    }

    func testExistingUserTrialAnnouncementUsesItalianTrialAndPaywallCopy() {
        let content = UpdateTrialAnnouncementContent.localized(
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertEqual(content.badge, "Oggi")
        XCTAssertEqual(content.title, "Le prossime due settimane con Pillie Plus")
        XCTAssertEqual(content.subtitle, "La prova di Pillie Plus inizia ora. Ecco cosa include.")
        XCTAssertEqual(
            content.perks.map(\.title),
            [
                "Metti in pausa le app che distraggono",
                "Muovi per confermare",
                "Promemoria smart",
                "Messaggi dei promemoria personalizzati",
            ]
        )
        XCTAssertEqual(content.primaryCTA, "Continua")
        XCTAssertEqual(content.dismissCTA, "Non ora")
    }
}
