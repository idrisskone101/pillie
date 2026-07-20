//
//  PremiumPaywallView.swift
//  Pillie

import SwiftUI
import RevenueCat
import os

struct SoftPaywallContent {
    struct ComparisonRow {
        let title: String
        let detail: String?
        let icon: String
        let iconBackground: Color
        let iconColor: Color
        let freeIncluded: Bool
        let plusIncluded: Bool

        init(
            title: String,
            detail: String? = nil,
            icon: String,
            iconBackground: Color,
            iconColor: Color,
            freeIncluded: Bool,
            plusIncluded: Bool
        ) {
            self.title = title
            self.detail = detail
            self.icon = icon
            self.iconBackground = iconBackground
            self.iconColor = iconColor
            self.freeIncluded = freeIncluded
            self.plusIncluded = plusIncluded
        }
    }

    let title: String
    let titleAccent: String
    let subtitle: String
    let comparisonLabel: String
    let freeColumnLabel: String
    let plusColumnLabel: String
    let rows: [ComparisonRow]
    let annualPlanLabel: String
    let monthlyPlanLabel: String
    let reassurances: [String]
    let monthlyReassurances: [String]
    let primaryCTA: String
    let monthlyCTA: String
    let freeCTA: String
    let restoreCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle, comparisonLabel, freeColumnLabel, plusColumnLabel]
            + rows.map(\.title)
            + rows.compactMap(\.detail)
            + [annualPlanLabel, monthlyPlanLabel]
            + reassurances
            + monthlyReassurances
            + [primaryCTA, monthlyCTA, freeCTA, restoreCTA]
    }

    static let `default` = SoftPaywallContent(
        title: "Stay on Track with",
        titleAccent: "Pillie Plus",
        subtitle: "Blocks distracting apps right when your reminder is due, for the days a nudge isn't enough.",
        comparisonLabel: "What you get",
        freeColumnLabel: "Free",
        plusColumnLabel: "Plus",
        rows: [
            ComparisonRow(
                title: "Daily reminders",
                icon: "bell.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: true,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Smart Reminders",
                icon: "bell.badge.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Block distracting apps",
                icon: "nosign",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Shake to confirm",
                icon: "iphone.radiowaves.left.and.right",
                iconBackground: PillieTheme.sage,
                iconColor: PillieTheme.verifiedGreen,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "Custom reminder messages",
                icon: "text.bubble.fill",
                iconBackground: PillieTheme.lavender,
                iconColor: PillieTheme.dark,
                freeIncluded: false,
                plusIncluded: true
            ),
            ComparisonRow(
                title: "New perks as they launch",
                icon: "sparkles",
                iconBackground: PillieTheme.coralLight,
                iconColor: PillieTheme.coral,
                freeIncluded: false,
                plusIncluded: true
            )
        ],
        annualPlanLabel: "Annual",
        monthlyPlanLabel: "Monthly",
        reassurances: ["Cancel anytime"],
        monthlyReassurances: ["Cancel anytime", "No commitment"],
        primaryCTA: "Unlock Pillie Plus",
        monthlyCTA: "Start Pillie Plus monthly",
        freeCTA: "Continue with free plan",
        restoreCTA: "Restore Purchases"
    )
}

struct PremiumPaywallView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var selectedPlan: Plan = .annual
    @State private var offerings: Offerings?
    @State private var purchaseError: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var offeringsError = false
    @State private var didCompletePaidRoute = false
    private let performanceTier = PerformanceTier.current
    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = ProductAnalyticsTelemetry.live
    private let plusFeedback = PlusPaywallInteractionFeedback(performanceTier: PerformanceTier.current)
    private let onboardingFeedback = OnboardingInteractionFeedback(performanceTier: PerformanceTier.current)
    private let content = SoftPaywallContent.default

    var isFromOnboarding: Bool = true
    var paywallSurface: AnalyticsPaywallSurface? = nil
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private enum Plan {
        case annual, monthly

        var analyticsPlan: AnalyticsPlan {
            switch self {
            case .annual: return .annual
            case .monthly: return .monthly
            }
        }
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .annual: return annualPackage
        case .monthly: return monthlyPackage
        }
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, isFromOnboarding ? 24 : 28)
                    .padding(.top, isFromOnboarding ? 28 : 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headlineSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        comparisonSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        pricingCards
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        reassuranceRow
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 150)
                }
            }

            VStack {
                Spacer()
                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .background(
                        LinearGradient(
                            colors: [PillieTheme.bg.opacity(0), PillieTheme.bg, PillieTheme.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -20)
                        .ignoresSafeArea(.all, edges: .bottom)
                    )
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {
            if let paywallSurface {
                telemetry.paywallViewed(surface: paywallSurface)
            } else {
                telemetry.paywallViewed(isFromOnboarding: isFromOnboarding)
            }
            animateIn = true
            guard PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: accessibilityReduceMotion,
                performanceTier: performanceTier
            ) else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
        .task {
            subscriptionManager.configure()
            // Offerings (prices + CTA) and the entitlement refresh are independent,
            // so load them concurrently — the CTA un-spins as soon as offerings
            // arrive instead of waiting behind the customer-info fetch. Offerings are
            // usually already warm from the diagnosis-screen prefetch.
            async let offeringsLoaded: Void = loadOfferings()
            await subscriptionManager.refreshStatus()
            routeExistingPlusUserIfNeeded()
            await offeringsLoaded
        }
        .onChange(of: subscriptionManager.hasEntitlement) { _, isPlus in
            routeExistingPlusUserIfNeeded(isPlus: isPlus)
        }
        .alert("Purchase Error", isPresented: .init(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
        .alert("No Subscription Found", isPresented: $showNoSubscriptionAlert) {
            Button("OK") { }
        } message: {
            Text("No active subscription was found for this account.")
        }
    }

    // MARK: - Header

    /// Drawn from the shared onboarding section source of truth so this retired branch
    /// cannot reintroduce a screen-count denominator if it is previewed or restored.
    private var onboardingProgress: ProtectionPlanProgress {
        ProtectionPlanProgressIndex.progress(for: .paywall)
    }

    private var header: some View {
        Group {
            if isFromOnboarding {
                PersonalizationOnboardingHeader(
                    appeared: animateIn,
                    progress: onboardingProgress,
                    onBack: onBack
                )
            } else {
                HStack {
                    Spacer()
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(PillieTheme.sage, in: Circle())
                    }
                }
            }
        }
    }

    // MARK: - Headline

    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("\(content.title)\n")
                .foregroundColor(PillieTheme.textPrimary)
             + Text(content.titleAccent)
                .foregroundColor(PillieTheme.coral))
            .font(.pillie(30, weight: .black))
            .lineSpacing(0)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Text(content.subtitle)
                .font(.pillie(15, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Comparison table

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.comparisonLabel)
                .font(.pillie(13, weight: .black))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.textPrimary)

            comparisonTable
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonHeaderRow
                .padding(.vertical, 9)

            ForEach(Array(content.rows.enumerated()), id: \.offset) { _, row in
                Rectangle()
                    .fill(PillieTheme.sageHalf)
                    .frame(height: 1)
                comparisonRow(row)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
    }

    private var comparisonHeaderRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
                .frame(maxWidth: .infinity)

            Text(content.freeColumnLabel)
                .font(.pillie(11, weight: .black))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.textMuted)
                .frame(width: 52)

            Text(content.plusColumnLabel)
                .font(.pillie(11, weight: .black))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.coral)
                .padding(.vertical, 4)
                .frame(width: 56)
                .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 60)
        }
        .accessibilityHidden(true)
    }

    private func comparisonRow(_ row: SoftPaywallContent.ComparisonRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: row.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(row.iconColor)
                    .frame(width: 30, height: 30)
                    .background(row.iconBackground, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.pillie(14, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let detail = row.detail {
                        Text(detail)
                            .font(.pillie(12, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            includedGlyph(row.freeIncluded, emphasized: false)
                .frame(width: 52)

            includedGlyph(row.plusIncluded, emphasized: true)
                .frame(width: 60)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(comparisonAccessibilityLabel(row))
    }

    private func includedGlyph(_ included: Bool, emphasized: Bool) -> some View {
        Group {
            if included, emphasized {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PillieTheme.dark)
                    .frame(width: 24, height: 24)
                    .background(PillieTheme.coral, in: Circle())
            } else if included {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PillieTheme.verifiedGreen)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.45))
            }
        }
        .accessibilityHidden(true)
    }

    private func comparisonAccessibilityLabel(_ row: SoftPaywallContent.ComparisonRow) -> String {
        let tiers: String
        switch (row.freeIncluded, row.plusIncluded) {
        case (true, true): tiers = "included in Free and Plus"
        case (false, true): tiers = "Plus only"
        case (true, false): tiers = "Free only"
        case (false, false): tiers = "not included"
        }
        if let detail = row.detail {
            return "\(row.title), \(detail), \(tiers)"
        }
        return "\(row.title), \(tiers)"
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        VStack(spacing: 12) {
            annualCard
            monthlyCard
        }
        .padding(.top, 12)
    }

    private var annualPackage: Package? {
        guard let offering = offerings?.current else { return nil }
        return offering.annual ?? offering.availablePackages.first {
            $0.storeProduct.productIdentifier == SubscriptionManager.annualProductID
        }
    }

    private var monthlyPackage: Package? {
        guard let offering = offerings?.current else { return nil }
        return offering.monthly ?? offering.availablePackages.first {
            $0.storeProduct.productIdentifier == SubscriptionManager.monthlyProductID
        }
    }

    private var annualPriceText: String {
        annualPackage?.storeProduct.localizedPriceString ?? "$29.99"
    }

    private var monthlyPriceText: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$4.99"
    }

    /// Truthful annual-vs-monthly comparison from the live store prices (issue #79: no
    /// fake stats). `nil` until both packages have loaded.
    private var priceComparison: PaywallPriceComparison? {
        guard let annual = annualPackage?.storeProduct.price,
              let monthly = monthlyPackage?.storeProduct.price else { return nil }
        return PaywallPriceComparison(annualPrice: annual, monthlyPrice: monthly)
    }

    /// "$X/mo" for the annual plan, formatted in the store's currency. `nil` until the
    /// annual package and its formatter are available.
    private var annualPerMonthText: String? {
        guard let comparison = priceComparison,
              let formatter = annualPackage?.storeProduct.priceFormatter else { return nil }
        return comparison.monthlyEquivalentString(using: formatter)
    }

    /// "N months free" derived from the real prices (issue #162's annual anchor), or
    /// `nil` when there is no honest saving.
    private var savingsBadgeText: String? {
        guard let months = priceComparison?.monthsFree else { return nil }
        return months == 1 ? "1 month free" : "\(months) months free"
    }

    private var annualCard: some View {
        Button {
            selectPlan(.annual)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(content.annualPlanLabel)
                            .font(.pillie(12, weight: .black))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.55))

                        if let savingsBadgeText {
                            Text(savingsBadgeText)
                                .font(.pillie(10, weight: .black))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(PillieTheme.dark)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PillieTheme.coral, in: Capsule())
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(annualPriceText)
                            .font(.pillie(26, weight: .black))
                            .foregroundStyle(.white)
                        Text("/year")
                            .font(.pillie(14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        if let annualPerMonthText {
                            Text("· \(annualPerMonthText)/mo")
                                .font(.pillie(13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                radioCircle(selected: selectedPlan == .annual, onDark: true)
            }
            .padding(16)
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
                Text("Best Value")
                    .font(.pillie(10, weight: .black))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(PillieTheme.dark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(PillieTheme.coral, in: Capsule())
                    .offset(x: -16, y: -11)
            }
            .shadow(color: PillieTheme.dark.opacity(0.28), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Annual, \(annualPriceText) per year\(annualPerMonthText.map { ", \($0) per month" } ?? "").\(savingsBadgeText.map { " \($0)." } ?? "")")
        .accessibilityAddTraits(selectedPlan == .annual ? [.isButton, .isSelected] : .isButton)
    }

    private var monthlyCard: some View {
        Button {
            selectPlan(.monthly)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.monthlyPlanLabel)
                        .font(.pillie(12, weight: .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(PillieTheme.textMuted)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(monthlyPriceText)
                            .font(.pillie(26, weight: .black))
                            .foregroundStyle(PillieTheme.textPrimary)
                        Text("/month")
                            .font(.pillie(14, weight: .semibold))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                radioCircle(selected: selectedPlan == .monthly, onDark: false)
            }
            .padding(16)
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
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monthly, \(monthlyPriceText) per month")
        .accessibilityAddTraits(selectedPlan == .monthly ? [.isButton, .isSelected] : .isButton)
    }

    private func selectPlan(_ plan: Plan) {
        let response = plusFeedback.selectPlan(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            selectedPlan = plan
        }
        telemetry.paywallPlanSelected(plan: plan.analyticsPlan, isFromOnboarding: isFromOnboarding)
    }

    private func radioCircle(selected: Bool, onDark: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    selected ? PillieTheme.coral : (onDark ? Color.white.opacity(0.3) : PillieTheme.sage),
                    lineWidth: 2
                )
                .frame(width: 26, height: 26)

            if selected {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PillieTheme.dark)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Reassurance

    // The annual and monthly reassurances are cross-faded in place rather than diffed,
    // so the shared "Cancel anytime" chip fades instead of sliding across when the plan
    // changes. Both states occupy the same slot; only opacity animates.
    private var reassuranceRow: some View {
        ZStack {
            reassuranceChips(content.reassurances)
                .opacity(selectedPlan == .annual ? 1 : 0)
            reassuranceChips(content.monthlyReassurances)
                .opacity(selectedPlan == .monthly ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPlan)
    }

    private func reassuranceChips(_ items: [String]) -> some View {
        HStack(spacing: 16) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PillieTheme.verifiedGreen)
                    Text(item)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if offeringsError {
                Button {
                    Task { await loadOfferings() }
                } label: {
                    Text("Failed to load plans — Tap to retry")
                        .font(.pillie(16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: PillieTheme.ctaHeight)
                        .background(PillieTheme.textMuted)
                        .clipShape(Capsule())
                }
            } else {
                purchaseButton
            }

            secondaryLinks

            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://idrisskone101.github.io/pillie/terms-and-conditions")!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: "https://idrisskone101.github.io/pillie/privacy-policy")!)
            }
            .font(.pillie(11, weight: .regular))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
        }
    }

    // The "Continue with free plan" / "Restore Purchases" links sit side-by-side
    // with a divider at normal sizes, but at accessibility Dynamic Type sizes each
    // would only get ~half the width and truncate ("Continue with free…"), so they
    // stack vertically (and the now-meaningless divider is dropped) instead.
    private var secondaryLinks: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    continueFreeButton
                    restoreButton
                }
            } else {
                HStack(spacing: 14) {
                    continueFreeButton

                    Rectangle()
                        .fill(PillieTheme.textMuted.opacity(0.3))
                        .frame(width: 1, height: 13)

                    restoreButton
                }
            }
        }
    }

    private var continueFreeButton: some View {
        Button {
            let response = continueFreeFeedback()
            telemetry.continueFreeSelected(isFromOnboarding: isFromOnboarding)
            withAnimation(response.motionProfile.animation) {
                onSkip()
            }
        } label: {
            Text(content.freeCTA)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .buttonStyle(.plain)
    }

    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            Group {
                if isRestoring {
                    ProgressView()
                        .tint(PillieTheme.textMuted)
                        .scaleEffect(0.72)
                } else {
                    Text(content.restoreCTA)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    private var purchaseButton: some View {
        Button {
            guard let package = selectedPackage else {
                plusFeedback.unavailablePurchaseAction(accessibilityReduceMotion: accessibilityReduceMotion)
                return
            }
            let response = startPurchaseFeedback()
            withAnimation(response.motionProfile.animation) {
                isPurchasing = true
            }
            telemetry.purchaseStarted(plan: selectedPlan.analyticsPlan, isFromOnboarding: isFromOnboarding)
            Task {
                do {
                    let outcome = try await subscriptionManager.purchase(package)
                    // Record the conversion as its own funnel step: a trial start is
                    // distinct from a paid charge, and sandbox transactions
                    // (dev/TestFlight/review) emit nothing so they never inflate paid
                    // metrics. The user still proceeds either way.
                    switch outcome.conversionEvent {
                    case .trialStarted:
                        telemetry.trialStarted(plan: selectedPlan.analyticsPlan, isFromOnboarding: isFromOnboarding)
                    case .purchaseCompleted:
                        telemetry.purchaseCompleted(plan: selectedPlan.analyticsPlan, isFromOnboarding: isFromOnboarding)
                    case nil:
                        break
                    }
                    plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    completePaidRoute()
                } catch {
                    plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    if error.isCancelledPurchase {
                        telemetry.purchaseCancelled(plan: selectedPlan.analyticsPlan, isFromOnboarding: isFromOnboarding)
                        await subscriptionManager.refreshStatus()
                    } else {
                        telemetry.purchaseFailed(plan: selectedPlan.analyticsPlan, isFromOnboarding: isFromOnboarding)
                        telemetry.trackError(.purchase, error: error)
                        purchaseError = error.localizedDescription
                    }
                }
                withAnimation(response.motionProfile.animation) {
                    isPurchasing = false
                }
            }
        } label: {
            Group {
                if isPurchasing || offerings == nil {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(selectedPlan == .annual ? content.primaryCTA : content.monthlyCTA)
                        .font(.pillie(17, weight: .bold))
                        // Keep the primary CTA on one line at large Dynamic Type
                        // sizes instead of truncating ("Try Pillie Plus for fr…").
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.dark)
            .clipShape(Capsule())
            .shadow(color: PillieTheme.dark.opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isPurchasing || offerings == nil)
    }

    private func restorePurchases() {
        let response = plusFeedback.startRestore(accessibilityReduceMotion: accessibilityReduceMotion)
        withAnimation(response.motionProfile.animation) {
            isRestoring = true
        }
        telemetry.restoreStarted(isFromOnboarding: isFromOnboarding)
        Task {
            do {
                try await subscriptionManager.restore()
                if subscriptionManager.hasEntitlement {
                    telemetry.restoreCompleted(isFromOnboarding: isFromOnboarding)
                    plusFeedback.successfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    completePaidRoute()
                } else {
                    telemetry.restoreFailed(isFromOnboarding: isFromOnboarding)
                    let calmResponse = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                    withAnimation(calmResponse.motionProfile.animation) {
                        showNoSubscriptionAlert = true
                    }
                }
            } catch {
                telemetry.restoreFailed(isFromOnboarding: isFromOnboarding)
                telemetry.trackError(.restore, error: error)
                let calmResponse = plusFeedback.unsuccessfulPaidOutcome(accessibilityReduceMotion: accessibilityReduceMotion)
                withAnimation(calmResponse.motionProfile.animation) {
                    purchaseError = error.localizedDescription
                }
            }
            withAnimation(response.motionProfile.animation) {
                isRestoring = false
            }
        }
    }

    private func loadOfferings() async {
        offeringsError = false
        do {
            offerings = try await subscriptionManager.fetchOfferings()
        } catch {
            os_log(.error, "Pillie: failed to fetch offerings: %{public}@", error.localizedDescription)
            telemetry.trackError(.offerings, error: error)
            offeringsError = true
        }
    }

    private func routeExistingPlusUserIfNeeded(isPlus: Bool? = nil) {
        guard isFromOnboarding, isPlus ?? subscriptionManager.hasEntitlement else { return }
        completePaidRoute()
    }

    private func completePaidRoute() {
        guard !didCompletePaidRoute else { return }
        didCompletePaidRoute = true
        onContinue()
    }

    private func startPurchaseFeedback() -> OnboardingInteractionFeedback.Response {
        if isFromOnboarding {
            return onboardingFeedback.openSoftPaywallOrUpgrade(
                accessibilityReduceMotion: accessibilityReduceMotion)
        }

        let plusResponse = plusFeedback.openPaywallOrStartPurchase(
            accessibilityReduceMotion: accessibilityReduceMotion)
        return OnboardingInteractionFeedback.Response(
            motion: plusResponse.motion,
            motionProfile: plusResponse.motionProfile,
            skipsHaptics: plusResponse.skipsHaptics
        )
    }

    private func continueFreeFeedback() -> OnboardingInteractionFeedback.Response {
        if isFromOnboarding {
            return onboardingFeedback.continueFreePath(
                accessibilityReduceMotion: accessibilityReduceMotion)
        }

        let plusResponse = plusFeedback.dismissOrContinueFree(
            accessibilityReduceMotion: accessibilityReduceMotion)
        return OnboardingInteractionFeedback.Response(
            motion: plusResponse.motion,
            motionProfile: plusResponse.motionProfile,
            skipsHaptics: plusResponse.skipsHaptics
        )
    }
}

// MARK: - Error Helper

private extension Error {
    var isCancelledPurchase: Bool {
        if let purchaseError = self as? SubscriptionPurchaseError,
           purchaseError == .userCancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1
    }
}

#Preview {
    PremiumPaywallView(onBack: {}, onContinue: {}, onSkip: {})
}
