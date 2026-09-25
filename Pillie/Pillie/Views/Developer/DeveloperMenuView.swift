#if DEBUG
import SwiftUI

struct DeveloperMenuView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(verbatim: "Debug-only. These jumps rewrite local pack history, trial grant, and paywall flags. Never compiled into release.")
                        .font(.pillie(14, weight: .regular))
                        .foregroundStyle(PillieTheme.textMuted)

                    ForEach(DebugQASection.allCases) { section in
                        DeveloperMenuSectionView(
                            section: section,
                            onSelect: apply
                        )
                    }
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
            }
            .background(PillieTheme.bg.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "Developer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "Done")
                            .font(.pillie(16, weight: .semibold))
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func apply(_ scenario: DebugQAScenario) {
        DebugQA.apply(scenario, store: store)
        dismiss()
    }
}
#endif
