//
//  OnboardingPaywallArmBTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct OnboardingPaywallArmBTests {
    private let english = Locale(identifier: "en")
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Step order

    @Test func `The paywall step keeps raw value 22`() {
        #expect(OnboardingFlow.Step.onboardingPaywall.rawValue == 22)
        #expect(OnboardingFlow.Step(rawValue: 14) == .freePlanConfirmation)
        #expect(OnboardingFlow.Step(rawValue: 21) == .trialGranted)
    }

    @Test func `Control keeps today's order`() {
        #expect(OnboardingFlow.displayOrder(for: .control) == OnboardingFlow.displayOrder)
        #expect(!OnboardingFlow.displayOrder(for: .control).contains(.onboardingPaywall))
        #expect(OnboardingFlow.nextStep(after: .reminderPlan, arm: .control) == .appBlocking)
        #expect(OnboardingFlow.previousStep(before: .appBlocking, arm: .control) == .reminderPlan)
    }

    @Test func `Hard trial sells Plus between the diagnosis and the Screen Time ask`() throws {
        let order = OnboardingFlow.displayOrder(for: .hardTrial)
        let reminderPlan = try #require(order.firstIndex(of: .reminderPlan))
        #expect(Array(order[reminderPlan...reminderPlan + 2]) == [.reminderPlan, .onboardingPaywall, .appBlocking])
        #expect(OnboardingFlow.nextStep(after: .reminderPlan, arm: .hardTrial) == .onboardingPaywall)
        #expect(OnboardingFlow.nextStep(after: .onboardingPaywall, arm: .hardTrial) == .appBlocking)
        #expect(OnboardingFlow.previousStep(before: .appBlocking, arm: .hardTrial) == .onboardingPaywall)
        #expect(order.filter { $0 != .onboardingPaywall } == OnboardingFlow.displayOrder)
    }

    @Test func `Funnel step index follows the arm's order`() {
        let paywall = OnboardingFlow.Step.onboardingPaywall.rawValue
        let appBlocking = OnboardingFlow.Step.appBlocking.rawValue
        #expect(OnboardingFlow.displayIndex(for: paywall, arm: .control) == nil)
        #expect(OnboardingFlow.displayIndex(for: paywall, arm: .hardTrial) == OnboardingFlow.displayIndex(for: appBlocking, arm: .control))
        #expect(OnboardingFlow.displayIndex(for: appBlocking, arm: .hardTrial) == OnboardingFlow.displayIndex(for: appBlocking, arm: .control).map { $0 + 1 })
    }

    @Test func `Leaving the paywall for app blocking reads as forward`() throws {
        let transition = try #require(OnboardingFlow.transition(
            from: OnboardingFlow.Step.onboardingPaywall.rawValue,
            to: OnboardingFlow.Step.appBlocking.rawValue
        ))
        #expect(transition.direction == .forward)
        #expect(transition.completedAnalyticsStep == .onboardingPaywall)
    }

    @Test func `Only control writes the in-app trial`() {
        #expect(OnboardingFlow.grantsReverseTrial(on: .appBlocking, arm: .control))
        #expect(!OnboardingFlow.grantsReverseTrial(on: .appBlocking, arm: .hardTrial))
    }

    @Test func `Relaunching on the paywall resumes on the paywall`() {
        #expect(visibleStep(.onboardingPaywall, arm: .hardTrial) == .onboardingPaywall)
        #expect(visibleStep(.onboardingPaywall, arm: .control) == .appBlocking)
    }

    // MARK: - Root gate

    @Test func `A hard trial install without Plus is sent back to the paywall`() {
        #expect(gate(arm: .hardTrial, hasEntitlement: false, resolved: true) == .onboardingPaywallRequired)
    }

    @Test func `A hard trial install waits for RevenueCat before choosing`() {
        #expect(gate(arm: .hardTrial, hasEntitlement: false, resolved: false) == .verifyingAccess)
    }

    @Test func `A hard trial payer gets the app`() {
        #expect(gate(arm: .hardTrial, hasEntitlement: true, resolved: true) == .app)
    }

    @Test func `Control without a trial grant still gets the app`() {
        #expect(gate(arm: .control, hasEntitlement: false, resolved: true) == .app)
    }

    // MARK: - Reinstall

    @Test func `A reinstalled hard trial install that never paid keeps its arm`() {
        let stored = OnboardingPaywallEnrollment.assigned(OnboardingPaywallAssignment(
            arm: .hardTrial,
            source: .flag,
            assignedAt: now,
            appVersion: "2.3"
        ))
        let enrollment = OnboardingPaywallExperiment.enrollment(
            stored: stored,
            hasExistingAppState: false,
            hasTrialGrant: false,
            now: now,
            appVersion: "2.3"
        )
        #expect(enrollment == stored)
    }

    @Test func `Offline at the diagnosis falls back to control`() {
        let locked = OnboardingPaywallExperiment.lockedAssignment(.pending(since: now), now: now, appVersion: "2.3")
        #expect(locked.arm == .control)
        #expect(locked.source == .offlineDefault)
    }

    // MARK: - App Review link

    @Test func `The review link works until the diagnosis continues`() {
        #expect(acceptsReview(step: nil))
        #expect(acceptsReview(step: .welcome))
        #expect(acceptsReview(step: .method))
        #expect(acceptsReview(step: .reminderPlan))
        #expect(!acceptsReview(step: .onboardingPaywall))
        #expect(!acceptsReview(step: .appBlocking))
        #expect(!acceptsReview(step: .trialGranted))
        #expect(!acceptsReview(step: .complete))
    }

    @Test func `A payer skips the paywall unless the install came from the review link`() {
        #expect(OnboardingFlow.skipsOnboardingPaywall(hasEntitlement: true, isReviewInstall: false))
        #expect(!OnboardingFlow.skipsOnboardingPaywall(hasEntitlement: true, isReviewInstall: true))
        #expect(!OnboardingFlow.skipsOnboardingPaywall(hasEntitlement: false, isReviewInstall: false))
    }

    @Test func `A review install stays out of the analysis`() {
        let review = OnboardingPaywallAssignment(arm: .hardTrial, source: .review, assignedAt: now, appVersion: "2.2.1")
        #expect(!review.isEligible)
        #expect(OnboardingPaywallAssignmentSource.review.rawValue == "review")
    }

    // MARK: - Trial-end machinery stays off

    @Test func `The trial-end wall never auto-presents without a trial grant`() {
        let state = PlusAccessState(hasEntitlement: false, trialGrantDate: nil)
        #expect(!TrialEndPaywallAutoPresentation.shouldPresent(
            state: state,
            terms: .hardPaywall,
            termsCohort: .postCutover,
            entitlementResolved: true,
            alreadyShown: false,
            calendar: calendar,
            now: now
        ))
    }

    @Test func `The extend offer never rises on the onboarding paywall`() {
        let board = onboardingBoard(hasEntitlement: false)
        #expect(board?.isTrialEnd == false)
        #expect(TrialEndExtendOfferDecision.offer(
            trigger: .sheetCancel,
            isTrialEndBoard: board?.isTrialEnd ?? true,
            phase: .unseen,
            eligibility: .eligible,
            product: TrialEndExtendProduct(productID: SubscriptionManager.extendAnnualProductID, priceDisplay: "$29.99", freeDays: 7),
            now: now,
            calendar: calendar
        ) == nil)
    }

    // MARK: - Board

    @Test func `The onboarding board has no way past it`() throws {
        let board = try #require(onboardingBoard(hasEntitlement: false))
        #expect(board.moment == .onboarding)
        #expect(board.chrome == HonestPaywallChrome(showsClose: false, allowsInteractiveDismiss: false, showsContinueFree: false))
    }

    @Test func `A payer gets no onboarding board`() {
        #expect(onboardingBoard(hasEntitlement: true) == nil)
    }

    // MARK: - Free week

    @Test func `The free week shows only for an eligible seven day intro`() {
        #expect(snapshot(introDays: 7).offersAnnualFreeWeek(eligibility: .eligible))
        #expect(!snapshot(introDays: 7).offersAnnualFreeWeek(eligibility: .ineligible))
        #expect(!snapshot(introDays: 7).offersAnnualFreeWeek(eligibility: .unknown))
        #expect(!snapshot(introDays: 14).offersAnnualFreeWeek(eligibility: .eligible))
        #expect(!snapshot(introDays: nil).offersAnnualFreeWeek(eligibility: .eligible))
    }

    @Test func `Onboarding plans read Year, Month, Lifetime with the free week on Year`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .onboarding,
            offerings: snapshot(introDays: 7),
            selection: .subscribe(.year),
            locale: english,
            annualFreeWeek: true
        )
        #expect(checkout.cards.map(\.intent) == [.subscribe(.year), .subscribe(.month), .lifetime])
        #expect(checkout.cards[0].price == "$29.99")
        #expect(checkout.cards[0].savingsBadge == "7 days free")
        #expect(checkout.primaryCTA == "Start my free week")
        #expect(checkout.reassurance == "7 days free, then $29.99 a year. Cancel anytime in Settings.")
        #expect(checkout.primaryAction == .purchase)
    }

    @Test func `A reinstaller who used a trial sees the plain yearly price`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .onboarding,
            offerings: snapshot(introDays: 7),
            selection: .subscribe(.year),
            locale: english,
            annualFreeWeek: false
        )
        #expect(checkout.primaryCTA == "Get Plus for $29.99 a year")
        #expect(checkout.reassurance == "Cancel anytime in Settings")
        #expect(checkout.cards[0].savingsBadge != "7 days free")
    }

    @Test func `Monthly on the onboarding paywall never mentions a free week`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .onboarding,
            offerings: snapshot(introDays: 7),
            selection: .subscribe(.month),
            locale: english,
            annualFreeWeek: true
        )
        #expect(checkout.primaryCTA == "Get Plus for $4.99 a month")
        #expect(checkout.reassurance == "Cancel anytime in Settings")
    }

    @Test func `Plans that fail to load offer Try again on the onboarding paywall`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .onboarding,
            offerings: nil,
            selection: .subscribe(.year),
            locale: english,
            loadFailed: true
        )
        #expect(checkout.primaryAction == .retry)
        #expect(checkout.isPurchaseEnabled)
        #expect(checkout.primaryCTA == "Try again")
    }

    @Test func `The trial-end wall keeps its disabled placeholder`() {
        let checkout = PaywallCheckoutBuilder.build(
            moment: .trialEnded(.hardPaywall),
            offerings: nil,
            selection: .subscribe(.year),
            locale: english,
            loadFailed: true
        )
        #expect(checkout.primaryAction == .purchase)
        #expect(!checkout.isPurchaseEnabled)
        #expect(checkout.cards.map(\.intent) == [.subscribe(.month), .subscribe(.year)])
    }

    // MARK: - Helpers

    private func acceptsReview(step: OnboardingFlow.Step?) -> Bool {
        OnboardingPaywallExperiment.acceptsReviewOverride(onboardingStep: step?.rawValue)
    }

    private func visibleStep(_ step: OnboardingFlow.Step, arm: OnboardingPaywallArm) -> OnboardingFlow.Step? {
        OnboardingFlow.visibleStep(for: step.rawValue, isPlus: false, selectedFreePlan: false, arm: arm)
    }

    private func gate(arm: OnboardingPaywallArm, hasEntitlement: Bool, resolved: Bool) -> RootCommerceGate {
        RootCommerceGate.resolve(
            state: PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: nil),
            arm: arm,
            termsCohort: .postCutover,
            hardPaywallEnabled: true,
            entitlementResolved: resolved,
            configurationResolved: true,
            calendar: calendar,
            now: now
        )
    }

    private func onboardingBoard(hasEntitlement: Bool) -> HonestPaywallBoard? {
        HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: nil),
            entry: .onboardingEnd,
            method: .pill,
            calendar: calendar,
            now: now,
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
    }

    private func snapshot(introDays: Int?) -> PaywallOfferingsSnapshot {
        .fixture(
            annualDisplay: "$29.99",
            monthlyDisplay: "$4.99",
            lifetimeDisplay: "$69.99",
            annual: 29.99,
            monthly: 4.99,
            lifetime: 69.99,
            annualIntroFreeDays: introDays
        )
    }
}
