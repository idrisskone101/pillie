//
//  PrimaryTitleAnchor.swift
//  Pillie
//

import SwiftUI

struct PrimaryTitleAnchor: View {
    let title: String
    let titleFont: Font
    var titleColor: Color = PillieTheme.textPrimary
    var showsAccessorySlot: Bool = true
    var accessory: (() -> AnyView)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PillieTheme.primaryTitleAccessoryToTitleSpacing) {
            if showsAccessorySlot {
                Group {
                    if let accessory {
                        accessory()
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: PillieTheme.primaryTitleAccessoryHeight, alignment: .center)
            }

            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
        }
    }
}

