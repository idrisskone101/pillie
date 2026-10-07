//
//  PaywallSuccessSheet.swift
//  Pillie
//
//  The S2c success sheet: rises over the phone once a purchase or restore lands.
//

import SwiftUI

struct PaywallSuccessSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: PaywallSuccessContent
    let onDone: () -> Void

    @State private var isRevealed = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(content: PaywallSuccessContent, onDone: @escaping () -> Void) {
        self.content = content
        self.onDone = onDone
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            ViewThatFits(in: .vertical) {
                card(gap: 40, bottomInset: bottomInset)
                card(gap: 16, bottomInset: bottomInset)
                ScrollView {
                    card(gap: 16, bottomInset: bottomInset)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .clipShape(Self.shape)
            .background(alignment: .bottom) {
                Self.shape
                    .fill(PillieTheme.bg)
                    .shadow(color: PillieTheme.textPrimary.opacity(0.10), radius: 15, y: -12)
            }
            .offset(y: reduceMotion || isRevealed ? 0 : PaywallSuccessMotion.sheetRise)
            .animation(reduceMotion ? nil : PaywallSuccessMotion.sheet, value: isRevealed)
            .opacity(reduceMotion && !isRevealed ? 0 : 1)
            .animation(reduceMotion ? PaywallSuccessMotion.fadeIn : nil, value: isRevealed)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // The sheet runs to the physical bottom, under the home indicator.
            .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywallSuccessSheet")
        .onAppear { isRevealed = true }
        .task {
            try? await Task.sleep(for: reduceMotion ? PaywallSuccessMotion.reducedSettled : PaywallSuccessMotion.settled)
            guard !Task.isCancelled else { return }
            isTitleFocused = true
        }
    }

    private func card(gap: CGFloat, bottomInset: CGFloat) -> some View {
        let rows = RowSequence(hasReminder: content.reminder != nil)
        return VStack(alignment: .leading, spacing: 0) {
            Text(content.title)
                .font(.pillie(30, weight: .black))
                .tracking(-0.9)
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
                .accessibilityIdentifier("paywallSuccessTitle")
                .successRow(rows.title, isRevealed: isRevealed)

            Text(content.receipt)
                .font(.pillie(14, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(PillieTheme.coralLight, in: Capsule())
                .accessibilityIdentifier("paywallSuccessReceipt")
                .padding(.top, 12)
                .successRow(rows.receipt, isRevealed: isRevealed)

            PaywallSuccessPerks(
                label: content.perksLabel,
                perks: content.perks,
                rows: rows,
                isRevealed: isRevealed
            )
            .padding(.top, 20)

            if let reminder = content.reminder {
                PaywallSuccessReminderCard(reminder: reminder)
                    .padding(.top, 18)
                    .successRow(rows.reminder, isRevealed: isRevealed)
            }

            Spacer(minLength: gap)

            Button(action: onDone) {
                Text(content.button)
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background {
                        Capsule()
                            .fill(PillieTheme.textPrimary)
                            .shadow(color: PillieTheme.textPrimary.opacity(0.25), radius: 7.5, y: 8)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywallSuccessDone")
            .successRow(rows.button, isRevealed: isRevealed)

            if let manageLine = content.manageLine {
                Text(manageLine)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .successRow(rows.manage, isRevealed: isRevealed)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .padding(.top, 26)
        // Without the Settings line the button would sit on the home indicator.
        .padding(.bottom, content.manageLine == nil ? max(22, bottomInset) : 22)
    }

    private static let shape = UnevenRoundedRectangle(
        topLeadingRadius: 32,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 32,
        style: .continuous
    )
}

/// Each row's place in the fade-up sequence. An absent reminder card closes its gap.
private struct RowSequence {
    let hasReminder: Bool

    let title = 0
    let receipt = 1
    /// The perks label rides with the first perk.
    func perk(_ index: Int) -> Int { 2 + index }
    var reminder: Int { perk(4) }
    var button: Int { hasReminder ? reminder + 1 : reminder }
    var manage: Int { button + 1 }
}

private struct PaywallSuccessPerks: View {
    let label: String
    let perks: [String]
    let rows: RowSequence
    let isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.pillie(13, weight: .bold))
                .foregroundStyle(PillieTheme.textMuted)
                .successRow(rows.perk(0), isRevealed: isRevealed)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(stride(from: 0, to: perks.count, by: 2)), id: \.self) { start in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(start..<min(start + 2, perks.count), id: \.self) { index in
                            PaywallSuccessPerk(title: perks[index])
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .successRow(rows.perk(index), isRevealed: isRevealed)
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
    }
}

private struct PaywallSuccessPerk: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(PillieTheme.coral)
                .frame(width: 22, height: 22)
                .overlay {
                    PaywallCheckmark()
                        .stroke(PillieTheme.textPrimary, style: PaywallCheckmark.stroke(size: 12))
                        .frame(width: 12, height: 12)
                }
                .accessibilityHidden(true)

            Text(title)
                .font(.pillie(14, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PaywallSuccessReminderCard: View {
    let reminder: PaywallSuccessContent.Reminder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.label)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                Text(reminder.when)
                    .font(.pillie(16, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(reminder.step)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Self.chipFill, in: Capsule())
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PillieTheme.cardWhite)
                .strokeBorder(Self.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywallSuccessReminder")
    }

    private static let chipFill = Color(hex: "F3F0EC")
    private static let border = Color(hex: "EDE9E5")
}

/// Paper's check, `M9 21l7.5 7.5L31 13` on a 40 pt grid.
struct PaywallCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 40
        var path = Path()
        path.move(to: CGPoint(x: 9 * scale, y: 21 * scale))
        path.addLine(to: CGPoint(x: 16.5 * scale, y: 28.5 * scale))
        path.addLine(to: CGPoint(x: 31 * scale, y: 13 * scale))
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }

    /// Paper strokes 6 on the 40 pt grid, so the line scales with the drawn size.
    static func stroke(size: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: 6 / 40 * size, lineCap: .round, lineJoin: .round)
    }
}

private struct SuccessRow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let index: Int
    let isRevealed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed || reduceMotion ? 1 : 0)
            .offset(y: isRevealed || reduceMotion ? 0 : PaywallSuccessMotion.rowRise)
            .animation(reduceMotion ? nil : PaywallSuccessMotion.row(index), value: isRevealed)
    }
}

private extension View {
    func successRow(_ index: Int, isRevealed: Bool) -> some View {
        modifier(SuccessRow(index: index, isRevealed: isRevealed))
    }
}
