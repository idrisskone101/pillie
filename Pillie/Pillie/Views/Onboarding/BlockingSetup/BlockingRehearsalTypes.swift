//
//  BlockingRehearsalTypes.swift
//  Pillie
//
//  The rehearsal's nouns: what it is made from (her answers), the mini Home
//  Screen it draws, and what a pick tile may hold.
//

import FamilyControls
import Foundation
import ManagedSettings

/// Everything personal the rehearsal shows, made from her answers.
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

/// The four apps on row 1 of the mini Home Screen, in display order.
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
        switch self {
        case .tiktok: .tiktok
        case .instagram: .instagram
        case .youtube: .youtube
        case .messages: .messages
        }
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
        case .photos: .photos
        case .camera: .camera
        case .maps: .maps
        case .notes: .notes
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

/// The twelve bundled icons. Raw values are asset catalog names.
enum BlockingRehearsalIcon: String, CaseIterable {
    case tiktok = "RehearsalAppTikTok"
    case instagram = "RehearsalAppInstagram"
    case youtube = "RehearsalAppYouTube"
    case messages = "RehearsalAppMessages"
    case photos = "RehearsalAppPhotos"
    case camera = "RehearsalAppCamera"
    case maps = "RehearsalAppMaps"
    case notes = "RehearsalAppNotes"
    case phone = "RehearsalAppPhone"
    case safari = "RehearsalAppSafari"
    case mail = "RehearsalAppMail"
    case music = "RehearsalAppMusic"

    static let dock: [BlockingRehearsalIcon] = [.phone, .safari, .mail, .music]
}

/// One tile on the picks card.
///
/// A real pick carries an opaque FamilyControls token and nothing else. No
/// case holds a `String`, so this type cannot carry an app name: iOS draws the
/// name inside `Label(token)` and Pillie never sees it.
enum BlockingRehearsalPick: Hashable {
    case category(ActivityCategoryToken)
    case application(ApplicationToken)
    case webDomain(WebDomainToken)
    #if DEBUG
    /// The simulator cannot hand out tokens, so QA tiles are drawn from
    /// bundled art.
    case sample(BlockingRehearsalSamplePick)
    #endif

    /// Categories, then apps, then websites. Order inside a group is the set's own.
    static func picks(in selection: FamilyActivitySelection) -> [BlockingRehearsalPick] {
        selection.categoryTokens.map(BlockingRehearsalPick.category)
            + selection.applicationTokens.map(BlockingRehearsalPick.application)
            + selection.webDomainTokens.map(BlockingRehearsalPick.webDomain)
    }
}

/// What the picks card draws: at most two rows of four. When she picked more,
/// the last tile counts the rest.
struct BlockingRehearsalPickGrid: Equatable {
    enum Tile: Hashable {
        case pick(BlockingRehearsalPick)
        case more(Int)
    }

    static let columns = 4
    static let capacity = 8

    let rows: [[Tile]]

    init(picks: [BlockingRehearsalPick]) {
        var tiles = picks.prefix(Self.capacity).map(Tile.pick)
        if picks.count > Self.capacity {
            tiles[Self.capacity - 1] = .more(picks.count - (Self.capacity - 1))
        }
        rows = stride(from: 0, to: tiles.count, by: Self.columns).map {
            Array(tiles[$0..<min($0 + Self.columns, tiles.count)])
        }
    }
}
