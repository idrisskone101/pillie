//
//  PlusSetupSheet.swift
//  Pillie
//
//  ENG-135: the Plus setup sheet behind the Today strip. Blocking, Messages,
//  Reminders, then Done, at one fixed height so the buttons never move.
//  Blocking and Messages open the existing editors; Reminders edits inline.
//

import SwiftUI

struct PlusSetupSheet: View {
    static let height: CGFloat = 480

    @Environment(PillStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PlusSetupProgress.finishedStorageKey) private var finished = false
    @State private var current: PlusSetupSheetStep
    @State private var editor: PlusSetupEditor?
    /// Whether the step was already done when its editor opened. Only a step
    /// the editor takes from not done to done advances the sheet.
    @State private var editorStepWasDone = false

    init(opening: PlusSetupSheetStep) {
        self.current = opening
    }

    private var progress: PlusSetupProgress {
        PlusSetupProgress.live(store: store)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.bottom, current == .step(.reminders) ? 16 : 20)

            Group {
                switch current {
                case .step(.reminders):
                    PlusSetupRemindersPage(
                        progress: progress,
                        initialInterval: store.autoReminderIntervalMinutes,
                        initialRetryLimit: store.autoReminderRetryLimit,
                        onSkip: { skip(.reminders) },
                        onSave: saveReminders
                    )
                case .step(let step):
                    PlusSetupFeaturePage(
                        step: step,
                        progress: progress,
                        onPrimary: { open(step) },
                        onSkip: { skip(step) }
                    )
                case .done:
                    PlusSetupDonePage(progress: progress) { dismiss() }
                }
            }
            .id(current)
            .transition(.opacity)
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PillieTheme.bg)
        .ignoresSafeArea(.container, edges: .bottom)
        .presentationDetents([.height(Self.height)])
        .onChange(of: current, initial: true) { _, step in
            switch step {
            case .step(let step):
                ProductAnalyticsTelemetry.live.plusSetupStep(step, action: .viewed)
            case .done:
                finished = true
            }
        }
        .sheet(item: $editor, onDismiss: editorDismissed) { editor in
            switch editor {
            case .blocking:
                BlockedAppsEditor()
                    .presentationDetents([.height(430)])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(PillieTheme.bg)
            case .messages:
                CustomReminderMessagesEditor(store: store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(PillieTheme.bg)
            }
        }
    }

    private func open(_ step: PlusSetupStep) {
        editorStepWasDone = progress.isDone(step)
        switch step {
        case .blocking:
            Task {
                _ = await AppBlockingManager.shared.ensureAuthorized()
                editor = .blocking
            }
        case .messages:
            editor = .messages
        case .reminders:
            break
        }
    }

    /// A cancelled editor leaves the step where it was; only a step the
    /// editor actually finished earns its check and moves the sheet on.
    private func editorDismissed() {
        guard case .step(let step) = current, !editorStepWasDone, progress.isDone(step) else {
            return
        }
        if step != .blocking {
            ProductAnalyticsTelemetry.live.plusSetupStep(step, action: .completed)
        }
        advance(from: step)
    }

    private func skip(_ step: PlusSetupStep) {
        ProductAnalyticsTelemetry.live.plusSetupStep(step, action: .skipped)
        advance(from: step)
    }

    private func saveReminders(intervalMinutes: Int, retryLimit: Int) {
        if intervalMinutes != store.autoReminderIntervalMinutes {
            ScheduleCriticalSettingChange.saveSettingsAutoReminderInterval(
                store: store,
                intervalMinutes: intervalMinutes
            )
        }
        if retryLimit != store.autoReminderRetryLimit {
            ScheduleCriticalSettingChange.saveSettingsAutoReminderRetryLimit(
                store: store,
                retryLimit: retryLimit
            )
        }
        store.autoRemindersConfigured = true
        if progress.isDone(.reminders) {
            ProductAnalyticsTelemetry.live.plusSetupStep(.reminders, action: .completed)
        }
        advance(from: .reminders)
    }

    private func advance(from step: PlusSetupStep) {
        withAnimation(PillieMotion.animation(for: .standard, accessibilityReduceMotion: reduceMotion)) {
            current = PlusSetupSheetStep.next(after: step)
        }
    }
}

private enum PlusSetupEditor: String, Identifiable {
    case blocking
    case messages

    var id: String { rawValue }
}

// MARK: - Pages

private struct PlusSetupFeaturePage: View {
    let step: PlusSetupStep
    let progress: PlusSetupProgress
    let onPrimary: () -> Void
    let onSkip: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 20) {
            PlusSetupSegments(current: step, progress: progress)
            PlusSetupImagePair(step: step)
            VStack(alignment: .leading, spacing: 6) {
                PlusSetupTitle(text: string("title"))
                Text(string("body"))
                    .font(.pillie(15, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            PlusSetupButtons(
                primaryTitle: string("action"),
                onSkip: onSkip,
                onPrimary: onPrimary
            )
        }
    }

    private func string(_ field: String) -> String {
        PillieLocalization.string("plus_setup.\(step.rawValue).\(field)", locale: locale)
    }
}

private struct PlusSetupRemindersPage: View {
    let progress: PlusSetupProgress
    let onSkip: () -> Void
    let onSave: (_ intervalMinutes: Int, _ retryLimit: Int) -> Void

    @Environment(\.locale) private var locale
    @State private var intervalMinutes: Int
    @State private var retryLimit: Int

    init(
        progress: PlusSetupProgress,
        initialInterval: Int,
        initialRetryLimit: Int,
        onSkip: @escaping () -> Void,
        onSave: @escaping (_ intervalMinutes: Int, _ retryLimit: Int) -> Void
    ) {
        self.progress = progress
        self.onSkip = onSkip
        self.onSave = onSave
        self.intervalMinutes = initialInterval
        self.retryLimit = initialRetryLimit
    }

    var body: some View {
        VStack(spacing: 16) {
            PlusSetupSegments(current: .reminders, progress: progress)
            PlusSetupImagePair(step: .reminders)
            VStack(alignment: .leading, spacing: 6) {
                PlusSetupTitle(text: PillieLocalization.string(
                    "plus_setup.reminders.title",
                    locale: locale
                ))
                PlusSetupReminderSentence(
                    intervalMinutes: $intervalMinutes,
                    retryLimit: $retryLimit
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            PlusSetupButtons(
                primaryTitle: PillieLocalization.string("global.action.save", locale: locale),
                onSkip: onSkip,
                onPrimary: { onSave(intervalMinutes, retryLimit) }
            )
        }
    }
}

private struct PlusSetupDonePage: View {
    let progress: PlusSetupProgress
    let onClose: () -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 20) {
            Color.clear
                .frame(height: 176)
                .overlay {
                    Image("PlusSetupDone")
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            VStack(alignment: .leading, spacing: 6) {
                PlusSetupTitle(text: PillieLocalization.string("plus_setup.done.title", locale: locale))
                Text(PillieLocalization.formatted(
                    // A skipped step can still be set up from Settings.
                    progress.isComplete ? "plus_setup.done.body" : "plus_setup.done.body_partial",
                    locale: locale,
                    arguments: SettingsPresentation.time(
                        hour: store.reminderHour,
                        minute: store.reminderMinute,
                        locale: locale
                    )
                ))
                .font(.pillie(15, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(spacing: 6) {
                ForEach(PlusSetupStep.allCases, id: \.self) { step in
                    PlusSetupStepLabel(step: step, isDone: progress.isDone(step))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            progress.isDone(step) ? PillieTheme.sage : PlusSetupPalette.neutralFill,
                            in: Capsule()
                        )
                }
            }
            Button(action: onClose) {
                Text(PillieLocalization.string("plus_setup.done.action", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("plusSetupDone")
        }
    }
}

// MARK: - Shared pieces

/// Blocking · Messages · Reminders. The current step is a raised white pill,
/// finished steps read "✓ Name" in green, the rest are muted.
private struct PlusSetupSegments: View {
    let current: PlusSetupStep
    let progress: PlusSetupProgress

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PlusSetupStep.allCases, id: \.self) { step in
                let isCurrent = step == current
                PlusSetupStepLabel(
                    step: step,
                    isDone: !isCurrent && progress.isDone(step),
                    isCurrent: isCurrent
                )
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    if isCurrent {
                        Capsule()
                            .fill(PillieTheme.cardWhite)
                            .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
                    }
                }
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityIdentifier("plusSetupStep_\(step.rawValue)")
            }
        }
        .padding(4)
        .background(PlusSetupPalette.neutralFill, in: Capsule())
    }
}

private struct PlusSetupStepLabel: View {
    let step: PlusSetupStep
    let isDone: Bool
    var isCurrent = false

    @Environment(\.locale) private var locale

    private var name: String {
        PillieLocalization.string(step.titleKey, locale: locale)
    }

    var body: some View {
        HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(name)
                .font(.pillie(13, weight: isCurrent ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(
            isCurrent ? PillieTheme.textPrimary
                : isDone ? PlusSetupPalette.doneText
                : PlusSetupPalette.pendingText
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isDone
                ? PillieLocalization.formatted(
                    "plus_setup.tab.done_accessibility",
                    locale: locale,
                    arguments: name
                )
                : name
        )
    }
}

private struct PlusSetupImagePair: View {
    let step: PlusSetupStep

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            frame(image: "Before", caption: "before")
            frame(image: "After", caption: "after")
        }
    }

    private func frame(image suffix: String, caption field: String) -> some View {
        VStack(spacing: 8) {
            Color.clear
                .frame(height: 132)
                .overlay {
                    Image("PlusSetup\(step.rawValue.capitalized)\(suffix)")
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
            Text(PillieLocalization.string("plus_setup.\(step.rawValue).\(field)", locale: locale))
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlusSetupTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.pillieExtraBold(26))
            .tracking(-0.4)
            .foregroundStyle(PillieTheme.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PlusSetupButtons: View {
    let primaryTitle: String
    let onSkip: () -> Void
    let onPrimary: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSkip) {
                Text(PillieLocalization.string("plus_setup.skip", locale: locale))
                    .font(.pillieBodySemibold())
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 22)
                    .frame(height: PillieTheme.ctaHeight)
                    .background(PlusSetupPalette.neutralFill, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plusSetupSkip")

            Button(action: onPrimary) {
                Text(primaryTitle)
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("plusSetupPrimary")
        }
    }
}
