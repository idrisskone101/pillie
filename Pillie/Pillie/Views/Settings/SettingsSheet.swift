enum SettingsSheet: Identifiable {
    case protocolEditor
    case reminderTime
    case customReminders
    case customRemindersUpsell
    case refillReminder
    case autoReminderInterval
    case autoReminderRetryLimit
    case smartRemindersUpsell
    case cycleDay
    case blockedApps
    case blockingUpsell
    case language
    #if DEBUG
    case developerMenu
    #endif

    var id: Self { self }
}
