/// Copy for a `PlusUpsellSheet` variant, kept as a value type so the framing of
/// each Plus-gated feature can be unit-tested without rendering the view.
struct PlusUpsellContent: Equatable {
    let localizedFeatureKey: String
    let subtitleKey: String
    let paywallSurface: AnalyticsPaywallSurface

    static func appBlocking(
        action: DoseScheduleAction? = nil,
        method: ContraceptiveMethod = .pill
    ) -> PlusUpsellContent {
        PlusUpsellContent(
            localizedFeatureKey: "paywall.feature.app_blocking.compact",
            subtitleKey: MethodAwareCopy.key(
                .upsellBlocking,
                action: action,
                method: method
            ),
            paywallSurface: .plusUpsell
        )
    }

    static let smartReminders = PlusUpsellContent(
        localizedFeatureKey: "paywall.feature.smart_reminders",
        subtitleKey: "paywall.upsell.smart_reminders.body",
        paywallSurface: .plusUpsell
    )

    static let customReminders = PlusUpsellContent(
        localizedFeatureKey: "paywall.feature.custom_messages.compact",
        subtitleKey: "paywall.upsell.custom_messages.body",
        paywallSurface: .plusUpsell
    )
}
