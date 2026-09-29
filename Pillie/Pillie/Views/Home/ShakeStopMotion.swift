import SwiftUI

struct ShakeClip: Equatable {
    let poses: [StopMotionPose]
    let cutoutImage: String?
    let side: CGFloat
    let stops: Stops

    struct Stops: Equatable {
        let dented: Int
        let torn: Int
        let done: Int
    }

    func stop(for stage: ShakeConfirmStage) -> Int {
        switch stage {
        case .sealed: 0
        case .dented: stops.dented
        case .torn: stops.torn
        case .done: stops.done
        }
    }

    func posesToPlay(from shown: Int, to stage: ShakeConfirmStage) -> Range<Int> {
        let forwardOnly = max(shown, stop(for: stage))
        return (shown + 1)..<(forwardOnly + 1)
    }
}

struct LayerPose: Equatable {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var scale: CGFloat = 1
}

struct StopMotionPose: Equatable {
    var shell: String
    var squash: CGFloat = 1
    var cutout: LayerPose?
    var cutoutInsidePouch = false
    var flap: LayerPose?
    var hold: Duration = .milliseconds(90)
}

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
    init?(action: DoseScheduleAction) {
        switch action.type {
        case .pillActive, .pillSugar:
            self = .pill
        case .patchChange:
            self = action.cycleDay == 1 ? .patchApply : .patchChange
        case .patchRemove:
            self = .patchRemove
        case .ringInsert, .ringReinsert:
            self = .ringInsert
        case .ringRemove:
            self = .ringRemove
        case .pillBreak, .patchActive, .patchBreak, .ringActive, .ringBreak:
            return nil
        }
    }

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
        stops: Stops(dented: 2, torn: 3, done: 7)
    )

    static let patchApply = patchTear(opening: "ShakeLayerPatchPouchSealed")
    static let patchChange = patchTear(opening: "ShakePatchFoldedOnPouch")

    static let patchRemove = frames("ShakePatchWorn", "ShakePatchPeeling", "ShakePatchFolded", side: 330)
    static let ringInsert = frames("ShakeRingPouchSealed", "ShakeRingPouchTorn", "ShakeRingOut", side: 240)
    static let ringRemove = frames("ShakeRingOut", "ShakeRingPouchTorn", "ShakeRingPouchResealed", side: 240)

    private static func patchTear(opening: String) -> ShakeClip {
        ShakeClip(poses: [
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
        ], cutoutImage: "ShakeLayerPatch", side: 240, stops: Stops(dented: 9, torn: 11, done: 11))
    }

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
            stops: Stops(dented: 2, torn: 4, done: 4)
        )
    }
}
