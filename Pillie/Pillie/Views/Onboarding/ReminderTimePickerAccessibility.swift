//
//  ReminderTimePickerAccessibility.swift
//  Pillie
//
//  VoiceOver labels for the reminder-time wheel picker. Relocated here from the now
//  -removed legacy `TimeSetupView` so the shared constants outlive that dead view —
//  they are still used by `ProtectionPlanReminderTimeView` (#77) and
//  `TimeSetupAccessibilityTests`.
//

import Foundation

enum ReminderTimePickerAccessibility {
    static let hourLabel = "Reminder hour"
    static let minuteLabel = "Reminder minute"
    static let periodLabel = "Reminder period"
}
