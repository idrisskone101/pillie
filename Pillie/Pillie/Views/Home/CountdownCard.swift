//
//  CountdownCard.swift
//  Pillie
//

import SwiftUI

/// The V4 patch and ring card: gauge, countdown and milestone track for one `HomeCountdownProgress`.
/// It only shows state; Home's own button logs.
struct CountdownCard<Menu: View>: View {
    let progress: HomeCountdownProgress
    let reminderTime: String
    @ViewBuilder let menu: Menu

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                CountdownHeader(
                    title: progress.title(locale: locale),
                    subtitle: progress.subtitle(locale: locale),
                    isLogged: progress.isLogged
                )
                menu
            }

            HStack(spacing: 20) {
                CountdownGauge(
                    gauge: progress.gauge,
                    methodColor: progress.method.color,
                    object: progress.object,
                    isObjectFaded: progress.isObjectFaded
                )
                CountdownHero(
                    headline: progress.headline(locale: locale),
                    isAlert: progress.isAlert,
                    daysLeft: progress.daysLeft,
                    dayCount: progress.dayCount(locale: locale),
                    detail: progress.detail(locale: locale),
                    chip: progress.chip(reminderTime: reminderTime, locale: locale),
                    chipTone: progress.chipTone
                )
            }

            MilestoneTrack(
                milestones: progress.milestones.map { milestone in
                    MilestoneTrack.Node(milestone: milestone, label: progress.label(milestone.label, locale: locale))
                },
                lineSegments: progress.lineSegments,
                todayTick: progress.todayTick.map { MilestoneTrack.Tick(position: $0.position, tint: $0.tint) },
                methodColor: progress.method.color
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                .fill(PillieTheme.cardWhite)
                .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        )
        .animation(.smooth(duration: 0.45), value: progress)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeCountdownCard")
    }
}

enum CountdownColor {
    static let patch = PillieTheme.patchChangeRose
    static let ring = PillieTheme.ringReinsertCoral
    static let sage = PillieTheme.verifiedGreen
    static let amber = PillieTheme.amber
    static let amberText = PillieTheme.amberText
    static let loggedText = Color(hex: "5E8A5C")
    static let detailText = Color(hex: "57534E")
    static let pastLabel = Color(hex: "A8A29E")
    static let gaugeTrack = Color(hex: "F4F0EB")
    static let trackLine = Color(hex: "EAE4DD")
    static let tray = Color(hex: "FAF8F5")
    static let menuBorder = Color(hex: "EFEAE4")
}

extension RoutineDialMethod {
    var color: Color {
        switch self {
        case .patch: CountdownColor.patch
        case .ring: CountdownColor.ring
        }
    }
}

extension HomeCountdownProgress {
    enum ChipTone: Hashable {
        case neutral
        case duePatch
        case dueRing
        case amber
    }

    var isLogged: Bool {
        if case .logged = state { return true }
        return false
    }

    var isAlert: Bool {
        switch state {
        case .late, .missed: true
        default: false
        }
    }

    var chipTone: ChipTone {
        switch state {
        case .due, .newCycleDue: method == .patch ? .duePatch : .dueRing
        case .late, .missed: .amber
        case .logged, .wearing, .offWeek: .neutral
        }
    }

    func color(for tint: Tint) -> Color {
        switch tint {
        case .method: method.color
        case .sage: CountdownColor.sage
        case .amber: CountdownColor.amber
        }
    }
}

/// The card's "…" button, drawn to Paper's 32 pt ring with three dots.
struct CountdownMenuLabel: View {
    var body: some View {
        HStack(spacing: 2.8) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(CountdownColor.pastLabel)
                    .frame(width: 2.45, height: 2.45)
            }
        }
        .frame(width: 32, height: 32)
        .overlay(Circle().strokeBorder(CountdownColor.menuBorder, lineWidth: 1))
        .contentShape(Circle())
    }
}

private struct CountdownHeader: View {
    let title: String
    let subtitle: String
    let isLogged: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.pillie(17, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 22)
            Text(subtitle)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(isLogged ? CountdownColor.loggedText : PillieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minHeight: 16)
        }
        .contentTransition(.opacity)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct CountdownGauge: View {
    let gauge: HomeCountdownProgress.Gauge
    let methodColor: Color
    let object: HomeCountdownProgress.Object
    let isObjectFaded: Bool

    /// Paper draws the gauge in a 150 pt box and shows it at 128 pt.
    private static let size: CGFloat = 128
    private static let scale = size / 150

    var body: some View {
        ZStack {
            arc
            Image(object.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .opacity(isObjectFaded ? 0.45 : 1)
                .accessibilityHidden(true)
        }
        .frame(width: Self.size, height: Self.size)
        .overlay(alignment: .topLeading) {
            if gauge == .logged {
                LoggedBadge()
                    .offset(x: 94, y: 6)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var arc: some View {
        let radius = 66 * Self.scale
        let width = 9 * Self.scale
        let diameter = radius * 2
        switch gauge {
        case .due, .late:
            let isLate = gauge == .late
            let color = isLate ? CountdownColor.amber : methodColor
            ZStack {
                Circle()
                    .stroke(color, lineWidth: width)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .stroke(
                        color.opacity(isLate ? 0.45 : 0.22),
                        style: StrokeStyle(
                            lineWidth: 2 * Self.scale,
                            dash: isLate ? [3 * Self.scale, 5 * Self.scale] : []
                        )
                    )
                    .frame(width: 73.5 * 2 * Self.scale, height: 73.5 * 2 * Self.scale)
            }
        case .missed:
            Circle()
                .stroke(
                    CountdownColor.amber.opacity(0.7),
                    style: StrokeStyle(lineWidth: 3 * Self.scale, lineCap: .round, dash: [7 * Self.scale, 7 * Self.scale])
                )
                .frame(width: diameter, height: diameter)
        case .logged, .progress:
            let fraction: Double = if case .progress(let value, _) = gauge { value } else { 0 }
            let color: Color = if case .progress(_, .sage) = gauge { CountdownColor.sage } else { methodColor }
            ZStack {
                Circle()
                    .stroke(CountdownColor.gaugeTrack, lineWidth: width)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(fraction > 0 ? 1 : 0)
            }
            .frame(width: diameter, height: diameter)
        }
    }
}

private struct LoggedBadge: View {
    var body: some View {
        Circle()
            .fill(CountdownColor.sage)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .overlay {
                CheckShape(start: CGPoint(x: 2.5, y: 6.2), mid: CGPoint(x: 4.8, y: 8.5), end: CGPoint(x: 9.5, y: 3.7), box: 12)
                    .stroke(.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
            }
            .frame(width: 26, height: 26)
            .shadow(color: PillieTheme.textPrimary.opacity(0.12), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// A check mark drawn in a `box`-point square, like Paper's `M a l b l c` paths.
private struct CheckShape: Shape {
    let start: CGPoint
    let mid: CGPoint
    let end: CGPoint
    let box: CGFloat

    /// A check mark reads the same in right-to-left layouts; Shape mirrors by default.
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / box
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * scale, y: rect.minY + p.y * scale)
        }
        var path = Path()
        path.move(to: point(start))
        path.addLine(to: point(mid))
        path.addLine(to: point(end))
        return path
    }
}

private struct CountdownHero: View {
    let headline: String?
    let isAlert: Bool
    let daysLeft: Int
    let dayCount: String
    let detail: String
    let chip: String?
    let chipTone: HomeCountdownProgress.ChipTone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let headline {
                    Text(headline)
                        .font(.pillie(40, weight: .extraBold))
                        .tracking(-1.4)
                        .foregroundStyle(isAlert ? CountdownColor.amberText : PillieTheme.textPrimary)
                        .accessibilityIdentifier("homeCountdownHeadline")
                } else {
                    Text(dayCountText)
                        .foregroundStyle(PillieTheme.textPrimary)
                        .contentTransition(.numericText(value: Double(daysLeft)))
                        .accessibilityIdentifier("homeCountdownDays")
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: 46, alignment: .leading)

            Text(detail)
                .font(.pillie(15, weight: .medium))
                .foregroundStyle(CountdownColor.detailText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            if let chip {
                CountdownChip(text: chip, tone: chipTone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "5 days" with the number at display size and the unit smaller, wherever the locale puts the number.
    private var dayCountText: AttributedString {
        var text = AttributedString(dayCount)
        text.font = .pillie(22, weight: .bold)
        text.tracking = -0.44
        if let range = text.range(of: String(daysLeft)) {
            text[range].font = .pillie(46, weight: .extraBold)
            text[range].tracking = -1.84
            // Tracking also pulls in the gap after the last digit; Paper keeps a 6 pt gap there.
            text[text.characters.index(before: range.upperBound)..<range.upperBound].tracking = 0
        }
        return text
    }
}

private struct CountdownChip: View {
    let text: String
    let tone: HomeCountdownProgress.ChipTone

    var body: some View {
        let isAmber = tone == .amber
        HStack(spacing: isAmber ? 5 : 6) {
            ClockGlyph()
                .stroke(foreground, style: StrokeStyle(lineWidth: 1.5 * 13 / 14, lineCap: .round, lineJoin: .round))
                .frame(width: 13, height: 13)
            Text(text)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 5)
        .padding(.leading, isAmber ? 7 : 8)
        .padding(.trailing, isAmber ? 9 : 10)
        .background(Capsule().fill(background))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("homeCountdownChip")
    }

    private var foreground: Color {
        switch tone {
        case .neutral: CountdownColor.detailText
        case .duePatch: Color(hex: "B94A62")
        case .dueRing: Color(hex: "A5563E")
        case .amber: Color(hex: "9A5B2E")
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: Color(hex: "F7F4F0")
        case .duePatch: Color(hex: "FFF0ED")
        case .dueRing: CountdownColor.ring.opacity(0x24 / 255)
        case .amber: CountdownColor.amber.opacity(0x2E / 255)
        }
    }
}

/// Paper's 14 pt clock: a 5.4 pt circle and a hand from 12 o'clock bending to the right.
private struct ClockGlyph: Shape {
    /// Clock hands turn the same way in every layout direction.
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 14
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.addEllipse(in: CGRect(origin: point(7 - 5.4, 7 - 5.4), size: CGSize(width: 10.8 * scale, height: 10.8 * scale)))
        path.move(to: point(7, 4.2))
        path.addLine(to: point(7, 7))
        path.addLine(to: point(8.9, 8.3))
        return path
    }
}

private struct MilestoneTrack: View {
    struct Node: Identifiable {
        let milestone: HomeCountdownProgress.Milestone
        let label: String
        var id: Int { milestone.id }
    }

    struct Tick {
        let position: Double
        let tint: HomeCountdownProgress.Tint
    }

    let milestones: [Node]
    let lineSegments: [HomeCountdownProgress.LineSegment]
    let todayTick: Tick?
    let methodColor: Color

    /// Paper's track runs from x 12 to 12 pt short of the tray's inner edge.
    /// SwiftUI mirrors these coordinates in right-to-left layouts, so they stay left-to-right here.
    static let inset: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let span = proxy.size.width - Self.inset * 2
                let x = { (position: Double) in Self.inset + span * position }
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: x(0), y: 10))
                        path.addLine(to: CGPoint(x: x(1), y: 10))
                    }
                    .stroke(CountdownColor.trackLine, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    ForEach(Array(lineSegments.enumerated()), id: \.offset) { _, segment in
                        Path { path in
                            path.move(to: CGPoint(x: x(segment.from), y: 10))
                            path.addLine(to: CGPoint(x: x(segment.to), y: 10))
                        }
                        .stroke(color(segment.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    if let todayTick {
                        Capsule()
                            .fill(color(todayTick.tint))
                            .frame(width: 3, height: 16)
                            .position(x: x(todayTick.position), y: 10)
                    }

                    ForEach(milestones) { node in
                        MilestoneNode(mark: node.milestone.mark, methodColor: methodColor)
                            .position(x: x(node.milestone.position), y: 10)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 20)

            MilestoneLabelsLayout(positions: milestones.map(\.milestone.position)) {
                ForEach(milestones) { node in
                    MilestoneLabel(text: node.label, isFocus: node.milestone.isFocus)
                        .foregroundStyle(labelColor(node.milestone))
                        .accessibilityIdentifier("countdownMilestone.\(node.milestone.cycleDay)")
                        .accessibilityValue(Text(verbatim: "\(node.milestone.mark)"))
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(CountdownColor.tray))
    }

    private func color(_ tint: HomeCountdownProgress.Tint) -> Color {
        switch tint {
        case .method: methodColor
        case .sage: CountdownColor.sage
        case .amber: CountdownColor.amber
        }
    }

    private func labelColor(_ milestone: HomeCountdownProgress.Milestone) -> Color {
        if milestone.isFocus {
            switch milestone.mark {
            case .late, .missed: return CountdownColor.amberText
            default: return PillieTheme.textPrimary
            }
        }
        return milestone.isPast ? CountdownColor.pastLabel : PillieTheme.textMuted
    }
}

private struct MilestoneNode: View {
    let mark: HomeCountdownProgress.Mark
    let methodColor: Color

    var body: some View {
        switch mark {
        case .done:
            Circle()
                .fill(CountdownColor.sage)
                .overlay {
                    CheckShape(start: CGPoint(x: 4.6, y: 8.2), mid: CGPoint(x: 6.8, y: 10.4), end: CGPoint(x: 11.1, y: 6), box: 16)
                        .stroke(.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
                .frame(width: 16, height: 16)
        case .current, .late:
            let color = mark == .late ? CountdownColor.amber : methodColor
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(color, lineWidth: 2.5))
                .overlay(Circle().fill(color).frame(width: 7, height: 7))
                .frame(width: 17, height: 17)
        case .missed:
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(CountdownColor.amber, style: StrokeStyle(lineWidth: 2, dash: [3, 2.4])))
                .frame(width: 17, height: 17)
        case .upcoming, .offDashed:
            Circle()
                .fill(.white)
                .overlay(
                    Circle().stroke(
                        PillieTheme.hairlineStrong,
                        style: StrokeStyle(lineWidth: 1.5, dash: mark == .offDashed ? [2.2, 2.2] : [])
                    )
                )
                .frame(width: 14, height: 14)
        }
    }
}

private extension HomeCountdownProgress.Object {
    var assetName: String {
        switch self {
        case .patch: ContraceptiveMethod.patch.iconImageName
        case .sachet: "MethodIconSachet"
        case .ring: ContraceptiveMethod.ring.iconImageName
        }
    }
}

/// Places each milestone label under its node without leaving the tray or touching a neighbour.
private struct MilestoneLabelsLayout: Layout {
    let positions: [Double]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 290
        let frames = frames(width: width, subviews: subviews)
        let height = zip(subviews, frames).map { subview, frame in
            subview.sizeThatFits(ProposedViewSize(width: frame.width, height: nil)).height
        }.max() ?? 16
        return CGSize(width: width, height: max(16, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.x, y: bounds.minY),
                proposal: ProposedViewSize(width: frame.width, height: nil)
            )
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [MilestoneLabelPlacement.Frame] {
        let span = width - MilestoneTrack.inset * 2
        return MilestoneLabelPlacement.frames(
            centers: positions.map { MilestoneTrack.inset + span * $0 },
            widths: subviews.map { ceil($0.sizeThatFits(.unspecified).width) },
            trayWidth: width
        )
    }
}

/// One line when it fits, then two lines split at the last space, then two lines shrunk.
/// A word is never broken across lines.
private struct MilestoneLabel: View {
    let text: String
    let isFocus: Bool

    var body: some View {
        let stacked = text.lastIndex(of: " ").map { text.replacingCharacters(in: $0...$0, with: "\n") } ?? text
        ViewThatFits(in: .horizontal) {
            label(text).lineLimit(1)
            label(stacked).lineLimit(2)
            label(stacked).lineLimit(2).minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    private func label(_ string: String) -> some View {
        Text(verbatim: string)
            .font(.pillie(12, weight: isFocus ? .bold : .medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
