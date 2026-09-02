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

private struct DeveloperMenuSectionView: View {
    let section: DebugQASection
    let onSelect: (DebugQAScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: section.title.uppercased())
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            VStack(spacing: 0) {
                ForEach(
                    Array(DebugQAScenario.scenarios(in: section).enumerated()),
                    id: \.element.id
                ) { index, scenario in
                    if index > 0 {
                        Rectangle()
                            .fill(PillieTheme.sageHalf)
                            .frame(height: 1)
                    }
                    Button {
                        onSelect(scenario)
                    } label: {
                        DeveloperMenuRowView(scenario: scenario)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
        }
    }
}

private struct DeveloperMenuRowView: View {
    let scenario: DebugQAScenario

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: scenario.title)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(verbatim: scenario.detail)
                    .font(.pillie(14, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityIdentifier("developerScenario.\(scenario.rawValue)")
    }
}

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
