//
//  BlockingRehearsalTypes.swift
//  Pillie
//
//  The rehearsal's nouns: what it is made from (her answers), the mini Home
//  Screen it draws, and what a pick tile may hold.
//

import Foundation

struct BlockingRehearsalScript: Equatable {
    let featuredApp: BlockingRehearsalApp
    let method: ContraceptiveMethod
    let reminderHour: Int
    let reminderMinute: Int

    init(
        featuredApp: BlockingRehearsalApp,
        method: ContraceptiveMethod,
        reminderHour: Int,
        reminderMinute: Int
    ) {
        self.featuredApp = featuredApp
        self.method = method
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    init(
        distractionChoices: Set<DistractionChoice>,
        method: ContraceptiveMethod,
        reminderHour: Int,
        reminderMinute: Int
    ) {
        self.init(
            featuredApp: .featured(in: distractionChoices),
            method: method,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    func reminderClock(locale: Locale) -> String {
        Self.clock(minuteOfDay: reminderHour * 60 + reminderMinute, locale: locale)
    }

    /// She checks in one minute after the reminder rings.
    func checkedInClock(locale: Locale) -> String {
        Self.clock(minuteOfDay: (reminderHour * 60 + reminderMinute + 1) % (24 * 60), locale: locale)
    }

    /// The first reminder her method sends, whose shipped title and body the
    /// banner shows.
    var reminderAction: DoseScheduleAction {
        let type: PillDay.ActionType = switch method {
        case .pill: .pillActive
        case .patch: .patchChange
        case .ring: .ringInsert
        }
        return DoseScheduleAction(date: .distantPast, type: type, method: method, cycleDay: 1, cycleLength: 28)
    }

    var shakeClip: ShakeClip {
        switch method {
        case .pill: .pill
        case .patch: .patchApply
        case .ring: .ringInsert
        }
    }

    private static func clock(minuteOfDay: Int, locale: Locale) -> String {
        let twelve = ReminderTimeConverter.toTwelveHour(hour24: minuteOfDay / 60, minute: minuteOfDay % 60)
        return ProtectionPlanRoutineSummary.clockText(
            hour12: twelve.hour,
            minute: twelve.minute,
            isPM: twelve.period == 1,
            locale: locale
        )
    }
}

enum BlockingRehearsalApp: String, CaseIterable, Equatable {
    case tiktok
    case instagram
    case youtube
    case messages

    /// Her first Distractions answer in this list's order. Her answers are a
    /// set, so the order she tapped them in is not known.
    static func featured(in choices: Set<DistractionChoice>) -> BlockingRehearsalApp {
        allCases.first { choices.contains($0.choice) } ?? .tiktok
    }

    var choice: DistractionChoice {
        switch self {
        case .tiktok: .tiktok
        case .instagram: .instagram
        case .youtube: .youtube
        case .messages: .messages
        }
    }

    var icon: BlockingRehearsalIcon {
        .symbol(choice.symbolName)
    }

    func name(locale: Locale) -> String {
        choice.localizedTitle(locale: locale)
    }
}

/// Row 2 of the mini Home Screen: Apple's own apps, which no demo pauses.
enum BlockingRehearsalSystemApp: CaseIterable, Equatable {
    case photos
    case camera
    case maps
    case notes

    var icon: BlockingRehearsalIcon {
        switch self {
        case .photos: .plain("photo.fill")
        case .camera: .plain("camera.shutter.button.fill")
        case .maps: .plain("map.fill")
        case .notes: .plain("note.text")
        }
    }

    var label: BlockingRehearsalCopyKey {
        switch self {
        case .photos: .homePhotos
        case .camera: .homeCamera
        case .maps: .homeMaps
        case .notes: .homeNotes
        }
    }
}

/// A tile on the mini Home Screen. The rehearsal ships no other company's
/// artwork: apps are named in text and drawn as neutral tiles.
enum BlockingRehearsalIcon: Hashable {
    /// A dark tile with a coral SF Symbol, for an app the demo pauses.
    case symbol(String)
    /// A light tile with a muted SF Symbol, for the rest of the Home Screen.
    case plain(String)

    static let dock: [BlockingRehearsalIcon] = [
        .plain("phone.fill"), .plain("safari.fill"), .plain("envelope.fill"), .plain("headphones"),
    ]
}
