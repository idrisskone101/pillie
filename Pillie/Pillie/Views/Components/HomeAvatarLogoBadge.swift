//
//  HomeAvatarLogoBadge.swift
//  Pillie
//

import SwiftUI

struct HomeAvatarLogoBadge: View {
    var size: CGFloat = 44

    var body: some View {
        Image("HomeAvatarLogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

