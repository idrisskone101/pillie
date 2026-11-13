//
//  BlockedAppsEditor.swift
//  Pillie
//
//  Settings sheet for managing blocked apps via FamilyActivityPicker.
//  It asks for Screen Time itself, so no entry point can open it dead.
//  An install that was never asked reads a lead-in before Apple's alert.
//

import SwiftUI
import FamilyControls

struct BlockedAppsEditor: View {
    /// The surface that opened the editor, for its Screen Time and save events.
    let surface: AnalyticsBlockerSetupSurface

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store
    @State private var showPicker = false
    @State private var stage = BlockedAppsAccessStage.opening(
        for: AppBlockingManager.shared.authorizationStatus
    )
    @State private var isRequesting = false
    @State private var blockingWasDone = false

    @Bindable private var blockingManager = AppBlockingManager.shared

    var body: some View {
        SettingsSheetContainer(title: PillieLocalization.string(
            "settings.blocked_apps.title",
            locale: locale
        )) {
            switch stage {
            case .leadIn:
                leadInContent
            case .refused:
                refusedContent
            case .requesting, .granted:
                editorContent
            }
        }
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
        // The lead-in carries more words than the editor, and they run long
        // in Tamil and Greek.
        .presentationDetents([.height(stage == .leadIn ? 500 : 430)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(PillieTheme.bg)
        .task { await open() }
        // Every surface that sets up blocking opens this editor, so the Plus
        // setup step completes here, not in the strip's sheet.
        .onAppear {
            blockingWasDone = PlusSetupProgress.live(store: store).isDone(.blocking)
        }
        .onDisappear {
            guard !blockingWasDone, PlusSetupProgress.live(store: store).isDone(.blocking) else { return }
            ProductAnalyticsTelemetry.live.plusSetupStep(.blocking, action: .completed)
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        // Status indicator
        statusCard

        // Selection summary
        selectionSummary

        // Choose apps button
        Button(action: chooseApps) {
            HStack(spacing: 8) {
                Image(systemName: blockingManager.hasAppsSelected ? "pencil" : "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text(PillieLocalization.string(
                    "settings.blocked_apps.edit",
                    locale: locale
                ))
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
        .padding(.horizontal, 20)

        Button {
            blockingManager.saveSelectionAndReconcile(routine: appBlockingRoutine)
            ScheduleCriticalSettingChange.blockerSetupChanged(store: store)
            ProductAnalyticsTelemetry.live.blockedAppsSaved(hasSelection: blockingManager.hasAppsSelected)
            // #163: the same dedicated event onboarding fires, with
            // source=settings, so the day-1 activation metric can tell
            // onboarding setup from later setup. Gated on a real selection
            // like onboarding's finishSetup — an empty Done must not count
            // as "blocker configured" in the activation metric.
            if blockingManager.hasAppsSelected {
                ProductAnalyticsTelemetry.live.editorBlockerConfigSaved(
                    hasSelection: true,
                    surface: surface
                )
            }
            dismiss()
        } label: {
            Text(PillieLocalization.string("global.action.done", locale: locale))
        }
        .buttonStyle(.pillieDark)
        .padding(.horizontal, 28)
    }

    /// The sheet has a fixed height, and Continue has to stay on screen in
    /// every language and text size. The privacy note is the first thing to
    /// go, and the card scrolls if it still does not fit.
    @ViewBuilder
    private var leadInContent: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 24) {
                leadInCard
                leadInPrivacyNote
            }
            leadInCard
            ScrollView { leadInCard }
        }

        Button {
            Task { await requestAccess() }
        } label: {
            Text(PillieLocalization.string("global.action.continue", locale: locale))
        }
        .buttonStyle(.pillieDark)
        .disabled(isRequesting)
        .padding(.horizontal, 28)
        .accessibilityIdentifier("blockedAppsLeadInContinue")
    }

    private var leadInCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .accessibilityHidden(true)
            Text(PillieLocalization.string("error.screen_time.body", locale: locale))
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(PillieLocalization.string("settings.blocked_apps.lead_in.next", locale: locale))
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("blockedAppsLeadIn")
    }

    private var leadInPrivacyNote: some View {
        Text(PillieLocalization.string("onboarding.blocking_setup.privacy", locale: locale))
            .font(.pillie(13, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28)
    }

    @ViewBuilder
    private var refusedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
            Text(PillieLocalization.string("error.screen_time.title", locale: locale))
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
            Text((blockingManager.refusal ?? .notAllowed).detail(locale: locale))
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("blockedAppsScreenTimeRefused")

        Button {
            Task { await requestAccess() }
        } label: {
            Text(PillieLocalization.string("global.action.retry", locale: locale))
        }
        .buttonStyle(.pillieDark)
        .disabled(isRequesting)
        .padding(.horizontal, 28)
        .accessibilityIdentifier("blockedAppsTryAgain")
    }

    /// The status can change while the app is away, so the stage is read
    /// again here before anything is asked.
    private func open() async {
        blockingManager.updateAuthorizationStatus()
        stage = .opening(for: blockingManager.authorizationStatus)
        if stage == .leadIn {
            ProductAnalyticsTelemetry.live.editorScreenTimeLeadInViewed(surface: surface)
        }
        if stage.requestsOnOpen {
            await requestAccess()
        }
    }

    private func requestAccess() async {
        guard !isRequesting else { return }
        isRequesting = true
        stage = .resolved(isAuthorized: await blockingManager.ensureAuthorized(from: surface))
        isRequesting = false
    }

    private func chooseApps() {
        guard blockingManager.isAuthorized else { return }
        showPicker = true
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 10, height: 10)

            Text(statusLabel)
                .font(.pillieBodySemibold())
                .foregroundStyle(PillieTheme.textPrimary)
                .accessibilityHidden(true)

            Spacer()

            Toggle("", isOn: $blockingManager.blockingEnabled)
                .labelsHidden()
                .tint(PillieTheme.coral)
                .accessibilityLabel(PillieLocalization.string(
                    "settings.section.blocking",
                    locale: locale
                ))
                .accessibilityValue(statusLabel)
                .accessibilityIdentifier("blockedAppsEnabledToggle")
                .onChange(of: blockingManager.blockingEnabled) { _, enabled in
                    if enabled {
                        blockingManager.reconcileEnabledBlocking(routine: appBlockingRoutine)
                    } else {
                        blockingManager.stopMonitoring()
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(blockingManager.blockingActive ? PillieTheme.coralLight : PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var statusDotColor: Color {
        if !blockingManager.blockingEnabled { return PillieTheme.sage }
        return blockingManager.blockingActive ? PillieTheme.coral : PillieTheme.sage
    }

    private var statusLabel: String {
        SettingsPresentation.blockingToggleStatus(
            isEnabled: blockingManager.blockingEnabled,
            locale: locale
        )
    }

    private var selectionSummary: some View {
        Group {
            if blockingManager.hasAppsSelected {
                let count = blockingManager.selectedCount
                summaryCard(
                    icon: "app.badge.checkmark",
                    text: "\(count.formatted(.number.locale(locale))) · \(PillieLocalization.string("settings.blocked_apps.title", locale: locale))",
                    iconColor: PillieTheme.coral
                )
            } else {
                summaryCard(
                    icon: "app.dashed",
                    text: PillieLocalization.string(
                        "empty.blocked_apps.title",
                        locale: locale
                    ),
                    iconColor: PillieTheme.textMuted
                )
            }
        }
    }

    private func summaryCard(icon: String, text: String, iconColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
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
        .padding(.horizontal, 20)
    }

    private var appBlockingRoutine: AppBlockingManager.RoutineState {
        AppBlockingManager.RoutineState(
            isTodayHandled: store.isTodayHandled,
            liveDay: store.today,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method,
            blockingSchedule: store.blockingScheduleMirror
        )
    }
}

#Preview {
    BlockedAppsEditor(surface: .settings)
}
