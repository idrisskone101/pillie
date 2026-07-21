import XCTest

@testable import Pillie

final class AppBlockingSetupContentTests: XCTestCase {
    private let content = AppBlockingSetupContent.default

    // MARK: - Reversible pill-time framing (#218)

    func testSetupCopyExplainsPillTimePauseMedicationUnlockAndReversibility() {
        XCTAssertEqual(content.badge, "Pillie Plus")
        XCTAssertEqual(content.chooseAppsCTA, "Choose apps to pause at pill time")

        let explanation = [content.subtitle, content.emptyDetail]
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(explanation.contains("after your pillie reminder"))
        XCTAssertTrue(explanation.contains("unlock when you log your pill"))
        XCTAssertTrue(explanation.contains("change"))
        XCTAssertTrue(explanation.contains("later"))
    }

    func testTrialDisclosureIsClearAndDoesNotReplaceSkip() {
        XCTAssertEqual(
            content.trialDisclosure,
            "Pillie Plus is unlocked for 14 days. No card required."
        )
        XCTAssertTrue(content.visibleCopy.contains(content.trialDisclosure))
        XCTAssertEqual(content.skipCTA, "Continue with reminders only")
    }

    func testDeniedOrCancelledAuthorizationShowsRecoveryWithoutStrandingReminderOnly() {
        var permission = AppBlockingSetupPermissionState()

        XCTAssertTrue(permission.beginRequest())
        XCTAssertEqual(
            permission.completeRequest(isAuthorized: false),
            .showRecovery
        )
        XCTAssertTrue(permission.isRecoveryVisible)
        XCTAssertEqual(content.retryAuthorizationCTA, "Try Screen Time again")
        XCTAssertEqual(content.skipCTA, "Continue with reminders only")
    }

    func testRecoveryRetryStartsANewExplicitAuthorizationRequest() {
        var permission = AppBlockingSetupPermissionState()
        XCTAssertTrue(permission.beginRequest())
        XCTAssertEqual(permission.completeRequest(isAuthorized: false), .showRecovery)

        XCTAssertTrue(permission.beginRequest())
        XCTAssertTrue(permission.isRequesting)
    }

    func testSavedSelectionWithoutAuthorizationRequestsPermissionBeforeSaving() {
        XCTAssertEqual(
            AppBlockingSetupPrimaryAction.resolve(
                hasSelection: true,
                isAuthorized: false
            ),
            .requestAuthorization
        )
    }

    func testDebugRecoverySeamRendersTheSameDeniedStateUsedByAuthorizationFailure() {
        var permission = AppBlockingSetupPermissionState()

        permission.showRecoveryForDebug()

        XCTAssertTrue(permission.isRecoveryVisible)
    }

    // MARK: - Empty state (AC3 honest empty state)

    func testEmptyStateExplainsScreenTimePickerAndCountOnlyStorage() {
        XCTAssertFalse(content.emptyTitle.isEmpty)
        XCTAssertTrue(content.emptyDetail.contains("Screen Time"))
        XCTAssertTrue(content.emptyDetail.lowercased().contains("count"))
        XCTAssertEqual(content.chooseAppsCTA, "Choose apps to pause at pill time")
    }

    func testCategoryHintsAreGenericCategoriesNotAppNames() {
        XCTAssertEqual(
            content.categoryHints.map(\.name),
            ["Social", "Entertainment", "Games", "Shopping"]
        )
    }

    // MARK: - Selected state (AC5 privacy-safe summary)

    func testSelectedStateCopyReassuresPrivacy() {
        XCTAssertEqual(content.changeSelectionCTA, "Change selection")
        let note = content.selectedPrivacyNote.lowercased()
        // Pillie stores only a count; it never learns which apps were chosen.
        XCTAssertTrue(note.contains("never") || note.contains("count"))
    }

    func testSelectedSummaryLabelIsGenericAndNamesNoApps() {
        // The selected state shows only a count + this label — no category chips,
        // icons, or app names.
        XCTAssertEqual(content.selectedSummaryLabel, "apps & categories blocked")
        let label = content.selectedSummaryLabel.lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat"] {
            XCTAssertFalse(label.contains(name))
        }
    }

    // MARK: - Footer

    func testFooterUsesFinishAndSkipCopy() {
        XCTAssertEqual(content.finishCTA, "Finish Setup")
        XCTAssertEqual(content.skipCTA, "Continue with reminders only")
    }

    // MARK: - Invariants preserved from the prior screen

    func testVisibleCopyKeepsPlusScreenTimeAndOnDeviceAndExcludesAds() {
        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertTrue(visibleCopy.contains("pillie plus"))
        XCTAssertTrue(visibleCopy.contains("screen time"))
        XCTAssertTrue(visibleCopy.contains("device"))
        XCTAssertFalse(visibleCopy.contains("pillie+"))
        XCTAssertFalse(visibleCopy.contains("ad blocking"))
        XCTAssertFalse(visibleCopy.contains("ads"))
    }

    // MARK: - Permission-state VoiceOver labels (#84 QA)

    func testEmptyPermissionStateExposesOneClearVoiceOverLabel() {
        // The empty permission card reads as a single coherent element instead of
        // scattered Text/chip fragments — same treatment as the selected card.
        let label = content.emptyStateAccessibilityLabel
        XCTAssertTrue(label.contains(content.emptyTitle))
        XCTAssertTrue(label.contains("Screen Time"))
        XCTAssertTrue(label.lowercased().contains("count"))
        XCTAssertGreaterThan(label.count, content.emptyTitle.count)
    }

    func testLockedPermissionStateExposesOneClearVoiceOverLabel() {
        let label = content.lockedAccessibilityLabel
        XCTAssertTrue(label.contains(content.lockedTitle))
        XCTAssertTrue(label.contains(content.lockedDetail))
    }

    func testPermissionStateAccessibilityLabelsNameNoRealApps() {
        let combined = (content.emptyStateAccessibilityLabel + " " + content.lockedAccessibilityLabel).lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit"] {
            XCTAssertFalse(combined.contains(name), "VoiceOver label must not name a real app: \(name)")
        }
    }

    // MARK: - AC5: copy must never name real third-party apps

    func testVisibleCopyNeverNamesRealThirdPartyApps() {
        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        let realAppNames = ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit", "twitter"]
        for name in realAppNames {
            XCTAssertFalse(visibleCopy.contains(name), "Copy must not name a real app: \(name)")
        }
    }
}
