//
//  HomePackCard.swift
//  Pillie
//

import SwiftUI

/// Home's pill pack. Logging today flips its mark, and PackCard pops the tile, wherever the log came from.
struct HomePackCard: View {
    /// A log made while Home is covered or in the background waits here, so its pop plays once Home is seen.
    let holdsTodayLog: Bool

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsNewPackConfirmation = false
    @State private var showsPackSheet = false
    @State private var pickedPack: PackChoice?
    @State private var showsResetConfirmation = false
    @State private var heldTaken: Bool?
    private let homeFeedback = HomeActionInteractionFeedback()

    var body: some View {
        let _ = store.protocolChangeVersion
        let _ = store.dayRecordsRevision
        let pack = store.pack
        let today = store.today
        let progress = HomePackProgress(
            regimen: pack.regimen,
            elapsedDays: pack.elapsedCycleDays(on: today),
            isTodayTaken: heldTaken ?? store.isTodayTaken,
            today: today,
            calendar: .current
        )
        PackCard(
            regimen: progress.regimen,
            dayOneWeekday: progress.dayOneWeekday,
            todayIndex: progress.todayIndex,
            marks: progress.marks
        ) {
            HomePackHeader(
                title: progress.title(locale: locale),
                subtitle: progress.subtitle(
                    reminderTime: SettingsPresentation.time(
                        hour: store.reminderHour,
                        minute: store.reminderMinute,
                        locale: locale
                    ),
                    locale: locale
                ),
                isTakenToday: progress.status == .taken,
                onChangeType: { showsPackSheet = true },
                onStartNew: { showsNewPackConfirmation = true }
            )
        }
        .sheet(isPresented: $showsPackSheet, onDismiss: {
            showsResetConfirmation = pickedPack != nil
        }) {
            PackTypeSheet(current: PackChoice(pack.regimen)) { pickedPack = $0 }
        }
        .onChange(of: holdsTodayLog || scenePhase != .active, initial: true) { _, holds in
            heldTaken = holds ? store.isTodayTaken : nil
        }
        .alert(startNewConfirmation.title, isPresented: $showsNewPackConfirmation) {
            Button(PillieLocalization.string("today.pack.start_new.confirm", locale: locale)) {
                let feedbackResponse = homeFeedback.commitNewPackOrCycle(
                    accessibilityReduceMotion: accessibilityReduceMotion
                )
                withAnimation(feedbackResponse.motionProfile.animation) {
                    store.startNewPack()
                }
            }
            Button(PillieLocalization.string("global.action.cancel", locale: locale), role: .cancel) {}
        } message: {
            Text(startNewConfirmation.body)
        }
        .alert(resetConfirmation.title, isPresented: $showsResetConfirmation) {
            Button(resetConfirmation.cancelTitle, role: .cancel) { pickedPack = nil }
            Button(resetConfirmation.confirmTitle, role: .destructive) { startOver() }
        } message: {
            Text(resetConfirmation.body)
        }
    }

    /// The same reset Settings runs when the schedule changes: history clears and the new pack starts at pill 1 today.
    private var resetConfirmation: ScheduleCriticalSettingChange.Confirmation {
        ScheduleCriticalSettingChange.confirmation(cycleDay: 1, locale: locale)
    }

    private func startOver() {
        guard let choice = pickedPack else { return }
        pickedPack = nil
        let feedbackResponse = homeFeedback.commitNewPackOrCycle(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.resetAndStartFresh(
                method: .pill,
                regimen: choice.preset,
                customRegimen: choice.preset == .custom ? choice.regimen : nil,
                cycleDay: 1
            )
        }
        ProductAnalyticsTelemetry.live.protocolChangeSaved()
    }

    private var startNewConfirmation: CycleNounPresentation.StartNewConfirmation {
        CycleNounPresentation.startNewConfirmation(for: store.pack.method, locale: locale)
    }
}

private struct HomePackHeader: View {
    let title: String
    let subtitle: String
    let isTakenToday: Bool
    let onChangeType: () -> Void
    let onStartNew: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.pillie(13))
                    .foregroundStyle(isTakenToday ? PillieTheme.verifiedGreen : PillieTheme.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentTransition(.opacity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Menu {
                Button(action: onChangeType) {
                    Label(
                        PillieLocalization.string("home.pack.change_type", locale: locale),
                        systemImage: "pills"
                    )
                }
                .accessibilityIdentifier("homePackChangeType")
                Button(action: onStartNew) {
                    Label(
                        PillieLocalization.string("today.pack.start_new.confirm", locale: locale),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Self.menuFill))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("home.pack.options", locale: locale))
            .accessibilityIdentifier("homePackOptions")
        }
    }

    private static let menuFill = Color(hex: "F5F5F4")
}

#Preview {
    HomePackCard(holdsTodayLog: false)
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
