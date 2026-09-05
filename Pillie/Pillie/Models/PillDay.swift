//
//  PillDay.swift
//  Pillie
//

import Foundation
import SwiftData

@Model
final class PillDay: Identifiable {
    var id: UUID
    var date: Date
    var status: Status
    var actionTypeRaw: String = ActionType.pillActive.rawValue
    var pack: PillPack?

    enum Status: String, Codable, Hashable {
        case taken
        case missed
        case upcoming
        case breakDay
        case noData
    }

    enum ActionType: String, Codable, Hashable, CaseIterable {
        case pillActive
        case pillBreak
        case patchChange
        case patchRemove
        case patchActive
        case patchBreak
        case ringInsert
        case ringRemove
        case ringReinsert
        case ringActive
        case ringBreak

        var title: String {
            switch self {
            case .pillActive:
                return "Take Pill"
            case .pillBreak:
                return "Break/Placebo"
            case .patchChange:
                return "Change Patch"
            case .patchRemove:
                return "Remove Patch"
            case .patchActive:
                return "Patch Active"
            case .patchBreak:
                return "Off Week"
            case .ringInsert:
                return "Insert Ring"
            case .ringRemove:
                return "Remove Ring"
            case .ringReinsert:
                return "Reinsert Ring"
            case .ringActive:
                return "Ring Active"
            case .ringBreak:
                return "Off Week"
            }
        }

        /// Whether this action type requires explicit user interaction (logging).
        var requiresUserAction: Bool {
            switch self {
            case .pillActive, .patchChange, .patchRemove, .ringInsert, .ringRemove, .ringReinsert:
                return true
            case .pillBreak, .patchBreak, .ringBreak, .patchActive, .ringActive:
                return false
            }
        }

        /// Whether this represents a break/off-week day.
        var isBreakType: Bool {
            switch self {
            case .pillBreak, .patchBreak, .ringBreak:
                return true
            default:
                return false
            }
        }

        /// Whether this represents a passive wearing/active day (no user action needed).
        var isPassiveActive: Bool {
            switch self {
            case .patchActive, .ringActive:
                return true
            default:
                return false
            }
        }
    }

    var actionType: ActionType {
        get { ActionType(rawValue: actionTypeRaw) ?? .pillActive }
        set { actionTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        status: Status,
        actionType: ActionType = .pillActive,
        pack: PillPack? = nil
    ) {
        self.id = id
        self.date = date
        self.status = status
        self.actionTypeRaw = actionType.rawValue
        self.pack = pack
    }
}
