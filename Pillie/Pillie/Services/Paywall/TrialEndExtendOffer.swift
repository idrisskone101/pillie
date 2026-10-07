//
//  TrialEndExtendOffer.swift
//  Pillie
//

import Foundation
import RevenueCat

/// The one-time "extend with a free week" card on the Trial-End Paywall
/// (ENG-172): offered once, after the person backs out of Apple's purchase
/// sheet or a restore finds nothing (plus one second chance from the slot 3
/// win-back push, ENG-173), for the annual SKU that carries a free
/// intro offer. The decision is nil whenever any input is missing, so the app
/// never offers a product App Store Connect or RevenueCat does not serve.
struct TrialEndExtendOffer: Equatable {
    let trigger: TrialEndExtendTrigger
    let product: TrialEndExtendProduct
    let timeline: TrialEndExtendTimeline
}

enum TrialEndExtendOfferDecision {
    static func offer(
        trigger: TrialEndExtendTrigger,
        isTrialEndBoard: Bool,
        phase: TrialEndExtendOfferPhase,
        eligibility: TrialEndExtendEligibility,
        product: TrialEndExtendProduct?,
        now: Date,
        calendar: Calendar
    ) -> TrialEndExtendOffer? {
        guard isTrialEndBoard,
              phase.offers,
              eligibility == .eligible,
              let product,
              let timeline = TrialEndExtendTimeline(
                  start: now,
                  freeDays: product.freeDays,
                  calendar: calendar
              )
        else { return nil }
        return TrialEndExtendOffer(trigger: trigger, product: product, timeline: timeline)
    }
}

enum TrialEndExtendTrigger: String, Codable {
    case sheetCancel = "sheet_cancel"
    case restoreEmpty = "restore_empty"
}

/// Lifecycle of the offer on this device. One-way, except for one explicit
/// second chance: tapping the slot 3 win-back push (ENG-173) re-arms a card
/// she saw or turned down, and a no to that second showing closes it for
/// good. An event that does not apply to the current phase leaves it
/// unchanged, so a repeated or late event can never re-arm the card.
/// Raw values persist in the Keychain.
enum TrialEndExtendOfferPhase: String {
    case unseen
    case shown
    case accepted
    case declined
    case rearmed
    case reshown
    case closed

    enum Event {
        case present
        case accept
        case decline
        case rearm
    }

    var offers: Bool {
        self == .unseen || self == .rearmed
    }

    /// Whether the slot 3 push may still pitch the card: never after a yes,
    /// and never once the second chance is armed or spent.
    var allowsWinbackPitch: Bool {
        switch self {
        case .unseen, .shown, .declined: true
        case .accepted, .rearmed, .reshown, .closed: false
        }
    }

    func next(on event: Event) -> TrialEndExtendOfferPhase {
        switch (self, event) {
        case (.unseen, .present): .shown
        case (.shown, .accept): .accepted
        case (.shown, .decline): .declined
        case (.shown, .rearm), (.declined, .rearm): .rearmed
        case (.rearmed, .present): .reshown
        case (.reshown, .accept): .accepted
        case (.reshown, .decline): .closed
        default: self
        }
    }
}

struct TrialEndExtendProduct: Equatable {
    let productID: String
    let priceDisplay: String
    let freeDays: Int

    /// Nil unless the product's intro offer is a free trial measured in days
    /// or weeks: the card's timeline promises a day count and a reminder.
    init?(storeProduct: StoreProduct) {
        guard let intro = storeProduct.introductoryDiscount,
              let freeDays = Self.freeDays(
                  paymentMode: intro.paymentMode,
                  period: intro.subscriptionPeriod,
                  numberOfPeriods: intro.numberOfPeriods
              )
        else { return nil }
        self.init(
            productID: storeProduct.productIdentifier,
            priceDisplay: storeProduct.localizedPriceString,
            freeDays: freeDays
        )
    }

    init(productID: String, priceDisplay: String, freeDays: Int) {
        self.productID = productID
        self.priceDisplay = priceDisplay
        self.freeDays = freeDays
    }

    static func freeDays(
        paymentMode: StoreProductDiscount.PaymentMode,
        period: SubscriptionPeriod,
        numberOfPeriods: Int
    ) -> Int? {
        guard paymentMode == .freeTrial, period.value > 0, numberOfPeriods > 0 else { return nil }
        let daysPerUnit: Int
        switch period.unit {
        case .day: daysPerUnit = 1
        case .week: daysPerUnit = 7
        case .month, .year: return nil
        @unknown default: return nil
        }
        return daysPerUnit * period.value * numberOfPeriods
    }
}

/// RevenueCat's `unknown` (the check could not run) and `noIntroOfferExists`
/// both mean "do not offer"; only a confirmed `eligible` shows the card.
enum TrialEndExtendEligibility {
    case eligible
    case ineligible
    case unknown

    init(_ status: IntroEligibilityStatus) {
        switch status {
        case .eligible: self = .eligible
        case .ineligible, .noIntroOfferExists: self = .ineligible
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

/// Today free, a reminder two days before the charge, then the charge.
/// Day math is calendar days so a DST change keeps the wall-clock time.
struct TrialEndExtendTimeline: Equatable {
    /// Matches the day-13 trial expiry warning: two days out, 20:00 local
    /// (`ReminderSchedulePlanner.trialNoticeSlots`).
    static let reminderDaysBeforeCharge = 2
    static let reminderHour = 20

    let start: Date
    let reminder: Date?
    let charge: Date

    init?(start: Date, freeDays: Int, calendar: Calendar) {
        guard let charge = calendar.date(byAdding: .day, value: freeDays, to: start) else {
            return nil
        }
        self.start = start
        self.charge = charge
        self.reminder = Self.reminder(charge: charge, freeDays: freeDays, calendar: calendar)
    }

    /// Nil for a trial of two days or less: the reminder would land on or
    /// before the start day. Any longer trial puts it at least a day ahead.
    private static func reminder(charge: Date, freeDays: Int, calendar: Calendar) -> Date? {
        guard freeDays > reminderDaysBeforeCharge,
              let day = calendar.date(byAdding: .day, value: -reminderDaysBeforeCharge, to: charge)
        else { return nil }
        return calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day)
    }
}
