//
//  DoseWindowExplainerTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct DoseWindowExplainerTests {
    private let english = Locale(identifier: "en")

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func time(_ hour: Int) -> String {
        SettingsPresentation.time(hour: hour, minute: 0, locale: english)
    }

    private func window(_ subject: DoseWindowExplainer.Subject = .pill(number: 11), hour: Int) -> DoseWindowExplainer {
        DoseWindowExplainer(
            subject: subject,
            day: date(day: 28, hour: 12),
            reminderHour: hour,
            reminderMinute: 0,
            calendar: calendar
        )!
    }

    @Test func eveningReminderSeenTheSameNight() {
        let explainer = window(hour: 20)
        let now = date(day: 28, hour: 21, minute: 14)

        #expect(explainer.startLabel(now: now, locale: english) == "\(time(20)) tonight")
        #expect(explainer.endLabel(now: now, locale: english) == "\(time(20)) tomorrow")
        #expect(explainer.timeLeft(now: now, locale: english) == "22h 46m left")
        #expect(explainer.midnightFraction == 4.0 / 24)
    }

    @Test func eveningReminderSeenAfterMidnight() {
        let explainer = window(hour: 20)
        let now = date(day: 29, hour: 1)

        #expect(explainer.startLabel(now: now, locale: english) == "\(time(20)) yesterday")
        #expect(explainer.endLabel(now: now, locale: english) == "\(time(20)) today")
        #expect(explainer.timeLeft(now: now, locale: english) == "19h left")
    }

    @Test func morningReminderSeenTheSameAfternoon() {
        let explainer = window(hour: 8)
        let now = date(day: 28, hour: 16)

        #expect(explainer.startLabel(now: now, locale: english) == "\(time(8)) today")
        #expect(explainer.endLabel(now: now, locale: english) == "\(time(8)) tomorrow")
        #expect(explainer.midnightFraction == 16.0 / 24)
    }

    @Test func midnightReminderHasNoMidnightInside() {
        #expect(window(hour: 0).midnightFraction == nil)
        #expect(window(hour: 1).midnightFraction == 23.0 / 24)
    }

    @Test func timeLeftStopsAtZeroAfterTheDeadline() {
        let explainer = window(hour: 20)

        #expect(explainer.timeLeft(now: date(day: 29, hour: 20, minute: 30), locale: english) == "0m left")
        #expect(explainer.timeLeft(now: date(day: 29, hour: 19, minute: 59), locale: english) == "1m left")
    }

    @Test func pillCopy() {
        let explainer = window(.pill(number: 11), hour: 20)

        #expect(explainer.title(locale: english) == "Each pill gets 24 hours.")
        #expect(
            explainer.body(locale: english)
                == "The clock starts at your \(time(20)) reminder and runs to the next one. Midnight doesn't reset it."
        )
        #expect(explainer.midnightCaption(locale: english) == "Still pill 11")
    }

    @Test func patchAndRingCopy() {
        let patch = window(.patch, hour: 20)
        let ring = window(.ring, hour: 20)

        #expect(patch.title(locale: english) == "Each patch change gets 24 hours.")
        #expect(patch.midnightCaption(locale: english) == "Still counts as today")
        #expect(ring.title(locale: english) == "Each ring change gets 24 hours.")
        #expect(ring.midnightCaption(locale: english) == "Still counts as today")
    }

    @Test func accessibilitySummaryReadsTheRibbonLeftToRight() {
        let explainer = window(.pill(number: 11), hour: 20)
        let now = date(day: 28, hour: 21, minute: 14)

        #expect(
            explainer.accessibilitySummary(now: now, locale: english)
                == "\(time(20)) tonight, Midnight, Still pill 11, \(time(20)) tomorrow, 22h 46m left, Then missed"
        )
    }
}
