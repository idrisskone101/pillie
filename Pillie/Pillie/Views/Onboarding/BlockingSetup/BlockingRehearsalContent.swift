//
//  BlockingRehearsalContent.swift
//  Pillie
//
//  Every word the rehearsal shows, resolved once per locale and script, and the
//  table that says which of them each screen draws.
//

import Foundation

struct BlockingRehearsalContent: Equatable {
    let featuredAppName: String

    let beatsHeader: String
    let setupHeader: String

    let reminderTitle: String
    let reminderBody: String
    let bannerTitle: String
    let bannerBody: String
    let bannerTime: String

    let pausedTitle: String
    let pausedBody: String
    let pauseCardTitle: String
    let pauseCardBody: String
    let openPillie: String

    let shakeEyebrow: String
    let shakeHeadline: String
    let tapInstead: String

    let askTitle: String
    let askBody: String
    let checkedIn: String
    let chooseCTA: String
    let appleLine: String

    let picksTitle: String
    let picksBody: String
    let picksHeader: String
    let changePicks: String
    let categoryCaption: String
    let pauseRowTitle: String
    let pauseRowBody: String
    let resumeRowTitle: String
    let resumeRowBody: String
    let privacyLine: String
    let continueCTA: String

    let refusedTitle: String
    let refusedBody: String
    let conflictBody: String
    let refusedCaption: String
    let retryCTA: String
    let remindersOnly: String

    let trialLine: String

    /// The quiet button is the only way to leave without blocking. No beat has
    /// one. The ask has none while Screen Time is not
    /// allowed, so her first chance to say no is Apple's prompt. Once it is
    /// allowed that prompt never comes back, so the ask offers the exit itself.
    func chrome(
        for stage: BlockingRehearsalStage,
        refusal: ScreenTimeRefusal? = nil,
        isAuthorized: Bool,
        hasEntitlement: Bool
    ) -> BlockingRehearsalChrome {
        let trial: [BlockingRehearsalChrome.Footnote] = hasEntitlement ? [] : [.trial(trialLine)]
        switch stage {
        case .reminder:
            return BlockingRehearsalChrome(
                layout: .page, header: beatsHeader, eyebrow: nil,
                title: reminderTitle, body: reminderBody,
                footnotes: [], primary: nil, quietTitle: nil
            )
        case .paused:
            return BlockingRehearsalChrome(
                layout: .page, header: beatsHeader, eyebrow: nil,
                title: pausedTitle, body: pausedBody,
                footnotes: [], primary: nil, quietTitle: nil
            )
        case .shake:
            return BlockingRehearsalChrome(
                layout: .shakeCover, header: nil, eyebrow: shakeEyebrow,
                title: shakeHeadline, body: nil,
                footnotes: [],
                primary: .init(title: tapInstead, event: .beatControlTapped, showsArrow: false),
                quietTitle: nil
            )
        case .ask:
            return BlockingRehearsalChrome(
                layout: .page, header: setupHeader, eyebrow: nil,
                title: askTitle, body: askBody,
                footnotes: isAuthorized ? trial : trial + [.apple(appleLine)],
                primary: .init(title: chooseCTA, event: .chooseTapped, showsArrow: true),
                quietTitle: isAuthorized ? remindersOnly : nil
            )
        case .refused:
            return BlockingRehearsalChrome(
                layout: .page, header: setupHeader, eyebrow: nil,
                title: refusedTitle,
                body: refusal == .heldByAnotherApp ? conflictBody : refusedBody,
                footnotes: trial,
                primary: .init(title: retryCTA, event: .chooseTapped, showsArrow: false),
                quietTitle: remindersOnly
            )
        case .picks:
            return BlockingRehearsalChrome(
                layout: .page, header: setupHeader, eyebrow: nil,
                title: picksTitle, body: picksBody,
                footnotes: trial,
                primary: isAuthorized
                    ? .init(title: continueCTA, event: .continueTapped, showsArrow: false)
                    : .init(title: chooseCTA, event: .chooseTapped, showsArrow: true),
                quietTitle: nil
            )
        }
    }

    /// The drawn alert teaches "tap Continue". When another app holds Screen
    /// Time there is no prompt to tap anything on.
    static func showsPromptPreview(for refusal: ScreenTimeRefusal?) -> Bool {
        refusal != .heldByAnotherApp
    }

    static func localized(
        script: BlockingRehearsalScript,
        locale: Locale = PillieLocalization.appLocale,
        trialClock: ReverseTrialClock? = nil,
        now: Date = Date()
    ) -> BlockingRehearsalContent {
        let appName = script.featuredApp.name(locale: locale)
        let reminderClock = script.reminderClock(locale: locale)
        let reminder = script.reminderAction

        return BlockingRehearsalContent(
            featuredAppName: appName,
            beatsHeader: BlockingRehearsalCopyKey.header.string(locale: locale),
            setupHeader: BlockingRehearsalCopyKey.askHeader.string(locale: locale),
            reminderTitle: BlockingRehearsalCopyKey.reminderTitle.formatted(reminderClock, locale: locale),
            reminderBody: BlockingRehearsalCopyKey.reminderBody.formatted(appName, locale: locale),
            bannerTitle: reminder.localizedReminderTitle(locale: locale),
            bannerBody: reminder.localizedReminderBody(locale: locale),
            bannerTime: justNow(locale: locale),
            pausedTitle: BlockingRehearsalCopyKey.pausedTitle.formatted(appName, locale: locale),
            pausedBody: BlockingRehearsalCopyKey.pausedBody.string(locale: locale),
            pauseCardTitle: PillieLocalization.string(
                "paywall.mockup.shield.title", table: "Commerce", locale: locale
            ),
            pauseCardBody: PillieLocalization.string(
                "paywall.mockup.shield.subtitle", table: "Commerce", locale: locale
            ),
            openPillie: BlockingRehearsalCopyKey.pausedOpenPillie.string(locale: locale),
            shakeEyebrow: BlockingRehearsalCopyKey.shakeEyebrow.string(locale: locale),
            shakeHeadline: PillieLocalization.string("today.action.shake", locale: locale),
            tapInstead: PillieLocalization.string("today.action.tap_instead", locale: locale),
            askTitle: breakingAfterFirstSentence(
                BlockingRehearsalCopyKey.askTitle.formatted(appName, locale: locale)
            ),
            askBody: BlockingRehearsalCopyKey.askBody.string(locale: locale),
            checkedIn: BlockingRehearsalCopyKey.askCheckedIn.formatted(
                script.checkedInClock(locale: locale), locale: locale
            ),
            chooseCTA: BlockingRehearsalCopyKey.askCTA.string(locale: locale),
            appleLine: BlockingRehearsalCopyKey.askAppleLine.string(locale: locale),
            picksTitle: BlockingRehearsalCopyKey.picksTitle.string(locale: locale),
            picksBody: BlockingRehearsalCopyKey.picksBody.string(locale: locale),
            picksHeader: BlockingRehearsalCopyKey.picksHeader.string(locale: locale),
            changePicks: BlockingRehearsalCopyKey.picksChange.string(locale: locale),
            categoryCaption: BlockingRehearsalCopyKey.picksCategoryCaption.string(locale: locale),
            pauseRowTitle: reminderClock,
            pauseRowBody: BlockingRehearsalCopyKey.picksPauseBody.string(locale: locale),
            resumeRowTitle: BlockingRehearsalCopyKey.picksResumeTitle.string(locale: locale),
            resumeRowBody: BlockingRehearsalCopyKey.picksResumeBody.string(locale: locale),
            privacyLine: PillieLocalization.string("onboarding.blocking_setup.privacy", locale: locale),
            continueCTA: PillieLocalization.string("global.action.continue", locale: locale),
            refusedTitle: BlockingRehearsalCopyKey.refusedTitle.string(locale: locale),
            refusedBody: BlockingRehearsalCopyKey.refusedBody.string(locale: locale),
            conflictBody: ScreenTimeRefusal.heldByAnotherApp.detail(locale: locale),
            refusedCaption: BlockingRehearsalCopyKey.refusedCaption.string(locale: locale),
            retryCTA: PillieLocalization.string("global.action.retry", locale: locale),
            remindersOnly: BlockingRehearsalCopyKey.refusedRemindersOnly.string(locale: locale),
            trialLine: trialLine(locale: locale, trialClock: trialClock, now: now)
        )
    }

    /// `trialClock` is the Reverse Trial already granted, if any: a resumed or
    /// reinstalled setup promises the days it has left.
    static func trialLine(
        locale: Locale = PillieLocalization.appLocale,
        trialClock: ReverseTrialClock? = nil,
        now: Date = Date()
    ) -> String {
        String(
            format: PillieLocalization.string(
                TrialDayRule.copyKey("onboarding.blocking_setup.trial_line"),
                table: "Commerce",
                locale: locale
            ),
            locale: locale,
            trialClock?.displayedDaysRemaining(calendar: .current, now: now)
                ?? TrialLengthEnrollment.current().length.fullDays
        )
    }

    /// A language that writes the ask's title without sentence punctuation
    /// wraps on its own.
    static func breakingAfterFirstSentence(_ text: String) -> String {
        let terminators: Set<Character> = [".", "。", "।", "۔", "!", "?"]
        guard let end = text.firstIndex(where: terminators.contains) else { return text }
        let rest = text[text.index(after: end)...].drop(while: \.isWhitespace)
        guard !rest.isEmpty else { return text }
        return String(text[...end]) + "\n" + String(rest)
    }

    private static func justNow(locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        return formatter.localizedString(from: DateComponents(second: 0))
    }
}

struct BlockingRehearsalChrome: Equatable {
    enum Layout: Equatable {
        case page
        case shakeCover
    }

    enum Footnote: Equatable {
        case trial(String)
        case apple(String)
    }

    struct Primary: Equatable {
        let title: String
        let event: BlockingRehearsalEvent
        let showsArrow: Bool
    }

    let layout: Layout
    let header: String?
    let eyebrow: String?
    let title: String
    let body: String?
    let footnotes: [Footnote]
    /// nil on the first two beats, whose controls are inside the phone card.
    let primary: Primary?
    let quietTitle: String?
}

/// The catalog keys this feature owns. The content reads its own strings only
/// through this type, so the copy test can walk every case in every catalog.
enum BlockingRehearsalCopyKey: String, CaseIterable {
    case header = "onboarding.blocking_rehearsal.header"
    case reminderTitle = "onboarding.blocking_rehearsal.reminder.title"
    case reminderBody = "onboarding.blocking_rehearsal.reminder.body"
    case pausedTitle = "onboarding.blocking_rehearsal.paused.title"
    case pausedBody = "onboarding.blocking_rehearsal.paused.body"
    case pausedOpenPillie = "onboarding.blocking_rehearsal.paused.open_pillie"
    case shakeEyebrow = "onboarding.blocking_rehearsal.shake.eyebrow"
    case askHeader = "onboarding.blocking_rehearsal.ask.header"
    case askTitle = "onboarding.blocking_rehearsal.ask.title"
    case askBody = "onboarding.blocking_rehearsal.ask.body"
    case askCheckedIn = "onboarding.blocking_rehearsal.ask.checked_in"
    case askCTA = "onboarding.blocking_rehearsal.ask.cta"
    case askAppleLine = "onboarding.blocking_rehearsal.ask.apple_line"
    case picksTitle = "onboarding.blocking_rehearsal.picks.title"
    case picksBody = "onboarding.blocking_rehearsal.picks.body"
    case picksHeader = "onboarding.blocking_rehearsal.picks.header"
    case picksChange = "onboarding.blocking_rehearsal.picks.change"
    case picksCategoryCaption = "onboarding.blocking_rehearsal.picks.category_caption"
    case picksPauseBody = "onboarding.blocking_rehearsal.picks.pause_body"
    case picksResumeTitle = "onboarding.blocking_rehearsal.picks.resume_title"
    case picksResumeBody = "onboarding.blocking_rehearsal.picks.resume_body"
    case refusedTitle = "onboarding.blocking_rehearsal.refused.title"
    case refusedBody = "onboarding.blocking_rehearsal.refused.body"
    case refusedCaption = "onboarding.blocking_rehearsal.refused.caption"
    case refusedRemindersOnly = "onboarding.blocking_rehearsal.refused.reminders_only"
    case homePhotos = "onboarding.blocking_rehearsal.home.photos"
    case homeCamera = "onboarding.blocking_rehearsal.home.camera"
    case homeMaps = "onboarding.blocking_rehearsal.home.maps"
    case homeNotes = "onboarding.blocking_rehearsal.home.notes"

    var argumentCount: Int {
        switch self {
        case .reminderTitle, .reminderBody, .pausedTitle, .askTitle, .askCheckedIn: 1
        default: 0
        }
    }

    func string(locale: Locale) -> String {
        PillieLocalization.string(rawValue, locale: locale)
    }

    func formatted(_ argument: String, locale: Locale) -> String {
        PillieLocalization.formatted(rawValue, locale: locale, arguments: argument)
    }
}
