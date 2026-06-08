//
//  SettingsSheetContainer.swift
//  Pillie
//

import SwiftUI

struct SettingsSheetContainer<Content: View>: View {
    let title: String
    let spacing: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        spacing: CGFloat = 24,
        bottomPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.spacing = spacing
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            PillieTheme.bg
                .ignoresSafeArea()

            VStack(spacing: spacing) {
                Capsule()
                    .fill(PillieTheme.sage)
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                Text(title)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)

                content

                if bottomPadding > 0 {
                    PillieTheme.bg.frame(height: bottomPadding)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PillieTheme.bg.ignoresSafeArea())
    }
}
