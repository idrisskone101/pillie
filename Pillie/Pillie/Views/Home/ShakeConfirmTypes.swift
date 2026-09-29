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

    var motionLineCount: Int {
        switch self {
        case .sealed, .done: 0
        case .dented: 8
        case .torn: 14
        }
    }

    /// Only mention the streak when there is one to keep.
    func headlineKey(streakBefore: Int, streakAfter: Int) -> String {
        let keepsStreak = streakBefore > 0 && streakAfter > streakBefore
        switch self {
        case .sealed:
            return keepsStreak ? "shake.streak.headline.start" : "today.action.shake"
        case .dented:
            return "shake.streak.headline.keep_going"
        case .torn:
            return "shake.streak.headline.almost"
        case .done:
            return keepsStreak ? "shake.streak.headline.kept" : "global.action.done"
        }
    }
}

/// The three photos the shake confirm steps through for a dose: one per
/// stage until the counter takes over. Each sequence follows how the real
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

    /// Sealed, dented and torn frames, in shake order.
    var imageNames: [String] {
        switch self {
        case .pillBlister:
            ["ShakeBlisterSealed", "ShakeBlisterDented", "ShakeBlisterCrunched"]
        case .patchApply:
            ["ShakePatchPouchSealed", "ShakePatchPouchTorn", "ShakePatchOnLiner"]
        case .patchChange:
            ["ShakePatchFoldedOnPouch", "ShakePatchPouchTorn", "ShakePatchOnLiner"]
        case .patchRemove:
            ["ShakePatchWorn", "ShakePatchPeeling", "ShakePatchFolded"]
        case .ringInsert:
            ["ShakeRingPouchSealed", "ShakeRingPouchTorn", "ShakeRingOut"]
        case .ringRemove:
            ["ShakeRingOut", "ShakeRingPouchTorn", "ShakeRingPouchResealed"]
        }
    }

    /// Point size of the square photo inside the 270 pt plinth, so each
    /// object fills the circle about as much as the pill blister does.
    var imageSize: Double {
        switch self {
        case .pillBlister: 300
        case .patchRemove: 330
        case .patchApply, .patchChange, .ringInsert, .ringRemove: 240
        }
    }

    func imageName(for stage: ShakeConfirmStage) -> String {
        imageNames[min(stage.rawValue, imageNames.count - 1)]
    }
}

/// The streak before and after today's dose, frozen when the shake confirm opens
/// so the counter keeps its numbers while the store updates underneath it.
struct StreakChange: Equatable {
    let before: Int
    let after: Int

    static let none = StreakChange(before: 0, after: 0)
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
