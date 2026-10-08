import Foundation
import Observation

/// Hands a tapped win-back push to the trial-end wall, which Home already
/// presents for every hard-paywall expiree. The wall may be on screen already
/// (the tap brought the app back) or still on its way (a cold launch).
@Observable @MainActor
final class WinbackRouter {
    static let shared = WinbackRouter()

    /// An open older than this is ignored: she has moved on.
    static let pendingLifetime: TimeInterval = 10 * 60

    var pendingOpen: WinbackOpen?

    /// The push tap, and DEBUG's `pillie://debug/winback-open`, since the
    /// simulator cannot tap a banner.
    func open(slot: WinbackSlot, variant: WinbackVariant, at date: Date = Date()) {
        let open = WinbackOpen(slot: slot, variant: variant, date: date)
        ProductAnalyticsTelemetry.live.winbackNotificationOpened(slot: slot, variant: variant)
        open.save()
        pendingOpen = open
    }

    /// The pending open if it is still fresh, without taking it.
    func freshPendingOpen(now: Date = Date()) -> WinbackOpen? {
        guard let pendingOpen, now.timeIntervalSince(pendingOpen.date) < Self.pendingLifetime else { return nil }
        return pendingOpen
    }

    /// Takes the pending open once; a stale one is dropped.
    func takePendingOpen(now: Date = Date()) -> WinbackOpen? {
        let open = freshPendingOpen(now: now)
        pendingOpen = nil
        return open
    }
}

/// The win-back request's userInfo, shared by the request builder and the tap
/// handler so the two can never drift apart.
enum WinbackPayload {
    static let requestKindValue = "winback"
    static let slotKey = "winbackSlot"
    static let variantKey = "winbackVariant"

    static func userInfo(for intent: WinbackIntent) -> [AnyHashable: Any] {
        [
            NotificationManager.PayloadKey.requestKind: requestKindValue,
            slotKey: intent.slot.rawValue,
            variantKey: intent.variant.rawValue,
        ]
    }

    /// Nil unless the notification is a win-back push with a known slot and variant.
    static func push(from userInfo: [AnyHashable: Any]) -> (slot: WinbackSlot, variant: WinbackVariant)? {
        guard userInfo[NotificationManager.PayloadKey.requestKind] as? String == requestKindValue,
              let slot = (userInfo[slotKey] as? Int).flatMap(WinbackSlot.init(rawValue:)),
              let variant = (userInfo[variantKey] as? String).flatMap(WinbackVariant.init(rawValue:))
        else { return nil }
        return (slot, variant)
    }
}
