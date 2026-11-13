//
//  BlockingRehearsalShakeBeat.swift
//  Pillie
//
//  What sits on the coral cover of the third beat: shake once, or tap, and her
//  method's own clip plays through to the pop. The view that owns the cover
//  draws the coral, so it can spread and pull back on its own.
//

import SwiftUI

struct BlockingRehearsalShakeBeat: View {
    let clip: ShakeClip
    let chrome: BlockingRehearsalChrome
    let playsClip: Bool
    let onBack: () -> Void
    let send: (BlockingRehearsalEvent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var tapInsteadFocused: Bool
    @State private var rockAngle = 0.0
    @State private var entered = false

    private static let stageSize = CGSize(width: 402, height: 400)
    private static let plinthDiameter: CGFloat = 270

    private var rocks: Bool {
        entered && !playsClip && !reduceMotion && !voiceOverEnabled
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 24) {
                header
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                stage
                Spacer(minLength: 0)
                tapInstead
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.bottom, 12)
            }

            ProtectionPlanBackButton(action: onBack)
                .padding(.leading, PillieTheme.screenHorizontalPadding)
                .padding(.top, 8)
        }
        .onAppear {
            entered = true
            tapInsteadFocused = true
        }
        .onChange(of: rocks, initial: true) { _, rocks in
            if rocks {
                rockAngle = -3
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { rockAngle = 3 }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { rockAngle = 0 }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let eyebrow = chrome.eyebrow {
                Text(eyebrow)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textPrimary.opacity(0.7))
                    // Keeps a long eyebrow clear of the back button beside it.
                    .padding(.horizontal, 60)
            }
            Text(chrome.title)
                .font(.pillieHeadline())
                .tracking(-0.64)
                .foregroundStyle(PillieTheme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 36)
    }

    private var stage: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Self.stageSize.width,
                proxy.size.height / Self.stageSize.height,
                1
            )
            ZStack {
                Image(playsClip ? "ShakeHalftone3" : "ShakeHalftone0")
                    .resizable()
                    .frame(width: Self.stageSize.width, height: Self.stageSize.height)
                    .transaction { $0.animation = nil }

                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: Self.plinthDiameter, height: Self.plinthDiameter)
                        .shadow(color: PillieTheme.patchChangeRose.opacity(0.7), radius: 16, y: 16)

                    ShakeStopMotionStage(
                        clip: clip,
                        shakes: playsClip ? clip.shakeCount : 0,
                        onFinished: {
                            InteractionFeedback.live.perform(.success)
                            send(.shakeClipFinished)
                        }
                    )
                    .rotationEffect(.degrees(rockAngle))
                }
                .scaleEffect(entered || reduceMotion ? 1 : 0.9)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: entered)
            }
            .frame(width: Self.stageSize.width, height: Self.stageSize.height)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxHeight: Self.stageSize.height)
        .contentShape(Rectangle())
        #if targetEnvironment(simulator)
        // The simulator has no accelerometer, so QA taps the stage to shake.
        .onTapGesture { send(.shaken) }
        #endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chrome.title)
        .accessibilityIdentifier("blockingRehearsalShakeBeat")
    }

    @ViewBuilder
    private var tapInstead: some View {
        if let primary = chrome.primary {
            Button {
                send(primary.event)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 18, weight: .semibold))
                    Text(primary.title)
                }
            }
            .buttonStyle(.pillieDark)
            .disabled(playsClip)
            .accessibilityFocused($tapInsteadFocused)
            .accessibilityIdentifier("blockingRehearsalTapInstead")
        }
    }
}
