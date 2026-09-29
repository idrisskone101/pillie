//
//  ShakeStopMotion.swift
//  Pillie
//

import SwiftUI

/// A stop-motion clip for the shake confirm: a list of poses that snap with no tween,
/// and the pose each shake stage rests on. Methods without cut-out layers are clips
/// whose poses are whole photos.
struct ShakeClip {
    let poses: [StopMotionPose]
    /// The moving cut-out (pill or patch) drawn over the shell when a pose places it.
    let cutoutImage: String?
    /// Side of the square photo on the board, in points.
    let side: CGFloat
    /// The pose each `ShakeConfirmStage` rests on, indexed by its raw value.
    let stops: [Int]

    func stop(for stage: ShakeConfirmStage) -> Int {
        stops[stage.rawValue]
    }

    /// The poses after the one on screen, up to the stage's stop. Empty when the clip is
    /// already there or past it: a late shake keeps going forward, it never rewinds.
    func posesToPlay(from shown: Int, to stage: ShakeConfirmStage) -> Range<Int> {
        (shown + 1)..<(max(shown, stop(for: stage)) + 1)
    }
}

struct LayerPose {
    /// Offsets are fractions of the clip side so poses survive a resize.
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var scale: CGFloat = 1
}

struct StopMotionPose {
    var shell: String
    var squash: CGFloat = 1
    var cutout: LayerPose?
    var cutoutInsidePouch = false
    var flap: LayerPose?
    var hold: Duration = .milliseconds(90)
}

/// The torn mouth of the empty pouch shell, in unit coordinates of the clip.
/// A patch masked by it only shows above the tear line, so it reads as inside the pouch.
/// Matches `ShakeLayerPouchEmpty` and the `ShakeLayerFlap` cut: re-measure all three together.
struct PouchOpening: Shape {
    static let tearHinge = UnitPoint(x: 0.82, y: 0.37)
    private static let points: [CGPoint] = [
        CGPoint(x: 0.19, y: 0.19), CGPoint(x: 0.82, y: 0.19), CGPoint(x: 0.82, y: 0.37),
        CGPoint(x: 0.70, y: 0.40), CGPoint(x: 0.55, y: 0.38), CGPoint(x: 0.42, y: 0.345),
        CGPoint(x: 0.29, y: 0.322), CGPoint(x: 0.19, y: 0.31),
    ]

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines(Self.points.map {
                CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
            })
            path.closeSubpath()
        }
    }
}

extension ShakeClip {
    /// Shake 1 presses and strains the foil, shake 2 seats the pill in the torn foil,
    /// shake 3 pops it before the counter takes the stage.
    static let pill = ShakeClip(
        poses: [
            .init(shell: "ShakeLayerBlisterSealed", hold: .milliseconds(350)),
            .init(shell: "ShakeLayerBlisterDented", squash: 0.97, hold: .milliseconds(120)),
            .init(shell: "ShakeLayerBlisterDented", squash: 0.94, hold: .milliseconds(220)),
            .init(shell: "ShakeLayerBlisterEmpty", cutout: .init(x: 0.02, y: 0.01, scale: 1.03), hold: .milliseconds(60)),
            .init(shell: "ShakeLayerBlisterEmpty", cutout: .init(y: -0.12, angle: -10, scale: 1.10)),
            .init(shell: "ShakeLayerBlisterEmpty", cutout: .init(y: -0.25, angle: -21, scale: 1.16), hold: .milliseconds(80)),
            .init(shell: "ShakeLayerBlisterEmpty", cutout: .init(y: -0.30, angle: -26, scale: 1.19), hold: .milliseconds(140)),
            .init(shell: "ShakeLayerBlisterEmpty", cutout: .init(y: -0.27, angle: -24, scale: 1.16), hold: .milliseconds(600)),
        ],
        cutoutImage: "ShakeLayerPill",
        side: 300,
        stops: [0, 2, 3, 7]
    )

    /// Shake 1 tears the pouch and the patch peeks out, shake 2 lays it flat on its liner.
    static let patchApply = ShakeClip(
        poses: patchTear(opening: "ShakeLayerPatchPouchSealed"),
        cutoutImage: "ShakeLayerPatch",
        side: 240,
        stops: [0, 9, 11, 11]
    )

    /// Opens on the old patch folded on the new pouch; the next pose is the bare pouch.
    static let patchChange = ShakeClip(
        poses: patchTear(opening: "ShakePatchFoldedOnPouch"),
        cutoutImage: "ShakeLayerPatch",
        side: 240,
        stops: [0, 9, 11, 11]
    )

    static let patchRemove = frames("ShakePatchWorn", "ShakePatchPeeling", "ShakePatchFolded", side: 330)
    static let ringInsert = frames("ShakeRingPouchSealed", "ShakeRingPouchTorn", "ShakeRingOut", side: 240)
    static let ringRemove = frames("ShakeRingOut", "ShakeRingPouchTorn", "ShakeRingPouchResealed", side: 240)

    private static func patchTear(opening: String) -> [StopMotionPose] {
        [
            .init(shell: opening, hold: .milliseconds(350)),
            .init(shell: "ShakeLayerPatchPouchSealed", squash: 0.97, hold: .milliseconds(120)),
            .init(shell: "ShakeLayerPouchEmpty", flap: .init(), hold: .milliseconds(160)),
            .init(shell: "ShakeLayerPouchEmpty", flap: .init(x: 0.02, y: -0.02, angle: -6), hold: .milliseconds(70)),
            .init(shell: "ShakeLayerPouchEmpty", flap: .init(x: 0.06, y: -0.06, angle: -18)),
            .init(shell: "ShakeLayerPouchEmpty", flap: .init(x: 0.16, y: -0.12, angle: -38)),
            .init(shell: "ShakeLayerPouchEmpty", flap: .init(x: 0.36, y: -0.22, angle: -62), hold: .milliseconds(70)),
            .init(shell: "ShakeLayerPouchEmpty", cutout: .init(y: 0.12, angle: 2), cutoutInsidePouch: true, hold: .milliseconds(110)),
            .init(shell: "ShakeLayerPouchEmpty", cutout: .init(y: 0.0, angle: -3), cutoutInsidePouch: true),
            .init(shell: "ShakeLayerPouchEmpty", cutout: .init(y: -0.06, angle: -4), cutoutInsidePouch: true, hold: .milliseconds(260)),
            .init(shell: "ShakeLayerPatchOnLiner", squash: 1.03, hold: .milliseconds(80)),
            .init(shell: "ShakeLayerPatchOnLiner", hold: .milliseconds(600)),
        ]
    }

    /// Three whole photos with a squash beat into each new one, so they still read as stop-motion.
    private static func frames(_ first: String, _ second: String, _ third: String, side: CGFloat) -> ShakeClip {
        ShakeClip(
            poses: [
                .init(shell: first, hold: .milliseconds(350)),
                .init(shell: second, squash: 0.94),
                .init(shell: second),
                .init(shell: third, squash: 0.94),
                .init(shell: third),
            ],
            cutoutImage: nil,
            side: side,
            stops: [0, 2, 4, 4]
        )
    }
}
