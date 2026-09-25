import Foundation

enum DueActionCopy {
    static func key(for action: DoseScheduleAction) -> String {
        switch action.type {
        case .pillActive:
            "today.action.take_pill"
        case .patchChange:
            action.cycleDay == 1 ? "today.action.apply_patch" : "today.action.change_patch"
        case .patchRemove:
            "today.action.remove_patch"
        case .ringInsert:
            "today.action.insert_ring"
        case .ringReinsert:
            "today.action.change_ring"
        case .ringRemove:
            "today.action.remove_ring"
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            "today.empty.title"
        }
    }

    static func localizedLabel(
        for action: DoseScheduleAction,
        locale: Locale = .current
    ) -> String {
        PillieLocalization.string(key(for: action), locale: locale)
    }
}
