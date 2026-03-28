//
//  PremiumPaywallView.swift
//  Pillie

import SwiftUI
import RevenueCat
import os

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

    var isFromOnboarding: Bool = true
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private enum Plan {
        case annual, monthly
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
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headlineSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        featureCards
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        pricingCards
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        freePlanSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, PillieTheme.scrollBottomPaddingWithCTA)
                }
            }

            VStack {
                Spacer()
                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
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
                OnboardingStepHeader(
                    appeared: animateIn,
                    progress: 0.50,
                    trailingLabel: "6/6",
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
        VStack(spacing: 8) {
            Text("LIMITED OFFER AVAILABLE")
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.coral)
                .tracking(1.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(PillieTheme.coral.opacity(0.15))
                )

            VStack(spacing: 2) {
                Text("Commit to your health,")
                    .foregroundStyle(PillieTheme.textPrimary)
                Text("Join Pillie Plus")
                    .foregroundStyle(PillieTheme.coral)
            }
            .font(.pillie(30, weight: .bold))
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 12) {
            premiumFeatureRow(
                icon: "lock.fill",
                iconBg: PillieTheme.coral,
                iconFg: .white,
                title: "App Blocking",
                subtitle: "Lock distracting apps like Instagram until you've logged your daily pill."
            )

            premiumFeatureRow(
                icon: "iphone.radiowaves.left.and.right",
                iconBg: PillieTheme.lavender,
                iconFg: PillieTheme.textPrimary,
                title: "Challenge Mode",
                subtitle: "Shake your phone to unlock selected blocked apps and verify your dose."
            )

            premiumFeatureRow(
                icon: "checkmark.shield.fill",
                iconBg: PillieTheme.sage,
                iconFg: PillieTheme.textPrimary,
                title: "Habit Mastery",
                subtitle: "Premium features designed to ensure you never miss a day, even on your busiest mornings."
            )
        }
    }

    private func premiumFeatureRow(icon: String, iconBg: Color, iconFg: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconFg)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(iconBg)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(subtitle)
                    .font(.pillie(14, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PillieTheme.cardWhite.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PillieTheme.sage, lineWidth: 1)
        )
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        VStack(spacing: 12) {
            annualCard
                .zIndex(1)
            monthlyCard
        }
        .padding(.top, 8)
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
                        Text("ANNUAL PLAN")
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
                    }

                    Spacer()

                    radioCircle(selected: selectedPlan == .annual)
                }
                .padding(20)
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
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONTHLY PLAN")
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
            .padding(20)
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

    // MARK: - Free Plan Section

    private var freePlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("INCLUDED IN FREE PLAN")
                    .font(.pillie(13, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .tracking(1.5)

                Spacer()

                Text("CURRENT PLAN")
                    .font(.pillie(10, weight: .black))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.6))
                    .tracking(0.5)
            }

            VStack(spacing: 14) {
                freePlanRow(icon: "bell", label: "Daily pill notifications")
                freePlanRow(icon: "calendar.badge.clock", label: "Historical tracking (taken/missed logs)")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.sage.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sage, lineWidth: 1)
        )
    }

    private func freePlanRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PillieTheme.cardWhite.opacity(0.6))
                )
                .shadow(color: PillieTheme.cardShadow, radius: 4, y: 2)

            Text(label)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if offeringsError {
                Button {
                    Task { await loadOfferings() }
                } label: {
                    VStack(spacing: 1) {
                        Text("Failed to load plans")
                            .font(.pillie(17, weight: .bold))
                        Text("Tap to retry")
                            .font(.pillie(11, weight: .medium))
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: PillieTheme.ctaHeight)
                    .background(PillieTheme.textMuted)
                    .clipShape(Capsule())
                }
            } else {
                Button {
                    guard let package = selectedPackage else { return }
                    isPurchasing = true
                    Task {
                        do {
                            try await subscriptionManager.purchase(package)
                            onContinue()
                        } catch {
                            if !error.isCancelledPurchase {
                                purchaseError = error.localizedDescription
                            }
                        }
                        isPurchasing = false
                    }
                } label: {
                    VStack(spacing: 1) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else if offerings == nil {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(selectedPlan == .annual
                                 ? "Start Your Free Trial"
                                 : "Subscribe Now")
                                .font(.pillie(17, weight: .bold))
                            Text(selectedPlan == .annual
                                 ? "7 days free, then \(annualPriceText)/year"
                                 : "\(monthlyPriceText)/month")
                                .font(.pillie(11, weight: .medium))
                                .opacity(0.8)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: PillieTheme.ctaHeight)
                    .background(PillieTheme.dark)
                    .clipShape(Capsule())
                    .shadow(color: PillieTheme.dark.opacity(0.4), radius: 15, y: 8)
                }
                .disabled(isPurchasing || offerings == nil)
            }

            Button {
                onSkip()
            } label: {
                Text("Continue with Free Plan")
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }

            Button {
                isRestoring = true
                Task {
                    do {
                        try await subscriptionManager.restore()
                        if subscriptionManager.isPlus {
                            onContinue()
                        } else {
                            showNoSubscriptionAlert = true
                        }
                    } catch {
                        purchaseError = error.localizedDescription
                    }
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                        .tint(PillieTheme.textMuted)
                        .frame(height: 20)
                } else {
                    Text("Restore Purchases")
                        .font(.pillie(12, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted.opacity(0.6))
                }
            }
            .disabled(isRestoring)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://idrisskone101.github.io/pillie/terms-and-conditions")!)
                Text("|")
                Link("Privacy Policy", destination: URL(string: "https://idrisskone101.github.io/pillie/privacy-policy")!)
            }
            .font(.pillie(11, weight: .regular))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.5))
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
