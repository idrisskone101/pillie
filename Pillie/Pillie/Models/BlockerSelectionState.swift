//
//  BlockerSelectionState.swift
//  Pillie
//
//  Issue #82 — the pure value core behind the App Selection screen.
//
//  The real selection lives in AppBlockingManager.activitySelection as opaque
//  Screen Time tokens (Set<ApplicationToken> / Set<ActivityCategoryToken>) that
//  Pillie can never read or fabricate. Everything the UI and telemetry need is
//  derived here from *counts only*, so a real app/category name can never leak
//  into a summary or an analytics payload (AC5). Plain value type — trivially
//  testable without booting FamilyControls.
//

import Foundation

/// Count-derived view of the user's Screen Time selection.
struct BlockerSelectionState: Equatable {
    /// Number of individually selected applications (opaque token count).
    let applicationCount: Int
    /// Number of selected app categories (opaque token count).
    let categoryCount: Int

    /// Total selected app + category tokens — the only quantity Pillie stores.
    var selectedCount: Int { applicationCount + categoryCount }

    /// No apps and no categories were chosen.
    var isEmpty: Bool { selectedCount == 0 }

    /// At least one app or category is selected.
    var hasSelection: Bool { !isEmpty }

    /// AC2: an empty selection must not save a blocker configuration.
    var canSaveBlockerConfig: Bool { hasSelection }

    /// AC3: the "Finish Setup" CTA is enabled only once something is selected;
    /// while empty, the user keeps the skip / reminder-only path instead.
    var canFinish: Bool { hasSelection }

    /// AC5: the count badge shown on the selected-state card. Derived from the
    /// total count alone, so it can never contain an app or category name.
    var countText: String { "\(selectedCount)" }

    /// AC5: a generic, count-only summary for VoiceOver and any text summary —
    /// "3 selected", never "TikTok, Instagram".
    var accessibilitySummary: String { localizedAccessibilitySummary() }

    func localizedAccessibilitySummary(locale: Locale = .current) -> String {
        if selectedCount == 1 {
            return PillieLocalization.string(
                "onboarding.blocking_setup.selected_count_one",
                locale: locale
            )
        }
        return PillieLocalization.formatted(
            "onboarding.blocking_setup.selected_count",
            locale: locale,
            arguments: Int64(selectedCount)
        )
    }
}
