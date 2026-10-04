//
//  CustomReminderWordsEditor.swift
//  Pillie
//

import SwiftUI

/// Edits one reminder's title and message, writing straight into the Reminder messages
/// draft. Nothing persists until Save on that sheet.
struct CustomReminderWordsEditor: View {
    let kind: CustomReminderKind
    @Binding var title: String
    @Binding var message: String
    let preview: CustomReminderBannerContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: Field?

    private enum Field: String, Hashable {
        case title
        case body
    }

    private var sheetTitle: String {
        switch kind {
        case .daily: PillieLocalization.string("settings.custom_messages.daily_group", locale: locale)
        case .followup: PillieLocalization.string("settings.followup.title", locale: locale)
        }
    }

    var body: some View {
        let content = CustomReminderEditorContent.localized(locale: locale)
        SettingsSheetContainer(title: sheetTitle, spacing: 20) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    CustomReminderNotificationBanner(
                        content: preview,
                        timestamp: Date.now.formatted(.relative(presentation: .named).locale(locale)),
                        kind: kind,
                        onEdit: nil
                    )
                    .padding(12)
                    .background(CustomReminderWallpaper())

                    field(
                        label: content.titleFieldLabel,
                        placeholder: content.defaultTitlePlaceholder,
                        text: $title,
                        cap: CustomReminderCopy.titleCap,
                        axis: .horizontal,
                        field: .title
                    )
                    field(
                        label: content.messageFieldLabel,
                        placeholder: content.defaultMessagePlaceholder,
                        text: $message,
                        cap: CustomReminderCopy.bodyCap,
                        axis: .vertical,
                        field: .body
                    )

                    Text(PillieLocalization.string("settings.custom_messages.blank", locale: locale))
                        .font(.pillieCaption())
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(PillieLocalization.string("global.action.done", locale: locale)) {
                dismiss()
            }
            .buttonStyle(.pillieDark)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("reminder-words-done")
        }
        .onAppear { focusedField = .title }
    }

    private func field(
        label: String,
        placeholder: String,
        text: Binding<String>,
        cap: Int,
        axis: Axis,
        field: Field
    ) -> some View {
        let isFocused = focusedField == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.textMuted)
                    .tracking(1)
                Spacer()
                Text("\(text.wrappedValue.count)/\(cap)")
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                    .monospacedDigit()
            }

            TextField(placeholder, text: text, axis: axis)
                .accessibilityIdentifier("reminder-field-\(kind.rawValue)-\(field.rawValue)")
                .lineLimit(axis == .vertical ? 3...5 : 1...1)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textPrimary)
                .focused($focusedField, equals: field)
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
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}
