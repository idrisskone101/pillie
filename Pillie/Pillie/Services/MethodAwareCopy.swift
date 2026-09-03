import Foundation

enum MethodAwareCopy {
    enum Surface {
        case todayOff
        case todaySetup
        case upsellBlocking
    }

    static func key(
        _ surface: Surface,
        action: DoseScheduleAction?,
        method: ContraceptiveMethod
    ) -> String {
        let variant = variantToken(action: action, method: method)
        switch surface {
        case .todayOff:
            return "today.protection.off.detail.\(variant)"
        case .todaySetup:
            return "today.protection.setup.detail.\(variant)"
        case .upsellBlocking:
            return "paywall.upsell.app_blocking.body.\(variant)"
        }
    }

    static func variantToken(
        action: DoseScheduleAction?,
        method: ContraceptiveMethod
    ) -> String {
        if let action {
            switch action.type {
            case .pillActive:
                return "pill"
            case .patchChange:
                return action.cycleDay == 1 ? "patch.apply" : "patch.change"
            case .patchRemove:
                return "patch.remove"
            case .ringInsert:
                return "ring.insert"
            case .ringReinsert:
                return "ring.change"
            case .ringRemove:
                return "ring.remove"
            default:
                break
            }
        }
        switch method {
        case .pill: return "pill"
        case .patch: return "patch.apply"
        case .ring: return "ring.insert"
        }
    }
}
