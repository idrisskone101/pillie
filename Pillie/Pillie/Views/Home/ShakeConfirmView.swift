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
    func progressShake(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .lowRiskTap,
            motion: .quick,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    @discardableResult
    func completion(accessibilityReduceMotion: Bool) -> Response {
        response(
            feedbackIntent: .success,
            motion: .rewardSpring,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    private func response(
        feedbackIntent: InteractionFeedback.Intent,
        motion: PillieMotion.Semantic,
        accessibilityReduceMotion: Bool
    ) -> Response {
        feedback.perform(feedbackIntent)
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

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @State private var shakeManager = ShakeDetectionManager()
    @State private var appeared = false
    @State private var hasConfirmed = false
    private let shakeFeedback = ShakeConfirmationInteractionFeedback()

    /// The stage is laid out at the design's phone size and scaled to fit.
    private static let stageSize = CGSize(width: 402, height: 400)
    private static let plinthDiameter: CGFloat = 270
    private static let autoConfirmDelay: Duration = .seconds(1.6)

    private var stage: ShakeConfirmStage {
        ShakeConfirmStage(
            shakeCount: shakeManager.shakeCount,
            requiredShakes: shakeManager.requiredShakes
        )
    }

    private var isDone: Bool { stage == .done }
    private var artwork: ShakeConfirmArtwork? { ShakeConfirmArtwork(action: action) }
    private var digits: StreakOdometerDigits {
        StreakOdometerDigits(from: streak.before, to: streak.after)
    }

    private var stageAnimation: Animation {
        PillieMotion.animation(for: .rewardSpring, accessibilityReduceMotion: accessibilityReduceMotion)
    }

    private var eyebrow: String {
        let dayOfTotal = PillieLocalization.formatted(
            "today.pack.day_of_total",
            locale: locale,
            arguments: Int64(action.cycleDay),
            Int64(action.cycleLength)
        )
        return "\(DueActionCopy.localizedLabel(for: action, locale: locale)) · \(dayOfTotal)"
    }

    private var headline: String {
        PillieLocalization.string(
            stage.headlineKey(streakBefore: streak.before, streakAfter: streak.after),
            locale: locale
        )
    }

    var body: some View {
        ZStack {
            (isDone ? PillieTheme.patchChangeRose : PillieTheme.coral)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                stageArea
                    .modifier(FadeInUp(appeared: appeared, delay: 0.05))

                compactCounter
                    .opacity(isDone ? 0 : 1)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                Spacer(minLength: 0)

                actions
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        }
        .animation(stageAnimation, value: stage)
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
                shakeFeedback.completion(accessibilityReduceMotion: accessibilityReduceMotion)
            } else {
                shakeFeedback.progressShake(accessibilityReduceMotion: accessibilityReduceMotion)
            }
        }
        .task(id: isDone) {
            guard isDone else { return }
            do {
                try await Task.sleep(for: Self.autoConfirmDelay)
            } catch {
                return
            }
            confirm()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(isDone ? Color.white : PillieTheme.textPrimary.opacity(0.7))

            Text(headline)
                .font(.pillieHeadline())
                .foregroundStyle(isDone ? Color.white : PillieTheme.textPrimary)
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
            ShakeHalftoneField(
                intensity: Double(stage.rawValue),
                motionLineCount: stage.motionLineCount
            )
            .opacity(isDone ? 0.5 : 1)

            if isDone {
                heroCounter
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                plinth
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .keyframeAnimator(
            initialValue: 1.0,
            trigger: shakeManager.shakeCount
        ) { content, squash in
            content.scaleEffect(x: 2 - squash, y: squash)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(accessibilityReduceMotion ? 1 : 0.9, duration: 0.08)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
        }
    }

    private var plinth: some View {
        ZStack {
            Circle().fill(Color.white)
            blister
        }
        .frame(width: Self.plinthDiameter, height: Self.plinthDiameter)
        .clipShape(Circle())
        .shadow(color: PillieTheme.patchChangeRose.opacity(0.7), radius: 16, y: 16)
    }

    @ViewBuilder
    private var blister: some View {
        if let artwork {
            let imageName = artwork.imageName(for: stage)
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .frame(width: artwork.imageSize, height: artwork.imageSize)
                .id(imageName)
                .transition(.opacity)
                .accessibilityHidden(true)
        } else {
            Text(action.method.emoji)
                .font(.system(size: 96))
        }
    }

    private var compactCounter: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(PillieTheme.patchChangeRose)

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
        .accessibilityValue("\(isDone ? streak.after : streak.before)")
    }

    private var heroCounter: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(PillieTheme.patchChangeRose)

            StreakOdometer(digits: digits, progress: 1, size: .hero)

            Text(PillieLocalization.string("today.streak.title", locale: locale))
                .font(.pillie(14, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(PillieTheme.textPrimary)
        }
        .padding(28)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 40))
        .shadow(color: PillieTheme.textPrimary.opacity(0.2), radius: 20, y: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.string("today.streak.title", locale: locale))
        .accessibilityValue("\(streak.after)")
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                if isDone {
                    confirm()
                } else {
                    shakeManager.fillToComplete()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isDone ? "checkmark.circle" : "hand.tap")
                        .font(.system(size: 18, weight: .semibold))
                    Text(PillieLocalization.string(
                        isDone ? "global.action.done" : "today.action.tap_instead",
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
            .opacity(isDone ? 0 : 1)
            .disabled(isDone)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Private

    private func confirm() {
        guard !hasConfirmed else { return }
        hasConfirmed = true
        onConfirm()
    }
}
