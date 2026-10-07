//
//  DoseWindowExplainerSheet.swift
//  Pillie
//

import SwiftUI

/// The sheet behind Home's late line: one dose window drawn to scale, from one reminder to the next.
/// Sizes itself to its content.
struct DoseWindowExplainerSheet: View {
    let explainer: DoseWindowExplainer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var contentHeight: CGFloat = 520

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(PillieTheme.hairlineStrong)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(explainer.title(locale: locale))
                    .font(.pillieExtraBold(30))
                    .tracking(-0.6)
                    .foregroundStyle(PillieTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(explainer.body(locale: locale))
                    .font(.pillie(16))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 22)

            TimelineView(.everyMinute) { _ in
                DoseWindowRibbon(explainer: explainer, now: PillieClock.now)
            }
            .padding(.top, 32)

            Button {
                dismiss()
            } label: {
                Text(PillieLocalization.string("home.window.done", locale: locale))
                    .font(.pillie(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(PillieTheme.dark))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("doseWindowExplainer.done")
            .padding(.top, 36)
        }
        .padding(.top, 12)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PillieTheme.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doseWindowExplainer")
        .presentationDetents([.height(contentHeight)])
        .presentationCornerRadius(34)
    }
}

/// The small ⓘ after Home's late line that opens `DoseWindowExplainerSheet`.
struct LateInfoButton: View {
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            Image(systemName: "info")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(LateInfoButtonStyle())
        .accessibilityLabel(PillieLocalization.string("home.window.info", locale: locale))
    }
}

/// A 20 pt circle that answers to a 44 pt touch without taking more room in the line.
private struct LateInfoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.white : PillieTheme.amberText)
            .frame(width: 20, height: 20)
            .background(Circle().fill(configuration.isPressed ? PillieTheme.amber : Self.fill))
            .padding(12)
            .contentShape(Rectangle())
            .padding(-12)
    }

    private static let fill = Color(hex: "FBEBDD")
}

/// One amber bar from the reminder that opened the window to the next one. Midnight is a notch in the bar,
/// joined by a leader to its label above, so nothing below the bar reads as its marker.
private struct DoseWindowRibbon: View {
    let explainer: DoseWindowExplainer
    let now: Date

    @Environment(\.locale) private var locale

    var body: some View {
        let midnightFraction = explainer.midnightFraction
        RibbonLayout(midnightFraction: midnightFraction) {
            Capsule()
                .fill(PillieTheme.amber)
                .ribbonPart(.bar)
            Circle()
                .fill(PillieTheme.amber)
                .ribbonPart(.startDot)
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(PillieTheme.amber, lineWidth: 2))
                .ribbonPart(.endDot)
            HorizontalLine()
                .stroke(PillieTheme.hairlineStrong, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                .ribbonPart(.tail)
            if midnightFraction != nil {
                Rectangle()
                    .fill(PillieTheme.bg)
                    .ribbonPart(.notch)
                Capsule()
                    .fill(PillieTheme.textMuted)
                    .ribbonPart(.tick)
                VStack(spacing: 1) {
                    Text(PillieLocalization.string("home.window.midnight", locale: locale))
                        .font(.pillie(12, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                    Text(explainer.midnightCaption(locale: locale))
                        .font(.pillie(12))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .multilineTextAlignment(.center)
                .ribbonPart(.midnight)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(explainer.startLabel(now: now, locale: locale))
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(PillieLocalization.string("home.window.start.caption", locale: locale))
                    .font(.pillie(12))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .ribbonPart(.start)
            VStack(alignment: .trailing, spacing: 2) {
                Text(explainer.endLabel(now: now, locale: locale))
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(explainer.timeLeft(now: now, locale: locale))
                    .font(.pillie(12, weight: .semibold))
                    .foregroundStyle(PillieTheme.amberText)
            }
            .ribbonPart(.end)
            Text(PillieLocalization.string("home.window.then_missed", locale: locale))
                .font(.pillie(12, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .ribbonPart(.thenMissed)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(explainer.accessibilitySummary(now: now, locale: locale))
        .accessibilityIdentifier("doseWindowExplainer.ribbon")
    }
}

/// Places the bar between its dots, midnight's tick and labels above it, and the start, end and
/// "then missed" labels below it, each label clamped so none overlaps another or leaves the row.
private struct RibbonLayout: Layout {
    nonisolated enum Part: Hashable {
        case bar, startDot, endDot, tail, notch, tick, midnight, start, end, thenMissed
    }

    nonisolated struct PartKey: LayoutValueKey {
        static let defaultValue = Part.bar
    }

    let midnightFraction: Double?

    private static let dot: CGFloat = 12
    private static let barHeight: CGFloat = 6
    private static let tickWidth: CGFloat = 1.5
    private static let rowHeight: CGFloat = 18
    private static let tailLength: CGFloat = 28
    private static let tailGap: CGFloat = 6
    private static let midnightGap: CGFloat = 14
    private static let notchWidth: CGFloat = 4
    private static let labelGap: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let height = frames(width: width, subviews: subviews).values.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(width: bounds.width, subviews: subviews)
        for subview in subviews {
            guard let frame = frames[subview[PartKey.self]] else { continue }
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    /// The bar runs from the start dot's center to the end dot's center; the tail after the end dot
    /// is as wide as its "then missed" label, so that label never reaches under the end labels.
    private func frames(width: CGFloat, subviews: Subviews) -> [Part: CGRect] {
        let parts = Dictionary(subviews.map { ($0[PartKey.self], $0) }, uniquingKeysWith: { first, _ in first })
        func size(_ part: Part, maxWidth: CGFloat) -> CGSize {
            let limit = max(0, maxWidth)
            guard let subview = parts[part] else { return .zero }
            let fitted = subview.sizeThatFits(ProposedViewSize(width: limit, height: nil))
            return CGSize(width: min(ceil(fitted.width), limit), height: ceil(fitted.height))
        }

        let radius = Self.dot / 2
        let thenMissed = size(.thenMissed, maxWidth: width * 0.3)
        let endCenter = width - max(Self.tailLength, thenMissed.width) - Self.tailGap - radius
        let endEdge = endCenter + radius
        let tailStart = endEdge + Self.tailGap
        var frames: [Part: CGRect] = [:]

        var rowTop: CGFloat = 0
        if let midnightFraction {
            let tickX = radius + max(0, endCenter - radius) * midnightFraction
            let label = size(.midnight, maxWidth: endEdge)
            let labelX = min(max(0, tickX - label.width / 2), max(0, endEdge - label.width))
            frames[.midnight] = CGRect(x: labelX, y: 0, width: label.width, height: label.height)
            rowTop = label.height + Self.midnightGap
            let barTop = rowTop + (Self.rowHeight - Self.barHeight) / 2
            frames[.tick] = CGRect(
                x: tickX - Self.tickWidth / 2, y: label.height + 3,
                width: Self.tickWidth, height: barTop - label.height - 3
            )
            frames[.notch] = CGRect(
                x: tickX - Self.notchWidth / 2, y: barTop, width: Self.notchWidth, height: Self.barHeight
            )
        }

        let rowMid = rowTop + Self.rowHeight / 2
        frames[.bar] = CGRect(
            x: radius, y: rowMid - Self.barHeight / 2,
            width: max(0, endCenter - radius), height: Self.barHeight
        )
        frames[.startDot] = CGRect(x: 0, y: rowMid - radius, width: Self.dot, height: Self.dot)
        frames[.endDot] = CGRect(x: endCenter - radius, y: rowMid - radius, width: Self.dot, height: Self.dot)
        frames[.tail] = CGRect(x: tailStart, y: rowMid - 1, width: Self.tailLength, height: 2)

        let labelsTop = rowTop + Self.rowHeight + Self.labelGap
        let half = (endEdge - Self.labelGap) / 2
        let start = size(.start, maxWidth: half)
        let end = size(.end, maxWidth: half)
        frames[.start] = CGRect(x: 0, y: labelsTop, width: start.width, height: start.height)
        frames[.end] = CGRect(x: endEdge - end.width, y: labelsTop, width: end.width, height: end.height)
        frames[.thenMissed] = CGRect(x: tailStart, y: labelsTop, width: thenMissed.width, height: thenMissed.height)
        return frames
    }
}

private extension View {
    func ribbonPart(_ part: RibbonLayout.Part) -> some View {
        layoutValue(key: RibbonLayout.PartKey.self, value: part)
    }
}

private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
