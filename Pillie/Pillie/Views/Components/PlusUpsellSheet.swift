//
//  PlusUpsellSheet.swift
//  Pillie

import SwiftUI

struct PlusUpsellSheet: View {
    let featureName: String
    let featureDescription: String

    static func appBlocking() -> PlusUpsellSheet {
        PlusUpsellSheet(
            featureName: "App Blocking",
            featureDescription: "Lock distracting apps until you've taken your pill. Upgrade to Pillie+ to enable app blocking."
        )
    }
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var showNoSubscriptionAlert = false
    @State private var restoreError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PillieTheme.coral)

                Text(featureName)
                    .font(.pillieExtraBold(24))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(featureDescription)
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade to Pillie+")
                }
                .buttonStyle(.pillieDark)
                .padding(.horizontal, 28)

                Button {
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }

                Button {
                    isRestoring = true
                    Task {
                        do {
                            try await SubscriptionManager.shared.restore()
                            if SubscriptionManager.shared.isPlus {
                                dismiss()
                            } else {
                                showNoSubscriptionAlert = true
                            }
                        } catch {
                            restoreError = error.localizedDescription
                        }
                        isRestoring = false
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .tint(PillieTheme.textMuted)
                            .frame(height: 16)
                    } else {
                        Text("Restore Purchases")
                            .font(.pillie(12, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted.opacity(0.6))
                    }
                }
                .disabled(isRestoring)
            }

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .alert("No Subscription Found", isPresented: $showNoSubscriptionAlert) {
            Button("OK") { }
        } message: {
            Text("No active subscription was found for this account.")
        }
        .alert("Restore Error", isPresented: .init(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK") { restoreError = nil }
        } message: {
            Text(restoreError ?? "")
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView(
                isFromOnboarding: false,
                onBack: { showPaywall = false },
                onContinue: {
                    showPaywall = false
                    dismiss()
                },
                onSkip: {
                    showPaywall = false
                    dismiss()
                }
            )
        }
    }
}
