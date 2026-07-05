//
//  PillieShieldConfigurationExtension.swift
//  PillieShieldConfiguration
//
//  Provides branded shield UI when blocked apps are opened.
//  Uses Pillie design tokens for consistent branding.
//

import ManagedSettingsUI
import ManagedSettings
import UIKit

final class PillieShieldConfigurationExtension: ShieldConfigurationDataSource {
    private enum Palette {
        static let background   = UIColor(red: 253/255, green: 252/255, blue: 248/255, alpha: 1) // #FDFCF8 cream
        static let title        = UIColor(red: 41/255,  green: 37/255,  blue: 36/255,  alpha: 1) // #292524
        static let subtitle     = UIColor(red: 120/255, green: 113/255, blue: 108/255, alpha: 1) // #78716C
        static let primaryBtnBg = UIColor(red: 41/255,  green: 37/255,  blue: 36/255,  alpha: 1) // #292524
        static let coralLight   = UIColor(red: 255/255, green: 240/255, blue: 237/255, alpha: 1) // #FFF0ED
    }

    private let defaults = AppGroupConstants.sharedDefaults

    private var blockingReason: String {
        defaults?.string(forKey: AppGroupKeys.blockingReason) ?? "Take your pill, then get back to it"
    }

    override nonisolated func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    override nonisolated func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    override nonisolated func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    override nonisolated func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    private nonisolated func makeShieldConfiguration() -> ShieldConfiguration {
        // Rendering the shield IS the intercept — the aha moment behind
        // blocker_intervention_fired (#161). This extension has no network,
        // so the count accumulates in the App Group and the main app flushes
        // it to PostHog on next open. Coarse count only; the shielded app is
        // never recorded.
        BlockerInterventionSharedState().recordIntercept()

        let reason = blockingReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleText: String
        if reason.isEmpty {
            subtitleText = "\nTake your pill, then get back to it\nYour apps will be waiting"
        } else {
            subtitleText = "\n\(reason)\nYour apps will be waiting"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Palette.coralLight,
            // The asset carries transparent headroom so the badge renders lower
            // in the system's fixed icon frame; the leading title newline drops
            // the text block with it. Both are deliberate — the stock layout
            // sits too high on the shield.
            icon: UIImage(named: "ShieldIcon"),
            title: ShieldConfiguration.Label(
                text: "\nTime for self-care!",
                color: Palette.title
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: Palette.subtitle
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "On it! ✨",
                color: .white
            ),
            primaryButtonBackgroundColor: Palette.primaryBtnBg
        )
    }
}
