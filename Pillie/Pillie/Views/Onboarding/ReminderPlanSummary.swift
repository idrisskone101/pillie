import SwiftUI

struct ReminderPlanSummary {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        let symbolName: String
        let color: Color
        let background: Color
    }

    let methodValue: String
    let methodDetail: String
    let cyclePositionValue: String
    let cyclePositionDetail: String
    let reminderTimeValue: String
    let reminderTimeDetail: String
    let supportFocusTitle: String
    let supportFocusValue: String

    var items: [Item] {
        [
            Item(
                id: "method",
                title: "Method",
                value: methodValue,
                detail: methodDetail,
                symbolName: "pills.fill",
                color: PillieTheme.coral,
                background: PillieTheme.coralLight
            ),
            Item(
                id: "cycle",
                title: "Current cycle",
                value: cyclePositionValue,
                detail: cyclePositionDetail,
                symbolName: "calendar",
                color: Color(hex: "7DA37B"),
                background: PillieTheme.sage
            ),
            Item(
                id: "time",
                title: "Schedule",
                value: reminderTimeValue,
                detail: reminderTimeDetail,
                symbolName: "clock.fill",
                color: Color(hex: "8C84A9"),
                background: PillieTheme.lavender
            ),
            Item(
                id: "support",
                title: "Support focus",
                value: supportFocusTitle,
                detail: supportFocusValue,
                symbolName: "sparkles",
                color: Color(hex: "E5B454"),
                background: Color(hex: "FFF9EB")
            )
        ]
    }

    var visibleCopy: [String] {
        [
            "Your Personalized Reminder Plan",
            "Built specifically for your routine.",
            methodValue,
            methodDetail,
            cyclePositionValue,
            cyclePositionDetail,
            reminderTimeValue,
            reminderTimeDetail,
            supportFocusTitle,
            supportFocusValue,
            "This is a reminder setup based on your inputs. You can edit it later in Settings."
        ]
    }

    @MainActor
    init(store: PillStore) {
        methodValue = store.pack.method.title
        methodDetail = Self.methodDetailText(for: store.pack)

        let cycle = Self.cyclePosition(for: store)
        cyclePositionValue = cycle.value
        cyclePositionDetail = cycle.detail

        reminderTimeValue = Self.reminderTimeText(hour: store.reminderHour, minute: store.reminderMinute)
        reminderTimeDetail = Self.reminderTimeDetail(hour: store.reminderHour)

        let support = Self.supportFocus(
            goal: store.personalGoal,
            missFrequency: store.missFrequency,
            painPoints: store.painPoints
        )
        supportFocusTitle = support.title
        supportFocusValue = support.detail
    }

    @MainActor
    private static func cyclePosition(for store: PillStore) -> (value: String, detail: String) {
        if let dueAction = DoseScheduleEngine.dueAction(on: store.today, pack: store.pack) {
            return (
                "Day \(dueAction.cycleDay) of \(dueAction.cycleLength)",
                dueAction.cycleDay == 1 ? "Started today" : "Current routine position"
            )
        }
        let cycleLength = max(1, store.pack.cycleLength)
        let day = store.pack.cycleDayIndex(on: store.today) + 1
        let safeDay = min(max(1, day), cycleLength)
        return (
            "Day \(safeDay) of \(cycleLength)",
            safeDay == 1 ? "Started today" : "Current routine position"
        )
    }

    private static func reminderTimeText(hour: Int, minute: Int) -> String {
        let selection = ReminderTimeConverter.toTwelveHour(hour24: hour, minute: minute)
        let period = selection.period == 1 ? "PM" : "AM"
        return "Daily at \(selection.hour):\(String(format: "%02d", selection.minute)) \(period)"
    }

    private static func reminderTimeDetail(hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "Morning consistency anchor"
        case 12..<17:
            return "Afternoon routine cue"
        case 17..<22:
            return "Evening consistency anchor"
        default:
            return "Daily routine cue"
        }
    }

    private static func methodDetailText(for pack: PillPack) -> String {
        switch pack.method {
        case .pill:
            if pack.pillRegimen == .custom, let active = pack.customActiveDays, let breakDays = pack.customBreakDays {
                return "\(active) active / \(breakDays) break days"
            }
            return "\(pack.activeDays) active / \(pack.breakDays) break days"
        case .patch:
            return "Weekly change rhythm"
        case .ring:
            return "Insert, remove, and reinsert rhythm"
        }
    }

    private static func supportFocus(
        goal: PersonalGoal?,
        missFrequency: MissFrequency?,
        painPoints: Set<PainPoint>
    ) -> (title: String, detail: String) {
        if let missFrequency {
            switch missFrequency {
            case .rarely:
                return ("Light nudges", "Keep your routine visible")
            case .sometimes:
                return ("Routine reinforcement", "Weekly check-ins for steadier follow-through")
            case .often:
                return ("Busy-day backup", "Extra follow-through when days get busy")
            case .almostDaily:
                return ("Daily structure", "Make the routine feel more automatic")
            }
        }

        if painPoints.contains(.phoneDistractions) {
            return ("Focus-friendly cue", "A less distracting reminder moment")
        }
        if painPoints.contains(.chaoticSchedule) {
            return ("Flexible cues", "A reminder rhythm for busy days")
        }
        if painPoints.contains(.noRoutine) {
            return ("Routine building", "Simple repetition until it feels automatic")
        }
        if painPoints.contains(.forgetful) {
            return ("Clear reminders", "A nudge before the day gets away")
        }

        switch goal {
        case .buildRoutine:
            return ("Routine building", "Simple cues to make it automatic")
        case .peaceOfMind:
            return ("Confidence check", "A clear log when you need to check")
        case .stayProtected:
            return ("Consistency focus", "Steady reminders for your daily routine")
        case .hormonalBalance:
            return ("Timing support", "Steady cues for your routine")
        case nil:
            return ("Daily rhythm", "Reminders that match your setup")
        }
    }
}
