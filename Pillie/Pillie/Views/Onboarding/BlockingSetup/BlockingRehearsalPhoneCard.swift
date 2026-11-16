//
//  BlockingRehearsalPhoneCard.swift
//  Pillie
//
//  The mini Home Screen the first two beats and the ask play on.
//

import SwiftUI

struct BlockingRehearsalPhoneCard: View {
    enum Scene {
        case reminder
        case paused
        case ask

        /// The ask waits on the card while the shake cover is over it.
        init?(_ stage: BlockingRehearsalStage) {
            switch stage {
            case .reminder: self = .reminder
            case .paused: self = .paused
            case .shake, .ask: self = .ask
            case .refused, .picks: return nil
            }
        }
    }

    let stage: Scene
    /// She played this beat and its exit is running.
    let isLeaving: Bool
    /// False while the coral cover still hides the ask, so its entrance plays
    /// when she can see it.
    let isLive: Bool
    let script: BlockingRehearsalScript
    let content: BlockingRehearsalContent
    /// Changes once per nudge of the pause card.
    let nudges: Int
    let send: (BlockingRehearsalEvent) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bannerLanded = false
    @State private var showsHand = false
    @State private var haloBreathes = false
    @State private var openPillieBreathes = false

    /// The hand taps the featured app on a loop until she does it herself.
    private var tapCueRuns: Bool { showsHand && !isLeaving && !reduceMotion }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                homeScreen(height: proxy.size.height)
                if stage == .paused {
                    pauseCard
                        .padding(.horizontal, Metrics.inset)
                        .padding(.bottom, Metrics.bottomInset)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(alignment: .topLeading) { wallpaper }
            .overlayPreferenceValue(FeaturedIconBounds.self) { anchor in
                if let anchor, stage == .reminder, isLeaving, !reduceMotion {
                    OpeningApp(
                        icon: script.featuredApp.icon,
                        from: proxy[anchor],
                        card: proxy.size,
                        delay: 0.1
                    )
                }
            }
        }
        .background(PillieTheme.lavender)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(PillieTheme.textPrimary.opacity(0.05), lineWidth: 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(stageAnimation, value: stage)
        .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.3, dampingFraction: 0.7), value: isLive)
        .task(id: stage) { await runCues() }
    }

    private var stageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.86)
    }

    private func runCues() async {
        bannerLanded = false
        showsHand = false
        haloBreathes = false
        openPillieBreathes = false
        do {
            if stage == .paused {
                try await Task.sleep(for: .milliseconds(550))
                InteractionFeedback.live.perform(.meaningfulCommit)
                // Nothing moves on without her, so once she has read the card
                // the way forward breathes like the app tile did.
                try await Task.sleep(for: .milliseconds(1800))
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        openPillieBreathes = true
                    }
                }
            }
            guard stage == .reminder else { return }
            // The card rises in, then holds on "This is a practice run." long
            // enough to read before the reminder rings.
            try await Task.sleep(for: .milliseconds(2000))
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.72)) {
                bannerLanded = true
            }
            InteractionFeedback.live.perform(.lowRiskTap)
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    haloBreathes = true
                }
            }
            try await Task.sleep(for: .milliseconds(1000))
            withAnimation(.easeOut(duration: 0.3)) { showsHand = true }
        } catch {
            return
        }
    }

    // MARK: - Home Screen

    private var wallpaper: some View {
        Circle()
            .fill(BlockingRehearsalPalette.wallpaperBlob.opacity(0.7))
            .frame(width: 300, height: 300)
            .padding(.leading, 130)
            .padding(.top, stage == .ask ? 120 : 250)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private func homeScreen(height: CGFloat) -> some View {
        VStack(spacing: Metrics.rowSpacing) {
            if stage == .reminder {
                banner
                    .overlay { practiceRunChip }
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ForEach(BlockingRehearsalApp.allCases, id: \.self) { app in
                    if app != BlockingRehearsalApp.allCases.first { Spacer(minLength: 0) }
                    appTile(app)
                }
            }

            if stage == .ask {
                // Absent, not just transparent, until the cover is gone: a flow
                // that waits for the pill is waiting for a visible ask.
                if isLive {
                    checkedInPill
                        .padding(.top, 16)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
                }
            } else if height >= (stage == .paused ? Metrics.heightForRowAbovePauseCard : Metrics.heightForSecondRow) {
                HStack(spacing: 0) {
                    ForEach(BlockingRehearsalSystemApp.allCases, id: \.self) { app in
                        if app != BlockingRehearsalSystemApp.allCases.first { Spacer(minLength: 0) }
                        iconTile(app.icon, label: app.label.string(locale: locale))
                    }
                }
                .accessibilityHidden(true)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            if stage == .reminder, height >= Metrics.heightForDock {
                dock
                    .transition(.opacity)
            }
        }
        .padding(.top, Metrics.topInset)
        .padding(.horizontal, Metrics.inset)
        .padding(.bottom, Metrics.bottomInset)
    }

    /// Holds the banner's place until the reminder drops in over it.
    private var practiceRunChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .accessibilityHidden(true)
            Text(content.practiceRun)
                .font(.pillie(15, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.7), in: Capsule())
        .scaleEffect(bannerLanded ? 0.9 : 1)
        .opacity(bannerLanded ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: bannerLanded)
        .allowsHitTesting(false)
        .accessibilityHidden(bannerLanded)
        .accessibilityIdentifier("blockingRehearsalPracticeRun")
    }

    private var banner: some View {
        Button {
            send(.beatControlTapped)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(decorative: "HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(content.bannerTitle)
                            .font(.pillie(15, weight: .bold))
                            .foregroundStyle(PillieTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(content.bannerTime)
                            .font(.pillie(13, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    Text(content.bannerBody)
                        .font(.pillie(14, weight: .regular))
                        .foregroundStyle(BlockingRehearsalPalette.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: PillieTheme.textPrimary.opacity(0.12), radius: 14, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(isLeaving)
        .offset(y: bannerLanded || reduceMotion ? 0 : -150)
        .opacity(bannerLanded ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.bannerTitle). \(content.bannerBody)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("blockingRehearsalBanner")
    }

    @ViewBuilder
    private func appTile(_ app: BlockingRehearsalApp) -> some View {
        let name = app.name(locale: locale)
        let isFeatured = app == script.featuredApp
        switch stage {
        case .reminder where isFeatured:
            Button {
                send(.beatControlTapped)
            } label: {
                iconTile(app.icon, label: name, halo: .invite, pressed: isLeaving)
            }
            .buttonStyle(.plain)
            .disabled(isLeaving)
            .overlay(alignment: .bottomTrailing) { hand }
            .accessibilityLabel(name)
            .accessibilityIdentifier("blockingRehearsalFeaturedApp")
        case .paused:
            Button {
                send(.greyedAppTapped)
            } label: {
                iconTile(app.icon, label: name, dimmed: true)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        case .ask where isFeatured:
            iconTile(app.icon, label: name, halo: .checkedIn)
                .accessibilityHidden(true)
        default:
            iconTile(app.icon, label: name)
                .accessibilityHidden(true)
        }
    }

    private enum Halo {
        case invite
        case checkedIn
    }

    private func iconTile(
        _ icon: BlockingRehearsalIcon,
        label: String,
        halo: Halo? = nil,
        dimmed: Bool = false,
        pressed: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            iconImage(icon, side: Metrics.icon, radius: 14)
                .keyframeAnimator(initialValue: 1.0, repeating: halo == .invite && tapCueRuns) { icon, scale in
                    icon.scaleEffect(scale)
                } keyframes: { _ in
                    // Dips the moment the fingertip lands.
                    KeyframeTrack {
                        LinearKeyframe(1, duration: TapCue.press)
                        LinearKeyframe(0.92, duration: 0.1)
                        SpringKeyframe(1, duration: TapCue.cycle - TapCue.press - 0.1)
                    }
                }
                .overlay {
                    if halo == .invite { tapRipple }
                }
                .grayscale(dimmed ? 1 : 0)
                .opacity(dimmed ? 0.38 : 1)
                .scaleEffect(pressed ? 0.92 : 1)
                .animation(.easeOut(duration: 0.1), value: pressed)
                .animation(.easeOut(duration: 0.3), value: dimmed)
                .background { haloView(halo) }
                .anchorPreference(key: FeaturedIconBounds.self, value: .bounds) {
                    halo == .invite ? $0 : nil
                }

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
                .frame(width: Metrics.icon + 12)
                // Keeps a card that is short on height from shrinking the label.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: Metrics.icon)
    }

    @ViewBuilder
    private func haloView(_ halo: Halo?) -> some View {
        // Hugs the icon: the label sits 6 pt below it, so the halo (even at
        // the top of its breath) has to stay inside that gap.
        let shape = RoundedRectangle(cornerRadius: 19, style: .continuous)
        switch halo {
        case .invite:
            shape
                .fill(PillieTheme.coral.opacity(0.25))
                .overlay { shape.strokeBorder(PillieTheme.coral, lineWidth: 3) }
                .frame(width: Metrics.halo, height: Metrics.halo)
                .scaleEffect(haloBreathes && !isLeaving ? 1.04 : 1)
                .opacity(bannerLanded && !isLeaving ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: isLeaving)
        case .checkedIn:
            shape
                .fill(PillieTheme.verifiedGreen.opacity(0.18))
                .overlay {
                    shape
                        .inset(by: 1.5)
                        .trim(from: 0, to: isLive || reduceMotion ? 1 : 0)
                        .stroke(PillieTheme.verifiedGreen, lineWidth: 3)
                }
                .frame(width: Metrics.halo, height: Metrics.halo)
                .opacity(isLive ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: isLive)
        case nil:
            EmptyView()
        }
    }

    private var tapRipple: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(PillieTheme.coral, lineWidth: 3)
            .keyframeAnimator(initialValue: RipplePose(), repeating: tapCueRuns) { ring, pose in
                ring.scaleEffect(pose.scale).opacity(pose.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: TapCue.press)
                    LinearKeyframe(1.25, duration: 0.6, timingCurve: .easeOut)
                    LinearKeyframe(1, duration: TapCue.cycle - TapCue.press - 0.6)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: TapCue.press)
                    LinearKeyframe(0.9, duration: 0.02)
                    LinearKeyframe(0, duration: 0.58, timingCurve: .easeOut)
                    LinearKeyframe(0, duration: TapCue.cycle - TapCue.press - 0.6)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var hand: some View {
        ZStack {
            Image(systemName: "hand.point.up.left.fill")
                .foregroundStyle(.white)
            Image(systemName: "hand.point.up.left")
                .foregroundStyle(PillieTheme.textPrimary)
        }
        .font(.system(size: 34, weight: .medium))
        .frame(width: 40, height: 40)
        .keyframeAnimator(initialValue: HandPose(), repeating: tapCueRuns) { hand, pose in
            hand.scaleEffect(pose.scale, anchor: .topLeading).offset(pose.offset)
        } keyframes: { _ in
            // Reaches in, presses, and lifts back out, once per cycle.
            KeyframeTrack(\.offset) {
                LinearKeyframe(.zero, duration: 0.35)
                SpringKeyframe(CGSize(width: -10, height: -12), duration: TapCue.press - 0.35)
                LinearKeyframe(CGSize(width: -10, height: -12), duration: 0.3)
                SpringKeyframe(.zero, duration: TapCue.cycle - TapCue.press - 0.3)
            }
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: TapCue.press)
                LinearKeyframe(0.82, duration: 0.1)
                SpringKeyframe(1, duration: TapCue.cycle - TapCue.press - 0.1)
            }
        }
        .flipsForRightToLeftLayoutDirection(true)
        .padding(.trailing, -20)
        .padding(.bottom, 14)
        .opacity(showsHand ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var dock: some View {
        HStack(spacing: 0) {
            ForEach(BlockingRehearsalIcon.dock, id: \.self) { icon in
                if icon != BlockingRehearsalIcon.dock.first { Spacer(minLength: 0) }
                iconImage(icon, side: 54, radius: 13)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityHidden(true)
    }

    private func iconImage(_ icon: BlockingRehearsalIcon, side: CGFloat, radius: CGFloat) -> some View {
        BlockingRehearsalIconTile(icon: icon)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    // MARK: - The pause card

    private var pauseCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(decorative: "HomeAvatarLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                iconImage(script.featuredApp.icon, side: 40, radius: 11)
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(content.pauseCardTitle)
                    .font(.pillie(22, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(content.pauseCardBody)
                    .font(.pillie(15, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("blockingRehearsalPauseCard")

            Button {
                send(.beatControlTapped)
            } label: {
                Text(content.openPillie)
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PillieTheme.dark, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLeaving)
            .scaleEffect(openPillieBreathes && !isLeaving ? 1.04 : 1)
            .scaleEffect(isLeaving ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: isLeaving)
            .accessibilityIdentifier("blockingRehearsalOpenPillie")
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous))
        .shadow(color: PillieTheme.textPrimary.opacity(0.14), radius: 20, y: 18)
        .modifier(NudgeEffect(nudges: CGFloat(nudges)))
        .animation(.linear(duration: 0.25), value: nudges)
    }

    // MARK: - Checked in

    private var checkedInPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(PillieTheme.verifiedGreen)
                .frame(width: 28, height: 28)
            Text(content.checkedIn)
                .font(.pillie(16, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .background(.white, in: Capsule())
        .shadow(color: PillieTheme.textPrimary.opacity(0.12), radius: 13, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("blockingRehearsalCheckedInPill")
    }

    private enum Metrics {
        static let cardRadius: CGFloat = 40
        static let inset: CGFloat = 26
        static let topInset: CGFloat = 30
        static let bottomInset: CGFloat = 18
        static let rowSpacing: CGFloat = 22
        static let icon: CGFloat = 62
        static let halo: CGFloat = 72
        /// Below these card heights the banner, two rows and the dock no
        /// longer fit, so the dock goes first and then the second row.
        static let heightForDock: CGFloat = 470
        static let heightForSecondRow: CGFloat = 364
        static let heightForRowAbovePauseCard: CGFloat = 486
    }
}

private enum TapCue {
    static let cycle: TimeInterval = 1.6
    /// When the fingertip lands, from the start of a cycle.
    static let press: TimeInterval = 0.75
}

private struct HandPose {
    var offset = CGSize.zero
    var scale: CGFloat = 1
}

private struct RipplePose {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

private struct FeaturedIconBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct OpeningApp: View {
    let icon: BlockingRehearsalIcon
    let from: CGRect
    let card: CGSize
    let delay: Double

    @State private var isOpen = false

    var body: some View {
        BlockingRehearsalIconTile(icon: icon)
            .frame(width: isOpen ? card.width : from.width, height: isOpen ? card.height : from.height)
            .clipShape(RoundedRectangle(cornerRadius: isOpen ? 40 : 14, style: .continuous))
            .position(x: isOpen ? card.width / 2 : from.midX, y: isOpen ? card.height / 2 : from.midY)
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeIn(duration: 0.35).delay(delay)) { isOpen = true }
            }
    }
}

private struct NudgeEffect: GeometryEffect {
    var nudges: CGFloat

    var animatableData: CGFloat {
        get { nudges }
        set { nudges = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(nudges * 2 * .pi), y: 0))
    }
}
