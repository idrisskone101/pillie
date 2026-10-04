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
    @State private var showMethodPicker = false

    private let settingsFeedback = SettingsInteractionFeedback()

    private static let topAnchor = "protocolEditorTop"
    private static let bottomAnchor = "protocolEditorBottom"
    private static let chipFill = Color(hex: "F5F5F4")

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

    var body: some View {
        VStack(spacing: 0) {
            header

            if let draft {
                methodCard(draft.method)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                ScrollViewReader { scroll in
                    ScrollView {
                        content(draft) { [method = draft.method] in
                            // The card being replaced on a method switch also reports a change; only the live one scrolls.
                            guard self.draft?.method == method else { return }
                            reveal(in: scroll)
                        }
                    }
                    .clipped()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        footer(draft)
                    }
                    .onChange(of: draft.method) {
                        scroll.scrollTo(Self.topAnchor, anchor: .top)
                    }
                }
            } else {
                Spacer()
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            draft = .seeded(store.pack.method, from: current)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)

            HStack {
                Color.clear
                    .frame(width: 36, height: 36)

                Text(PillieLocalization.string("settings.schedule.title", locale: locale))
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                Button {
                    ProductAnalyticsTelemetry.live.protocolChangeCancelled()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(width: 36, height: 36)
                        .background(Self.chipFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PillieLocalization.string("global.action.close", locale: locale))
                .accessibilityIdentifier("protocolEditorClose")
            }
            .frame(height: 44)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    private func methodCard(_ method: ContraceptiveMethod) -> some View {
        HStack(spacing: 12) {
            Image(decorative: method.iconImageName)
                .resizable()
                .scaledToFit()
                .frame(width: method.iconImageSize, height: method.iconImageSize)
                .frame(width: 44, height: 44)
                .background(method.settingsTileFill, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(PillieLocalization.string("settings.schedule.your_method", locale: locale))
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                Text(method.localizedTitle(locale: locale))
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switchButton(current: method)
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .background(PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(PillieTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([
            PillieLocalization.string("settings.schedule.your_method", locale: locale),
            method.localizedTitle(locale: locale),
            PillieLocalization.string("settings.schedule.switch", locale: locale)
        ].joined(separator: ", "))
        .accessibilityIdentifier("protocolEditorMethodCard")
    }

    private func switchButton(current method: ContraceptiveMethod) -> some View {
        Button {
            showMethodPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .bold))
                Text(PillieLocalization.string("settings.schedule.switch", locale: locale))
                    .font(.pillie(14, weight: .bold))
            }
            .foregroundStyle(PillieTheme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Self.chipFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("protocolEditorSwitch")
        .sheet(isPresented: $showMethodPicker) {
            MethodPickerSheet(current: method) { picked in
                draft = .seeded(picked, from: current)
            }
        }
    }

    private func footer(_ draft: ScheduleDraft) -> some View {
        VStack(spacing: 10) {
            Text(draft.saveNote(from: store.pack.method, locale: locale))
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("protocolEditorSaveNote")

            Button(action: save) {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.38)
            .accessibilityIdentifier("protocolEditorSave")
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 40)
        .background {
            LinearGradient(
                stops: [
                    .init(color: PillieTheme.bg.opacity(0), location: 0),
                    .init(color: PillieTheme.bg, location: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
        .id(Self.topAnchor)
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
        case .dial(let selection) where selection.method == .ring:
            PillieLocalization.string("settings.schedule.ring_title", locale: locale)
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
