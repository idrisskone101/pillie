import Foundation

/// Plans the win-back pushes from `WinbackSlot`. Pure: the caller supplies
/// expiry, the clock, and everything it read from storage.
enum WinbackPlanner {
    static let leadMinutes = 120
    static let earliestLeadMinute = 9 * 60
    /// A push this soon after an open is skipped, not postponed: she has just
    /// seen the wall.
    static let quietAfterOpen: TimeInterval = 24 * 60 * 60

    static func plan(_ input: WinbackPlanInput) -> [WinbackIntent] {
        let expiryDay = input.calendar.startOfDay(for: input.expiry)
        return WinbackSlot.allCases.compactMap { slot in
            guard let words = message(for: slot, input),
                  let fire = fireDate(for: slot, expiryDay: expiryDay, input),
                  fire > input.now,
                  !openedJustBefore(fire, input)
            else { return nil }
            return WinbackIntent(slot: slot, variant: words.variant, fireDate: fire, detail: words.detail)
        }
    }

    /// Minutes after midnight for the lead pushes.
    static func leadMinute(reminderHour: Int, reminderMinute: Int) -> Int {
        max(reminderHour * 60 + reminderMinute - leadMinutes, earliestLeadMinute)
    }

    private static func fireDate(for slot: WinbackSlot, expiryDay: Date, _ input: WinbackPlanInput) -> Date? {
        guard let day = input.calendar.date(byAdding: .day, value: slot.calendarDaysAfterExpiry, to: expiryDay) else {
            return nil
        }
        let minute = switch slot.fireTime {
        case .lead: leadMinute(reminderHour: input.reminderHour, reminderMinute: input.reminderMinute)
        case .reminder: input.reminderHour * 60 + input.reminderMinute
        }
        return input.calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }

    /// Only an open at or after expiry counts: before it there was no wall to
    /// see, and a daily logger opens the app the evening before slot 1.
    private static func openedJustBefore(_ fireDate: Date, _ input: WinbackPlanInput) -> Bool {
        guard let lastOpen = input.context.lastAppOpen, lastOpen >= input.expiry else { return false }
        return fireDate < lastOpen.addingTimeInterval(quietAfterOpen)
    }

    private static func message(
        for slot: WinbackSlot,
        _ input: WinbackPlanInput
    ) -> (variant: WinbackVariant, detail: WinbackDetail)? {
        let context = input.context
        let blocker = input.cohort == .blockerConfigured
        let reminderTime = WinbackDetail.reminderTime(hour: input.reminderHour, minute: input.reminderMinute)
        switch slot {
        case .expiryDay:
            return (variant: blocker ? .blocker : .reminder, detail: reminderTime)
        case .dayAfter:
            // Blocker users stay out of the A/B: their line is about the lock.
            if blocker { return (variant: .blocker, detail: reminderTime) }
            return (variant: context.slot2Arm == .challenger ? .notAReminder : .reminder, detail: reminderTime)
        case .extendOffer:
            guard let pitch = context.extendPitch, context.extendPhase.allowsWinbackPitch else { return nil }
            let variant: WinbackVariant = if pitch.trigger == .restoreEmpty {
                .restore
            } else {
                blocker ? .blocker : .offer
            }
            return (variant: variant, detail: .extendPrice(pitch.priceDisplay))
        case .lastNote:
            let days = context.daysLogged
            guard days >= 3 else { return (variant: .new, detail: .daysLogged(days)) }
            return (variant: blocker ? .blocker : .days, detail: .daysLogged(days))
        }
    }
}

struct WinbackPlanInput {
    let now: Date
    /// `ReverseTrialClock.expiryMoment`: local midnight starting trial day 15.
    let expiry: Date
    let reminderHour: Int
    let reminderMinute: Int
    let cohort: TrialEndPaywallCohort
    let context: WinbackContext
    let calendar: Calendar
}
