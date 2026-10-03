//
//  PlusSetupReminderSentence.swift
//  Pillie
//
//  ENG-135: "Nudge me every [10 min] up to [3 times] until I check in."
//  One localized format, split at its placeholders; the words stay plain text
//  and each placeholder becomes a menu chip, so every locale keeps its order.
//

import SwiftUI

struct PlusSetupReminderSentence: View {
    @Binding var intervalMinutes: Int
    @Binding var retryLimit: Int

    @Environment(\.locale) private var locale

    private var parts: [PlusSetupSentencePart] {
        PlusSetupSentence.parts(of: PillieLocalization.string(
            "plus_setup.reminders.sentence",
            locale: locale
        ))
    }

    var body: some View {
        PlusSetupFlowLayout(spacing: 6, lineSpacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let words):
                    Text(words)
                        .font(.pillie(17, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                case .interval(let trailing):
                    flush(intervalMenu, trailing: trailing)
                case .repeats(let trailing):
                    flush(repeatsMenu, trailing: trailing)
                }
            }
        }
        .padding(.top, 2)
    }

    private func flush(_ chip: some View, trailing: String) -> some View {
        HStack(spacing: 1) {
            chip
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.pillie(17, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }
        }
    }

    private var intervalMenu: some View {
        Menu {
            Picker(selection: $intervalMinutes) {
                ForEach(PillStore.autoReminderIntervalOptions, id: \.self) { minutes in
                    Text(SettingsPresentation.interval(minutes: minutes, locale: locale))
                        .tag(minutes)
                }
            } label: {
                Text(PillieLocalization.string("settings.followup.interval_title", locale: locale))
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            PlusSetupChip(
                text: PillieLocalization.formatted(
                    "plus_setup.reminders.interval_chip",
                    locale: locale,
                    arguments: Int64(intervalMinutes)
                ),
                isAccent: true
            )
        }
        .menuOrder(.fixed)
        .accessibilityIdentifier("plusSetupIntervalMenu")
    }

    private var repeatsMenu: some View {
        Menu {
            Picker(selection: $retryLimit) {
                ForEach(PillStore.autoReminderRetryLimitOptions, id: \.self) { limit in
                    Text(repeatsLabel(limit)).tag(limit)
                }
            } label: {
                Text(PillieLocalization.string("settings.followup.retry_limit_title", locale: locale))
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            PlusSetupChip(text: repeatsLabel(retryLimit), isAccent: false)
        }
        .menuOrder(.fixed)
        .accessibilityIdentifier("plusSetupRepeatsMenu")
    }

    private func repeatsLabel(_ limit: Int) -> String {
        guard limit > 0 else {
            return PillieLocalization.string("global.status.off", locale: locale)
        }
        return PillieLocalization.formatted(
            "plus_setup.reminders.repeats_chip",
            locale: locale,
            arguments: Int64(limit)
        )
    }
}

private struct PlusSetupChip: View {
    let text: String
    let isAccent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.pillie(17, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
            Text(verbatim: "▾")
                .font(.pillie(11, weight: .bold))
                .foregroundStyle(isAccent ? PillieTheme.ringReinsertCoral : PillieTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isAccent ? PillieTheme.coralLight : PlusSetupPalette.neutralFill, in: Capsule())
        .overlay {
            if isAccent {
                Capsule().strokeBorder(PillieTheme.coral.opacity(0.8), lineWidth: 1.5)
            }
        }
        .contentShape(Capsule())
    }
}

/// Lays children left to right and wraps whole children onto the next line.
/// A child wider than the line gets the full width and wraps its own text.
struct PlusSetupFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(for: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let usedWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? usedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
