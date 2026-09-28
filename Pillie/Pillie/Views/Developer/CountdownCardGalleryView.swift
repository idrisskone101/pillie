#if DEBUG
import SwiftUI

/// `pillie://debug/countdown-card`: the 16 patch and ring lifecycle cards from the Paper board.
struct CountdownCardGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(GalleryCard.all) { card in
                        Text(verbatim: card.caption)
                            .font(.pillie(15, weight: .bold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .padding(.top, 8)
                        CountdownCard(progress: card.progress, reminderTime: "8:00 PM") {
                            CountdownMenuLabel()
                        }
                        .accessibilityIdentifier("countdown-card-\(card.id)")
                    }
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
            }
            .background(PillieTheme.bg.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "Countdown card"))
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

private struct GalleryCard: Identifiable {
    let id: String
    let caption: String
    let progress: HomeCountdownProgress

    private static let calendar = Calendar.current
    private static let today = calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!)
    private static let evening = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today)!
    private static let deadline = calendar.date(byAdding: .hour, value: 22, to: evening)!

    private static func card(
        _ id: String,
        _ caption: String,
        _ method: RoutineDialMethod,
        day: Int,
        taken: Bool = false,
        late: Bool = false,
        missed: Set<Int> = []
    ) -> GalleryCard {
        GalleryCard(
            id: id,
            caption: caption,
            progress: HomeCountdownProgress(
                method: method,
                cycleDay: day,
                isTodayTaken: taken,
                standing: late ? .late(until: deadline) : .upcoming,
                missedTaskDays: missed,
                reminderHour: 20,
                reminderMinute: 0,
                today: today,
                now: evening,
                calendar: calendar
            )
        )
    }

    static let all: [GalleryCard] = [
        card("patch-put-on", "Patch 1 · Put it on", .patch, day: 1),
        card("patch-on", "Patch 2 · On", .patch, day: 1, taken: true),
        card("patch-wearing", "Patch 3 · Wearing", .patch, day: 10),
        card("patch-change", "Patch 4 · Change day", .patch, day: 15),
        card("patch-late", "Patch 5 · Late change", .patch, day: 15, late: true),
        card("patch-missed", "Patch 6 · Missed change", .patch, day: 16, missed: [15]),
        card("patch-off", "Patch 7 · Off day", .patch, day: 22),
        card("patch-free", "Patch 8 · Patch-free week", .patch, day: 25),
        card("ring-put-in", "Ring 1 · Put it in", .ring, day: 1),
        card("ring-in", "Ring 2 · In", .ring, day: 1, taken: true),
        card("ring-wearing", "Ring 3 · Wearing", .ring, day: 10),
        card("ring-out", "Ring 4 · Out day", .ring, day: 22),
        card("ring-late", "Ring 5 · Late out", .ring, day: 22, late: true),
        card("ring-free", "Ring 6 · Ring-free week", .ring, day: 25),
        card("ring-back-in", "Ring 7 · Back in", .ring, day: 29),
        card("ring-new-cycle", "Ring 8 · Past day 29 (engine: new cycle due)", .ring, day: 30),
    ]
}
#endif
