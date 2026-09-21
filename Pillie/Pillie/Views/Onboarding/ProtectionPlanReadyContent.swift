/// Copy for the Pill Protection Plan Ready screen. Only `statusLabel` is data-driven
/// (the live reminder time); the rest is the fixed warm handoff. Kept as a value type
/// so the reminder-time formatting and the generic (name/count-free) summary are
/// testable without driving the SwiftUI view.
struct ProtectionPlanReadyContent {
    let title: String
    let titleAccent: String
    let subtitle: String
    let statusLabel: String
    let handNote: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle, statusLabel, handNote, primaryCTA]
    }

    /// Builds the ready copy for a reminder configured at `reminderHour`:`reminderMinute`
    /// (24-hour). The reminder time is the only personalized value — nothing about which
    /// apps, or how many, were blocked is ever included.
    static func make(reminderHour: Int, reminderMinute: Int) -> ProtectionPlanReadyContent {
        let twelve = ReminderTimeConverter.toTwelveHour(hour24: reminderHour, minute: reminderMinute)
        let time = ProtectionPlanRoutineSummary.clockText(
            hour12: twelve.hour,
            minute: twelve.minute,
            isPM: twelve.period == 1
        )
        return ProtectionPlanReadyContent(
            title: PillieLocalization.string("onboarding.ready.title"),
            titleAccent: "",
            subtitle: PillieLocalization.string("onboarding.ready.subtitle"),
            statusLabel: PillieLocalization.formatted(
                "onboarding.reminder_time.accessibility",
                arguments: time
            ),
            handNote: "",
            primaryCTA: PillieLocalization.string("onboarding.ready.cta")
        )
    }
}
