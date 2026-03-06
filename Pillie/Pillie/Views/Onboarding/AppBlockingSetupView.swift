//
//  AppBlockingSetupView.swift
//  Pillie
//

import SwiftUI
import FamilyControls

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var showPicker = false
    @State private var isRequestingAuth = false
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var blockingManager: AppBlockingManager { .shared }

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
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        infoBox
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        authorizationSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        if blockingManager.isAuthorized {
                            selectionSection
                                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 34)
            }
        }
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
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
    }

    // MARK: - Header

    private var header: some View {
        OnboardingStepHeader(
            appeared: animateIn,
            progress: 1.0,
            trailingLabel: "4/5",
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            (Text("Block your ")
                .foregroundStyle(PillieTheme.textPrimary)
            + Text("apps")
                .foregroundStyle(PillieTheme.coral))
                .font(.pillieHeadline())
                .multilineTextAlignment(.center)

            Text("Lock distracting apps until you've completed your action.")
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Info Box

    private var infoBox: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(PillieTheme.textMuted)

            Text("App blocking stays on your device. We never see which apps you use.")
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PillieTheme.lavender)
        )
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        Group {
            if blockingManager.isAuthorized {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PillieTheme.coral)
                    Text("Screen Time access granted")
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.coralLight)
                )
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 32))
                            .foregroundStyle(PillieTheme.coral)

                        Text("Screen Time Permission")
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)

                        Text("Pillie needs Screen Time access to block apps when your reminder fires.")
                            .font(.pillieBody())
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        isRequestingAuth = true
                        Task {
                            await blockingManager.requestAuthorization()
                            isRequestingAuth = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRequestingAuth {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Allow Screen Time")
                        }
                    }
                    .buttonStyle(.pillieDark)
                    .disabled(isRequestingAuth)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(PillieTheme.sage, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Selection Section

    private var selectionSection: some View {
        VStack(spacing: 16) {
            // Selection summary
            if blockingManager.hasAppsSelected {
                let count = blockingManager.activitySelection.applicationTokens.count
                    + blockingManager.activitySelection.categoryTokens.count
                HStack(spacing: 10) {
                    Image(systemName: "app.badge.checkmark")
                        .foregroundStyle(PillieTheme.coral)
                    Text("\(count) app\(count == 1 ? "" : "s")/categor\(count == 1 ? "y" : "ies") selected")
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(PillieTheme.sageHalf, lineWidth: 1)
                )
            }

            // Choose apps button
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: blockingManager.hasAppsSelected ? "pencil" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(blockingManager.hasAppsSelected ? "Change apps" : "Choose apps to block")
                        .font(.pillieBodySemibold())
                }
                .foregroundStyle(PillieTheme.coral)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .strokeBorder(PillieTheme.coral, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Button {
                blockingManager.saveSelection()
                // Schedule DeviceActivity and apply blocking immediately if past reminder time
                AppBlockingManager.shared.scheduleDeviceActivityBlock(
                    hour: store.reminderHour,
                    minute: store.reminderMinute
                )
                AppBlockingManager.shared.reconcileBlockingState(
                    isTodayTaken: store.isTodayHandled,
                    reminderHour: store.reminderHour,
                    reminderMinute: store.reminderMinute,
                    method: store.pack.method
                )
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Enable Blocking & Finish")
                }
            }
            .buttonStyle(.pillieDark)
            .disabled(!blockingManager.isAuthorized)

            Button {
                onSkip()
            } label: {
                Text("Skip for now")
            }
            .buttonStyle(.pillieSecondary)
        }
    }
}

// MARK: - PillieToggle

struct PillieToggle: View {
    @Binding var isOn: Bool

    private let width: CGFloat = 52
    private let height: CGFloat = 32
    private let thumbSize: CGFloat = 26
    private let padding: CGFloat = 3

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? PillieTheme.coral : PillieTheme.sage)
                    .frame(width: width, height: height)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .padding(padding)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AppBlockingSetupView(
        onBack: {},
        onContinue: {},
        onSkip: {}
    )
    .environment(PillStore.previewStore())
}
