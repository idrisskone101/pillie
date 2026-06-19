//
//  AppBlockingSetupView.swift
//  Pillie
//

import SwiftUI
import FamilyControls

struct AppBlockingSetupContent {
    let badge: String
    let title: String
    let plusSubtitle: String
    let lockedSubtitle: String
    let privacyNote: String
    let permissionTitle: String
    let permissionDetail: String
    let authorizedTitle: String
    let authorizedDetail: String
    let selectionTitle: String
    let noSelectionDetail: String
    let lockedTitle: String
    let lockedDetail: String

    var visibleCopy: [String] {
        [
            badge,
            title,
            plusSubtitle,
            lockedSubtitle,
            privacyNote,
            permissionTitle,
            permissionDetail,
            authorizedTitle,
            authorizedDetail,
            selectionTitle,
            noSelectionDetail,
            lockedTitle,
            lockedDetail
        ]
    }

    static let `default` = AppBlockingSetupContent(
        badge: "Pillie Plus",
        title: "App Blocking",
        plusSubtitle: "Choose the apps Pillie should pause after your reminder. iOS Screen Time handles the blocking.",
        lockedSubtitle: "App blocking is a Pillie Plus tool you can set up after upgrading.",
        privacyNote: "Your app choices stay on this device.",
        permissionTitle: "Allow Screen Time",
        permissionDetail: "Pillie needs permission before it can pause selected apps.",
        authorizedTitle: "Screen Time connected",
        authorizedDetail: "Choose the apps you want Pillie to pause.",
        selectionTitle: "Apps to pause",
        noSelectionDetail: "No apps selected yet.",
        lockedTitle: "Included with Pillie Plus",
        lockedDetail: "Your free plan still includes daily reminders and cycle tracking. You can upgrade from Settings when you want app blocking."
    )
}

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store
    @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var showPicker = false
    @State private var isRequestingAuth = false
    private let performanceTier = PerformanceTier.current
    private let onboardingTelemetry = OnboardingTelemetry()
    private let content = AppBlockingSetupContent.default

    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var blockingManager: AppBlockingManager { .shared }
    private var canSetUpBlocking: Bool {
        SubscriptionManager.shared.isPlus && !onboardingSelectedFreePlan
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        if canSetUpBlocking {
                            setupSection
                                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                        } else {
                            plusLockedSection
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
                    .padding(.bottom, 18)
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
        let progress = ProtectionPlanProgressIndex.progress(for: .appBlocking)
        return PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: progress.fraction,
            badge: progress.badge,
            onBack: onBack
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text(content.badge)
                .font(.pillie(10, weight: .black))
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(1.4)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PillieTheme.coralLight, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }

            Text(content.title)
                .font(.pillieHeadline())
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(canSetUpBlocking
                 ? content.plusSubtitle
                 : content.lockedSubtitle)
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Plus Locked Section

    private var plusLockedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.lockedTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text(content.lockedDetail)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: blockingManager.isAuthorized ? "checkmark.circle.fill" : "lock.shield.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .frame(width: 42, height: 42)
                    .background(PillieTheme.coralLight, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(blockingManager.isAuthorized ? content.authorizedTitle : content.permissionTitle)
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)

                    Text(blockingManager.isAuthorized ? content.authorizedDetail : content.permissionDetail)
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            privacyNote

            if blockingManager.isAuthorized {
                selectionControl
            } else {
                allowScreenTimeButton
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)

            Text(content.privacyNote)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PillieTheme.bg, in: RoundedRectangle(cornerRadius: 16))
    }

    private var allowScreenTimeButton: some View {
        Button {
            isRequestingAuth = true
            onboardingTelemetry.screenTimePermissionRequested()
            Task {
                await blockingManager.requestAuthorization()
                onboardingTelemetry.screenTimePermissionCompleted(isAuthorized: blockingManager.isAuthorized)
                isRequestingAuth = false
            }
        } label: {
            HStack(spacing: 8) {
                if isRequestingAuth {
                    ProgressView()
                        .tint(.white)
                }
                Text(content.permissionTitle)
            }
        }
        .buttonStyle(.pillieDark)
        .disabled(isRequestingAuth)
    }

    // MARK: - Selection Control

    private var selectionControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.selectionTitle)
                    .font(.pillieBodySemibold())
                    .foregroundStyle(PillieTheme.textPrimary)

                Spacer()

                if blockingManager.hasAppsSelected {
                    Text(selectionSummaryText)
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.coral)
                }
            }

            Text(blockingManager.hasAppsSelected ? "You can change this anytime from Settings." : content.noSelectionDetail)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)

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

    private var selectionSummaryText: String {
        let count = blockingManager.activitySelection.applicationTokens.count
            + blockingManager.activitySelection.categoryTokens.count
        return "\(count) selected"
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if canSetUpBlocking {
                if blockingManager.isAuthorized {
                    Button {
                        blockingManager.saveSelectionAndReconcile(routine: appBlockingRoutine)
                        ProductAnalyticsTelemetry.live.onboardingBlockedAppsSaved(
                            hasSelection: blockingManager.hasAppsSelected
                        )
                        onContinue()
                    } label: {
                        Text("Finish Setup")
                    }
                    .buttonStyle(.pillieDark)
                }

                Button {
                    onSkip()
                } label: {
                    Text("Skip for now")
                        .font(.pillie(16, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onContinue()
                } label: {
                    Text("Finish Setup")
                }
                .buttonStyle(.pillieDark)
            }
        }
    }

    private var appBlockingRoutine: AppBlockingManager.RoutineState {
        AppBlockingManager.RoutineState(
            isTodayHandled: store.isTodayHandled,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
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
