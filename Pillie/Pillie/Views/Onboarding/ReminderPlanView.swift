//
//  ReminderPlanView.swift
//  Pillie
//

import SwiftUI

struct ReminderPlanSummary {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        let symbolName: String
        let color: Color
        let background: Color
    }

    let methodValue: String
    let methodDetail: String
    let cyclePositionValue: String
    let cyclePositionDetail: String
    let reminderTimeValue: String
    let reminderTimeDetail: String
    let supportFocusTitle: String
    let supportFocusValue: String

    var items: [Item] {
        [
            Item(
                id: "method",
                title: "Method",
                value: methodValue,
                detail: methodDetail,
                symbolName: "pills.fill",
                color: PillieTheme.coral,
                background: PillieTheme.coralLight
            ),
            Item(
                id: "cycle",
                title: "Current cycle",
                value: cyclePositionValue,
                detail: cyclePositionDetail,
                symbolName: "calendar",
                color: Color(hex: "7DA37B"),
                background: PillieTheme.sage
            ),
            Item(
                id: "time",
                title: "Schedule",
                value: reminderTimeValue,
                detail: reminderTimeDetail,
                symbolName: "clock.fill",
                color: Color(hex: "8C84A9"),
                background: PillieTheme.lavender
            ),
            Item(
                id: "support",
                title: "Support focus",
                value: supportFocusTitle,
                detail: supportFocusValue,
                symbolName: "sparkles",
                color: Color(hex: "E5B454"),
                background: Color(hex: "FFF9EB")
            )
        ]
    }

    var visibleCopy: [String] {
        [
            "Your Personalized Reminder Plan",
            "Built specifically for your routine.",
            methodValue,
            methodDetail,
            cyclePositionValue,
            cyclePositionDetail,
            reminderTimeValue,
            reminderTimeDetail,
            supportFocusTitle,
            supportFocusValue,
            "This is a reminder setup based on your inputs. You can edit it later in Settings."
        ]
    }

    @MainActor
    init(store: PillStore) {
        methodValue = store.pack.method.title
        methodDetail = Self.methodDetailText(for: store.pack)

        let cycle = Self.cyclePosition(for: store)
        cyclePositionValue = cycle.value
        cyclePositionDetail = cycle.detail

        reminderTimeValue = Self.reminderTimeText(hour: store.reminderHour, minute: store.reminderMinute)
        reminderTimeDetail = Self.reminderTimeDetail(hour: store.reminderHour)

        let support = Self.supportFocus(
            goal: store.personalGoal,
            missFrequency: store.missFrequency,
            painPoints: store.painPoints
        )
        supportFocusTitle = support.title
        supportFocusValue = support.detail
    }

    @MainActor
    private static func cyclePosition(for store: PillStore) -> (value: String, detail: String) {
        if let dueAction = DoseScheduleEngine.dueAction(on: store.today, pack: store.pack) {
            return (
                "Day \(dueAction.cycleDay) of \(dueAction.cycleLength)",
                dueAction.cycleDay == 1 ? "Started today" : "Current routine position"
            )
        }
        let cycleLength = max(1, store.pack.cycleLength)
        let day = store.pack.cycleDayIndex(on: store.today) + 1
        let safeDay = min(max(1, day), cycleLength)
        return (
            "Day \(safeDay) of \(cycleLength)",
            safeDay == 1 ? "Started today" : "Current routine position"
        )
    }

    private static func reminderTimeText(hour: Int, minute: Int) -> String {
        let selection = ReminderTimeConverter.toTwelveHour(hour24: hour, minute: minute)
        let period = selection.period == 1 ? "PM" : "AM"
        return "Daily at \(selection.hour):\(String(format: "%02d", selection.minute)) \(period)"
    }

    private static func reminderTimeDetail(hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "Morning consistency anchor"
        case 12..<17:
            return "Afternoon routine cue"
        case 17..<22:
            return "Evening consistency anchor"
        default:
            return "Daily routine cue"
        }
    }

    private static func methodDetailText(for pack: PillPack) -> String {
        switch pack.method {
        case .pill:
            if pack.pillRegimen == .custom, let active = pack.customActiveDays, let breakDays = pack.customBreakDays {
                return "\(active) active / \(breakDays) break days"
            }
            return "\(pack.activeDays) active / \(pack.breakDays) break days"
        case .patch:
            return "Weekly change rhythm"
        case .ring:
            return "Insert, remove, and reinsert rhythm"
        }
    }

    private static func supportFocus(
        goal: PersonalGoal?,
        missFrequency: MissFrequency?,
        painPoints: Set<PainPoint>
    ) -> (title: String, detail: String) {
        if let missFrequency {
            switch missFrequency {
            case .rarely:
                return ("Light nudges", "Keep your routine visible")
            case .sometimes:
                return ("Routine reinforcement", "Weekly check-ins for steadier follow-through")
            case .often:
                return ("Busy-day backup", "Extra follow-through when days get busy")
            case .almostDaily:
                return ("Daily structure", "Make the routine feel more automatic")
            }
        }

        if painPoints.contains(.phoneDistractions) {
            return ("Focus-friendly cue", "A less distracting reminder moment")
        }
        if painPoints.contains(.chaoticSchedule) {
            return ("Flexible cues", "A reminder rhythm for busy days")
        }
        if painPoints.contains(.noRoutine) {
            return ("Routine building", "Simple repetition until it feels automatic")
        }
        if painPoints.contains(.forgetful) {
            return ("Clear reminders", "A nudge before the day gets away")
        }

        switch goal {
        case .buildRoutine:
            return ("Routine building", "Simple cues to make it automatic")
        case .peaceOfMind:
            return ("Confidence check", "A clear log when you need to check")
        case .stayProtected:
            return ("Consistency focus", "Steady reminders for your daily routine")
        case .hormonalBalance:
            return ("Timing support", "Steady cues for your routine")
        case nil:
            return ("Daily rhythm", "Reminders that match your setup")
        }
    }
}

struct ReminderPlanView: View {
    @Environment(PillStore.self) private var store
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: () -> Void

    private var summary: ReminderPlanSummary {
        ReminderPlanSummary(store: store)
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        VStack(spacing: 10) {
                            ForEach(summary.items) { item in
                                summaryCard(item)
                            }
                        }
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        noteText
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 104)
                }
            }

            VStack {
                Spacer()
                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [PillieTheme.bg.opacity(0), PillieTheme.bg, PillieTheme.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -20)
                        .ignoresSafeArea(.all, edges: .bottom)
                    )
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {
            animateIn = true
            guard performanceTier == .standard else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
    }

    private var header: some View {
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: PersonalizationOnboardingProgress.fraction(for: 8),
            badge: PersonalizationOnboardingProgress.badge(for: 8),
            onBack: onBack
        )
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 48, height: 48)
                .background(PillieTheme.coralLight, in: Circle())
                .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
                .accessibilityHidden(true)

            Text("Your Personalized\nReminder Plan")
                .font(.pillie(27, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(0)

            Text("Built specifically for your routine.")
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryCard(_ item: ReminderPlanSummary.Item) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(item.color)
                .frame(width: 44, height: 44)
                .background(item.background, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.pillie(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.68))
                    .textCase(.uppercase)

                Text(item.value)
                    .font(.pillie(14, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .strokeBorder(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(
            color: PillieTheme.cardShadow,
            radius: PillieTheme.cardShadowRadius,
            y: PillieTheme.cardShadowY
        )
    }

    private var noteText: some View {
        Text("This is a reminder setup based on your inputs. You can edit it later in Settings.")
            .font(.pillie(10, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.68))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 8)
    }

    private var footer: some View {
        Button {
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Text("See Recommendation")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(ReminderPlanPrimaryButtonStyle())
    }
}

private struct ReminderPlanPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color(hex: "FF8C86"), in: Capsule())
            .shadow(color: Color(hex: "FF8C86").opacity(0.42), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ReminderPlanView(onBack: {}, onContinue: {})
        .environment(PillStore.previewStore())
}
