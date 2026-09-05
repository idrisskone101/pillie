import XCTest

@testable import Pillie

final class AppBlockingSetupContentTests: XCTestCase {
    private let content = AppBlockingSetupContent.localized(
        locale: Locale(identifier: "en_US")
    )

    // MARK: - Reversible pill-time framing (#218)

    func testSetupCopyExplainsPillTimePauseMedicationUnlockAndReversibility() {
        XCTAssertEqual(content.badge, "Pillie Plus")
        XCTAssertEqual(content.chooseAppsCTA, "Choose apps to pause")

        let explanation = [content.subtitle, content.emptyDetail]
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(explanation.contains("after a pillie reminder"))
        XCTAssertTrue(explanation.contains("come back after you check in"))
        XCTAssertEqual(content.changeSelectionCTA, "Edit")
        XCTAssertEqual(content.skipCTA, "Continue without app blocking")
    }

    func testTrialDisclosureIsClearAndDoesNotReplaceSkip() {
        XCTAssertEqual(
            content.trialDisclosure,
            "14 days free, no card needed. App blocking turns off after the trial. Reminders stay free."
        )
        XCTAssertTrue(content.visibleCopy.contains(content.trialDisclosure))
        XCTAssertEqual(content.skipCTA, "Continue without app blocking")
    }

    func testHardPaywallTrialDisclosureRequiresAPlanAfterFourteenDays() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        XCTAssertEqual(
            hardPaywallContent.trialDisclosure,
            "Your free trial lasts 14 days. No card needed. After it ends, choose monthly, annual, or lifetime to keep Plus."
        )
    }

    func testEveryTrialDisclosureStatesThatNoCardIsRequired() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        XCTAssertTrue(content.trialDisclosure.localizedCaseInsensitiveContains("no card needed"))
        XCTAssertTrue(
            hardPaywallContent.trialDisclosure.localizedCaseInsensitiveContains("no card needed")
        )
    }

    func testPaidSubscriberDisclosureDoesNotPromiseAReverseTrial() {
        let subscriberContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall,
            isPaidSubscriber: true
        )

        XCTAssertEqual(
            subscriberContent.trialDisclosure,
            "Pillie Plus is active on this account. Set up app blocking whenever you’re ready."
        )
        XCTAssertFalse(subscriberContent.trialDisclosure.contains("14 days"))
    }

    func testHardPaywallLockedFallbackOffersUpgradeInsteadOfAFreeExit() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        XCTAssertEqual(
            hardPaywallContent.lockedDetail,
            "Choose monthly, annual, or lifetime to keep using Pillie."
        )
        XCTAssertEqual(hardPaywallContent.lockedCTA, "Get Pillie Plus")
    }

    func testDeniedOrCancelledAuthorizationShowsRecoveryWithoutStrandingReminderOnly() {
        var permission = AppBlockingSetupPermissionState()

        XCTAssertTrue(permission.beginRequest())
        XCTAssertEqual(
            permission.completeRequest(isAuthorized: false),
            .showRecovery
        )
        XCTAssertTrue(permission.isRecoveryVisible)
        XCTAssertEqual(content.retryAuthorizationCTA, "Try Again")
        XCTAssertEqual(content.skipCTA, "Continue without app blocking")
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
        XCTAssertTrue(content.privacyNote.lowercased().contains("number"))
        XCTAssertEqual(content.emptyDetail, "Use Apple Screen Time to choose categories or apps.")
        XCTAssertEqual(content.chooseAppsCTA, "Choose apps to pause")
    }

    func testEmptyStateCardOffersChooseAppsActionWhenIdle() {
        XCTAssertEqual(
            AppBlockingSetupEmptyCardAction.resolve(
                hasSelection: false,
                isRequesting: false
            ),
            .chooseApps
        )
    }

    func testCategoryHintsAreGenericCategoriesNotAppNames() {
        XCTAssertEqual(
            content.categoryHints.map(\.name),
            ["Social media", "Short videos", "Games", "Other"]
        )
    }

    // MARK: - Selected state (AC5 privacy-safe summary)

    func testSelectedStateCopyReassuresPrivacy() {
        XCTAssertEqual(content.changeSelectionCTA, "Edit")
        let note = content.selectedPrivacyNote.lowercased()
        // Pillie stores only a count; it never learns which apps were chosen.
        XCTAssertTrue(note.contains("number"))
        XCTAssertTrue(note.contains("device"))
    }

    func testSelectedSummaryLabelIsGenericAndNamesNoApps() {
        // The selected state shows only a count + this label — no category chips,
        // icons, or app names.
        XCTAssertEqual(content.selectedSummaryLabel, "Apps selected")
        let label = content.selectedSummaryLabel.lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat"] {
            XCTAssertFalse(label.contains(name))
        }
    }

    // MARK: - Footer

    func testFooterUsesFinishAndSkipCopy() {
        XCTAssertEqual(content.finishCTA, "Continue")
        XCTAssertEqual(content.skipCTA, "Continue without app blocking")
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
        XCTAssertTrue(label.lowercased().contains("number"))
        XCTAssertGreaterThan(label.count, content.emptyTitle.count)
    }

    func testLockedPermissionStateExposesOneClearVoiceOverLabel() {
        let label = content.lockedAccessibilityLabel
        XCTAssertTrue(label.contains(content.lockedTitle))
        XCTAssertTrue(label.contains(content.lockedDetail))
    }

    func testLockedPermissionVoiceOverLabelDoesNotDoubleSentencePunctuation() {
        XCTAssertFalse(content.lockedAccessibilityLabel.contains(".."))
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
