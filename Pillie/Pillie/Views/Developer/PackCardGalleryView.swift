#if DEBUG
import SwiftUI

/// `pillie://debug/pack-card`: every pack type and tile state from the Paper board, plus one card to drive the cascade.
struct PackCardGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    InteractivePackCard()
                    ForEach(GalleryCard.all) { card in
                        PackCard(
                            regimen: card.regimen,
                            dayOneWeekday: 2,
                            todayIndex: card.todayIndex,
                            marks: card.marks
                        ) {
                            GalleryTitle(text: card.title)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("pack-card-\(card.id)")
                    }
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
            }
            .background(PillieTheme.bg.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "Pack card"))
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
    }
}

private struct InteractivePackCard: View {
    @State private var todayIndex: Int?
    @State private var marks: [Int: PackTileMark] = [:]

    var body: some View {
        VStack(spacing: 12) {
            PackCard(
                regimen: PackRegimen(activeDays: 21, breakDays: 7),
                dayOneWeekday: 2,
                todayIndex: todayIndex,
                marks: marks,
                flagIndex: todayIndex,
                onSelectDay: { index in
                    marks = [:]
                    todayIndex = index
                }
            ) {
                GalleryTitle(text: "Interactive 21+7")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pack-card-interactive")

            HStack(spacing: 8) {
                control("Seal") {
                    todayIndex = nil
                    marks = [:]
                }
                control("Tap 12") {
                    marks = [:]
                    todayIndex = 11
                }
                control("Tap 5") {
                    marks = [:]
                    todayIndex = 4
                }
                control("Log today") {
                    guard let todayIndex else { return }
                    marks[todayIndex] = .taken
                }
            }
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.pillie(14, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(PillieTheme.cardWhite))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pack-card-control-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

private struct GalleryTitle: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.pillie(16, weight: .bold))
            .foregroundStyle(PillieTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GalleryCard: Identifiable {
    let id: String
    let title: String
    let regimen: PackRegimen
    let todayIndex: Int?
    var marks: [Int: PackTileMark] = [:]

    private static let twentyOneSeven = PackRegimen(activeDays: 21, breakDays: 7)

    static let all: [GalleryCard] = [
        GalleryCard(id: "21-7-due", title: "21+7 · due today, pill 12", regimen: twentyOneSeven, todayIndex: 11),
        GalleryCard(
            id: "21-7-taken", title: "21+7 · taken today", regimen: twentyOneSeven, todayIndex: 11,
            marks: [11: .taken]
        ),
        GalleryCard(
            id: "21-7-late", title: "21+7 · late", regimen: twentyOneSeven, todayIndex: 11, marks: [11: .late]
        ),
        GalleryCard(
            id: "21-7-missed", title: "21+7 · pill 11 missed, today 12", regimen: twentyOneSeven, todayIndex: 11,
            marks: [10: .missed]
        ),
        GalleryCard(id: "21-7-sugar", title: "21+7 · sugar week, today 24", regimen: twentyOneSeven, todayIndex: 23),
        GalleryCard(
            id: "21-only-break", title: "21 only · break day 2",
            regimen: PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills), todayIndex: 22
        ),
        GalleryCard(
            id: "24-4-last", title: "24+4 · last active pill", regimen: PackRegimen(activeDays: 24, breakDays: 4),
            todayIndex: 23
        ),
        GalleryCard(
            id: "26-2-sugar", title: "26+2 · sugar pill 1", regimen: PackRegimen(activeDays: 26, breakDays: 2),
            todayIndex: 26
        ),
        GalleryCard(
            id: "every-day", title: "Every day · pill 1", regimen: PackRegimen(activeDays: 28, breakDays: 0),
            todayIndex: 0
        ),
        GalleryCard(
            id: "21-4-break", title: "21+4 · break day 2",
            regimen: PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills), todayIndex: 22
        ),
        GalleryCard(
            id: "88-3", title: "Custom 88+3 · today 40", regimen: PackRegimen(activeDays: 88, breakDays: 3),
            todayIndex: 39
        ),
        GalleryCard(id: "21-7-finished", title: "21+7 · finished", regimen: twentyOneSeven, todayIndex: 28),
    ]
}
#endif
