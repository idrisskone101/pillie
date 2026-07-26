//
//  BlockedAppsEditor.swift
//  Pillie
//
//  Settings sheet for managing blocked apps via FamilyActivityPicker.
//

import SwiftUI
import FamilyControls

struct BlockedAppsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PillStore.self) private var store
    @State private var showPicker = false
    @State private var isRequestingAuth = false

    private var blockingManager: AppBlockingManager { .shared }

    var body: some View {
        SettingsSheetContainer(title: PillieLocalization.string(
            "settings.blocked_apps.title",
            locale: locale
        )) {
            // Status indicator
            statusCard

            // Selection summary
            selectionSummary

            // Choose apps button
            Button(action: chooseApps) {
                HStack(spacing: 8) {
                    if isRequestingAuth {
                        ProgressView().tint(PillieTheme.coral)
                    } else {
                        Image(systemName: blockingManager.hasAppsSelected ? "pencil" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
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
            .disabled(isRequestingAuth)
            .padding(.horizontal, 20)

            Button {
                blockingManager.saveSelectionAndReconcile(routine: appBlockingRoutine)
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
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
    }

    // Reverse-trial users can reach this editor without ever passing onboarding's
    // blocker step, so Settings must be able to request Screen Time authorization
    // itself — previously the picker just opened unauthorized. Mirrors
    // AppBlockingSetupView.chooseApps(), with source=settings telemetry (#163).
    private func chooseApps() {
        Task {
            if !blockingManager.isAuthorized {
                isRequestingAuth = true
                ProductAnalyticsTelemetry.live.settingsScreenTimePermissionRequested()
                await blockingManager.requestAuthorization()
                ProductAnalyticsTelemetry.live.settingsScreenTimePermissionCompleted(
                    isAuthorized: blockingManager.isAuthorized
                )
                isRequestingAuth = false
            }
            if blockingManager.isAuthorized {
                showPicker = true
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 10, height: 10)

            Text(statusLabel)
                .font(.pillieBodySemibold())
                .foregroundStyle(PillieTheme.textPrimary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { blockingManager.blockingEnabled },
                set: { blockingManager.blockingEnabled = $0 }
            ))
                .labelsHidden()
                .tint(PillieTheme.coral)
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
        PillieLocalization.string(
            blockingManager.blockingActive ? "global.status.on" : "global.status.off",
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
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
    }
}

#Preview {
    BlockedAppsEditor()
}
