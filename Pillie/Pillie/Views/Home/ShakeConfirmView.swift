//
//  ShakeConfirmView.swift
//  Pillie
//

import SwiftUI

struct ShakeConfirmationInteractionFeedback {
    struct Response: Equatable {
        let motion: PillieMotion.Semantic
        let motionProfile: PillieMotion.Profile
    }

    private let feedback: InteractionFeedback
    private let performanceTier: PerformanceTier

    init(
        feedback: InteractionFeedback = .live,
        performanceTier: PerformanceTier = .standard
    ) {
        self.feedback = feedback
        self.performanceTier = performanceTier
    }

    @discardableResult
    func shakeLanded(on stage: ShakeConfirmStage, accessibilityReduceMotion: Bool) -> Response {
        let (intent, motion): (InteractionFeedback.Intent, PillieMotion.Semantic) = switch stage {
        case .sealed, .dented: (.meaningfulCommit, .quick)
        case .torn: (.rareHighEnergy, .quick)
        case .done: (.success, .rewardSpring)
        }
        feedback.perform(intent)
        return Response(
            motion: motion,
            motionProfile: PillieMotion.profile(
                for: motion,
                accessibilityReduceMotion: accessibilityReduceMotion,
                performanceTier: performanceTier
            )
        )
    }
}

struct ShakeConfirmView: View {
    let action: DoseScheduleAction
    let streak: StreakChange
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @State private var shakeManager = ShakeDetectionManager()
    @State private var appeared = false
    @State private var hasConfirmed = false
    @State private var revealedAt: Date?
    private let shakeFeedback = ShakeConfirmationInteractionFeedback()

    private static let stageSize = CGSize(width: 402, height: 400)
    private static let plinthDiameter: CGFloat = 270
    private static let autoConfirmDelay: Duration = .seconds(1.6)

    private var stage: ShakeConfirmStage {
        ShakeConfirmStage(
            shakeCount: shakeManager.shakeCount,
            requiredShakes: shakeManager.requiredShakes
        )
    }

    private var isRevealed: Bool { revealedAt != nil }

    private var shownStage: ShakeConfirmStage {
        stage == .done && !isRevealed ? .torn : stage
    }

    private var clip: ShakeClip? { ShakeClip(action: action) }
    private var digits: StreakOdometerDigits {
        StreakOdometerDigits(from: streak.before, to: streak.after)
    }

    private var stageAnimation: Animation {
        PillieMotion.animation(for: .rewardSpring, accessibilityReduceMotion: accessibilityReduceMotion)
    }

    private var eyebrow: String {
        guard action.method == .pill else {
            let dayOfTotal = SettingsPresentation.cycleDay(day: action.cycleDay, total: action.cycleLength, locale: locale)
            return "\(DueActionCopy.localizedLabel(for: action, locale: locale)) · \(dayOfTotal)"
        }
        let regimen = store.pack.regimen
        let weekday = action.date.formatted(.dateTime.weekday(.wide).locale(locale))
        let pill = HomePackProgress.title(for: regimen.day(atIndex: action.cycleDay - 1), in: regimen, locale: locale)
        return "\(weekday) · \(pill)"
    }

    private var foreground: Color { isRevealed ? .white : PillieTheme.textPrimary }

    var body: some View {
        ZStack {
            (isRevealed ? PillieTheme.patchChangeRose : PillieTheme.coral)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                stageArea
                    .modifier(FadeInUp(appeared: appeared, delay: 0.05))

                Group {
                    if let revealedAt {
                        loggedNote(at: revealedAt)
                    } else {
                        compactCounter
                    }
                }
                .transition(.opacity)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                Spacer(minLength: 0)

                actions
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        }
        .animation(stageAnimation, value: stage)
        .animation(stageAnimation, value: isRevealed)
        .onAppear {
            shakeManager.startDetecting()
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .onDisappear {
            shakeManager.stopDetecting()
        }
        .onChange(of: shakeManager.shakeCount) { oldValue, newValue in
            guard newValue > oldValue else { return }
            if shakeManager.isComplete {
                shakeManager.stopDetecting()
            }
            shakeFeedback.shakeLanded(on: stage, accessibilityReduceMotion: accessibilityReduceMotion)
        }
        .task(id: isRevealed) {
            guard isRevealed else { return }
            do {
                try await Task.sleep(for: Self.autoConfirmDelay)
            } catch {
                return
            }
            confirm()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(foreground.opacity(isRevealed ? 1 : 0.7))

            Text(shownStage.headline(streak: streak).text(locale: locale))
                .font(.pillieHeadline())
                .tracking(-0.64)
                .foregroundStyle(foreground)
                .contentTransition(.opacity)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 28)
    }

    private var stageArea: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Self.stageSize.width,
                proxy.size.height / Self.stageSize.height,
                1
            )
            stageContent
                .frame(width: Self.stageSize.width, height: Self.stageSize.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxHeight: Self.stageSize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            shakeManager.simulateShake()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.string("today.action.shake", locale: locale))
        .accessibilityValue(
            PillieLocalization.formatted(
                "accessibility.shake.progress",
                locale: locale,
                arguments: Int64(shakeManager.shakeCount),
                Int64(shakeManager.requiredShakes)
            )
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("shakeConfirmStage")
    }

    private var stageContent: some View {
        ZStack {
            Image("ShakeHalftone\(shownStage.rawValue)")
                .resizable()
                .frame(width: Self.stageSize.width, height: Self.stageSize.height)
                .opacity(isRevealed ? 0.5 : 1)
                .transaction { $0.animation = nil }
                .accessibilityHidden(true)

            if isRevealed {
                heroCounter
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                plinth
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }

    private var plinth: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: Self.plinthDiameter, height: Self.plinthDiameter)
                .shadow(color: PillieTheme.patchChangeRose.opacity(0.7), radius: 16, y: 16)

            if let clip {
                ShakeStopMotionStage(clip: clip, stage: stage, onSettled: reveal(ifDone:))
            } else {
                Text(action.method.emoji)
                    .font(.system(size: 96))
                    .task(id: stage) { reveal(ifDone: stage) }
            }
        }
    }

    private var compactCounter: some View {
        HStack(spacing: 14) {
            flame(side: 30)

            StreakOdometer(digits: digits, progress: stage.odometerProgress, size: .compact)

            Text(PillieLocalization.string("today.streak.title", locale: locale))
                .font(.pillie(15, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 22)
        .background(Color.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.string("today.streak.title", locale: locale))
        .accessibilityValue("\(stage == .done ? streak.after : streak.before)")
    }

    private var heroCounter: some View {
        VStack(spacing: 14) {
            flame(side: 48)

            StreakOdometer(digits: digits, progress: 1, size: .hero)

            Text(PillieLocalization.string("today.streak.title", locale: locale))
                .font(.pillie(14, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.68)
                .foregroundStyle(PillieTheme.textPrimary)
        }
        .padding(.top, 28)
        .padding(.bottom, 26)
        .frame(width: 320)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 40))
        .shadow(color: Color(hex: "78283C").opacity(0.28), radius: 20, y: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.string("today.streak.title", locale: locale))
        .accessibilityValue("\(streak.after)")
        .accessibilityIdentifier("shakeStreakHero")
    }

    private func loggedNote(at date: Date) -> some View {
        Text(ShakeLoggedNote(action: action).text(
            loggedAt: date.formatted(.dateTime.hour().minute().locale(locale)),
            locale: locale
        ))
        .font(.pillie(15, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 40)
        .background(Color.white.opacity(0.22), in: Capsule())
        .accessibilityIdentifier("shakeLoggedNote")
    }

    private func flame(side: CGFloat) -> some View {
        Image("StreakFlame")
            .resizable()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                if isRevealed {
                    confirm()
                } else {
                    shakeManager.fillToComplete()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isRevealed ? "checkmark.circle" : "hand.tap")
                        .font(.system(size: 18, weight: .semibold))
                    Text(PillieLocalization.string(
                        isRevealed ? "global.action.done" : "today.action.tap_instead",
                        locale: locale
                    ))
                }
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("shakeTapToConfirmFallback")

            Button(PillieLocalization.string("global.action.cancel", locale: locale)) {
                shakeManager.stopDetecting()
                onDismiss()
            }
            .buttonStyle(.pillieQuiet)
            .opacity(stage == .done ? 0 : 1)
            .disabled(stage == .done)
        }
        .padding(.bottom, 12)
    }

    private func reveal(ifDone settled: ShakeConfirmStage) {
        guard settled == .done, revealedAt == nil else { return }
        revealedAt = PillieClock.now
    }

    private func confirm() {
        guard !hasConfirmed else { return }
        hasConfirmed = true
        onConfirm()
    }
}
