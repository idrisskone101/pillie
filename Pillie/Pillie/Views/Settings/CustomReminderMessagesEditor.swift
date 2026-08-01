//
//  CustomReminderMessagesEditor.swift
//  Pillie
//

import SwiftUI

/// Editor for the Custom Reminder Message perk (Pillie+). Lets a subscriber write the
/// title and body of the daily Due Action Reminder, the Auto-Reminder Retry, and the
/// end-of-day Last Call Reminder. What they type is exactly what fires (WYSIWYG); a
/// blank field falls back to the default copy at fire time (see `CustomReminderCopy`).
/// Hard caps are enforced as the user types, with a live character counter. Words never
/// change reminder timing, snooze, retry cadence, or supply scheduling.
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
            retryBody: "",
            lastCallTitle: "",
            lastCallBody: ""
        )
    )

    /// Identifies every editable field so a single keyboard toolbar "Done" button (and
    /// interactive scroll-to-dismiss) can resign whichever field is active.
    private enum Field: String, Hashable {
        case dailyTitle = "daily-title"
        case dailyBody = "daily-body"
        case retryTitle = "retry-title"
        case retryBody = "retry-body"
        case lastCallTitle = "last-call-title"
        case lastCallBody = "last-call-body"
    }

    @FocusState private var focusedField: Field?

    private let settingsFeedback = SettingsInteractionFeedback()
    private var editorContent: CustomReminderEditorContent {
        CustomReminderEditorContent.localized(locale: locale)
    }

    /// The contraception method whose default copy fills any blank preview field.
    private var method: ContraceptiveMethod { store.pack.method }
    /// Same Plus gate the notification build uses, so the preview honors the entitlement.
    private var isPlus: Bool { SubscriptionManager.shared.hasPlusAccess }

    /// The method-aware default copy each field seeds with when no custom value is stored —
    /// the exact strings the notification falls back to (see `CustomReminderPreview`).
    private var defaultTitle: String { CustomReminderPreview.defaultDailyTitle(method: method) }
    private var defaultBody: String { CustomReminderPreview.defaultDailyBody(method: method) }
    private var defaultRetryTitle: String { NotificationManager.defaultRetryTitle }
    private var defaultRetryBody: String { NotificationManager.defaultRetryBody }
    private var defaultLastCallTitle: String { CustomReminderPreview.defaultLastCallTitle(method: method) }
    private var defaultLastCallBody: String { CustomReminderPreview.defaultLastCallBody(method: method) }
    private var defaultMessages: CustomReminderMessages {
        CustomReminderMessages(
            dueTitle: defaultTitle,
            dueBody: defaultBody,
            retryTitle: defaultRetryTitle,
            retryBody: defaultRetryBody,
            lastCallTitle: defaultLastCallTitle,
            lastCallBody: defaultLastCallBody
        )
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
        SettingsSheetContainer(title: PillieLocalization.string(
            "settings.custom_messages.title",
            locale: locale
        )) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text(PillieLocalization.string(
                        "settings.custom_messages.body",
                        locale: locale
                    ))
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    CustomReminderPresetPicker(
                        draft: $draft,
                        feedback: settingsFeedback,
                        accessibilityReduceMotion: accessibilityReduceMotion
                    )

                    Text(PillieLocalization.string(
                        "settings.custom_messages.advanced",
                        locale: locale
                    ))
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    group(
                        index: 1,
                        header: PillieLocalization.string(
                            "settings.custom_messages.daily_group",
                            locale: locale
                        ),
                        subtitle: PillieLocalization.string(
                            "settings.custom_messages.body",
                            locale: locale
                        ),
                        titleBinding: $draft.messages.dueTitle,
                        titleCount: draft.messages.dueTitle.count,
                        bodyBinding: $draft.messages.dueBody,
                        bodyCount: draft.messages.dueBody.count,
                        titleField: .dailyTitle,
                        bodyField: .dailyBody,
                        previewTitle: CustomReminderPreview.dailyTitle(custom: draft.messages.dueTitle, method: method, isPlus: isPlus),
                        previewBody: CustomReminderPreview.dailyBody(custom: draft.messages.dueBody, method: method, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-daily"
                    )

                    group(
                        index: 2,
                        header: PillieLocalization.string(
                            "settings.followup.title",
                            locale: locale
                        ),
                        subtitle: PillieLocalization.string(
                            "settings.followup.body",
                            locale: locale
                        ),
                        titleBinding: $draft.messages.retryTitle,
                        titleCount: draft.messages.retryTitle.count,
                        bodyBinding: $draft.messages.retryBody,
                        bodyCount: draft.messages.retryBody.count,
                        titleField: .retryTitle,
                        bodyField: .retryBody,
                        previewTitle: CustomReminderPreview.retryTitle(custom: draft.messages.retryTitle, isPlus: isPlus),
                        previewBody: CustomReminderPreview.retryBody(custom: draft.messages.retryBody, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-followup"
                    )

                    group(
                        index: 3,
                        header: PillieLocalization.string(
                            "settings.final_reminder.title",
                            locale: locale
                        ),
                        subtitle: PillieLocalization.string(
                            "settings.final_reminder.body",
                            locale: locale
                        ),
                        titleBinding: $draft.messages.lastCallTitle,
                        titleCount: draft.messages.lastCallTitle.count,
                        bodyBinding: $draft.messages.lastCallBody,
                        bodyCount: draft.messages.lastCallBody.count,
                        titleField: .lastCallTitle,
                        bodyField: .lastCallBody,
                        previewTitle: CustomReminderPreview.lastCallTitle(custom: draft.messages.lastCallTitle, method: method, isPlus: isPlus),
                        previewBody: CustomReminderPreview.lastCallBody(custom: draft.messages.lastCallBody, method: method, isPlus: isPlus),
                        previewIdentifier: "reminder-preview-lastcall"
                    )

                    Button(PillieLocalization.string(
                        "settings.custom_messages.restore",
                        locale: locale
                    )) {
                        settingsFeedback.sensitiveOrDestructiveChange(
                            accessibilityReduceMotion: accessibilityReduceMotion
                        )
                        draft.restoreDefaults(defaultMessages)
                        focusedField = nil
                    }
                    .font(.pillieBodySemibold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("reminder-restore-defaults")

                    Text(PillieLocalization.string(
                        "settings.custom_messages.blank",
                        locale: locale
                    ))
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    Button {
                        settingsFeedback.commitScheduleSave(accessibilityReduceMotion: accessibilityReduceMotion)
                        ScheduleCriticalSettingChange.saveSettingsCustomReminders(
                            store: store,
                            title: normalized(draft.messages.dueTitle, default: defaultTitle),
                            body: normalized(draft.messages.dueBody, default: defaultBody),
                            retryTitle: normalized(draft.messages.retryTitle, default: defaultRetryTitle),
                            retryBody: normalized(draft.messages.retryBody, default: defaultRetryBody),
                            lastCallTitle: normalized(draft.messages.lastCallTitle, default: defaultLastCallTitle),
                            lastCallBody: normalized(draft.messages.lastCallBody, default: defaultLastCallBody),
                            preset: draft.appliedPreset,
                            editedAfterPreset: draft.wasEditedAfterPreset
                        )
                        dismiss()
                    } label: {
                        Text(PillieLocalization.string("global.action.save", locale: locale))
                    }
                    .buttonStyle(.pillieDark)
                    .padding(.top, 8)

                    Button(PillieLocalization.string("global.action.cancel", locale: locale)) {
                        draft.discardChanges()
                        dismiss()
                    }
                    .buttonStyle(.pillieSecondary)
                }
                .padding(.horizontal, 24)
                // The dark CTA casts a soft drop shadow (radius 15, y 8); without room
                // below it the ScrollView clips the shadow against the beige bg, leaving
                // a hard cut-off line. Reserve enough space for the shadow to fade out.
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(PillieLocalization.string("global.action.done", locale: locale)) {
                        focusedField = nil
                    }
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
        }
        .onAppear {
            // Seed every field with the wording that will actually fire: the saved custom
            // text where present, otherwise the same default the notification would use. Both
            // sections open pre-filled and editable rather than blank, while the "blank uses
            // Pillie's default" contract is preserved by re-normalizing on save.
            draft = CustomReminderDraft(
                messages: CustomReminderMessages(
                    dueTitle: prefilled(store.customDueReminderTitle, default: defaultTitle),
                    dueBody: prefilled(store.customDueReminderBody, default: defaultBody),
                    retryTitle: prefilled(store.customRetryReminderTitle, default: defaultRetryTitle),
                    retryBody: prefilled(store.customRetryReminderBody, default: defaultRetryBody),
                    lastCallTitle: prefilled(store.customLastCallReminderTitle, default: defaultLastCallTitle),
                    lastCallBody: prefilled(store.customLastCallReminderBody, default: defaultLastCallBody)
                )
            )
            ProductAnalyticsTelemetry.live.customRemindersSettingsOpened()
        }
    }

    @ViewBuilder
    private func group(
        index: Int,
        header: String,
        subtitle: String,
        titleBinding: Binding<String>,
        titleCount: Int,
        bodyBinding: Binding<String>,
        bodyCount: Int,
        titleField: Field,
        bodyField: Field,
        previewTitle: String,
        previewBody: String,
        previewIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(index: index, header: header, subtitle: subtitle)

            field(
                label: editorContent.titleFieldLabel,
                placeholder: editorContent.defaultTitlePlaceholder,
                text: titleBinding,
                count: titleCount,
                cap: CustomReminderCopy.titleCap,
                axis: .horizontal,
                field: titleField
            )

            field(
                label: editorContent.messageFieldLabel,
                placeholder: editorContent.defaultMessagePlaceholder,
                text: bodyBinding,
                count: bodyCount,
                cap: CustomReminderCopy.bodyCap,
                axis: .vertical,
                field: bodyField
            )

            previewBanner(title: previewTitle, body: previewBody, identifier: previewIdentifier)
        }
    }

    /// A numbered, two-line header so the three reminders read as an ordered sequence
    /// (daily → follow-up → last call) and each one clearly states what it does.
    @ViewBuilder
    private func sectionHeader(index: Int, header: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(index)")
                .font(.pillie(15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(PillieTheme.dark))

            VStack(alignment: .leading, spacing: 2) {
                Text(header)
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(subtitle)
                    .font(.pillieDate())
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(header). \(subtitle)")
    }

    /// A mock lock-screen notification banner that renders the *effective* copy that will
    /// actually fire — custom text where present, the method-aware default where a field is
    /// blank. Driven entirely by `CustomReminderPreview`, so it can never diverge from the
    /// scheduled notification.
    @ViewBuilder
    private func previewBanner(title: String, body: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PillieLocalization.string(
                "settings.custom_messages.preview",
                locale: locale
            ))
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                .tracking(2)

            HStack(alignment: .top, spacing: 12) {
                Image("HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.pillieBody())
                            .fontWeight(.semibold)
                            .foregroundStyle(PillieTheme.textPrimary)
                            .lineLimit(2)
                            .accessibilityIdentifier("\(identifier)-title")
                        Spacer(minLength: 8)
                        Text(Date.now.formatted(
                            .relative(presentation: .named).locale(locale)
                        ))
                            .font(.pillieCaption())
                            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                    }
                    Text(body)
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(3)
                        .accessibilityIdentifier("\(identifier)-body")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                    .fill(PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
            .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
        }
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([
            PillieLocalization.string("settings.custom_messages.preview", locale: locale),
            title,
            body,
        ].joined(separator: ". "))
    }

    @ViewBuilder
    private func field(
        label: String,
        placeholder: String,
        text: Binding<String>,
        count: Int,
        cap: Int,
        axis: Axis,
        field: Field
    ) -> some View {
        let isFocused = focusedField == field
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.textMuted)
                    .tracking(1)
                Spacer()
                Text("\(count)/\(cap)")
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                    .monospacedDigit()
            }

            TextField(placeholder, text: text, axis: axis)
                .accessibilityIdentifier("reminder-field-\(field.rawValue)")
                .lineLimit(axis == .vertical ? 3...5 : 1...1)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textPrimary)
                .focused($focusedField, equals: field)
                // Hard cap: drop anything typed or pasted past the limit so the field
                // can never exceed `cap` (the count label stays in sync).
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > cap {
                        text.wrappedValue = String(newValue.prefix(cap))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .fill(PillieTheme.cardWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                        .stroke(isFocused ? PillieTheme.verifiedGreen : PillieTheme.sageHalf,
                                lineWidth: isFocused ? 1.5 : 1)
                )
                .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}

private struct CustomReminderPresetPicker: View {
    @Binding var draft: CustomReminderDraft
    @Environment(\.locale) private var locale
    let feedback: SettingsInteractionFeedback
    let accessibilityReduceMotion: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(PillieLocalization.string(
                    "settings.custom_messages.start_tone",
                    locale: locale
                ))
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(PillieLocalization.string(
                    "settings.custom_messages.start_tone_body",
                    locale: locale
                ))
                    .font(.pillieDate())
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CustomReminderPreset.allCases) { preset in
                    let isSelected = draft.appliedPreset == preset
                        || (draft.appliedPreset == nil
                            && CustomReminderPreset.matching(
                                draft.messages,
                                locale: locale
                            ) == preset)

                    Button {
                        feedback.openRow(accessibilityReduceMotion: accessibilityReduceMotion)
                        draft.apply(preset, locale: locale)
                    } label: {
                        HStack(spacing: 7) {
                            Text(preset.localizedDisplayName(locale: locale))
                                .font(.pillieDate())
                                .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                            Spacer(minLength: 0)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.pillie(14, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : PillieTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                                .fill(isSelected ? PillieTheme.dark : PillieTheme.cardWhite)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                                .stroke(isSelected ? PillieTheme.dark : PillieTheme.sageHalf, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.localizedDisplayName(locale: locale))
                    .accessibilityValue(
                        CustomReminderEditorContent.localized(locale: locale)
                            .selectionValue(isSelected: isSelected)
                    )
                    .accessibilityIdentifier("reminder-preset-\(preset.rawValue)")
                }
            }
        }
    }
}
