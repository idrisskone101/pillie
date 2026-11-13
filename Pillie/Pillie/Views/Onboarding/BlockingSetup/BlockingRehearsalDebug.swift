//
//  BlockingRehearsalDebug.swift
//  Pillie
//
//  QA stand-ins the simulator needs. Release does not compile this file's
//  contents.
//

#if DEBUG
import Foundation

/// A tile that stands in for a FamilyControls token on the simulator.
struct BlockingRehearsalSamplePick: Hashable {
    enum Kind: Hashable {
        case category(symbol: String)
        case application(BlockingRehearsalIcon)
        case webDomain

        fileprivate var group: Int {
            switch self {
            case .category: 0
            case .application: 1
            case .webDomain: 2
            }
        }
    }

    let kind: Kind
    /// English and never localized: it stands in for a name iOS would draw.
    let name: String

    private static let cycle: [BlockingRehearsalSamplePick] = [
        BlockingRehearsalSamplePick(kind: .category(symbol: "bubble.left.fill"), name: "Social"),
        BlockingRehearsalSamplePick(kind: .category(symbol: "gamecontroller.fill"), name: "Games"),
        BlockingRehearsalSamplePick(kind: .application(.youtube), name: "YouTube"),
        BlockingRehearsalSamplePick(kind: .webDomain, name: "reddit.com"),
        BlockingRehearsalSamplePick(kind: .application(.tiktok), name: "TikTok"),
        BlockingRehearsalSamplePick(kind: .application(.instagram), name: "Instagram"),
        BlockingRehearsalSamplePick(kind: .application(.messages), name: "Messages"),
        BlockingRehearsalSamplePick(kind: .webDomain, name: "news.example.com"),
    ]

    /// The first `count` of a fixed list that mixes all three kinds, grouped
    /// the way real picks are: categories, apps, websites. Past the list's end
    /// the names repeat with a number, so every tile stays distinct.
    static func tiles(count: Int) -> [BlockingRehearsalPick] {
        let samples = (0..<max(count, 0)).map { index in
            let base = cycle[index % cycle.count]
            let lap = index / cycle.count
            return lap == 0 ? base : BlockingRehearsalSamplePick(kind: base.kind, name: "\(base.name) \(lap + 1)")
        }
        return [0, 1, 2].flatMap { group in
            samples.filter { $0.kind.group == group }.map(BlockingRehearsalPick.sample)
        }
    }
}
#endif
