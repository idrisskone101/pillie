//
//  BlockingRehearsalIconTile.swift
//  Pillie
//

import SwiftUI

/// Fills whatever frame it is given, so the same tile draws a Home Screen icon
/// and the app "opening" across the whole phone card.
struct BlockingRehearsalIconTile: View {
    let icon: BlockingRehearsalIcon

    var body: some View {
        GeometryReader { proxy in
            Image(systemName: symbolName)
                .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.44, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(tile)
        }
    }

    private var symbolName: String {
        switch icon {
        case .symbol(let name), .plain(let name): name
        }
    }

    private var glyph: Color {
        switch icon {
        case .symbol: PillieTheme.coral
        case .plain: PillieTheme.textMuted
        }
    }

    private var tile: Color {
        switch icon {
        case .symbol: PillieTheme.dark
        case .plain: .white.opacity(0.9)
        }
    }
}
