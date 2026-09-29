//
//  ShakeConfirmTypes.swift
//  Pillie
//

import Foundation

/// Where the shake confirm is in its three-shake story: the blister dents, the
/// foil tears, then the streak counter clicks over.
enum ShakeConfirmStage: Int, Equatable {
    case sealed
    case dented
    case torn
    case done

    init(shakeCount: Int, requiredShakes: Int) {
        if shakeCount >= requiredShakes {
            self = .done
        } else if shakeCount <= 0 {
            self = .sealed
        } else if shakeCount * 2 < requiredShakes {
            self = .dented
        } else {
            self = .torn
        }
    }

    /// How far the counter's changing wheels have rolled toward the new streak.
    var odometerProgress: Double {
        switch self {
        case .sealed: 0
        case .dented: 1.0 / 3.0
        case .torn: 2.0 / 3.0
        case .done: 1
        }
    }

    /// Only mention the streak when there is one to keep.
    func headline(streak: StreakChange) -> ShakeHeadline {
        switch (self, streak.isKept) {
        case (.sealed, true): ShakeHeadline(key: "shake.streak.headline.start")
        case (.sealed, false): ShakeHeadline(key: "today.action.shake")
        case (.dented, true): ShakeHeadline(key: "shake.streak.headline.counting", number: streak.before)
        case (.dented, false): ShakeHeadline(key: "shake.streak.headline.keep_going")
        case (.torn, true): ShakeHeadline(key: "shake.streak.headline.almost_count", number: streak.after)
        case (.torn, false): ShakeHeadline(key: "shake.streak.headline.almost")
        case (.done, true): ShakeHeadline(key: "shake.streak.headline.kept")
        case (.done, false): ShakeHeadline(key: "global.action.done")
        }
    }
}

struct ShakeHeadline: Equatable {
    let key: String
    var number: Int?

    func text(locale: Locale) -> String {
        guard let number else { return PillieLocalization.string(key, locale: locale) }
        return PillieLocalization.formatted(key, locale: locale, arguments: Int64(number))
    }
}

/// The line that replaces the counter once the dose is logged. Its key mirrors the
/// `today.action.*` label Home showed for the same action.
struct ShakeLoggedNote: Equatable {
    let key: String
    let pillNumber: Int?

    init(action: DoseScheduleAction) {
        key = DueActionCopy.key(for: action).replacingOccurrences(of: "today.action.", with: "shake.logged.")
        pillNumber = action.method == .pill ? action.cycleDay : nil
    }

    func text(loggedAt time: String, locale: Locale) -> String {
        guard let pillNumber else { return PillieLocalization.formatted(key, locale: locale, arguments: time) }
        return PillieLocalization.formatted(key, locale: locale, arguments: Int64(pillNumber), time)
    }
}

/// What the shake confirm opens for a dose. Each clip follows how the real
/// method is opened (blister, patch pouch, resealable ring pouch).
enum ShakeConfirmArtwork: Equatable {
    case pillBlister
    case patchApply
    case patchChange
    case patchRemove
    case ringInsert
    case ringRemove

    /// Nil for actions with no physical step to show (break and active days).
    init?(action: DoseScheduleAction) {
        switch action.type {
        case .pillActive, .pillSugar:
            self = .pillBlister
        case .patchChange:
            self = action.cycleDay == 1 ? .patchApply : .patchChange
        case .patchRemove:
            self = .patchRemove
        case .ringInsert, .ringReinsert:
            self = .ringInsert
        case .ringRemove:
            self = .ringRemove
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            return nil
        }
    }

    var clip: ShakeClip {
        switch self {
        case .pillBlister: .pill
        case .patchApply: .patchApply
        case .patchChange: .patchChange
        case .patchRemove: .patchRemove
        case .ringInsert: .ringInsert
        case .ringRemove: .ringRemove
        }
    }
}

/// The streak before and after today's dose, frozen when the shake confirm opens
/// so the counter keeps its numbers while the store updates underneath it.
struct StreakChange: Equatable {
    let before: Int
    let after: Int

    static let none = StreakChange(before: 0, after: 0)

    var isKept: Bool { before > 0 && after > before }
}

/// The digit wheels of the streak counter. Wheels whose digit changes roll from
/// the old digit to the new one; a wheel that only exists in the new number
/// (9 → 10) rolls in from blank.
struct StreakOdometerDigits: Equatable {
    struct Wheel: Equatable {
        let from: Character?
        let to: Character

        var rolls: Bool { from != to }
    }

    let wheels: [Wheel]

    init(from: Int, to: Int) {
        let old = Array(String(max(0, from)))
        let new = Array(String(max(0, to)))
        let padding = max(0, new.count - old.count)
        let alignedOld = Array(
            ([Character?](repeating: nil, count: padding) + old.map { Optional($0) }).suffix(new.count)
        )
        wheels = zip(alignedOld, new).map { Wheel(from: $0, to: $1) }
    }
}
