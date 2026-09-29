import Foundation

enum DueActionCopy {
    static func key(for action: DoseScheduleAction) -> String {
        verb(for: action).map { "today.action.\($0)" } ?? "today.empty.title"
    }

    static func loggedKey(for action: DoseScheduleAction) -> String {
        verb(for: action).map { "shake.logged.\($0)" } ?? "global.status.completed"
    }

    private static func verb(for action: DoseScheduleAction) -> String? {
        switch action.type {
        case .pillActive, .pillSugar:
            "take_pill"
        case .patchChange:
            action.cycleDay == 1 ? "apply_patch" : "change_patch"
        case .patchRemove:
            "remove_patch"
        case .ringInsert:
            "insert_ring"
        case .ringReinsert:
            "change_ring"
        case .ringRemove:
            "remove_ring"
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            nil
        }
    }

    static func localizedLabel(
        for action: DoseScheduleAction,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.string(key(for: action), locale: locale)
    }
}
