//
//  BlockedAppsEditor.swift
//  Pillie
//
//  Settings sheet for managing blocked apps via FamilyActivityPicker.
//  It asks for Screen Time itself, so no entry point can open it dead.
//

import SwiftUI
import FamilyControls

struct BlockedAppsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store
    @State private var showPicker = false
    @State private var isRefused = false
    @State private var isRequesting = false
    @State private var blockingWasDone = false

    @Bindable private var blockingManager = AppBlockingManager.shared

    var body: some View {
        SettingsSheetContainer(title: PillieLocalization.string(
            "settings.blocked_apps.title",
            locale: locale
        )) {
            if isRefused {
                refusedContent
            } else {
                editorContent
            }
        }
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).pickerSelection
        )
        .task { await requestAccess() }
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
            // source=settings, so the day-1 activation metric can tell the
            // two blocker-setup surfaces apart. Gated on a real selection
            // like onboarding's finishSetup — an empty Done must not count
            // as "blocker configured" in the activation metric.
            if blockingManager.hasAppsSelected {
                ProductAnalyticsTelemetry.live.settingsBlockerConfigSaved(
                    hasSelection: true
                )
            }
            dismiss()
        } label: {
            Text(PillieLocalization.string("global.action.done", locale: locale))
        }
        .buttonStyle(.pillieDark)
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

    private func requestAccess() async {
        guard !isRequesting else { return }
        isRequesting = true
        isRefused = !(await blockingManager.ensureAuthorized())
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
    BlockedAppsEditor()
}
