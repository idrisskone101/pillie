//
//  BlockingRehearsalPicksCard.swift
//  Pillie
//
//  What she picked, drawn by iOS, and when it pauses and opens again.
//

import FamilyControls
import ManagedSettings
import SwiftUI

struct BlockingRehearsalPicksCard: View {
    let grid: BlockingRehearsalPickGrid
    let content: BlockingRehearsalContent
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilesShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            card
            privacyLine
        }
        .onAppear {
            tilesShown = true
            InteractionFeedback.live.perform(.success)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.picksHeader)
                    .font(.pillie(13, weight: .semibold))
                    .tracking(0.78)
                    .textCase(.uppercase)
                    .foregroundStyle(PillieTheme.textMuted)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                Button(action: onChange) {
                    Text(content.changePicks)
                        .font(.pillie(15, weight: .semibold))
                        .underline()
                        .foregroundStyle(PillieTheme.textPrimary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
                .accessibilityIdentifier("blockingRehearsalChangePicks")
            }

            tiles

            VStack(alignment: .leading, spacing: 14) {
                rhythmRow(
                    dot: PillieTheme.patchChangeRose,
                    title: content.pauseRowTitle,
                    detail: content.pauseRowBody
                )
                rhythmRow(
                    dot: PillieTheme.verifiedGreen,
                    title: content.resumeRowTitle,
                    detail: content.resumeRowBody
                )
            }
            .padding(.top, 20)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PillieTheme.textPrimary.opacity(0.1))
                    .frame(height: 1)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BlockingSetupCardSurface())
    }

    private var tiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(grid.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0..<BlockingRehearsalPickGrid.columns, id: \.self) { column in
                        Group {
                            if column < row.count {
                                tile(row[column])
                                    .modifier(TilePop(
                                        shown: tilesShown,
                                        index: rowIndex * BlockingRehearsalPickGrid.columns + column,
                                        reduceMotion: reduceMotion
                                    ))
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("blockingRehearsalPicksCard")
    }

    @ViewBuilder
    private func tile(_ tile: BlockingRehearsalPickGrid.Tile) -> some View {
        switch tile {
        case .pick(.category(let token)):
            Label(token)
                .labelStyle(PickTileStyle(art: .category, caption: content.categoryCaption))
        case .pick(.application(let token)):
            Label(token)
                .labelStyle(PickTileStyle(art: .application, caption: nil))
        case .pick(.webDomain(let token)):
            Label(token)
                .labelStyle(PickTileStyle(art: .webDomain, caption: nil))
        #if DEBUG
        case .pick(.sample(let sample)):
            sampleTile(sample)
        #endif
        case .more(let count):
            PickTileArt(kind: .webDomain) {
                Text("+\(count)")
                    .font(.pillie(17, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
    }

    #if DEBUG
    private func sampleTile(_ sample: BlockingRehearsalSamplePick) -> some View {
        Label {
            Text(sample.name)
        } icon: {
            switch sample.kind {
            case .category(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
            case .application(let icon):
                Image(icon.rawValue)
                    .resizable()
                    .frame(width: PickTileMetrics.side, height: PickTileMetrics.side)
            case .webDomain:
                Image(systemName: "globe")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(PillieTheme.textPrimary)
            }
        }
        .labelStyle(PickTileStyle(
            art: sample.kind.art,
            caption: sample.kind.art == .category ? content.categoryCaption : nil,
            iconScale: 1
        ))
    }
    #endif

    private func rhythmRow(dot: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pillie(16, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(detail)
                    .font(.pillie(15, weight: .regular))
                    .foregroundStyle(BlockingRehearsalPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var privacyLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
            Text(content.privacyLine)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

private enum PickTileKind {
    case category
    case application
    case webDomain
}

private enum PickTileMetrics {
    static let side: CGFloat = 56
    static let artHeight: CGFloat = 66
}

#if DEBUG
private extension BlockingRehearsalSamplePick.Kind {
    var art: PickTileKind {
        switch self {
        case .category: .category
        case .application: .application
        case .webDomain: .webDomain
        }
    }
}
#endif

/// Lays a FamilyControls label out as a tile: icon over name. The name comes
/// from `configuration.title`, which iOS draws. Nothing here reads it.
private struct PickTileStyle: LabelStyle {
    let art: PickTileKind
    let caption: String?
    /// iOS draws a token's icon small and ignores a frame, so it is scaled up
    /// to the tile.
    var iconScale: CGFloat = 1.9

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 8) {
            PickTileArt(kind: art) {
                configuration.icon
                    .scaleEffect(iconScale)
            }
            VStack(spacing: 2) {
                configuration.title
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
                if let caption {
                    Text(caption)
                        .font(.pillie(12, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The 66 pt high art box of a tile. A category sits on a stack of two sheets,
/// because it stands for every app in it.
private struct PickTileArt<Icon: View>: View {
    let kind: PickTileKind
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        let side = PickTileMetrics.side
        ZStack(alignment: .bottomLeading) {
            if kind == .category {
                sheet(PillieTheme.lavender).padding(.leading, 14).padding(.bottom, 10)
                sheet(BlockingRehearsalPalette.tileStack).padding(.leading, 7).padding(.bottom, 5)
            }
            icon()
                .frame(width: side, height: side)
                .background(kind == .application ? Color.clear : background)
                .clipShape(RoundedRectangle(cornerRadius: kind == .category ? 14 : 13, style: .continuous))
        }
        .frame(
            width: kind == .category ? side + 14 : side,
            height: PickTileMetrics.artHeight,
            alignment: .bottomLeading
        )
    }

    private var background: Color {
        kind == .category ? PillieTheme.dark : PillieTheme.lavender
    }

    private func sheet(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(color)
            .frame(width: PickTileMetrics.side, height: PickTileMetrics.side)
    }
}

/// The tiles pop in 45 ms apart, like the pack card.
private struct TilePop: ViewModifier {
    let shown: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.32, dampingFraction: 0.68).delay(Double(index) * 0.045),
                value: shown
            )
    }
}
