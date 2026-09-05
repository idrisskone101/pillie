#!/usr/bin/env python3
"""Restore regular written casing on Pillie catalogs and the locked table.

Sentence-case user-facing copy. Keep Pillie and Plus as proper nouns.
Shorten a few onboarding titles and paywall bodies so they stay medium length.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
LOCKED = SCRIPT_DIR / "locked-copy.json"
CATALOGS = {
    "Localizable": REPO_ROOT / "Pillie" / "Pillie" / "Localizable.xcstrings",
    "Commerce": REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings",
    "Notifications": REPO_ROOT / "Pillie" / "Pillie" / "Notifications.xcstrings",
}

SPECIAL_DE: dict[tuple[str, str], str] = {
    ("Commerce", "paywall.title"): "Mehr als ein Ping mit Pillie Plus.",
    ("Commerce", "paywall.subtitle"): (
        "Plus pingt weiter und kann Apps pausieren."
    ),
    ("Commerce", "trial.granted.disclosure"): (
        "14 Tage gratis, keine Karte. App-Pause endet mit dem Trial. Erinnerungen bleiben frei."
    ),
    ("Commerce", "onboarding.blocking_setup.plus_locked"): (
        "App-Pause ist Plus. Setup nach dem Upgrade."
    ),
    ("Commerce", "paywall.upsell.custom_messages.body"): (
        "Schreib den Ping in deinen Worten. Plus ändert den täglichen und den letzten."
    ),
    ("Localizable", "onboarding.welcome.title"): "Der Wecker für deine Pille, jeden Abend.",
    ("Localizable", "onboarding.welcome.subtitle"): (
        "Du kannst sie nicht wegwischen. Sie bleibt bis zum Check-in."
    ),
    ("Localizable", "onboarding.welcome.demo.reminder_title"): "Check-in am Abend",
    ("Localizable", "today.protection.off.detail.pill"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.apply"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.change"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.remove"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.insert"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.change"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.remove"): (
        "Erinnerungen an. Plus pausiert Apps."
    ),
    ("Localizable", "onboarding.blocking_setup.subtitle"): (
        "Ausgewählte Apps pausieren nach einer Erinnerung. Nach dem Check-in sind sie wieder da."
    ),
    ("Localizable", "today.protection.setup.detail.pill"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.patch.apply"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.patch.change"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.patch.remove"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.ring.insert"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.ring.change"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "today.protection.setup.detail.ring.remove"): (
        "Tägliche Erinnerungen laufen schon. Richte es zu Ende ein, wenn Apps bis zum Check-in pausieren sollen."
    ),
    ("Localizable", "onboarding.personalise.pain.title"): "Was kommt dazwischen?",
    ("Localizable", "onboarding.blocking_demo.body"): (
        "Plus pausiert Apps bei einer Erinnerung. Nach dem Check-in sind sie wieder da."
    ),
    ("Localizable", "onboarding.method.patch.subtitle"): "Pflaster · ein Wechselplan",
    ("Localizable", "onboarding.personalise.choice.busy"): "Ich hab dann keine Zeit.",
    ("Localizable", "onboarding.personalise.outcome.title"): "Was würde mehr helfen?",
    ("Localizable", "onboarding.frequency.title"): "Wie oft verpasst du deine Pille?",
    ("Localizable", "onboarding.frequency.subtitle"): (
        "So wissen wir, wie fest die Erinnerungen sein sollen."
    ),
    ("Localizable", "onboarding.permission.cta"): "Weiter zu den Mitteilungen",
    ("Localizable", "onboarding.risk_window.title"): "Wie bald nimmst du sie nach der Erinnerung?",
    ("Localizable", "onboarding.risk_window.subtitle"): (
        "Nur grob. Du kannst das später ändern."
    ),
    ("Localizable", "onboarding.plan.title"): "Dein Erinnerungsplan",
    ("Localizable", "onboarding.ready.title"): "Alles bereit.",
    ("Localizable", "onboarding.blocking_demo.title"): "Apps pausieren bis zum Check-in.",
    ("Localizable", "onboarding.mechanism.unlocked"): "Erledigt. Deine Apps sind wieder da.",
    ("Localizable", "onboarding.method.title"): "Wähl die Methode.",
    ("Localizable", "onboarding.cycle_position.title"): "Wo stehst du in deiner Routine?",
    ("Localizable", "onboarding.reminder_time.title"): "Wähl eine Zeit.",
    ("Localizable", "today.action.undo_complete"): "Eingetragen. Zum Rückgängig tippen.",
    ("Commerce", "trial.end.legacy.title"): "Deine Plus-Testphase ist vorbei.",
    ("Commerce", "trial.end.worth_keeping"): "Plus behalten?",
    ("Commerce", "trial.granted.headline_accent"): "auf uns.",
    ("Notifications", "notification.reminder.pill.title"): "Pillie-Zeit!",
    ("Notifications", "notification.reminder.patch.title"): "Pillie-Zeit!",
    ("Notifications", "notification.reminder.ring.title"): "Pillie-Zeit!",
    ("Notifications", "notification.reminder.pill.body"): (
        "Hey, kurzer Check-in. Trag deine Pille ein, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.patch.apply.body"): (
        "Hey, kurzer Check-in. Kleb dein Pflaster auf, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.patch.change.body"): (
        "Hey, kurzer Check-in. Wechsel dein Pflaster, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.patch.remove.body"): (
        "Hey, kurzer Check-in. Nimm dein Pflaster ab, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.ring.insert.body"): (
        "Hey, kurzer Check-in. Setz deinen Ring ein, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.ring.change.body"): (
        "Hey, kurzer Check-in. Wechsel deinen Ring, wenn du fertig bist"
    ),
    ("Notifications", "notification.reminder.ring.remove.body"): (
        "Hey, kurzer Check-in. Nimm deinen Ring raus, wenn du fertig bist"
    ),
    ("Notifications", "notification.followup.body"): (
        "Hey, der kurze Check-in ist noch offen. Check-in, wenn du soweit bist"
    ),
    ("Notifications", "notification.final.body"): "Für heute noch kein Check-in.",
    ("Notifications", "notification.trial_expiry.day10.body"): (
        "Die App-Pause wird in 5 Tagen deaktiviert."
    ),
    ("Notifications", "notification.trial_expiry.day13.body"): (
        "Die App-Pause wird morgen Abend deaktiviert."
    ),
    ("Notifications", "notification.trial_ending.body"): (
        "Die App-Pause wird am Ende der Testphase deaktiviert."
    ),
    ("Notifications", "notification.custom.direct.primary"): (
        "Dein geplanter Check-in ist fällig."
    ),
    ("Notifications", "notification.custom.direct.followup"): (
        "Der heutige Check-in ist noch offen."
    ),
    ("Notifications", "notification.custom.direct.final"): (
        "Letzte Erinnerung: für heute noch kein Check-in."
    ),
    ("Notifications", "notification.custom.encouraging.followup"): (
        "Du kannst den Check-in machen, wenn du bereit bist."
    ),
    ("Notifications", "notification.custom.gentle.followup"): (
        "Wenn du bereit bist, denk daran, heute einzuchecken."
    ),
    ("Localizable", "onboarding.regimen.21_7"): "21 aktive Tage, 7 Pausentage",
    ("Localizable", "onboarding.regimen.24_4"): "24 aktive Tage, 4 Pausentage",
    ("Localizable", "onboarding.regimen.26_2"): "26 aktive Tage, 2 Pausentage",
    ("Localizable", "onboarding.regimen.28_0"): "28 aktive Tage, keine Pause",
    ("Localizable", "onboarding.regimen.365_0"): "365 aktive Tage, keine Pause",
    ("Localizable", "onboarding.regimen.84_7"): "84 aktive Tage, 7 Pausentage",
}

SPECIAL_IT: dict[tuple[str, str], str] = {
    ("Commerce", "paywall.title"): "Più di un ping con Pillie Plus.",
    ("Commerce", "paywall.subtitle"): (
        "Plus continua a mandare ping e può pausare le app."
    ),
    ("Commerce", "trial.granted.disclosure"): (
        "14 giorni gratis, niente carta. Il blocco finisce col trial. I promemoria restano gratis."
    ),
    ("Commerce", "onboarding.blocking_setup.plus_locked"): (
        "Il blocco è Plus. Setup dopo l’upgrade."
    ),
    ("Commerce", "trial.end.legacy.keep"): "Tieni Plus.",
    ("Commerce", "paywall.upsell.custom_messages.body"): (
        "Scrivi il ping con le tue parole. Plus cambia quello giornaliero e l'ultimo."
    ),
    ("Localizable", "onboarding.welcome.title"): "La sveglia per la tua pillola, ogni sera.",
    ("Localizable", "onboarding.welcome.subtitle"): (
        "Non puoi scartarlo. Resta fino al check-in."
    ),
    ("Localizable", "onboarding.welcome.demo.reminder_title"): "Check-in serale",
    ("Localizable", "today.protection.off.detail.pill"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.patch.apply"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.patch.change"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.patch.remove"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.ring.insert"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.ring.change"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "today.protection.off.detail.ring.remove"): (
        "I promemoria restano. Plus può pausare le app."
    ),
    ("Localizable", "onboarding.blocking_setup.subtitle"): (
        "Le app scelte vanno in pausa al promemoria. Tornano dopo il check-in."
    ),
    ("Localizable", "today.protection.setup.detail.pill"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.apply"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.change"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.remove"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.insert"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.change"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.remove"): (
        "I promemoria giornalieri funzionano già. Finisci il setup se vuoi che le app vadano in pausa fino al check-in."
    ),
    ("Localizable", "onboarding.personalise.pain.title"): "Cosa ti ostacola?",
    ("Localizable", "onboarding.personalise.outcome.title"): "Cosa aiuterebbe di più?",
    ("Localizable", "onboarding.frequency.title"): "Quanto spesso salti la pillola?",
    ("Localizable", "onboarding.frequency.subtitle"): (
        "Così sappiamo quanto devono essere insistenti i promemoria."
    ),
    ("Localizable", "onboarding.permission.cta"): "Continua alle notifiche",
    ("Localizable", "onboarding.risk_window.title"): "Quanto dopo il promemoria la prendi di solito?",
    ("Localizable", "onboarding.risk_window.subtitle"): (
        "A occhio. Puoi cambiarlo dopo."
    ),
    ("Localizable", "onboarding.plan.title"): "Il tuo piano promemoria",
    ("Localizable", "onboarding.ready.title"): "Tutto pronto.",
    ("Localizable", "onboarding.blocking_demo.title"): "App in pausa fino al check-in.",
    ("Localizable", "onboarding.blocking_demo.body"): (
        "Plus mette in pausa le app al promemoria. Tornano dopo il check-in."
    ),
    ("Localizable", "onboarding.demo.explainer"): (
        "Pillie ti aiuta a fare il check-in e a rivedere la cronologia."
    ),
    ("Localizable", "onboarding.reminder_time.title"): "Scegli un orario.",
    ("Localizable", "onboarding.method.patch.subtitle"): "Cerotto · un piano di cambio",
    ("Localizable", "onboarding.blocking_setup.title"): "Scegli le app da pausare",
    ("Localizable", "onboarding.mechanism.unlocked"): "Fatto. Le tue app sono di nuovo disponibili.",
    ("Localizable", "onboarding.method.title"): "Scegli il metodo.",
    ("Commerce", "trial.end.legacy.title"): "La prova Plus è finita.",
    ("Commerce", "trial.end.worth_keeping"): "Vuoi tenere Plus?",
    ("Commerce", "trial.granted.headline_accent"): "offerta nostra.",
    ("Notifications", "notification.reminder.pill.title"): "Pillie time!",
    ("Notifications", "notification.reminder.patch.title"): "Pillie time!",
    ("Notifications", "notification.reminder.ring.title"): "Pillie time!",
    ("Notifications", "notification.reminder.pill.body"): (
        "Ehi, check-in veloce. Registrala quando hai finito"
    ),
    ("Notifications", "notification.reminder.patch.apply.body"): (
        "Ehi, check-in veloce. Applica il cerotto quando hai finito"
    ),
    ("Notifications", "notification.reminder.patch.change.body"): (
        "Ehi, check-in veloce. Cambia il cerotto quando hai finito"
    ),
    ("Notifications", "notification.reminder.patch.remove.body"): (
        "Ehi, check-in veloce. Togli il cerotto quando hai finito"
    ),
    ("Notifications", "notification.reminder.ring.insert.body"): (
        "Ehi, check-in veloce. Inserisci l'anello quando hai finito"
    ),
    ("Notifications", "notification.reminder.ring.change.body"): (
        "Ehi, check-in veloce. Cambia l'anello quando hai finito"
    ),
    ("Notifications", "notification.reminder.ring.remove.body"): (
        "Ehi, check-in veloce. Togli l'anello quando hai finito"
    ),
    ("Notifications", "notification.followup.body"): (
        "Ehi, il check-in veloce è ancora aperto. Fai il check-in quando vuoi"
    ),
    ("Notifications", "notification.final.body"): "Per oggi non c'è ancora un check-in.",
    ("Notifications", "notification.trial_expiry.day10.body"): (
        "Il blocco delle app si disattiverà tra 5 giorni."
    ),
    ("Notifications", "notification.trial_expiry.day13.body"): (
        "Il blocco delle app si disattiverà domani sera."
    ),
    ("Notifications", "notification.trial_ending.body"): (
        "Il blocco delle app si disattiverà al termine della prova."
    ),
    ("Notifications", "notification.custom.direct.primary"): (
        "È previsto il check-in programmato."
    ),
    ("Notifications", "notification.custom.direct.followup"): (
        "Il check-in di oggi è ancora da fare."
    ),
    ("Notifications", "notification.custom.direct.final"): (
        "Promemoria finale: per oggi non c'è ancora un check-in."
    ),
    ("Notifications", "notification.custom.encouraging.followup"): (
        "Puoi fare il check-in quando vuoi."
    ),
    ("Notifications", "notification.custom.gentle.followup"): (
        "Quando vuoi, ricorda di fare il check-in oggi."
    ),
    ("Localizable", "onboarding.regimen.21_7"): "21 giorni attivi, 7 giorni di pausa",
    ("Localizable", "onboarding.regimen.24_4"): "24 giorni attivi, 4 giorni di pausa",
    ("Localizable", "onboarding.regimen.26_2"): "26 giorni attivi, 2 giorni di pausa",
    ("Localizable", "onboarding.regimen.28_0"): "28 giorni attivi, senza pausa",
    ("Localizable", "onboarding.regimen.365_0"): "365 giorni attivi, nessuna pausa",
    ("Localizable", "onboarding.regimen.84_7"): "84 giorni attivi, 7 giorni di pausa",
}

# Product-voice rewrites. Keys are (table, key). Only English.
SPECIAL_EN: dict[tuple[str, str], str] = {
    ("Commerce", "paywall.title"): "More than one ping with Pillie Plus.",
    ("Commerce", "paywall.subtitle"): (
        "Pillie Plus keeps pinging until you log today, and can pause apps until you check in."
    ),
    ("Commerce", "paywall.plan.lifetime"): "Pillie Plus lifetime",
    ("Commerce", "paywall.upsell.smart_reminders.body"): (
        "Keeps pinging until you log today. You pick how often, how many, and the last ping."
    ),
    ("Commerce", "paywall.upsell.custom_messages.body"): (
        "Write the ping in your own words. Plus lets you change the daily one and the last one."
    ),
    ("Commerce", "trial.granted.headline"): "Your next two weeks are",
    ("Commerce", "trial.granted.headline_accent"): "on us.",
    ("Commerce", "trial.granted.subtitle"): "Your Pillie Plus trial starts now. Here's what's included.",
    ("Commerce", "trial.granted.disclosure"): (
        "14 days free, no card needed. App blocking turns off after the trial. Reminders stay free."
    ),
    ("Commerce", "trial.granted.disclosure.hard_paywall"): (
        "Your free trial lasts 14 days. No card needed. "
        "After it ends, choose monthly, annual, or lifetime to keep Plus."
    ),
    ("Commerce", "trial.end.title"): "Your Pillie Plus trial is over.",
    ("Commerce", "trial.end.hard.blocker"): (
        "You had extra pings and paused apps for 14 days. Keep Plus if you want that to stay on."
    ),
    ("Commerce", "trial.end.hard.reminders"): (
        "You had extra pings for 14 days. Keep Plus if you want those to stay on."
    ),
    ("Commerce", "trial.end.subtitle.hard"): (
        "You had extra pings and paused apps for 14 days. Keep Plus if you want that to stay on."
    ),
    ("Commerce", "trial.end.subtitle.reminders"): (
        "You had extra pings for 14 days. Keep Plus if you want those to stay on."
    ),
    ("Commerce", "trial.end.legacy.subtitle"): (
        "Your 14 days ended, so app blocking is off. Reminders stay free forever."
    ),
    ("Commerce", "trial.end.legacy.title"): "Your Plus trial just ended.",
    ("Commerce", "trial.end.worth_keeping"): "Want to keep Plus?",
    ("Commerce", "trial.end.legacy.aside"): "Want to keep Plus?",
    ("Commerce", "trial.decline_feedback.title"): "One quick question.",
    ("Commerce", "trial.decline_feedback.prompt"): "What made Pillie Plus not the right fit?",
    ("Localizable", "onboarding.welcome.title"): "The alarm clock for your pill.",
    ("Localizable", "onboarding.welcome.subtitle"): (
        "You can't swipe this reminder away. It stays until you check in."
    ),
    ("Localizable", "onboarding.welcome.demo.reminder_title"): "Nightly check-in",
    ("Localizable", "today.protection.off.detail.pill"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.apply"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.change"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.patch.remove"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.insert"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.change"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.off.detail.ring.remove"): (
        "Reminders stay on. Plus can pause apps."
    ),
    ("Localizable", "today.protection.setup.detail.pill"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.apply"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.change"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.patch.remove"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.insert"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.change"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "today.protection.setup.detail.ring.remove"): (
        "Daily reminders are already on. Finish setup if you want apps to pause until you check in."
    ),
    ("Localizable", "onboarding.welcome.eyebrow"): "Here's how it works",
    ("Localizable", "onboarding.blocking_demo.title"): "Apps pause until you check in.",
    ("Localizable", "onboarding.blocking_demo.body"): (
        "Pillie Plus can pause selected apps when a reminder is due. "
        "They come back after you check in."
    ),
    ("Localizable", "onboarding.blocking_demo.drag_title"): "Drag this onto your apps.",
    ("Localizable", "onboarding.blocking_setup.subtitle"): (
        "Selected apps pause after a Pillie reminder. They come back after you check in."
    ),
    ("Localizable", "onboarding.demo.title"): "Your daily flow",
    ("Localizable", "onboarding.demo.explainer"): "Pillie helps you check in and review your history.",
    ("Localizable", "onboarding.demo.history_title"): "Your history builds as you go",
    ("Localizable", "onboarding.method.title"): "Pick your method.",
    ("Localizable", "onboarding.method.subtitle"): "What should Pillie remind you about?",
    ("Localizable", "onboarding.method.pill.subtitle"): "Pill · a daily pill schedule",
    ("Localizable", "onboarding.method.patch.subtitle"): "Patch · a change schedule",
    ("Localizable", "onboarding.permission.cta"): "Continue to notification settings",
    ("Localizable", "onboarding.method.ring.subtitle"): "Ring · a ring schedule",
    ("Localizable", "onboarding.regimen.title"): "Choose your pill regimen.",
    ("Localizable", "onboarding.regimen.21_7"): "21 active days, 7 break days",
    ("Localizable", "onboarding.regimen.24_4"): "24 active days, 4 break days",
    ("Localizable", "onboarding.regimen.26_2"): "26 active days, 2 break days",
    ("Localizable", "onboarding.regimen.28_0"): "28 active days, no break",
    ("Localizable", "onboarding.regimen.84_7"): "84 active days, 7 break days",
    ("Localizable", "onboarding.regimen.365_0"): "365 active days, no break",
    ("Localizable", "onboarding.reminder_time.title"): "Pick a time.",
    ("Localizable", "onboarding.reminder_time.subtitle"): "When should Pillie remind you?",
    ("Localizable", "onboarding.acquisition.title"): "Where did you find Pillie?",
    ("Localizable", "onboarding.acquisition.subtitle"): "Your answer helps more people find the app.",
    ("Localizable", "onboarding.personalise.pain.title"): "What's in the way?",
    ("Localizable", "onboarding.personalise.pain.subtitle"): "Choose the answer that feels closest.",
    ("Localizable", "onboarding.personalise.outcome.title"): "What would help more?",
    ("Localizable", "onboarding.personalise.outcome.subtitle"): "Choose the support you want from Pillie.",
    ("Localizable", "onboarding.frequency.title"): "How often do you miss your pill?",
    ("Localizable", "onboarding.frequency.subtitle"): (
        "So we know how firm the reminders should be."
    ),
    ("Localizable", "onboarding.risk_window.title"): (
        "How soon do you usually take it after the reminder?"
    ),
    ("Localizable", "onboarding.risk_window.subtitle"): (
        "Just a rough sense. You can change this later."
    ),
    ("Localizable", "onboarding.plan.title"): "Your reminder plan",
    ("Localizable", "onboarding.ready.title"): "You're all set.",
    ("Localizable", "onboarding.ready.subtitle"): (
        "Pillie will follow the schedule you picked. You can change it anytime."
    ),
    ("Localizable", "onboarding.personalise.choice.snooze"): "I dismiss reminders.",
    ("Localizable", "onboarding.personalise.choice.busy"): "I'm busy then.",
    ("Localizable", "onboarding.personalise.choice.forget"): "I just forget.",
    ("Localizable", "accessibility.progress.intro.title"): "See how Pillie works.",
    ("Localizable", "accessibility.progress.personalize.title"): "Personalize your plan.",
    ("Localizable", "history.title"): "Your month so far",
    ("Localizable", "today.greeting"): "Still showing up",
    ("Localizable", "today.protection.setup.title"): "You haven't set up app blocking yet.",
    ("Localizable", "today.protection.ended.detail"): (
        "Your Plus access ended, so your apps aren't paused. "
        "Your setup is saved. Turn Plus back on and it picks up where you left off."
    ),
    ("Localizable", "today.review_prompt.title"): "Enjoying Pillie?",
    ("Localizable", "today.review_prompt.body"): "How's it going for you so far?",
    ("Localizable", "settings.section.my_pillie"): "My Pillie",
    ("Localizable", "support.mail_failed.title"): "We couldn't open the mail app.",
    ("Localizable", "onboarding.mechanism.unlocked"): "Done. Your apps are available again.",
    ("Notifications", "notification.reminder.pill.title"): "Pillie time!",
    ("Notifications", "notification.reminder.patch.title"): "Pillie time!",
    ("Notifications", "notification.reminder.ring.title"): "Pillie time!",
    ("Notifications", "notification.reminder.pill.body"): (
        "Hey, quick check-in. Log your pill when you're done"
    ),
    ("Notifications", "notification.reminder.patch.apply.body"): (
        "Hey, quick check-in. Apply your patch when you're done"
    ),
    ("Notifications", "notification.reminder.patch.change.body"): (
        "Hey, quick check-in. Change your patch when you're done"
    ),
    ("Notifications", "notification.reminder.patch.remove.body"): (
        "Hey, quick check-in. Remove your patch when you're done"
    ),
    ("Notifications", "notification.reminder.ring.insert.body"): (
        "Hey, quick check-in. Insert your ring when you're done"
    ),
    ("Notifications", "notification.reminder.ring.change.body"): (
        "Hey, quick check-in. Change your ring when you're done"
    ),
    ("Notifications", "notification.reminder.ring.remove.body"): (
        "Hey, quick check-in. Remove your ring when you're done"
    ),
    ("Notifications", "notification.followup.body"): (
        "Hey, quick check-in is still open. Check in when you're ready"
    ),
    ("Notifications", "notification.final.body"): "Still no check-in for today.",
    ("Notifications", "notification.trial_expiry.day10.body"): (
        "App blocking turns off in 5 days."
    ),
    ("Notifications", "notification.trial_expiry.day13.body"): (
        "App blocking turns off tomorrow night."
    ),
    ("Notifications", "notification.trial_ending.body"): (
        "App blocking will turn off when the trial ends."
    ),
    ("Notifications", "notification.custom.direct.primary"): (
        "Your scheduled check-in is due."
    ),
    ("Notifications", "notification.custom.direct.followup"): (
        "Today's check-in is still open."
    ),
    ("Notifications", "notification.custom.direct.final"): (
        "Final reminder: still no check-in for today."
    ),
    ("Notifications", "notification.custom.encouraging.followup"): (
        "You can check in when you're ready."
    ),
    ("Notifications", "notification.custom.gentle.followup"): (
        "When you're ready, remember to check in today."
    ),
}

PROPER_NOUNS = (
    (re.compile(r"\bpillie plus\b", re.I), "Pillie Plus"),
    (re.compile(r"\bpillie\b", re.I), "Pillie"),
)


def first_alpha_index(text: str) -> int | None:
    i = 0
    while i < len(text):
        if text.startswith("%", i):
            i += 1
            while i < len(text) and text[i] in "@%ld":
                i += 1
            continue
        if text[i].isalpha():
            return i
        i += 1
    return None


def capitalize_sentence_starts(text: str) -> str:
    parts = re.split(r"([.!?]\s+)", text)
    out: list[str] = []
    for part in parts:
        if re.fullmatch(r"[.!?]\s+", part) or not part:
            out.append(part)
            continue
        leading = part.lstrip()
        if leading.startswith("%") or (leading and leading[0].isdigit()):
            out.append(part)
            continue
        idx = first_alpha_index(part)
        if idx is None:
            out.append(part)
            continue
        out.append(part[:idx] + part[idx].upper() + part[idx + 1 :])
    return "".join(out)


def apply_proper_nouns(text: str) -> str:
    for pattern, replacement in PROPER_NOUNS:
        text = pattern.sub(replacement, text)
    # Standalone product "plus" after a sentence start or as a label.
    text = re.sub(r"\bplus\b", "Plus", text)
    text = re.sub(r"\bPlus is on\b", "Plus is on", text)
    return text


def rewrite_en(table: str, key: str, text: str) -> str:
    special = SPECIAL_EN.get((table, key))
    if special is not None:
        return special
    return apply_proper_nouns(capitalize_sentence_starts(text))


def rewrite_localized(table: str, key: str, text: str, specials: dict[tuple[str, str], str]) -> str:
    special = specials.get((table, key))
    if special is not None:
        return special
    text = capitalize_sentence_starts(text)
    text = re.sub(r"\bpillie plus\b", "Pillie Plus", text, flags=re.I)
    text = re.sub(r"\bpillie\b", "Pillie", text, flags=re.I)
    return text


def localization_unit(entry: dict, lang: str) -> dict | None:
    return (entry.get("localizations") or {}).get(lang, {}).get("stringUnit")


def set_value(entry: dict, lang: str, value: str) -> None:
    locs = entry.setdefault("localizations", {})
    loc = locs.setdefault(lang, {})
    unit = loc.setdefault("stringUnit", {})
    unit["state"] = "translated"
    unit["value"] = value


def rewrite_catalogs() -> int:
    changed = 0
    for table, path in CATALOGS.items():
        data = json.loads(path.read_text())
        for key, entry in data.get("strings", {}).items():
            for lang, rewriter in (
                ("en", lambda value, k=key, t=table: rewrite_en(t, k, value)),
                ("de", lambda value, k=key, t=table: rewrite_localized(t, k, value, SPECIAL_DE)),
                ("it", lambda value, k=key, t=table: rewrite_localized(t, k, value, SPECIAL_IT)),
            ):
                unit = localization_unit(entry, lang)
                if not unit or not isinstance(unit.get("value"), str):
                    continue
                current = unit["value"]
                rewritten = rewriter(current)
                if rewritten != current:
                    unit["value"] = rewritten
                    changed += 1
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return changed


def rewrite_locked() -> int:
    data = json.loads(LOCKED.read_text())
    changed = 0
    for item in data["entries"]:
        table = item["table"]
        key = item["key"]
        if "en" in item:
            rewritten = rewrite_en(table, key, item["en"])
            if rewritten != item["en"]:
                item["en"] = rewritten
                changed += 1
        for lang, specials in (("de", SPECIAL_DE), ("it", SPECIAL_IT)):
            if lang not in item:
                continue
            rewritten = rewrite_localized(table, key, item[lang], specials)
            if rewritten != item[lang]:
                item[lang] = rewritten
                changed += 1
    data["source"] = (
        "Regular written copy. Sentence case for chrome and body. "
        "CTAs stay sentence case. Pillie and Plus stay proper nouns."
    )
    LOCKED.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return changed


def main() -> None:
    catalog_writes = rewrite_catalogs()
    locked_writes = rewrite_locked()
    print(f"catalog value writes: {catalog_writes}")
    print(f"locked value writes: {locked_writes}")


if __name__ == "__main__":
    main()
