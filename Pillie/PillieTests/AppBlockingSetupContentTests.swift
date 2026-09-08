import XCTest

@testable import Pillie

final class AppBlockingSetupContentTests: XCTestCase {
    private let content = AppBlockingSetupContent.localized(
        locale: Locale(identifier: "en_US")
    )

    // MARK: - Reversible pill-time framing

    func testSetupCopyExplainsPillTimePauseMedicationUnlockAndReversibility() {
        XCTAssertEqual(content.badge, "Pillie Plus")
        XCTAssertEqual(content.titleLead, "Pick the apps to pause")
        XCTAssertEqual(content.chooseAppsCTA, "Allow pausing")

        let explanation = [content.subtitle, content.emptyDetail]
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(explanation.contains("pause after a reminder"))
        XCTAssertTrue(explanation.contains("check in"))
        XCTAssertEqual(content.changeSelectionCTA, "Edit")
        XCTAssertEqual(content.skipCTA, "Not now")
    }

    func testTrialDisclosureIsClearAndDoesNotReplaceSkip() {
        XCTAssertEqual(
            content.trialDisclosure,
            "14 days free, no card needed. App blocking turns off after the trial. Reminders stay free."
        )
        XCTAssertTrue(content.visibleCopy.contains(content.trialDisclosure))
        XCTAssertEqual(content.skipCTA, "Not now")
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
        XCTAssertEqual(content.skipCTA, "Not now")
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

    // MARK: - Empty state

    func testEmptyStateExplainsScreenTimePickerAndCountOnlyStorage() {
        XCTAssertEqual(content.emptyTitle, "This app is paused")
        XCTAssertTrue(content.emptyDetail.contains("Screen Time"))
        XCTAssertEqual(
            content.emptyDetail,
            "Next, Apple asks for Screen Time so the apps can pause. Tap Continue."
        )
        XCTAssertEqual(content.chooseAppsCTA, "Allow pausing")
        XCTAssertTrue(content.emptyUnlockFormat.contains("%@"))
        XCTAssertTrue(content.emptyUnlockFormat.lowercased().contains("unlock"))
        XCTAssertTrue(content.privacyNote.lowercased().contains("number"))
    }

    func testFormattedEmptyUnlockInsertsTheReminderClock() {
        XCTAssertEqual(
            AppBlockingSetupContent.formattedEmptyUnlock(
                format: content.emptyUnlockFormat,
                reminderHour: 21,
                reminderMinute: 0,
                locale: Locale(identifier: "en_US")
            ),
            "Take your 9:00 PM pill to unlock."
        )
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

    // MARK: - Selected state

    func testSelectedStateCopyReassuresPrivacy() {
        XCTAssertEqual(content.changeSelectionCTA, "Edit")
        let note = content.selectedPrivacyNote.lowercased()
        XCTAssertTrue(note.contains("number"))
        XCTAssertTrue(note.contains("device"))
    }

    func testSelectedSummaryLabelIsGenericAndNamesNoApps() {
        XCTAssertEqual(content.selectedSummaryLabel, "Apps selected")
        let label = content.selectedSummaryLabel.lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat"] {
            XCTAssertFalse(label.contains(name))
        }
    }

    // MARK: - Footer

    func testFooterUsesFinishAndSkipCopy() {
        XCTAssertEqual(content.finishCTA, "Continue")
        XCTAssertEqual(content.skipCTA, "Not now")
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

    // MARK: - Permission-state VoiceOver labels

    func testEmptyPermissionStateExposesOneClearVoiceOverLabel() {
        let unlockHint = AppBlockingSetupContent.formattedEmptyUnlock(
            format: content.emptyUnlockFormat,
            reminderHour: 21,
            reminderMinute: 0,
            locale: Locale(identifier: "en_US")
        )
        let label = content.emptyStateAccessibilityLabel(unlockHint: unlockHint)
        XCTAssertTrue(label.contains(content.emptyTitle))
        XCTAssertTrue(label.contains(unlockHint))
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
        let combined = (
            content.emptyStateAccessibilityLabel(unlockHint: "Take your 9:00 PM pill to unlock.")
                + " "
                + content.lockedAccessibilityLabel
        ).lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit"] {
            XCTAssertFalse(combined.contains(name), "VoiceOver label must not name a real app: \(name)")
        }
    }

    // MARK: - Copy must never name real third-party apps

    func testVisibleCopyNeverNamesRealThirdPartyApps() {
        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        let realAppNames = ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit", "twitter"]
        for name in realAppNames {
            XCTAssertFalse(visibleCopy.contains(name), "Copy must not name a real app: \(name)")
        }
    }

    func testA10CopyIsTranslatedForEveryShippedCatalog() {
        let keys = [
            "onboarding.blocking_setup.title",
            "onboarding.blocking_setup.subtitle",
            "onboarding.blocking_setup.empty_detail",
            "onboarding.blocking_setup.skip",
            "onboarding.blocking_setup.allow_pausing",
            "onboarding.blocking_setup.paused_app",
            "onboarding.blocking_setup.unlock_hint",
        ]
        let english = Locale(identifier: AppLanguage.english.rawValue)
        let englishByKey = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, PillieLocalization.string($0, locale: english)) }
        )
        let catalogs = AppLanguage.allCases.compactMap(\.catalogIdentifier)

        for identifier in catalogs where identifier != AppLanguage.english.rawValue {
            let locale = Locale(identifier: identifier)
            for key in keys {
                let value = PillieLocalization.string(key, locale: locale)
                XCTAssertNotEqual(
                    value,
                    englishByKey[key],
                    "\(identifier) still uses English for \(key)"
                )
                XCTAssertFalse(value.isEmpty, "\(identifier) is empty for \(key)")
                if key == "onboarding.blocking_setup.unlock_hint" {
                    XCTAssertEqual(
                        value.components(separatedBy: "%@").count,
                        2,
                        "\(identifier) unlock hint must keep one %@"
                    )
                }
            }
        }
    }
}
