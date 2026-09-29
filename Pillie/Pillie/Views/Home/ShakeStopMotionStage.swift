import SwiftUI

struct ShakeStopMotionStage: View {
    let clip: ShakeClip
    let stage: ShakeConfirmStage
    let onSettled: (ShakeConfirmStage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    private var pose: StopMotionPose { clip.poses[shown] }

    var body: some View {
        let side = clip.side
        ZStack {
            layer(pose.shell)
                .blendMode(.multiply)

            if let cutout = pose.cutout, let cutoutImage = clip.cutoutImage {
                layer(cutoutImage)
                    .shadow(
                        color: .black.opacity(0.18),
                        radius: max(0, cutout.scale - 1) * 60,
                        y: max(0, cutout.scale - 1) * 90
                    )
                    .modifier(LayerPoseEffect(pose: cutout, side: side, anchor: .center))
                    .mask {
                        if pose.cutoutInsidePouch {
                            PouchOpening()
                        } else {
                            Rectangle().frame(width: side * 3, height: side * 3)
                        }
                    }
            }

            if let flap = pose.flap {
                layer("ShakeLayerFlap")
                    .modifier(LayerPoseEffect(pose: flap, side: side, anchor: PouchOpening.tearHinge))
            }
        }
        .frame(width: side, height: side)
        .scaleEffect(x: reduceMotion ? 1 : 2 - pose.squash, y: reduceMotion ? 1 : pose.squash)
        .offset(reduceMotion ? .zero : Self.boil(shown))
        .transaction { $0.animation = nil }
        .task(id: stage) { await play(to: stage) }
    }

    private func layer(_ name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: clip.side, height: clip.side)
            .accessibilityHidden(true)
    }

    private func play(to stage: ShakeConfirmStage) async {
        if reduceMotion {
            shown = max(shown, clip.stop(for: stage))
        } else {
            for index in clip.posesToPlay(from: shown, to: stage) {
                shown = index
                do {
                    try await Task.sleep(for: clip.poses[index].hold)
                } catch {
                    return
                }
            }
        }
        onSettled(stage)
    }

    private static func boil(_ index: Int) -> CGSize {
        CGSize(width: Double((index * 7) % 3 - 1) * 0.8, height: Double((index * 5 + 1) % 3 - 1) * 0.8)
    }
}

private struct LayerPoseEffect: ViewModifier {
    let pose: LayerPose
    let side: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(pose.scale, anchor: anchor)
            .rotationEffect(.degrees(pose.angle), anchor: anchor)
            .offset(x: pose.x * side, y: pose.y * side)
    }
}
