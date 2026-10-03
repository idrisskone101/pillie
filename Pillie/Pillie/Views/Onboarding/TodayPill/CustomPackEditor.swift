//
//  CustomPackEditor.swift
//  Pillie
//

import SwiftUI

struct CustomPackEditor: View {
    let onBack: () -> Void
    let onUse: (PackChoice) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded before the first frame, so the counts never spring in from the default pack.
    @State private var draft: CustomPackDraft
    @State private var typed: String?
    @State private var typingStartValue = 0

    private let feedback = OnboardingInteractionFeedback()

    init(seed: PackRegimen, onBack: @escaping () -> Void, onUse: @escaping (PackChoice) -> Void) {
        self.onBack = onBack
        self.onUse = onUse
        _draft = State(initialValue: CustomPackDraft(seed))
    }

    private var countAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2)
    }

    private var keypadAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.2)
    }

    private var keypadTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    CustomPackPreviewCard(draft: draft)
                    steppers
                    breakKindPicker
                }
                .padding(.top, 31)
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.bottom, 14)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { useButton }
            // A tap outside the pad commits the typed number and closes the pad.
            .contentShape(Rectangle())
            .onTapGesture { commitTyping() }

            if typed != nil {
                CustomPackKeypad(
                    feedback: feedback,
                    reduceMotion: reduceMotion,
                    onDigit: appendDigit,
                    onDelete: deleteDigit,
                    onDone: commitTyping
                )
                .transition(keypadTransition)
            }
        }
        .background(PillieTheme.bg)
        .animation(countAnimation, value: draft)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: {
                commitTyping()
                onBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(PillieTheme.cardWhite).shadow(color: .black.opacity(0.06), radius: 4, y: 3))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("global.action.back"))
            .accessibilityIdentifier("customPackBack")

            Text(PillieLocalization.string("custom_pack.title"))
                .font(.pillie(26, weight: .bold))
                .tracking(-0.52)
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("customPackTitle")
        }
    }

    private var activeSubtitle: String {
        if typed != nil {
            return PillieLocalization.formatted("custom_pack.active.typing", arguments: CustomPackDraft.activeRange.upperBound)
        }
        switch draft.layout {
        case .grid: return PillieLocalization.string("custom_pack.active.subtitle")
        case .map: return PillieLocalization.string("custom_pack.active.hint")
        }
    }

    private var steppers: some View {
        VStack(spacing: 0) {
            CustomPackStepperRow(
                dot: PackGlyph.GlyphColor.active,
                title: PillieLocalization.string("custom_pack.active.title"),
                subtitle: activeSubtitle,
                value: draft.activeDays,
                canDecrement: draft.activeDays > CustomPackDraft.activeRange.lowerBound,
                canIncrement: draft.activeDays < CustomPackDraft.activeRange.upperBound,
                idName: "Active",
                onStep: stepActive,
                onTypeNumber: startTyping
            ) {
                if let typed {
                    activeField(typed)
                } else {
                    Button(action: startTyping) {
                        CustomPackStepperValue(value: draft.activeDays)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("customPackActiveValue")
                }
            }

            Rectangle()
                .fill(EditorColor.divider)
                .frame(height: 1)

            CustomPackStepperRow(
                dot: PackGlyph.GlyphColor.sugar,
                title: PillieLocalization.string("custom_pack.break.title"),
                subtitle: PillieLocalization.string("custom_pack.break.subtitle"),
                value: draft.breakDays,
                canDecrement: draft.breakDays > draft.breakRange.lowerBound,
                canIncrement: draft.breakDays < draft.breakRange.upperBound,
                idName: "Break",
                onStep: stepBreak,
                onTypeNumber: nil
            ) {
                CustomPackStepperValue(value: draft.breakDays)
            }
        }
        .background(EditorShape.card.fill(PillieTheme.cardWhite).shadow(color: .black.opacity(0.05), radius: 7, y: 6))
    }

    private func activeField(_ text: String) -> some View {
        HStack(spacing: 2) {
            if text.isEmpty {
                Text(String(typingStartValue))
                    .foregroundStyle(PillieTheme.textMuted)
            } else {
                Text(text)
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            CustomPackCaret(reduceMotion: reduceMotion)
        }
        .font(.pillie(22, weight: .bold))
        .frame(width: 62, height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PillieTheme.coralLight))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PillieTheme.coral, lineWidth: 2))
        .accessibilityLabel(PillieLocalization.string("custom_pack.active.title"))
        .accessibilityIdentifier("customPackActiveField")
    }

    private var breakKindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PillieLocalization.string("custom_pack.break_kind.title").uppercased())
                .font(.pillie(13, weight: .semibold))
                .tracking(0.78)
                .foregroundStyle(PillieTheme.textMuted)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)

            CustomPackBreakKindPicker(selection: draft.breakKind) { kind in
                commitTyping()
                feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
                draft.setBreakKind(kind)
            }
            .disabled(draft.breakDays == 0)
            .opacity(draft.breakDays == 0 ? 0.4 : 1)
        }
    }

    private var useButton: some View {
        Button {
            commitTyping()
            feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
            onUse(draft.choice)
        } label: {
            Text(PillieLocalization.formatted("custom_pack.use", arguments: draft.choice.split))
                .font(.pillie(18, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .frame(height: PillieTheme.ctaHeight)
                .background(Capsule().fill(PillieTheme.dark))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customPackUse")
        .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .background(PillieTheme.bg)
    }

    private func stepActive(_ delta: Int) {
        commitTyping()
        draft.stepActive(by: delta)
        feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
    }

    private func stepBreak(_ delta: Int) {
        commitTyping()
        draft.stepBreak(by: delta)
        feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
    }

    private func startTyping() {
        guard typed == nil else { return }
        typingStartValue = draft.activeDays
        withAnimation(keypadAnimation) { typed = "" }
    }

    private func appendDigit(_ digit: Int) {
        guard let text = typed else { return }
        setTyping(CustomPackDraft.typingByAppending(digit, to: text))
    }

    private func deleteDigit() {
        guard let text = typed else { return }
        setTyping(CustomPackDraft.typingByDeletingLastDigit(from: text))
    }

    private func setTyping(_ sanitized: String) {
        typed = sanitized
        draft.setActiveDays(typed: Int(sanitized).flatMap { $0 > 0 ? $0 : nil } ?? typingStartValue)
    }

    private func commitTyping() {
        guard let text = typed else { return }
        withAnimation(keypadAnimation) { typed = nil }
        draft.setActiveDays(typed: CustomPackDraft.commitTyping(text, previousValue: typingStartValue))
    }
}

/// A blinking text-input caret, drawn since there's no real text cursor
/// without a `TextField`. Solid (no blink) under Reduce Motion.
private struct CustomPackCaret: View {
    let reduceMotion: Bool

    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(EditorColor.done)
            .frame(width: 2, height: 22)
            .opacity(reduceMotion || visible ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

private struct CustomPackPreviewCard: View {
    let draft: CustomPackDraft

    var body: some View {
        VStack(spacing: 12) {
            Group {
                switch draft.layout {
                case .grid:
                    PackGlyph(regimen: draft.regimen, size: .preview)
                        .accessibilityHidden(true)
                case .map:
                    CustomPackDotMap(regimen: draft.regimen)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: CustomPackMapMetrics.boxHeight)

            Text(draft.caption())
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
                .accessibilityIdentifier("customPackCaption")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .background(EditorShape.card.fill(PillieTheme.cardWhite).shadow(color: .black.opacity(0.05), radius: 7, y: 6))
    }
}

private struct CustomPackDotMap: View {
    let regimen: PackRegimen

    @State private var availableWidth: CGFloat = 300

    private var metrics: CustomPackMapMetrics {
        CustomPackMapMetrics(weeks: regimen.weekCount, availableWidth: availableWidth)
    }

    private var weekdayLabels: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<symbols.count).map { symbols[(first + $0) % symbols.count] }
    }

    var body: some View {
        let metrics = metrics
        HStack(alignment: .top, spacing: CustomPackMapMetrics.labelGap) {
            if metrics.showsLabels {
                VStack(spacing: 0) {
                    ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.pillie(10, weight: .semibold))
                            .foregroundStyle(EditorColor.weekday)
                            .frame(width: CustomPackMapMetrics.labelWidth, height: metrics.dot)
                            .padding(.bottom, metrics.pitch - metrics.dot)
                    }
                }
                .frame(height: metrics.size.height, alignment: .top)
            }

            Canvas { context, _ in
                for index in 0..<regimen.totalDays {
                    let rect = CGRect(origin: metrics.origin(ofDay: index), size: CGSize(width: metrics.dot, height: metrics.dot))
                    let circle = Path(ellipseIn: rect)
                    switch regimen.day(atIndex: index).kind {
                    case .active:
                        context.fill(circle, with: .color(PackGlyph.GlyphColor.active))
                    case .sugarPill:
                        context.fill(circle, with: .color(PackGlyph.GlyphColor.sugar))
                    case .noPill:
                        let inset = Path(ellipseIn: rect.insetBy(dx: 0.7, dy: 0.7))
                        context.stroke(inset, with: .color(PackGlyph.GlyphColor.noPill), style: StrokeStyle(lineWidth: 1.4, dash: [2.4, 2.1]))
                    }
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
        }
        .frame(maxWidth: .infinity)
        .background {
            Color.clear.onGeometryChange(for: CGFloat.self, of: \.size.width) { availableWidth = $0 }
        }
        .accessibilityHidden(true)
    }
}

private struct CustomPackStepperRow<Value: View>: View {
    let dot: Color
    let title: String
    let subtitle: String
    let value: Int
    let canDecrement: Bool
    let canIncrement: Bool
    let idName: String
    let onStep: (Int) -> Void
    let onTypeNumber: (() -> Void)?
    @ViewBuilder let valueView: () -> Value

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(dot).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.pillie(17, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.pillie(13, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                stepButton("\u{2212}", delta: -1, enabled: canDecrement)
                    .accessibilityIdentifier("customPack\(idName)Minus")
                valueView()
                stepButton("+", delta: 1, enabled: canIncrement)
                    .accessibilityIdentifier("customPack\(idName)Plus")
            }
        }
        .padding(.vertical, 16)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        // VoiceOver gets one adjustable row. Without it the buttons stay exposed so
        // UI automation can tap them by identifier.
        .accessibilityElement(children: voiceOverEnabled ? .ignore : .contain)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrement { onStep(1) }
            case .decrement: if canDecrement { onStep(-1) }
            @unknown default: break
            }
        }
        .modifier(TypeNumberAction(action: onTypeNumber))
        .accessibilityIdentifier("customPack\(idName)Row")
    }

    private func stepButton(_ symbol: String, delta: Int, enabled: Bool) -> some View {
        Button { onStep(delta) } label: {
            Text(symbol)
                .font(.pillie(20, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(EditorColor.stepButton))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

private struct TypeNumberAction: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Text(PillieLocalization.string("custom_pack.active.type_action")), action)
        } else {
            content
        }
    }
}

private struct CustomPackStepperValue: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.pillie(22, weight: .bold))
            .foregroundStyle(PillieTheme.textPrimary)
            .contentTransition(.numericText(value: Double(value)))
            .monospacedDigit()
            // The typing box's width, so neither a third digit nor typing moves the ± buttons.
            .frame(width: 62)
    }
}

private struct CustomPackBreakKindPicker: View {
    let selection: PackRegimen.BreakKind
    let onSelect: (PackRegimen.BreakKind) -> Void

    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 0) {
            segment(.sugarPills, title: "custom_pack.break_kind.sugar", id: "customPackSugar")
            segment(.noPills, title: "custom_pack.break_kind.none", id: "customPackNoPills")
        }
        .padding(4)
        .background(Capsule().fill(EditorColor.segmentTrack))
    }

    private func segment(_ kind: PackRegimen.BreakKind, title: String, id: String) -> some View {
        let isSelected = selection == kind
        return Button { onSelect(kind) } label: {
            Text(PillieLocalization.string(title))
                .font(.pillie(15, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? PillieTheme.textPrimary : PillieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(PillieTheme.cardWhite)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

private enum EditorShape {
    static let card = RoundedRectangle(cornerRadius: 24, style: .continuous)
}

private enum EditorColor {
    static let divider = Color(hex: "F0EEEC")
    static let stepButton = Color(hex: "F5F5F4")
    static let segmentTrack = Color(hex: "F1EFEC")
    static let weekday = Color(hex: "A8A29E")
    static let done = Color(hex: "F09A94")
}
