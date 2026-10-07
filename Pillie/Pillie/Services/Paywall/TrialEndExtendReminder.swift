//
//  TrialEndExtendReminder.swift
//  Pillie
//

import Foundation
import UserNotifications

/// The renewal reminder the extend offer card promises (Paper "6 · Lock
/// Screen"): two days before the charge at the trial-warning hour. Its id sits
/// outside every managed reminder prefix, so reminder replans never touch it.
enum TrialEndExtendReminder {
    static let identifier = "pillie_trial_end_extend_renewal"
    static let requestKindValue = "trialEndExtendRenewal"

    /// Nil when the timeline has no reminder day (a trial of two days or less).
    static func request(
        offer: TrialEndExtendOffer,
        calendar: Calendar,
        locale: Locale
    ) -> UNNotificationRequest? {
        guard let reminder = offer.timeline.reminder else { return nil }
        let dates = TrialEndExtendDates(calendar: calendar, locale: locale)

        let content = UNMutableNotificationContent()
        content.title = PillieLocalization.formatted(
            "notification.trial_end_extend.title",
            table: "Notifications",
            locale: locale,
            arguments: dates.monthDay(offer.timeline.charge)
        )
        content.body = PillieLocalization.formatted(
            "notification.trial_end_extend.body",
            table: "Notifications",
            locale: locale,
            arguments: offer.product.priceDisplay,
            dates.monthDay(offer.timeline.lastDayToCancel(calendar: calendar))
        )
        content.sound = .default
        content.userInfo = [NotificationManager.PayloadKey.requestKind: requestKindValue]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// Whether the pending reminder still tells the truth: the extend
    /// subscription is active and set to renew. A lapse, a cancel in Settings,
    /// or a switch to another plan all make "Plus renews on…" wrong.
    static func isStillDue(isActive: Bool, productID: String?, willRenew: Bool) -> Bool {
        isActive && willRenew && productID == SubscriptionManager.extendAnnualProductID
    }
}
