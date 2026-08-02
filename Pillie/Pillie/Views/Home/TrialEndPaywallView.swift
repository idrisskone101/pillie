//
//  TrialEndPaywallView.swift
//  Pillie
//
//  The Trial-End Paywall (issue #169 / ADR 0007 / CONTEXT.md): the purchase
//  ask after the user has lived with the blocker, shown once on first launch
//  after Reverse Trial expiry and re-opened from the Protection Off card.
//  Cohort copy + own-stats assembly live in TrialEndPaywallContent (value-type
//  tested); this view owns plan selection, purchase/restore, and the success
//  state. Claude Design "Trial-End Paywall" 2a–2e.
//

import SwiftUI
import RevenueCat
import os

struct TrialEndPaywallView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var animateIn = false
    @State private var selectedPlan: PilliePlusPlan = .annual
    @State private var offerings: Offerings?
    @State private var offeringsError = false
    @State private var purchaseError: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var purchaseSucceeded = false
    @State private var succeededPlan: PilliePlusPlan = .annual
    @State private var showDeclineFeedback = false
    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)

    let content: TrialEndPaywallContent
    let declineFeedbackContent: TrialDeclineFeedbackContent
    let routeContinueFree: () -> TrialDeclineFeedbackRoute
    let onDismiss: () -> Void
    let onFeedbackResolved: () -> Void

    #if DEBUG
    /// One-shot UserDefaults key consumed on appear to force the success state
    /// for simulator QA (see the /trial-end-paywall debug deep link).
    static let debugSuccessStateKey = "trialEndPaywallDebugSuccessState"
    #endif

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()
            backgroundBlob

            if showDeclineFeedback {
                TrialDeclineFeedbackView(
                    content: declineFeedbackContent,
                    onResolve: onFeedbackResolved
                )
                .transition(.opacity)
            } else if purchaseSucceeded {
                successState
                    .transition(.opacity)
            } else {
                offerState
                    .transition(.opacity)
            }
        }
        .animation(PillieTheme.fadeInUpCurve, value: purchaseSucceeded)
        .interactiveDismissDisabled(!content.allowsContinueFree)
        .onAppear {
            telemetry.trialEndPaywallViewed(
                cohort: content.cohort,
                terms: content.terms,
                termsCohort: content.termsCohort
            )
            withAnimation(PillieTheme.fadeInUpCurve) { animateIn = true }
            #if DEBUG
            // QA seam (#169): sandbox purchases aren't reachable from simctl
            // launches, so pillie://debug/trial-end-paywall?success=1 seeds this
            // one-shot flag to render the success state for visual QA.
            if UserDefaults.standard.bool(forKey: Self.debugSuccessStateKey) {
                UserDefaults.standard.removeObject(forKey: Self.debugSuccessStateKey)
                purchaseSucceeded = true
            }
            #endif
        }
        .task {
            subscriptionManager.configure()
            async let offeringsLoaded: Void = loadOfferings()
            await subscriptionManager.refreshStatus()
            await offeringsLoaded
        }
        .alert(PillieLocalization.string(
            "paywall.purchase_error.title",
            table: "Commerce",
            locale: locale
        ), isPresented: .init(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) {
                purchaseError = nil
            }
        } message: {
            Text(purchaseError ?? "")
        }
        // Design 2e: the native no-subscription alert over the sheet, matching
        // the existing paywall's restore path.
        .alert(PillieLocalization.string(
            "paywall.no_subscription.title",
            table: "Commerce",
            locale: locale
        ), isPresented: $showNoSubscriptionAlert) {
            Button(PillieLocalization.string("global.action.ok", locale: locale)) {}
        } message: {
            Text(PillieLocalization.string(
                "paywall.no_subscription.body",
                table: "Commerce",
                locale: locale
            ))
        }
    }

    // MARK: - Background

    private var backgroundBlob: some View {
        let color: Color
        switch content.card {
        case .record(_, _, _, let quietShieldNote):
            color = quietShieldNote == nil ? PillieTheme.coral.opacity(0.28) : PillieTheme.sage.opacity(0.9)
        case .perks:
            color = content.cohort == .reminderOnly
                ? PillieTheme.lavender.opacity(0.8)
                : PillieTheme.coral.opacity(0.28)
        }
        return Circle()
            .fill(color)
            .frame(width: 230, height: 230)
            .blur(radius: 50)
            .offset(x: content.cohort == .reminderOnly ? -110 : 110, y: -60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    // MARK: - Offer state (designs 2a / 2b / 2c)

    private var offerState: some View {
        let titleLead = content.titleAccent.isEmpty
            ? content.title
            : "\(content.title)\n"
        return ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if content.allowsContinueFree {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(PillieTheme.sage, in: Circle())
                    }
                    .accessibilityLabel(PillieLocalization.string(
                        "global.action.close",
                        locale: locale
                    ))
                    .accessibilityIdentifier("trialEndPaywallClose")
                }
            }

            (Text(titleLead).foregroundColor(PillieTheme.textPrimary)
                + Text(content.titleAccent).foregroundColor(PillieTheme.coral))
                .font(.pillie(30, weight: .black))
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))

            Text(content.subtitle)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

            centerpieceCard
                .padding(.top, 16)
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

            Text(content.handwrittenAside)
                .font(.pillieHandwriting(size: 23))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(maxWidth: .infinity)
                .rotationEffect(.degrees(-2))
                .padding(.top, 10)
                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))

            Spacer(minLength: 12)

            Group {
                planTiles
                if content.allowsContinueFree {
                    reassuranceRow
                        .padding(.top, 14)
                }
                purchaseButton
                    .padding(.top, 12)
                secondaryLinks
                    .padding(.top, 12)
                legalFooter
                    .padding(.top, 8)
            }
            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger5))
          }
          .padding(.horizontal, 24)
          .padding(.top, 8)
          .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Centerpiece card

    @ViewBuilder
    private var centerpieceCard: some View {
        switch content.card {
        case .record(let kicker, let dateRange, let rows, let quietShieldNote):
            recordCard(kicker: kicker, dateRange: dateRange, rows: rows, quietShieldNote: quietShieldNote)
        case .perks(let kicker, let chips, let footnote):
            perksCard(kicker: kicker, chips: chips, footnote: footnote)
        }
    }

    private func recordCard(
        kicker: String,
        dateRange: String,
        rows: [TrialEndPaywallContent.RecordRow],
        quietShieldNote: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(kicker)
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(PillieTheme.coral)
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.75)
                Spacer()
                Text(dateRange)
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.75)
            }
            .padding(.bottom, 6)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    (Text(row.value)
                        .font(.pillie(22, weight: .black))
                        .foregroundColor(row.emphasized ? PillieTheme.coral : .white)
                        + Text(row.valueSuffix.map { " \($0)" } ?? "")
                        .font(.pillie(13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5)))
                }
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)
            }

            if let quietShieldNote {
                if !rows.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shield")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                    Text(quietShieldNote)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 13)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.dark)
        )
        .shadow(color: PillieTheme.dark.opacity(0.25), radius: 15, y: 8)
        .accessibilityIdentifier("trialEndPaywallRecordCard")
    }

    private func perksCard(kicker: String, chips: [String], footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker)
                .font(.pillie(10, weight: .black))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.coral)

            FlowingChips(
                chips: chips,
                symbols: CommercePresentation.trialEndPerkSymbols
            )
                .padding(.top, 12)

            Text(footnote)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.dark)
        )
        .shadow(color: PillieTheme.dark.opacity(0.25), radius: 15, y: 8)
        .accessibilityIdentifier("trialEndPaywallPerksCard")
    }

    // MARK: - Plan tiles

    private var annualPackage: Package? {
        package(for: .annual)
    }

    private var monthlyPackage: Package? {
        package(for: .monthly)
    }

    private var lifetimePackage: Package? {
        package(for: .lifetime)
    }

    private func package(for plan: PilliePlusPlan) -> Package? {
        guard let offering = offerings?.current else { return nil }
        let preferredPackage = switch plan {
        case .annual: offering.annual
        case .monthly: offering.monthly
        case .lifetime: offering.lifetime
        }
        return PilliePlusPackageResolver.resolve(
            plan: plan,
            preferredPackage: preferredPackage,
            availablePackages: offering.availablePackages,
            productIdentifier: \Package.storeProduct.productIdentifier
        )
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .annual: return annualPackage
        case .monthly: return monthlyPackage
        case .lifetime: return lifetimePackage
        }
    }

    private var annualPriceText: String {
        annualPackage?.storeProduct.localizedPriceString ?? "—"
    }

    private var monthlyPriceText: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "—"
    }

    private var lifetimePriceText: String {
        lifetimePackage?.storeProduct.localizedPriceString ?? "—"
    }

    private var lifetimeTitle: String {
        lifetimePackage?.storeProduct.localizedTitle ?? "Pillie Plus Lifetime"
    }

    /// Truthful annual-vs-monthly comparison from live store prices (ADR 0002:
    /// no fake stats). `nil` until both packages have loaded.
    private var priceComparison: PaywallPriceComparison? {
        guard let annual = annualPackage?.storeProduct.price,
              let monthly = monthlyPackage?.storeProduct.price else { return nil }
        return PaywallPriceComparison(annualPrice: annual, monthlyPrice: monthly)
    }

    private var annualPerMonthText: String? {
        guard let comparison = priceComparison,
              let formatter = annualPackage?.storeProduct.priceFormatter else { return nil }
        return comparison.monthlyEquivalentString(using: formatter)
    }

    /// "2 months free" derived from real prices (the #162 annual anchor), or
    /// `nil` when there is no honest saving.
    private var savingsBadgeText: String? {
        guard priceComparison?.monthsFree != nil else { return nil }
        return PillieLocalization.string(
            "paywall.plan.best_value",
            table: "Commerce",
            locale: locale
        )
    }

    private var annualPriceAndPeriodText: String {
        CommercePresentation.priceAndPeriod(
            displayPrice: annualPriceText,
            subscriptionPeriod: annualPackage?.storeProduct.subscriptionPeriod,
            locale: locale
        )
    }

    private var monthlyPriceAndPeriodText: String {
        CommercePresentation.priceAndPeriod(
            displayPrice: monthlyPriceText,
            subscriptionPeriod: monthlyPackage?.storeProduct.subscriptionPeriod,
            locale: locale
        )
    }

    @ViewBuilder
    private var planTiles: some View {
        VStack(spacing: 14) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 14) {
                        annualTile
                        monthlyTile
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        annualTile
                            .frame(maxWidth: .infinity)
                        monthlyTile
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            lifetimeTile
        }
        .padding(.top, 10)
    }

    private var annualTile: some View {
        Button {
            selectPlan(.annual)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(PillieLocalization.string(
                    "paywall.plan.annual",
                    table: "Commerce",
                    locale: locale
                ))
                    .font(.pillie(11, weight: .black))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(
                        .top,
                        dynamicTypeSize.isAccessibilitySize && savingsBadgeText != nil ? 24 : 4
                    )

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(annualPriceAndPeriodText)
                        .font(.pillie(24, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Text(annualPerMonthText.map {
                    CommercePresentation.priceAndPeriod(
                        displayPrice: $0,
                        periodValue: 1,
                        periodUnit: .month,
                        locale: locale
                    )
                } ?? " ")
                    .font(.pillie(12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .fill(PillieTheme.dark)
            )
            .overlay {
                if selectedPlan == .annual {
                    RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                        .stroke(PillieTheme.coral, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                radioCircle(selected: selectedPlan == .annual, onDark: true)
                    .padding(12)
            }
            .overlay(alignment: .topLeading) {
                if let savingsBadgeText {
                    Text(savingsBadgeText)
                        .font(.pillie(9, weight: .black))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(PillieTheme.dark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PillieTheme.coral, in: Capsule())
                        .offset(x: 14, y: -10)
                }
            }
            .shadow(color: PillieTheme.dark.opacity(0.28), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(annualPriceAndPeriodText)
        .accessibilityAddTraits(selectedPlan == .annual ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("trialEndPaywallAnnualPlan")
    }

    private var monthlyTile: some View {
        Button {
            selectPlan(.monthly)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(PillieLocalization.string(
                    "paywall.plan.monthly",
                    table: "Commerce",
                    locale: locale
                ))
                    .font(.pillie(11, weight: .black))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(PillieTheme.textMuted)
                    .padding(.top, 4)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(monthlyPriceAndPeriodText)
                        .font(.pillie(24, weight: .black))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Text(PillieLocalization.string(
                    "paywall.plan.cancel_anytime_short",
                    table: "Commerce",
                    locale: locale
                ))
                    .font(.pillie(12, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .fill(selectedPlan == .monthly ? PillieTheme.coralLight : PillieTheme.cardWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(
                        selectedPlan == .monthly ? PillieTheme.coral : PillieTheme.sageHalf,
                        lineWidth: selectedPlan == .monthly ? 2 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                radioCircle(selected: selectedPlan == .monthly, onDark: false)
                    .padding(12)
            }
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monthlyPriceAndPeriodText)
        .accessibilityAddTraits(selectedPlan == .monthly ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("trialEndPaywallMonthlyPlan")
    }

    private var lifetimeTile: some View {
        Button {
            selectPlan(.lifetime)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lifetimeTitle)
                        .font(.pillie(12, weight: .black))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                Text(lifetimePriceText)
                    .font(.pillie(20, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                radioCircle(selected: selectedPlan == .lifetime, onDark: false)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .fill(selectedPlan == .lifetime ? PillieTheme.coralLight : PillieTheme.cardWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(
                        selectedPlan == .lifetime ? PillieTheme.coral : PillieTheme.sageHalf,
                        lineWidth: selectedPlan == .lifetime ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lifetimeTitle), \(lifetimePriceText)")
        .accessibilityAddTraits(selectedPlan == .lifetime ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("trialEndPaywallLifetimePlan")
    }

    private func radioCircle(selected: Bool, onDark: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    selected ? PillieTheme.coral : (onDark ? Color.white.opacity(0.3) : PillieTheme.sage),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)

            if selected {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PillieTheme.dark)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func selectPlan(_ plan: PilliePlusPlan) {
        let response = plusFeedback.selectPlan(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            selectedPlan = plan
        }
        telemetry.trialEndPlanSelected(
            plan: plan.analyticsPlan,
            cohort: content.cohort,
            terms: content.terms,
            termsCohort: content.termsCohort
        )
    }

    // MARK: - Reassurance + footer

    @ViewBuilder
    private var reassuranceRow: some View {
        let items = selectedPlan == .lifetime
            ? [PillieLocalization.string(
                "trial.end.free_title",
                table: "Commerce",
                locale: locale
            )]
            : [
                PillieLocalization.string(
                    "trial.end.free_title",
                    table: "Commerce",
                    locale: locale
                ),
                PillieLocalization.string(
                    "paywall.plan.cancel_anytime_short",
                    table: "Commerce",
                    locale: locale
                ),
            ]

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        reassuranceItem(item)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(items, id: \.self) { item in
                        reassuranceItem(item)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
        )
    }

    private func reassuranceItem(_ item: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PillieTheme.verifiedGreen)
            Text(item)
                .font(.pillie(12, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var purchaseButton: some View {
        Button {
            purchaseSelectedPlan()
        } label: {
            Group {
                if isPurchasing || offerings == nil && !offeringsError {
                    ProgressView()
                        .tint(.white)
                } else if offeringsError {
                    Text(PillieLocalization.string(
                        "paywall.loading.failed",
                        table: "Commerce",
                        locale: locale
                    ))
                        .font(.pillie(16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    HStack(spacing: 10) {
                        Text(content.primaryCTA)
                            .font(.pillie(17, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(offeringsError ? PillieTheme.textMuted : PillieTheme.dark)
            .clipShape(Capsule())
            .shadow(color: PillieTheme.dark.opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isPurchasing || (offerings == nil && !offeringsError))
        .accessibilityIdentifier("trialEndPaywallCTA")
    }

    @ViewBuilder
    private var secondaryLinks: some View {
        if content.allowsContinueFree {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        continueFreeButton
                        restorePurchasesButton
                    }
                } else {
                    HStack(spacing: 14) {
                        continueFreeButton

                        Rectangle()
                            .fill(PillieTheme.textMuted.opacity(0.3))
                            .frame(width: 1, height: 13)

                        restorePurchasesButton
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            restorePurchasesButton
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var continueFreeButton: some View {
        Button {
            continueFree()
        } label: {
            Text(declineFeedbackContent.continueFree)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trialEndPaywallContinueFree")
    }

    private var restorePurchasesButton: some View {
        Button {
            restorePurchases()
        } label: {
            Group {
                if isRestoring {
                    ProgressView()
                        .tint(PillieTheme.textMuted)
                        .scaleEffect(0.72)
                } else {
                    Text(PillieLocalization.string(
                        "paywall.action.restore",
                        table: "Commerce",
                        locale: locale
                    ))
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .accessibilityIdentifier("trialEndPaywallRestore")
    }

    private var legalFooter: some View {
        VStack(spacing: 2) {
            if selectedPlan != .lifetime {
                Text(PillieLocalization.string(
                    "paywall.plan.cancel_anytime",
                    table: "Commerce",
                    locale: locale
                ))
            }
            HStack(spacing: 4) {
                Link(PillieLocalization.string(
                    "paywall.action.terms",
                    table: "Commerce",
                    locale: locale
                ), destination: URL(string: "https://idrisskone101.github.io/pillie/terms-and-conditions")!)
                    .underline()
                Text("·")
                Link(PillieLocalization.string(
                    "paywall.action.privacy",
                    table: "Commerce",
                    locale: locale
                ), destination: URL(string: "https://idrisskone101.github.io/pillie/privacy-policy")!)
                    .underline()
            }
        }
        .font(.pillie(10, weight: .regular))
        .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Success state (design 2d)

    private var successState: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PillieTheme.coral.opacity(0.35))
                    .frame(width: 124, height: 124)
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
            }
            .accessibilityHidden(true)

            Text(PillieLocalization.string(
                "trial.end.welcome_back",
                table: "Commerce",
                locale: locale
            ))
                .foregroundColor(PillieTheme.textPrimary)
                .font(.pillie(34, weight: .black))
                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                .padding(.top, 24)

            Text(successSubtitle)
                .font(.pillie(15, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 10)

            Text(PillieLocalization.string(
                "trial.end.welcome_back",
                table: "Commerce",
                locale: locale
            ))
                .font(.pillieHandwriting(size: 26))
                .foregroundStyle(PillieTheme.patchChangeRose)
                .rotationEffect(.degrees(-2))
                .padding(.top, 12)

            HStack(spacing: 10) {
                Image(systemName: "shield")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .accessibilityHidden(true)
                Text(successPlanLabel)
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(PillieTheme.dark, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: PillieTheme.dark.opacity(0.25), radius: 15, y: 8)
            .padding(.top, 22)

            Spacer()
            Spacer()

            Button {
                onDismiss()
            } label: {
                HStack(spacing: 10) {
                    Text(PillieLocalization.string(
                        "trial.end.back_today",
                        table: "Commerce",
                        locale: locale
                    ))
                        .font(.pillie(17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: PillieTheme.ctaHeight)
                .background(PillieTheme.dark)
                .clipShape(Capsule())
                .shadow(color: PillieTheme.dark.opacity(0.4), radius: 12, y: 6)
            }
            .accessibilityIdentifier("trialEndPaywallSuccessCTA")

            Text(PillieLocalization.string(
                "paywall.plan.cancel_anytime_short",
                table: "Commerce",
                locale: locale
            ))
                .font(.pillie(11, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .accessibilityIdentifier("trialEndPaywallSuccess")
    }

    /// Honest per-cohort success copy (ADR 0002): "blocking is back on" is only
    /// claimed for users whose blocker config is actually saved.
    private var successSubtitle: String {
        CommercePresentation.trialEndSuccessSubtitle(
            cohort: content.cohort,
            locale: locale
        )
    }

    private var successPlanLabel: String {
        switch succeededPlan {
        case .annual: return annualPriceAndPeriodText
        case .monthly: return monthlyPriceAndPeriodText
        case .lifetime: return "\(lifetimeTitle) · \(lifetimePriceText)"
        }
    }

    // MARK: - Purchase / restore

    private func purchaseSelectedPlan() {
        if offeringsError {
            Task { await loadOfferings() }
            return
        }
        guard let package = selectedPackage else {
            plusFeedback.unavailablePurchaseAction(accessibilityReduceMotion: accessibilityReduceMotion)
            return
        }
        let response = plusFeedback.openPaywallOrStartPurchase(
            accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            isPurchasing = true
        }
        let plan = selectedPlan
        telemetry.trialEndPurchaseStarted(
            plan: plan.analyticsPlan,
            cohort: content.cohort,
            terms: content.terms,
            termsCohort: content.termsCohort
        )
        Task {
            do {
                let outcome = try await subscriptionManager.purchase(package)
                switch outcome.conversionEvent {
                case .trialStarted:
                    telemetry.trialEndTrialStarted(
                        plan: plan.analyticsPlan,
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                case .purchaseCompleted:
                    telemetry.trialEndPurchaseCompleted(
                        plan: plan.analyticsPlan,
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                case nil:
                    break
                }
                plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                succeededPlan = plan
                purchaseSucceeded = true
            } catch {
                plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                if error.isCancelledTrialEndPurchase {
                    telemetry.trialEndPurchaseCancelled(
                        plan: plan.analyticsPlan,
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                    await subscriptionManager.refreshStatus()
                } else {
                    telemetry.trialEndPurchaseFailed(
                        plan: plan.analyticsPlan,
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                    telemetry.trackError(.purchase, error: error)
                    purchaseError = CommercePresentation.purchaseErrorMessage(
                        error,
                        locale: locale
                    )
                }
            }
            withAnimation(response.motionProfile.animation) {
                isPurchasing = false
            }
        }
    }

    private func restorePurchases() {
        let response = plusFeedback.startRestore(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            isRestoring = true
        }
        telemetry.trialEndRestoreStarted(
            cohort: content.cohort,
            terms: content.terms,
            termsCohort: content.termsCohort
        )
        Task {
            do {
                try await subscriptionManager.restore()
                if subscriptionManager.hasEntitlement {
                    telemetry.trialEndRestoreCompleted(
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                    plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    purchaseSucceeded = true
                } else {
                    telemetry.trialEndRestoreFailed(
                        cohort: content.cohort,
                        terms: content.terms,
                        termsCohort: content.termsCohort
                    )
                    let calmResponse = plusFeedback.unsuccessfulPaidOutcome(
                        accessibilityReduceMotion: accessibilityReduceMotion)
                    withAnimation(calmResponse.motionProfile.animation) {
                        showNoSubscriptionAlert = true
                    }
                }
            } catch {
                telemetry.trialEndRestoreFailed(
                    cohort: content.cohort,
                    terms: content.terms,
                    termsCohort: content.termsCohort
                )
                telemetry.trackError(.restore, error: error)
                let calmResponse = plusFeedback.unsuccessfulPaidOutcome(
                    accessibilityReduceMotion: accessibilityReduceMotion)
                withAnimation(calmResponse.motionProfile.animation) {
                    purchaseError = CommercePresentation.purchaseErrorMessage(
                        error,
                        locale: locale
                    )
                }
            }
            withAnimation(response.motionProfile.animation) {
                isRestoring = false
            }
        }
    }

    private func continueFree() {
        guard content.allowsContinueFree else { return }
        telemetry.trialEndContinueFreeSelected(
            cohort: content.cohort,
            terms: content.terms,
            termsCohort: content.termsCohort
        )
        switch routeContinueFree() {
        case .enterFreeApp:
            onDismiss()
        case .presentFeedback:
            withAnimation(accessibilityReduceMotion ? nil : PillieTheme.fadeInUpCurve) {
                showDeclineFeedback = true
            }
        }
    }

    private func loadOfferings() async {
        offeringsError = false
        do {
            offerings = try await subscriptionManager.fetchOfferings()
        } catch {
            os_log(.error, "Pillie: failed to fetch trial-end offerings: %{public}@", error.localizedDescription)
            telemetry.trackError(.offerings, error: error)
            offeringsError = true
        }
    }
}

// MARK: - Perk chips

/// The gain-framed card's wrapping chip row. A simple two-row split (the four
/// perks never fit one line) keeps this free of layout-protocol complexity.
private struct FlowingChips: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let chips: [String]
    let symbols: [String]

    private var indexedChips: [(offset: Int, title: String)] {
        chips.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(indexedChips, id: \.offset) { chip in
                    chipView(chip)
                }
            } else {
                ForEach(0..<((chips.count + 1) / 2), id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(
                            indexedChips[rowIndex * 2..<min(rowIndex * 2 + 2, indexedChips.count)],
                            id: \.offset
                        ) { chip in
                            chipView(chip)
                        }
                    }
                }
            }
        }
    }

    private func chipView(_ chip: (offset: Int, title: String)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbols[chip.offset])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .accessibilityHidden(true)
            Text(chip.title)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1), in: Capsule())
    }
}

// MARK: - Error helper

private extension Error {
    var isCancelledTrialEndPurchase: Bool {
        if let purchaseError = self as? SubscriptionPurchaseError,
           purchaseError == .userCancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1
    }
}

#Preview("Loss-framed (2a)") {
    TrialEndPaywallView(
        content: TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: Calendar.current.date(byAdding: .day, value: -16, to: Date())
            ),
            blockerConfigSaved: true,
            stats: TrialEndOwnStats(
                blocksIntercepted: 23, dosesTaken: 13, dosesDue: 14, currentStreak: 9
            ),
            calendar: .current,
            now: Date()
        )!,
        declineFeedbackContent: .make(),
        routeContinueFree: { .presentFeedback },
        onDismiss: {},
        onFeedbackResolved: {}
    )
}

#Preview("Gain-framed (2b)") {
    TrialEndPaywallView(
        content: TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: Calendar.current.date(byAdding: .day, value: -16, to: Date())
            ),
            blockerConfigSaved: false,
            stats: .none,
            calendar: .current,
            now: Date()
        )!,
        declineFeedbackContent: .make(),
        routeContinueFree: { .presentFeedback },
        onDismiss: {},
        onFeedbackResolved: {}
    )
}
