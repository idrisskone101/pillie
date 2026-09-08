import Foundation
import Testing

@testable import Pillie

struct AppBlockingSetupContentTests {
    private var content: AppBlockingSetupContent {
        AppBlockingSetupContent.localized(locale: Locale(identifier: "en_US"))
    }

    @Test func setupCopyExplainsPillTimePauseMedicationUnlockAndReversibility() {
        #expect(content.badge == "Pillie Plus")
        #expect(content.titleLead == "Pick the apps to pause")
        #expect(content.chooseAppsCTA == "Allow pausing")

        let explanation = [content.subtitle, content.emptyDetail]
            .joined(separator: " ")
            .lowercased()
        #expect(explanation.contains("pause after a reminder"))
        #expect(explanation.contains("check in"))
        #expect(content.changeSelectionCTA == "Edit")
        #expect(content.skipCTA == "Not now")
    }

    @Test func trialDisclosureIsClearAndDoesNotReplaceSkip() {
        #expect(
            content.trialDisclosure
                == "14 days free, no card needed. App blocking turns off after the trial. Reminders stay free."
        )
        #expect(content.visibleCopy.contains(content.trialDisclosure))
        #expect(content.skipCTA == "Not now")
    }

    @Test func hardPaywallTrialDisclosureRequiresAPlanAfterFourteenDays() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        #expect(
            hardPaywallContent.trialDisclosure
                == "Your free trial lasts 14 days. No card needed. After it ends, choose monthly, annual, or lifetime to keep Plus."
        )
    }

    @Test func everyTrialDisclosureStatesThatNoCardIsRequired() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        #expect(content.trialDisclosure.localizedCaseInsensitiveContains("no card needed"))
        #expect(
            hardPaywallContent.trialDisclosure.localizedCaseInsensitiveContains("no card needed")
        )
    }

    @Test func paidSubscriberDisclosureDoesNotPromiseAReverseTrial() {
        let subscriberContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall,
            isPaidSubscriber: true
        )

        #expect(
            subscriberContent.trialDisclosure
                == "Pillie Plus is active on this account. Set up app blocking whenever you’re ready."
        )
        #expect(!subscriberContent.trialDisclosure.contains("14 days"))
    }

    @Test func hardPaywallLockedFallbackOffersUpgradeInsteadOfAFreeExit() {
        let hardPaywallContent = AppBlockingSetupContent.localized(
            locale: Locale(identifier: "en_US"),
            trialEndTerms: .hardPaywall
        )

        #expect(
            hardPaywallContent.lockedDetail
                == "Choose monthly, annual, or lifetime to keep using Pillie."
        )
        #expect(hardPaywallContent.lockedCTA == "Get Pillie Plus")
    }

    @Test func deniedOrCancelledAuthorizationShowsRecoveryWithoutStrandingReminderOnly() {
        var permission = AppBlockingSetupPermissionState()

        let started = permission.beginRequest()
        let resolution = permission.completeRequest(isAuthorized: false)
        #expect(started)
        #expect(resolution == .showRecovery)
        #expect(permission.isRecoveryVisible)
        #expect(content.retryAuthorizationCTA == "Try Again")
        #expect(content.skipCTA == "Not now")
    }

    @Test func recoveryRetryStartsANewExplicitAuthorizationRequest() {
        var permission = AppBlockingSetupPermissionState()
        let firstStart = permission.beginRequest()
        let firstResolution = permission.completeRequest(isAuthorized: false)
        let retryStart = permission.beginRequest()
        #expect(firstStart)
        #expect(firstResolution == .showRecovery)
        #expect(retryStart)
        #expect(permission.isRequesting)
    }

    @Test func savedSelectionWithoutAuthorizationRequestsPermissionBeforeSaving() {
        #expect(
            AppBlockingSetupPrimaryAction.resolve(
                hasSelection: true,
                isAuthorized: false
            ) == .requestAuthorization
        )
    }

    @Test func debugRecoverySeamRendersTheSameDeniedStateUsedByAuthorizationFailure() {
        var permission = AppBlockingSetupPermissionState()

        permission.showRecoveryForDebug()

        #expect(permission.isRecoveryVisible)
    }

    @Test func emptyStateExplainsScreenTimePickerAndCountOnlyStorage() {
        #expect(content.emptyTitle == "This app is paused")
        #expect(content.emptyMarkTaken == "Mark as taken")
        #expect(content.emptyDetail.contains("Screen Time"))
        #expect(
            content.emptyDetail
                == "Next, Apple asks for Screen Time so the apps can pause. Tap Continue."
        )
        #expect(content.chooseAppsCTA == "Allow pausing")
        #expect(content.emptyUnlockFormat.contains("%@"))
        #expect(content.emptyUnlockFormat.lowercased().contains("unlock"))
        #expect(content.privacyNote.lowercased().contains("number"))
    }

    @Test func formattedEmptyUnlockInsertsTheReminderClock() {
        let formatted = AppBlockingSetupContent.formattedEmptyUnlock(
            format: content.emptyUnlockFormat,
            reminderHour: 21,
            reminderMinute: 0,
            locale: Locale(identifier: "en_US")
        )
        // iOS 27 DateFormatter inserts U+202F before AM/PM.
        let normalized = formatted
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        #expect(normalized == "Take your 9:00 PM pill to unlock.")
    }

    @Test func emptyStateCardOffersChooseAppsActionWhenIdle() {
        #expect(
            AppBlockingSetupEmptyCardAction.resolve(
                hasSelection: false,
                isRequesting: false
            ) == .chooseApps
        )
    }

    @Test func categoryHintsAreGenericCategoriesNotAppNames() {
        #expect(
            content.categoryHints.map(\.name)
                == ["Social media", "Short videos", "Games", "Other"]
        )
    }

    @Test func selectedStateCopyReassuresPrivacy() {
        #expect(content.changeSelectionCTA == "Edit")
        let note = content.selectedPrivacyNote.lowercased()
        #expect(note.contains("number"))
        #expect(note.contains("device"))
    }

    @Test func selectedSummaryLabelIsGenericAndNamesNoApps() {
        #expect(content.selectedSummaryLabel == "Apps selected")
        let label = content.selectedSummaryLabel.lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat"] {
            #expect(!label.contains(name))
        }
    }

    @Test func footerUsesFinishAndSkipCopy() {
        #expect(content.finishCTA == "Continue")
        #expect(content.skipCTA == "Not now")
    }

    @Test func visibleCopyKeepsPlusScreenTimeAndOnDeviceAndExcludesAds() {
        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        #expect(visibleCopy.contains("pillie plus"))
        #expect(visibleCopy.contains("screen time"))
        #expect(visibleCopy.contains("device"))
        #expect(!visibleCopy.contains("pillie+"))
        #expect(!visibleCopy.contains("ad blocking"))
        #expect(!visibleCopy.contains("ads"))
    }

    @Test func emptyPermissionStateExposesOneClearVoiceOverLabel() {
        let unlockHint = AppBlockingSetupContent.formattedEmptyUnlock(
            format: content.emptyUnlockFormat,
            reminderHour: 21,
            reminderMinute: 0,
            locale: Locale(identifier: "en_US")
        )
        let label = content.emptyStateAccessibilityLabel(unlockHint: unlockHint)
        #expect(label.contains(content.emptyTitle))
        #expect(label.contains(unlockHint))
        #expect(label.lowercased().contains("number"))
        #expect(label.count > content.emptyTitle.count)
    }

    @Test func lockedPermissionStateExposesOneClearVoiceOverLabel() {
        let label = content.lockedAccessibilityLabel
        #expect(label.contains(content.lockedTitle))
        #expect(label.contains(content.lockedDetail))
    }

    @Test func lockedPermissionVoiceOverLabelDoesNotDoubleSentencePunctuation() {
        #expect(!content.lockedAccessibilityLabel.contains(".."))
    }

    @Test func permissionStateAccessibilityLabelsNameNoRealApps() {
        let combined = (
            content.emptyStateAccessibilityLabel(unlockHint: "Take your 9:00 PM pill to unlock.")
                + " "
                + content.lockedAccessibilityLabel
        ).lowercased()
        for name in ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit"] {
            #expect(!combined.contains(name), "VoiceOver label must not name a real app: \(name)")
        }
    }

    @Test func visibleCopyNeverNamesRealThirdPartyApps() {
        let visibleCopy = content.visibleCopy.joined(separator: " ").lowercased()
        let realAppNames = ["tiktok", "instagram", "youtube", "snapchat", "facebook", "reddit", "twitter"]
        for name in realAppNames {
            #expect(!visibleCopy.contains(name), "Copy must not name a real app: \(name)")
        }
    }

    @Test func a10CopyIsTranslatedForEveryShippedCatalog() {
        let keys = [
            "onboarding.blocking_setup.title",
            "onboarding.blocking_setup.subtitle",
            "onboarding.blocking_setup.empty_detail",
            "onboarding.blocking_setup.skip",
            "onboarding.blocking_setup.allow_pausing",
            "onboarding.blocking_setup.paused_app",
            "onboarding.blocking_setup.unlock_hint",
            "onboarding.blocking_setup.mark_taken",
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
                #expect(
                    value != englishByKey[key],
                    "\(identifier) still uses English for \(key)"
                )
                #expect(!value.isEmpty, "\(identifier) is empty for \(key)")
                if key == "onboarding.blocking_setup.unlock_hint" {
                    #expect(
                        value.components(separatedBy: "%@").count == 2,
                        "\(identifier) unlock hint must keep one %@"
                    )
                }
            }
        }
    }

    @Test func paperCircleSitsWellAboveThePhoneBezel() {
        #expect(A10PhoneStageLayout.designCircleBottomInset == 102)
        #expect(A10PhoneStageLayout.designCircleTop == 30)
        #expect(A10PhoneStageLayout.designPhone == CGSize(width: 232, height: 300))
    }

    @Test func paperCanvasFitsOneToOneOnTheArtboard() {
        let layout = A10PhoneStageLayout.fitted(in: CGSize(width: 390, height: 442))
        #expect(layout.scale == 1)
    }

    @Test func tallerPhoneKeepsArtboardWidthAndDoesNotStretchTheHalo() {
        let layout = A10PhoneStageLayout.fitted(in: CGSize(width: 390, height: 600))
        #expect(layout.scale == 1)
    }
}
