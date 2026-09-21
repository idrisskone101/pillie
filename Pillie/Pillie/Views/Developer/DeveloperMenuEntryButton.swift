#if DEBUG
import SwiftUI

struct DeveloperMenuEntryButton: View {
    @State private var showMenu = false

    var body: some View {
        Button {
            showMenu = true
        } label: {
            Image(systemName: "hammer.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(PillieTheme.coral)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
        }
        .accessibilityLabel(Text(verbatim: "Developer menu"))
        .accessibilityIdentifier("developerMenuButton")
        .sheet(isPresented: $showMenu) {
            DeveloperMenuView()
        }
    }
}

extension View {
    func developerMenuAnchor() -> some View {
        overlay(alignment: .bottomTrailing) {
            DeveloperMenuEntryButton()
                .padding(.trailing, 16)
                .padding(.bottom, 28)
        }
    }
}
#endif
