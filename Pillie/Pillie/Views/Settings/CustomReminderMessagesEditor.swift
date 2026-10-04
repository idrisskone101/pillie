//
//  CustomReminderMessagesEditor.swift
//  Pillie
//

import SwiftUI

/// Editor for the Custom Reminder Message perk (Pillie+). A mock Lock Screen shows the daily
/// Due Action Reminder and the Auto-Reminder Retry exactly as they will fire, and a Tone
/// control rewrites both. The pencil on a banner edits its words. A blank field falls back to
/// the default copy at fire time (see `CustomReminderCopy`). Words never change reminder
/// timing, snooze, retry cadence, or supply scheduling.
struct CustomReminderMessagesEditor: View {
    @Bindable var store: PillStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale

    @State private var draft = CustomReminderDraft(
        messages: CustomReminderMessages(
            dueTitle: "",
            dueBody: "",
            retryTitle: "",
            retryBody: ""
        )
    )
    @State private var editing: CustomReminderKind?

    private let settingsFeedback = SettingsInteractionFeedback()

    /// The contraception method whose default copy fills any blank preview field.
    private var method: ContraceptiveMethod { store.pack.method }
    /// Same Plus gate the notification build uses, so the preview honors the entitlement.
    private var isPlus: Bool { SubscriptionManager.shared.hasPlusAccess }

    /// The method-aware default copy each field seeds with when no custom value is stored,
    /// the exact strings the notification falls back to (see `CustomReminderPreview`).
    private var defaultTitle: String { CustomReminderPreview.defaultDailyTitle(method: method) }
    private var defaultBody: String { CustomReminderPreview.defaultDailyBody(method: method) }
    private var defaultRetryTitle: String { NotificationManager.defaultRetryTitle }
    private var defaultRetryBody: String { NotificationManager.defaultRetryBody }
    private var defaultMessages: CustomReminderMessages {
        CustomReminderMessages(
            dueTitle: defaultTitle,
            dueBody: defaultBody,
            retryTitle: defaultRetryTitle,
            retryBody: defaultRetryBody,
        )
    }

    private var tone: CustomReminderTone {
        CustomReminderTone.resolve(draft.messages, defaults: defaultMessages, locale: locale)
    }

    /// The effective copy one banner shows for the given words, honoring the method default
    /// and the Plus gate exactly as the notification build does.
    private func banner(_ kind: CustomReminderKind, _ words: CustomReminderWords) -> CustomReminderBannerContent {
        switch kind {
        case .daily:
            CustomReminderBannerContent(
                title: CustomReminderPreview.dailyTitle(custom: words.title, method: method, isPlus: isPlus),
                body: CustomReminderPreview.dailyBody(custom: words.message, method: method, isPlus: isPlus)
            )
        case .followup:
            CustomReminderBannerContent(
                title: CustomReminderPreview.retryTitle(custom: words.title, isPlus: isPlus),
                body: CustomReminderPreview.retryBody(custom: words.message, isPlus: isPlus)
            )
        }
    }

    /// The value to show in a field on open: the saved custom text, or the default when blank.
    private func prefilled(_ stored: String, default defaultCopy: String) -> String {
        stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultCopy : stored
    }

    /// The value to persist: an untouched default collapses back to "" so the field stays on
    /// the live default (and never pins today's wording), matching the blank→default contract.
    private func normalized(_ text: String, default defaultCopy: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == defaultCopy ? "" : text
    }

    var body: some View {
        SettingsSheetContainer(
            title: PillieLocalization.string("settings.custom_messages.title", locale: locale),
            spacing: 16,
            bottomPadding: 0
        ) {
            VStack(spacing: 0) {
                // Prefer the full clock, then smaller ones; scroll only when neither fits
                // (long locales, large Dynamic Type).
                ViewThatFits(in: .vertical) {
                    content(clockSize: 72)
                    content(clockSize: 52)
                    content(clockSize: 40)
                    ScrollView(.vertical, showsIndicators: false) {
                        content(clockSize: 40)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                actions
            }
        }
        .sheet(item: $editing) { kind in
            wordsEditor(for: kind)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(34)
                .presentationBackground(PillieTheme.bg)
        }
        .onAppear {
            // Seed every field with the wording that will actually fire: the saved custom
            // text where present, otherwise the same default the notification would use. The
            // "blank uses Pillie's default" contract is preserved by re-normalizing on save.
            draft = CustomReminderDraft(
                messages: CustomReminderMessages(
                    dueTitle: prefilled(store.customDueReminderTitle, default: defaultTitle),
                    dueBody: prefilled(store.customDueReminderBody, default: defaultBody),
                    retryTitle: prefilled(store.customRetryReminderTitle, default: defaultRetryTitle),
                    retryBody: prefilled(store.customRetryReminderBody, default: defaultRetryBody),
                )
            )
            ProductAnalyticsTelemetry.live.customRemindersSettingsOpened()
        }
    }

    private func content(clockSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CustomReminderLockScreenStage(
                hour: store.reminderHour,
                minute: store.reminderMinute,
                clockSize: clockSize,
                daily: banner(.daily, draft.messages[.daily]),
                followup: banner(.followup, draft.messages[.followup]),
                onEdit: { kind in
                    settingsFeedback.openRow(accessibilityReduceMotion: accessibilityReduceMotion)
                    editing = kind
                }
            )

            Text(PillieLocalization.string("settings.custom_messages.preview_caption", locale: locale))
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)

            toneSection
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PillieLocalization.string("settings.custom_messages.tone", locale: locale))
                .font(.pillie(18, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            CustomReminderToneControl(selection: tone.preset) { preset in
                settingsFeedback.openRow(accessibilityReduceMotion: accessibilityReduceMotion)
                draft.apply(preset, locale: locale)
            }

            Text(tone.localizedDescription(locale: locale))
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("reminder-tone-description")
        }
    }

    private var actions: some View {
        VStack(spacing: 4) {
            Button {
                settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                ScheduleCriticalSettingChange.saveSettingsCustomReminders(
                    store: store,
                    title: normalized(draft.messages.dueTitle, default: defaultTitle),
                    body: normalized(draft.messages.dueBody, default: defaultBody),
                    retryTitle: normalized(draft.messages.retryTitle, default: defaultRetryTitle),
                    retryBody: normalized(draft.messages.retryBody, default: defaultRetryBody),
                    preset: draft.appliedPreset,
                    editedAfterPreset: draft.wasEditedAfterPreset
                )
                dismiss()
            } label: {
                Text(PillieLocalization.string("global.action.save", locale: locale))
            }
            .buttonStyle(.pillieDark)

            Button(PillieLocalization.string("global.action.cancel", locale: locale)) {
                draft.discardChanges()
                dismiss()
            }
            .buttonStyle(.pillieSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private func wordsEditor(for kind: CustomReminderKind) -> some View {
        CustomReminderWordsEditor(
            kind: kind,
            words: draft.messages[kind],
            resetWords: draft.resetWords(for: kind, defaults: defaultMessages, locale: locale),
            preview: { banner(kind, $0) },
            onCommit: { draft.messages[kind] = $0 }
        )
    }
}

/// Sage track with an ink thumb. No segment is selected when the words match no preset.
private struct CustomReminderToneControl: View {
    let selection: CustomReminderPreset?
    let onSelect: (CustomReminderPreset) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CustomReminderPreset.allCases) { preset in
                segment(preset)
            }
        }
        .padding(4)
        .background(Capsule().fill(PillieTheme.sage))
        .animation(accessibilityReduceMotion ? nil : .snappy(duration: 0.25), value: selection)
    }

    private func segment(_ preset: CustomReminderPreset) -> some View {
        let isSelected = selection == preset
        let name = preset.localizedDisplayName(locale: locale)
        return Button { onSelect(preset) } label: {
            Text(name)
                .font(.pillie(14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : CustomReminderToneColor.idle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(PillieTheme.dark)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("reminder-tone-\(preset.rawValue)")
    }
}

private enum CustomReminderToneColor {
    static let idle = Color(hex: "44403C")
}
