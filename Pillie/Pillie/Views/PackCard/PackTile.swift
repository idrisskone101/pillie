//
//  PackTile.swift
//  Pillie
//

import SwiftUI

/// One blister tile, drawn at the Paper tile library's 42pt side. The card scales it to fit.
struct PackTile: View {
    static let designSide: CGFloat = 42

    let kind: PackDay.Kind
    let state: PackTileState
    let isCrunching: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var face: Face {
        Face(kind: kind, state: state, isCrunching: isCrunching)
    }

    var body: some View {
        ZStack {
            ring
            ZStack {
                faceView(face)
                    .id(face)
                    .transition(.opacity)
            }
            // Stop motion: frames snap. An ambient withAnimation must not crossfade them.
            .transaction { transaction in
                if !reduceMotion { transaction.animation = nil }
            }
            badge
        }
        .frame(width: Self.designSide, height: Self.designSide)
        .scaleEffect(isCrunching ? 0.94 : 1)
        .animation(isCrunching || reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.4), value: isCrunching)
    }

    // MARK: Ring

    @ViewBuilder
    private var ring: some View {
        switch face {
        case .today, .todayBreak:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .shadow(color: TileColor.todayShadow.opacity(0.45), radius: 8, y: 8)
                .overlay(outsideRing(PillieTheme.coral, width: 2.5))
                .transition(.opacity)
        case .logged:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .overlay(outsideRing(PillieTheme.verifiedGreen, width: 2.5))
        case .late:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .shadow(color: PillieTheme.amber.opacity(0.55), radius: 6)
                .overlay(outsideRing(PillieTheme.amber, width: 2))
        case .missed:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PillieTheme.amber, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        case .sealed, .popped, .crunch, .breakDay, .pastBreakDay:
            EmptyView()
        }
    }

    private func outsideRing(_ color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14 + width, style: .continuous)
            .strokeBorder(color, lineWidth: width)
            .padding(-width)
    }

    // MARK: Face

    @ViewBuilder
    private func faceView(_ face: Face) -> some View {
        switch face {
        case .sealed(let asset):
            pill(asset, drawn: 72, clipRadius: 12, side: Self.designSide)
        case .popped:
            pill(.popped, drawn: 72, clipRadius: 12, side: Self.designSide)
                .opacity(0.5)
        case .crunch:
            pill(.crunch, drawn: 54, clipRadius: 12, side: Self.designSide)
        case .today(let asset):
            pill(asset, drawn: 76, clipRadius: 14, side: Self.designSide)
        case .logged:
            pill(.popped, drawn: 72, clipRadius: 14, side: Self.designSide)
        case .late(let asset):
            pill(asset, drawn: 72, clipRadius: 14, side: Self.designSide)
        case .missed(let asset):
            pill(asset, drawn: 72, clipRadius: 12, side: Self.designSide - 4)
                .saturation(0.25)
                .opacity(0.7)
        case .breakDay:
            breakSlot(fill: TileColor.breakFill, stroke: TileColor.breakStroke)
        case .pastBreakDay:
            breakSlot(fill: TileColor.breakFill, stroke: TileColor.breakStroke)
                .opacity(0.5)
        case .todayBreak:
            breakSlot(fill: TileColor.todayBreakFill, stroke: TileColor.todayBreakStroke)
        }
    }

    private func pill(_ asset: PillAsset, drawn: CGFloat, clipRadius: CGFloat, side: CGFloat) -> some View {
        Image(asset.rawValue)
            .resizable()
            .interpolation(.high)
            .frame(width: drawn, height: drawn)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: clipRadius, style: .continuous))
    }

    private func breakSlot(fill: Color, stroke: Color) -> some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
            .frame(width: 30, height: 30)
    }

    // MARK: Badge

    @ViewBuilder
    private var badge: some View {
        ZStack {
            switch face {
            case .logged:
                CheckBadge()
                    .offset(x: 28 + 10 - Self.designSide / 2, y: -6 + 10 - Self.designSide / 2)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            case .late:
                ClockBadge()
                    .offset(x: 22 + 11 - Self.designSide / 2, y: -2 + 11 - Self.designSide / 2)
                    .transition(.opacity)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Face model

private enum PillAsset: String {
    case active = "PackTileActive"
    case sugar = "PackTilePlacebo"
    case popped = "PackTilePopped"
    case crunch = "PackTileCrunch"
}

/// Everything a tile can draw. Pill-free days never show logged, late, or missed.
private enum Face: Hashable {
    case sealed(PillAsset)
    case popped
    case crunch
    case today(PillAsset)
    case logged
    case late(PillAsset)
    case missed(PillAsset)
    case breakDay
    case pastBreakDay
    case todayBreak

    init(kind: PackDay.Kind, state: PackTileState, isCrunching: Bool) {
        let asset: PillAsset = kind == .sugarPill ? .sugar : .active
        if kind == .noPill {
            switch state {
            case .today, .logged: self = .todayBreak
            case .popped: self = .pastBreakDay
            case .sealed, .late, .missed: self = .breakDay
            }
            return
        }
        if isCrunching {
            self = .crunch
            return
        }
        switch state {
        case .sealed: self = .sealed(asset)
        case .popped: self = .popped
        case .today: self = .today(asset)
        case .logged: self = .logged
        case .late: self = .late(asset)
        case .missed: self = .missed(asset)
        }
    }
}

private enum TileColor {
    static let todayShadow = Color(hex: "F09A94")
    static let breakFill = Color(hex: "F7F6F4")
    static let breakStroke = Color(hex: "CFCBC7")
    static let todayBreakFill = Color(hex: "FFF6F4")
    static let todayBreakStroke = Color(hex: "F0A8A2")
}

// MARK: - Badges

private struct CheckBadge: View {
    var body: some View {
        Circle()
            .fill(PillieTheme.verifiedGreen)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .overlay(
                BadgeGlyph.check
                    .stroke(.white, style: StrokeStyle(lineWidth: 3.4 * 11 / 24, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 11)
            )
            .frame(width: 20, height: 20)
    }
}

private struct ClockBadge: View {
    var body: some View {
        Circle()
            .fill(PillieTheme.amber)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
            .overlay(
                BadgeGlyph.clock
                    .stroke(.white, style: StrokeStyle(lineWidth: 3 * 13 / 24, lineCap: .round, lineJoin: .round))
                    .frame(width: 13, height: 13)
            )
            .frame(width: 22, height: 22)
    }
}

/// Glyph paths from the Paper tile library, authored in a 24pt view box.
private enum BadgeGlyph: Shape {
    case check
    case clock

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch self {
        case .check:
            path.move(to: CGPoint(x: 5, y: 12.5))
            path.addLine(to: CGPoint(x: 9.5, y: 17))
            path.addLine(to: CGPoint(x: 19, y: 7.5))
        case .clock:
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
            path.move(to: CGPoint(x: 12, y: 7))
            path.addLine(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 15, y: 14))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
