//
//  CustomReminderWordsEditor.swift
//  Pillie
//

import SwiftUI

/// Edits one reminder's title and message under a live banner that stays above the keyboard.
/// The checkmark hands the words back to the Reminder messages draft. X drops them, and
/// swipe-down is held while there are unsaved edits. Nothing persists until Save on that sheet.
struct CustomReminderWordsEditor: View {
    let kind: CustomReminderKind
    let openedWords: CustomReminderWords
    let resetWords: CustomReminderWords
    let preview: (CustomReminderWords) -> CustomReminderBannerContent
    let onCommit: (CustomReminderWords) -> Void

    @State private var words: CustomReminderWords

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: Field?

    init(
        kind: CustomReminderKind,
        words: CustomReminderWords,
        resetWords: CustomReminderWords,
        preview: @escaping (CustomReminderWords) -> CustomReminderBannerContent,
        onCommit: @escaping (CustomReminderWords) -> Void
    ) {
        self.kind = kind
        self.openedWords = words
        self.resetWords = resetWords
        self.preview = preview
        self.onCommit = onCommit
        self.words = words
    }

    private enum Field: String, Hashable {
        case title
        case body
    }

    private func string(_ key: String) -> String {
        PillieLocalization.string(key, locale: locale)
    }

    var body: some View {
        let content = CustomReminderEditorContent.localized(locale: locale)
        VStack(spacing: 18) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    CustomReminderNotificationBanner(
                        content: preview(words),
                        timestamp: Date.now.formatted(.relative(presentation: .named).locale(locale)),
                        kind: kind,
                        onEdit: nil
                    )
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(CustomReminderWallpaper())

                    VStack(spacing: 0) {
                        field(
                            label: content.titleFieldLabel,
                            placeholder: content.defaultTitlePlaceholder,
                            text: $words.title,
                            cap: CustomReminderCopy.titleCap,
                            field: .title
                        )
                        Rectangle()
                            .fill(CustomReminderWordsColor.divider)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                        field(
                            label: content.messageFieldLabel,
                            placeholder: content.defaultMessagePlaceholder,
                            text: $words.message,
                            cap: CustomReminderCopy.bodyCap,
                            field: .body
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: PillieTheme.buttonRadius, style: .continuous)
                            .fill(PillieTheme.cardWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PillieTheme.buttonRadius, style: .continuous)
                            .stroke(PillieTheme.hairline, lineWidth: 1)
                    )

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PillieTheme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(words != openedWords)
        .onAppear { focusedField = .title }
    }

    private var titleKey: String {
        switch kind {
        case .daily: "settings.custom_messages.daily_group"
        case .followup: "settings.custom_messages.followup_group"
        }
    }

    private var subtitleKey: String {
        switch kind {
        case .daily: "settings.custom_messages.daily_subtitle"
        case .followup: "settings.custom_messages.followup_subtitle"
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(PillieTheme.hairline)
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(CustomReminderWordsColor.closeFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(string("global.action.cancel"))
                .accessibilityIdentifier("reminder-words-cancel")

                Spacer(minLength: 8)

                VStack(spacing: 1) {
                    Text(string(titleKey))
                        .font(.pillie(16, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(string(subtitleKey))
                        .font(.pillie(12, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Button {
                    onCommit(words)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(PillieTheme.dark))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(string("global.action.done"))
                .accessibilityIdentifier("reminder-words-done")
            }
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        let isReset = words == resetWords
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(string("settings.custom_messages.blank_hint"))
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(string("settings.custom_messages.reset")) {
                words = resetWords
            }
            .font(.pillie(14, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .buttonStyle(.plain)
            .disabled(isReset)
            .opacity(isReset ? 0.4 : 1)
            .accessibilityIdentifier("reminder-words-reset")
        }
        .padding(.horizontal, 6)
    }

    private func field(
        label: String,
        placeholder: String,
        text: Binding<String>,
        cap: Int,
        field: Field
    ) -> some View {
        let isFocused = focusedField == field
        let tint = isFocused ? PillieTheme.verifiedGreen : PillieTheme.textMuted
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .textCase(.uppercase)
                    .font(.pillie(12, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(tint)
                Spacer()
                if isFocused {
                    Text("\(text.wrappedValue.count)/\(cap)")
                        .font(.pillie(12, weight: .semibold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }

            TextField(placeholder, text: text, axis: .vertical)
                .accessibilityIdentifier("reminder-field-\(kind.rawValue)-\(field.rawValue)")
                .lineLimit(field == .title ? 1...2 : 1...5)
                .font(.pillie(17, weight: field == .title ? .semibold : .regular))
                .foregroundStyle(PillieTheme.textPrimary)
                .tint(PillieTheme.verifiedGreen)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, newValue in
                    // The title is one line, so Return moves on to the message.
                    if field == .title, newValue.contains("\n") {
                        text.wrappedValue = newValue.replacingOccurrences(of: "\n", with: "")
                        focusedField = .body
                    } else if newValue.count > cap {
                        text.wrappedValue = String(newValue.prefix(cap))
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, field == .title ? 12 : 14)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

private enum CustomReminderWordsColor {
    static let closeFill = Color(hex: "F1F0EC")
    static let divider = Color(hex: "F0EFEC")
}
