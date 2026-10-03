//
//  ProtocolEditor.swift
//  Pillie
//

import SwiftUI

struct ProtocolEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    // Seeded in onAppear, not a custom init, so the SDK 27 @State macro stays well-behaved.
    // Nil until then, so the modules first render on the seeded day and do not scroll on open.
    @State private var draft: ScheduleDraft?
    @State private var isScrubbing = false
    @State private var showResetConfirmation = false

    private let settingsFeedback = SettingsInteractionFeedback()

    private static let bottomAnchor = "protocolEditorBottom"

    private var current: ScheduleDraft.Current {
        ScheduleDraft.Current(
            method: store.pack.method,
            regimen: store.pack.regimen,
            cycleDayIndex: store.currentDayIndex,
            isTodayTaken: store.isTodayTaken
        )
    }

    private var canSave: Bool {
        (draft?.isComplete ?? false) && !isScrubbing
    }

    private var methodSelection: Binding<ContraceptiveMethod> {
        Binding(
            get: { draft?.method ?? store.pack.method },
            set: { method in
                guard method != draft?.method else { return }
                draft = .seeded(method, from: current)
            }
        )
    }

    private var resetConfirmation: ScheduleCriticalSettingChange.Confirmation {
        ScheduleCriticalSettingChange.confirmation(cycleDay: draft?.cycleDay ?? 1, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsSheetHeader(title: PillieLocalization.string("settings.schedule.title", locale: locale))

            if let draft {
                methodPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                ScrollViewReader { scroll in
                    ScrollView {
                        content(draft) { reveal(in: scroll) }
                    }
                    .clipped()
                }
            } else {
                Spacer()
            }

            VStack(spacing: 12) {
                Button {
                    showResetConfirmation = true
                } label: {
                    Text(PillieLocalization.string("global.action.save", locale: locale))
                }
                .buttonStyle(.pillieDark)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.38)
                .padding(.horizontal, 28)
                .accessibilityIdentifier("protocolEditorSave")

                Button {
                    ProductAnalyticsTelemetry.live.protocolChangeCancelled()
                    dismiss()
                } label: {
                    Text(PillieLocalization.string("global.action.cancel", locale: locale))
                }
                .buttonStyle(.pillieSecondary)
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 20)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .alert(resetConfirmation.title, isPresented: $showResetConfirmation) {
            Button(resetConfirmation.cancelTitle, role: .cancel) { }
            Button(resetConfirmation.confirmTitle, role: .destructive, action: save)
        } message: {
            Text(resetConfirmation.body)
        }
        .onAppear {
            draft = .seeded(store.pack.method, from: current)
        }
    }

    private func content(_ draft: ScheduleDraft, onReveal: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title(for: draft))
                .font(.pillie(20, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            module(for: draft, onReveal: onReveal)
                .id(draft.method)

            Text(PillieLocalization.string("settings.cycle_day.history_note", locale: locale))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)

            Color.clear
                .frame(height: 1)
                .id(Self.bottomAnchor)
        }
        .padding(20)
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PillieLocalization.string("settings.method.title", locale: locale))
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            Picker(PillieLocalization.string("settings.method.title", locale: locale), selection: methodSelection) {
                ForEach(ContraceptiveMethod.allCases, id: \.self) { method in
                    Text(method.localizedTitle(locale: locale)).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("protocolEditorMethod")
        }
    }

    @ViewBuilder
    private func module(for draft: ScheduleDraft, onReveal: @escaping () -> Void) -> some View {
        switch draft {
        case .pill(let selection):
            TodayPillCard(selection: pillSelection(selection), showsLoggedRow: false, onReveal: onReveal)
        case .dial(let selection):
            RoutineDialCard(selection: dialSelection(selection), isScrubbing: $isScrubbing, onReveal: onReveal)
        }
    }

    private func title(for draft: ScheduleDraft) -> String {
        switch draft {
        case .pill: PillieLocalization.string("onboarding.today_pill.title", locale: locale)
        case .dial(let selection): RoutineDialCopy(selection: selection, locale: locale).title
        }
    }

    // The getters read the live draft: a card mutates and then re-reads its
    // selection within one event, before the next body pass rebuilds the binding.
    private func pillSelection(_ shown: TodayPillSelection) -> Binding<TodayPillSelection> {
        Binding(
            get: {
                guard case .pill(let selection) = draft else { return shown }
                return selection
            },
            set: { draft = .pill($0) }
        )
    }

    private func dialSelection(_ shown: RoutineDialSelection) -> Binding<RoutineDialSelection> {
        Binding(
            get: {
                guard case .dial(let selection) = draft else { return shown }
                return selection
            },
            set: { draft = .dial($0) }
        )
    }

    private func reveal(in scroll: ScrollViewProxy) {
        withAnimation(accessibilityReduceMotion ? nil : .spring(duration: 0.4, bounce: 0.1)) {
            scroll.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private func save() {
        guard let draft else { return }
        settingsFeedback.sensitiveOrDestructiveChange(accessibilityReduceMotion: accessibilityReduceMotion)
        store.resetAndStartFresh(
            method: draft.method,
            regimen: draft.preset,
            customRegimen: draft.customRegimen,
            cycleDay: draft.cycleDay ?? 1
        )
        if draft.logsToday {
            store.markTodayAsTaken()
        }
        ProductAnalyticsTelemetry.live.protocolChangeSaved()
        dismiss()
    }
}
