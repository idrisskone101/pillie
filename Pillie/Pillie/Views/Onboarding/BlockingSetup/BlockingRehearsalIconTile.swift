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
        switch icon {
        case .symbol(let name):
            GeometryReader { proxy in
                Image(systemName: name)
                    .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.44, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(PillieTheme.dark)
            }
        case .blank:
            Color.white.opacity(0.6)
        }
    }
}
