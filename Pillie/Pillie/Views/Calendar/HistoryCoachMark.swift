//
//  HistoryCoachMark.swift
//  Pillie
//

import SwiftUI

struct HistoryCoachMark: View {
    let targetFrame: CGRect
    let calendarWidth: CGFloat
    let calendarHeight: CGFloat
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale

    private static let tooltipWidth: CGFloat = 220
    private static let tooltipHitHeight: CGFloat = 180
    private static let caretSize: CGFloat = 12
    private static let caretOffsetX: CGFloat = 22
    private static let verticalGap: CGFloat = 10

    var body: some View {
        tooltip
            .padding(.leading, tooltipOrigin.x)
            .padding(.top, tooltipOrigin.y)
            .frame(
                width: calendarWidth,
                height: calendarHeight,
                alignment: .topLeading
            )
            .contentShape(
                Path(CGRect(
                    x: tooltipOrigin.x,
                    y: tooltipOrigin.y,
                    width: Self.tooltipWidth,
                    height: Self.tooltipHitHeight
                ))
            )
    }

    private var tooltipOrigin: CGPoint {
        let rawX = targetFrame.minX + Self.caretOffsetX - Self.caretSize / 2
        let maxX = max(0, calendarWidth - Self.tooltipWidth)
        let clampedX = min(max(rawX, 0), maxX)
        let y = targetFrame.maxY + Self.verticalGap
        return CGPoint(x: clampedX, y: y)
    }

    private var tooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PillieLocalization.string("history.coachMark.new", locale: locale))
                .font(.pillie(11, weight: .bold))
                .tracking(0.88)
                .foregroundStyle(PillieTheme.coral)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: "3F3A37"))
                )

            Text(PillieLocalization.string("history.coachMark.title", locale: locale))
                .font(.pillie(15, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(PillieLocalization.string("history.coachMark.body", locale: locale))
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(Color(hex: "C4BDB8"))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Text(PillieLocalization.string("history.coachMark.dismiss", locale: locale))
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("historyDayCorrectionCoachMarkDismiss")
            .padding(.top, 4)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(width: Self.tooltipWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PillieTheme.dark)
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(PillieTheme.dark)
                .frame(width: Self.caretSize, height: Self.caretSize)
                .rotationEffect(.degrees(45))
                .offset(x: Self.caretOffsetX, y: -Self.caretSize / 2)
                .allowsHitTesting(false)
        }
    }
}
