//
//  SettingsSheetContainer.swift
//  Pillie
//

import SwiftUI

struct SettingsSheetHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(PillieTheme.sage)
                .frame(width: 36, height: 5)
                .padding(.top, 36)

            Text(title)
                .font(.pillieSubtitleBold())
                .foregroundStyle(PillieTheme.textPrimary)
        }
    }
}

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
                SettingsSheetHeader(title: title)

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
