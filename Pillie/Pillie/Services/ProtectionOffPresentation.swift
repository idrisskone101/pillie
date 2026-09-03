//
//  ProtectionOffPresentation.swift
//  Pillie
//
//  Drives the Protection Off State Home card (issue #167 / ADR 0007 /
//  CONTEXT.md): after Plus Access ends for a user who had blocker
//  configuration, blocking has stopped but their setup is preserved inert.
//  Pure presentation logic (no SwiftUI) so the gating and honesty contract —
//  the user must never believe blocking is active when it is not — is
//  testable as a value type. The card is persistent (no dismissal): it is the
//  way back to the upgrade path until access returns.
//

import Foundation

/// Copy for the Protection Off card. `nil` when the card must not show.
struct ProtectionOffCardContent: Equatable {
    let title: String
    let detail: String
    let ctaTitle: String

    /// Shown only to the blocker-configured cohort without Plus Access. Access
    /// returning (re-purchase or a fresh grant) hides it on the next Home pass;
    /// a user with no saved config lost nothing and is BlockingStatusCard's
    /// cohort instead.
    static func make(
        hasPlusAccess: Bool,
        blockerConfigSaved: Bool,
        locale: Locale = .current
    ) -> ProtectionOffCardContent? {
        guard !hasPlusAccess, blockerConfigSaved else { return nil }
        return ProtectionOffCardContent(
            title: PillieLocalization.string("today.protection.inactive", locale: locale),
            detail: PillieLocalization.string(
                "today.protection.ended.detail",
                locale: locale
            ),
            ctaTitle: PillieLocalization.string(
                "today.protection.ended.cta",
                locale: locale
            )
        )
    }
}
