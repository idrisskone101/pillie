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
    @Environment(PillStore.self) private var store
    @State private var showPicker = false

    private var blockingManager: AppBlockingManager { .shared }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text("Blocked Apps")
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)

            // Status indicator
            statusCard

            // Selection summary
            selectionSummary

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
            .padding(.horizontal, 20)

            Button {
                blockingManager.saveSelection()
                // Re-schedule and reconcile blocking immediately
                blockingManager.scheduleDeviceActivityBlock(
                    hour: store.reminderHour,
                    minute: store.reminderMinute
                )
                blockingManager.reconcileBlockingState(
                    isTodayTaken: store.isTodayHandled,
                    reminderHour: store.reminderHour,
                    reminderMinute: store.reminderMinute,
                    method: store.pack.method
                )
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 28)

            Spacer()
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
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
                        blockingManager.reconcileBlockingState(
                            isTodayTaken: store.isTodayHandled,
                            reminderHour: store.reminderHour,
                            reminderMinute: store.reminderMinute,
                            method: store.pack.method
                        )
                        blockingManager.scheduleDeviceActivityBlock(
                            hour: store.reminderHour,
                            minute: store.reminderMinute
                        )
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
        if !blockingManager.blockingEnabled { return "Blocking Off" }
        return blockingManager.blockingActive ? "Blocking Active" : "Blocking Enabled"
    }

    private var selectionSummary: some View {
        Group {
            if blockingManager.hasAppsSelected {
                let count = blockingManager.selectedCount
                summaryCard(
                    icon: "app.badge.checkmark",
                    text: "\(count) app\(count == 1 ? "" : "s")/categor\(count == 1 ? "y" : "ies") selected",
                    iconColor: PillieTheme.coral
                )
            } else {
                summaryCard(
                    icon: "app.dashed",
                    text: "No apps selected yet",
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
}

#Preview {
    BlockedAppsEditor()
}
