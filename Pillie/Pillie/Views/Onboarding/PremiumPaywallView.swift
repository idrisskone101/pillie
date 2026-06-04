//
//  PremiumPaywallView.swift
//  Pillie

import SwiftUI
import RevenueCat
import os

struct SoftPaywallContent {
    struct Benefit {
        let icon: String
        let tint: Color
        let title: String
        let subtitle: String
    }

    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String
    let benefits: [Benefit]
    let reassurance: String
    let primaryCTA: String
    let monthlyCTA: String
    let freeCTA: String

    var visibleCopy: [String] {
        [badge, title, titleAccent, subtitle]
            + benefits.flatMap { [$0.title, $0.subtitle] }
            + [reassurance, primaryCTA, monthlyCTA, freeCTA]
    }

    static let `default` = SoftPaywallContent(
        badge: "Pillie Plus",
        title: "Stay on Track with",
        titleAccent: "Pillie Plus",
        subtitle: "App blocks and shake checks when reminders need backup.",
        benefits: [
            Benefit(
                icon: "nosign",
                tint: PillieTheme.lavender,
                title: "Block the scroll",
                subtitle: "Pause chosen apps until you check in."
            ),
            Benefit(
                icon: "iphone.radiowaves.left.and.right",
                tint: PillieTheme.sage,
                title: "Shake to make it count",
                subtitle: "Shake to unlock or confirm with intention."
            ),
            Benefit(
                icon: "sparkles",
                tint: PillieTheme.coralLight,
                title: "More Plus perks coming",
                subtitle: "New Pillie Plus tools are included as they launch."
            )
        ],
        reassurance: "No long-term commitment. Cancel anytime in the App Store.",
        primaryCTA: "Try Pillie Plus for free",
        monthlyCTA: "Start Pillie Plus monthly",
        freeCTA: "Continue with free plan"
    )
}

struct PremiumPaywallView: View {
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var selectedPlan: Plan = .annual
    @State private var offerings: Offerings?
    @State private var purchaseError: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var offeringsError = false
    private let performanceTier = PerformanceTier.current
    private let subscriptionManager = SubscriptionManager.shared
    private let telemetry = PaywallSubscriptionTelemetry.live
    private let content = SoftPaywallContent.default

    var isFromOnboarding: Bool = true
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

    private var analyticsSource: AnalyticsSource {
        isFromOnboarding ? .onboarding : .settings
    }

    private var selectedPackage: Package? {
        guard let offering = offerings?.current else { return nil }
        switch selectedPlan {
        case .annual:
            return offering.annual ?? offering.availablePackages.first {
                $0.storeProduct.productIdentifier == SubscriptionManager.annualProductID
            }
        case .monthly:
            return offering.monthly ?? offering.availablePackages.first {
                $0.storeProduct.productIdentifier == SubscriptionManager.monthlyProductID
            }
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
                    VStack(spacing: 16) {
                        headlineSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        benefitRows
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        pricingCards
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, PillieTheme.scrollBottomPaddingWithCTA)
                }
            }

            VStack {
                Spacer()
                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
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
            telemetry.paywallViewed(source: analyticsSource, isFromOnboarding: isFromOnboarding, isPlus: subscriptionManager.isPlus)
            animateIn = true
            guard performanceTier == .standard else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
        .task {
            subscriptionManager.configure()
            await loadOfferings()
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

    private var header: some View {
        Group {
            if isFromOnboarding {
                PersonalizationOnboardingHeader(
                    appeared: animateIn,
                    progress: PersonalizationOnboardingProgress.fraction(for: 9),
                    badge: PersonalizationOnboardingProgress.badge(for: 9),
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
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)

                Text(content.badge)
                    .font(.pillie(10, weight: .black))
                    .foregroundStyle(PillieTheme.textMuted)
                    .tracking(1.6)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 3)

            (Text("\(content.title) ")
                .foregroundColor(PillieTheme.textPrimary)
             + Text(content.titleAccent)
                .foregroundColor(PillieTheme.coral))
            .font(.pillieExtraBold(28))
            .multilineTextAlignment(.center)

            Text(content.subtitle)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
    }

    // MARK: - Benefit Rows

    private var benefitRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(content.benefits.enumerated()), id: \.offset) { _, benefit in
                benefitRow(benefit)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(PillieTheme.cardWhite.opacity(0.76))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
    }

    private func benefitRow(_ benefit: SoftPaywallContent.Benefit) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: benefit.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 34, height: 34)
                .background(benefit.tint, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(benefit.title)
                    .font(.pillie(14, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(benefit.subtitle)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        VStack(spacing: 12) {
            annualCard
                .zIndex(1)
            monthlyCard
        }
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

    private var annualCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = .annual
            }
            telemetry.planSelected(source: analyticsSource, plan: .annual, isPlus: subscriptionManager.isPlus)
        } label: {
            VStack(spacing: -12) {
                HStack {
                    Spacer()
                    Text("Best Value")
                        .font(.pillie(10, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(PillieTheme.dark))
                        .padding(.trailing, 16)
                }
                .zIndex(1)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANNUAL TRIAL")
                            .font(.pillie(14, weight: .bold))
                            .foregroundStyle(PillieTheme.textMuted)
                            .tracking(1)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(annualPriceText)
                                .font(.pillieExtraBold(24))
                                .foregroundStyle(PillieTheme.textPrimary)
                            Text("/year")
                                .font(.pillie(14, weight: .medium))
                                .foregroundStyle(PillieTheme.textMuted)
                        }

                        Text("Pillie Plus starts with a 7-day trial")
                            .font(.pillie(13, weight: .semibold))
                            .foregroundStyle(PillieTheme.coral)
                    }

                    Spacer()

                    radioCircle(selected: selectedPlan == .annual)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(selectedPlan == .annual ? PillieTheme.coral : PillieTheme.sageHalf, lineWidth: selectedPlan == .annual ? 2 : 1)
                )
                .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private var monthlyCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = .monthly
            }
            telemetry.planSelected(source: analyticsSource, plan: .monthly, isPlus: subscriptionManager.isPlus)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONTHLY")
                        .font(.pillie(14, weight: .bold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .tracking(1)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(monthlyPriceText)
                            .font(.pillie(20, weight: .bold))
                            .foregroundStyle(PillieTheme.textPrimary)
                        Text("/month")
                            .font(.pillie(14, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                }

                Spacer()

                radioCircle(selected: selectedPlan == .monthly)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(selectedPlan == .monthly ? PillieTheme.coral : PillieTheme.sageHalf, lineWidth: selectedPlan == .monthly ? 2 : 1)
            )
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func radioCircle(selected: Bool) -> some View {
        Circle()
            .stroke(selected ? PillieTheme.coral : PillieTheme.sage, lineWidth: 2)
            .frame(width: 24, height: 24)
            .overlay {
                if selected {
                    Circle()
                        .fill(PillieTheme.coral)
                        .frame(width: 10, height: 10)
                }
            }
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PillieTheme.textMuted)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    guard let package = selectedPackage else { return }
                    isPurchasing = true
                    telemetry.purchaseStarted(source: analyticsSource, plan: selectedPlan.analyticsPlan, isPlus: subscriptionManager.isPlus)
                    Task {
                        do {
                            try await subscriptionManager.purchase(package)
                            telemetry.purchaseCompleted(source: analyticsSource, plan: selectedPlan.analyticsPlan, isPlus: subscriptionManager.isPlus)
                            onContinue()
                        } catch {
                            if error.isCancelledPurchase {
                                telemetry.purchaseCancelled(source: analyticsSource, plan: selectedPlan.analyticsPlan, isPlus: subscriptionManager.isPlus)
                            } else {
                                telemetry.purchaseFailed(source: analyticsSource, plan: selectedPlan.analyticsPlan, isPlus: subscriptionManager.isPlus)
                                purchaseError = error.localizedDescription
                            }
                        }
                        isPurchasing = false
                    }
                } label: {
                    Group {
                        if isPurchasing || offerings == nil {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: 6) {
                                Text(selectedPlan == .annual
                                     ? content.primaryCTA
                                     : content.monthlyCTA)
                                    .font(.pillie(16, weight: .bold))
                                Text("·")
                                    .font(.pillie(14, weight: .medium))
                                    .opacity(0.6)
                                Text(selectedPlan == .annual
                                     ? "annual trial"
                                     : "\(monthlyPriceText)/mo")
                                    .font(.pillie(13, weight: .medium))
                                    .opacity(0.8)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PillieTheme.dark)
                    .clipShape(Capsule())
                    .shadow(color: PillieTheme.dark.opacity(0.4), radius: 12, y: 6)
                }
                .disabled(isPurchasing || offerings == nil)
            }

            HStack(spacing: 14) {
                Button {
                    telemetry.continueFreeSelected(source: analyticsSource, isFromOnboarding: isFromOnboarding, isPlus: subscriptionManager.isPlus)
                    onSkip()
                } label: {
                    Text(content.freeCTA)
                        .font(.pillie(13, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(PillieTheme.cardWhite.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(PillieTheme.textMuted.opacity(0.12))
                    .frame(width: 1, height: 18)

                Button {
                    restorePurchases()
                } label: {
                    Group {
                        if isRestoring {
                            ProgressView()
                                .tint(PillieTheme.textMuted)
                                .scaleEffect(0.72)
                        } else {
                            Text("Restore Purchases")
                                .font(.pillie(12, weight: .semibold))
                                .foregroundStyle(PillieTheme.textMuted.opacity(0.62))
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                        }
                    }
                    .frame(minWidth: 118, maxWidth: 136)
                    .frame(height: 34)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }

            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://idrisskone101.github.io/pillie/terms-and-conditions")!)
                Text("|")
                Link("Privacy Policy", destination: URL(string: "https://idrisskone101.github.io/pillie/privacy-policy")!)
            }
            .font(.pillie(10, weight: .regular))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.42))
        }
    }

    private func restorePurchases() {
        isRestoring = true
        telemetry.restoreStarted(source: analyticsSource, isPlus: subscriptionManager.isPlus)
        Task {
            do {
                try await subscriptionManager.restore()
                if subscriptionManager.isPlus {
                    telemetry.restoreCompleted(source: analyticsSource, isPlus: subscriptionManager.isPlus)
                    onContinue()
                } else {
                    telemetry.restoreFailed(source: analyticsSource, isPlus: subscriptionManager.isPlus)
                    showNoSubscriptionAlert = true
                }
            } catch {
                telemetry.restoreFailed(source: analyticsSource, isPlus: subscriptionManager.isPlus)
                purchaseError = error.localizedDescription
            }
            isRestoring = false
        }
    }

    private func loadOfferings() async {
        offeringsError = false
        do {
            offerings = try await subscriptionManager.fetchOfferings()
        } catch {
            os_log(.error, "Pillie: failed to fetch offerings: %{public}@", error.localizedDescription)
            offeringsError = true
        }
    }
}

// MARK: - Error Helper

private extension Error {
    var isCancelledPurchase: Bool {
        let nsError = self as NSError
        return nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1
    }
}

#Preview {
    PremiumPaywallView(onBack: {}, onContinue: {}, onSkip: {})
}
