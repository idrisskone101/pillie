//
//  CustomPackKeypad.swift
//  Pillie
//

import SwiftUI

/// The in-sheet number pad that replaces the system keyboard for the Active
/// pills field. A system keyboard lifts the fixed-height pack sheet even with
/// `.ignoresSafeArea(.keyboard)`; this pad is regular view content instead, so
/// the sheet never moves.
struct CustomPackKeypad: View {
    let feedback: OnboardingInteractionFeedback
    let reduceMotion: Bool
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    private enum Key: Equatable {
        case digit(Int)
        case delete
    }

    private static let rows: [[Key?]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [nil, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            grid
        }
        .background(KeypadColor.background.ignoresSafeArea(edges: .bottom))
        .accessibilityIdentifier("customPackKeypad")
    }

    private var topBar: some View {
        HStack {
            Text(PillieLocalization.string("custom_pack.active.title"))
                .font(.pillie(14, weight: .regular))
                .foregroundStyle(KeypadColor.label)
            Spacer()
            Button(action: onDone) {
                Text(PillieLocalization.string("global.action.done"))
                    .font(.pillie(16, weight: .bold))
                    .foregroundStyle(KeypadColor.done)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customPackKeypadDone")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(KeypadColor.topBar)
        .overlay(alignment: .top) {
            Rectangle().fill(KeypadColor.topBarBorder).frame(height: 1)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                    keyView(key)
                }
            }
        }
        .padding(6)
    }

    @ViewBuilder
    private func keyView(_ key: Key?) -> some View {
        switch key {
        case .digit(let digit):
            KeypadKeyButton {
                feedback.lightTap(accessibilityReduceMotion: reduceMotion)
                onDigit(digit)
            } label: {
                Text("\(digit)")
                    .font(.pillie(24, weight: .regular))
                    .foregroundStyle(KeypadColor.digit)
            }
            .accessibilityLabel("\(digit)")
            .accessibilityIdentifier("customPackKey\(digit)")
        case .delete:
            KeypadKeyButton {
                feedback.lightTap(accessibilityReduceMotion: reduceMotion)
                onDelete()
            } label: {
                BackspaceGlyph()
                    .frame(width: 24, height: 20)
            }
            .accessibilityLabel(PillieLocalization.string("custom_pack.keypad.delete"))
            .accessibilityIdentifier("customPackKeyDelete")
        case nil:
            Color.clear.frame(height: 46)
        }
    }
}

private struct KeypadKeyButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(KeypadKeyButtonStyle())
    }
}

private struct KeypadKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// The Paper keypad's backspace glyph: a page-with-folded-corner outline and
/// an X, drawn as a path since it isn't an SF Symbol.
private struct BackspaceGlyph: View {
    var body: some View {
        ZStack {
            outline.stroke(KeypadColor.digit, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            crossMark.stroke(KeypadColor.digit, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }

    private var outline: Path {
        Path { path in
            path.move(to: CGPoint(x: 8, y: 2))
            path.addLine(to: CGPoint(x: 21, y: 2))
            path.addQuadCurve(to: CGPoint(x: 23, y: 4), control: CGPoint(x: 23, y: 2))
            path.addLine(to: CGPoint(x: 23, y: 16))
            path.addQuadCurve(to: CGPoint(x: 21, y: 18), control: CGPoint(x: 23, y: 18))
            path.addLine(to: CGPoint(x: 8, y: 18))
            path.addLine(to: CGPoint(x: 2, y: 10))
            path.closeSubpath()
        }
    }

    private var crossMark: Path {
        Path { path in
            path.move(to: CGPoint(x: 11, y: 7))
            path.addLine(to: CGPoint(x: 17, y: 13))
            path.move(to: CGPoint(x: 17, y: 7))
            path.addLine(to: CGPoint(x: 11, y: 13))
        }
    }
}

private enum KeypadColor {
    static let background = Color(hex: "D5D7DD")
    static let topBar = Color(hex: "F4F4F6")
    static let topBarBorder = Color(hex: "C9CBD1")
    static let label = Color(hex: "78716C")
    static let done = Color(hex: "F09A94")
    static let digit = Color(hex: "292524")
}
